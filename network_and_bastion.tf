# ==============================================================================
# --- CORE NETWORKING (VPC & SUBNETS) ---
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sonarqube-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "sonarqube-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = count.index == 0 ? "10.0.1.0/24" : "10.0.2.0/24"
  availability_zone       = count.index == 0 ? "us-east-1a" : "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sonarqube-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = count.index == 0 ? "10.0.3.0/24" : "10.0.4.0/24"
  availability_zone = count.index == 0 ? "us-east-1a" : "us-east-1b"

  tags = {
    Name = "sonarqube-private-subnet-${count.index + 1}"
  }
}

# ==============================================================================
# --- NAT GATEWAYS FOR PRIVATE SUBNET OUTBOUND INTERNET ---
# ==============================================================================

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "sonarqube-nat-gw-${count.index + 1}"
  }
}

# ==============================================================================
# --- ROUTE TABLES & ASSOCIATIONS ---
# ==============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "sonarqube-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "sonarqube-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ==============================================================================
# --- BASTION COMPUTE RESOURCE & ITS SECURITY GROUP ---
# ==============================================================================

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Control traffic moving through the public jump box"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-security-group"
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m7i-flex.large"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "jenkins-ssh-key"

  tags = {
    Name = "Bastion Host"
    Role = "Bastion-Jump-Box"
  }
}
