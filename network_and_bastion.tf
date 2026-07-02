# 1. VPC Configuration
resource "aws_vpc" "sonar_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sonar-vpc"
  }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "sonar_igw" {
  vpc_id = aws_vpc.sonar_vpc.id

  tags = {
    Name = "sonar-igw"
  }
}

# 3. Public Subnets (AZ1 & AZ2)
resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.sonar_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sonar-public-subnet-az1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id            = aws_vpc.sonar_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sonar-public-subnet-az2"
  }
}

# 4. Private Subnets (AZ1 & AZ2)
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.sonar_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "sonar-private-subnet-az1"
  }
}

resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.sonar_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "sonar-private-subnet-az2"
  }
}

# 5. Elastic IP & NAT Gateway (For Private Subnet Internet Access)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "sonar_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = {
    Name = "sonar-nat-gateway"
  }
}

# 6. Route Tables (Public & Private)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sonar_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sonar_igw.id
  }

  tags = {
    Name = "sonar-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.sonar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sonar_nat.id
  }

  tags = {
    Name = "sonar-private-rt"
  }
}

# 7. Route Table Associations
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_rt
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_rt
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_rt
}

# 8. Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Allow SSH access to Bastion host"
  vpc_id      = aws_vpc.sonar_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, restrict this to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-bastion"
  }
}

# 9. Bastion Host EC2 Instance (Located in Public Subnet AZ-1)
resource "aws_instance" "bastion" {
  ami           = "ami-0c7217cdde317cfec" # Standard Ubuntu 22.04 LTS in us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_az1.id
  key_name      = "aws-ec2-private-key" # Uses your existing Jenkins SSH Key profile

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "Bastion Host"
  }
}
