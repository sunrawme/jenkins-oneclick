resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id
  ingress { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id
  # Allow SSH from Bastion SG ID
  ingress { from_port = 22, to_port = 22, protocol = "tcp", security_groups = [aws_security_group.bastion_sg.id] }
  # Allow App Port (9000) from ALB
  ingress { from_port = 9000, to_port = 9000, protocol = "tcp", security_groups = [aws_security_group.alb_sg.id] }
  egress  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}
