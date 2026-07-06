# --- DYNAMIC AMIs ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- APPLICATION SECURITY GROUPS ---
resource "aws_security_group" "alb_sg" {
  name   = "alb-security-group"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "sonar-ec2-security-group"
  vpc_id = aws_vpc.main.id
  
  ingress {
    description     = "SonarQube Web Port from ALB"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description     = "Inter-node cluster DB sync"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    self            = true
  }
  ingress {
    description     = "SSH strictly from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- LOAD BALANCING ---
resource "aws_lb" "sonar_alb" {
  name               = "sonarqube-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "sonar_tg_az1" {
  name     = "sonarqube-tg-az1"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path = "/api/system/status"
    port = "9000"
  }
}

resource "aws_lb_target_group" "sonar_tg_az2" {
  name     = "sonarqube-tg-az2"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path = "/api/system/status"
    port = "9000"
  }
}

# --- ALB LISTENERS & HOST ROUTING RULES ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sonar_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_tg_az1.arn
  }
}

resource "aws_lb_listener_rule" "sonar1_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_tg_az1.arn
  }

  condition {
    host_header {
      values = ["sonar1.company.com"]
    }
  }
}

resource "aws_lb_listener_rule" "sonar2_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_tg_az2.arn
  }

  condition {
    host_header {
      values = ["sonar2.company.com"]
    }
  }
}

# --- LAUNCH TEMPLATE FOR ACTIVE NODE ---
resource "aws_launch_template" "sonar_lt_active" {
  name_prefix   = "sonarqube-active-template-"
  image_id      = "ami-0fa7042ecfdecafcc" # From your sonar-active image
  instance_type = var.instance_type
  key_name      = "jenkins-ssh-key"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode("#!/bin/bash\necho 'Booting Active SonarQube Node...'")
}

# --- LAUNCH TEMPLATE FOR PASSIVE NODE ---
resource "aws_launch_template" "sonar_lt_passive" {
  name_prefix   = "sonarqube-passive-template-"
  image_id      = "ami-057e0f5a47ebc3a4d" # From your sonar-passive image
  instance_type = var.instance_type
  key_name      = "jenkins-ssh-key"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode("#!/bin/bash\necho 'Booting Passive SonarQube Node...'")
}

# --- AUTO SCALING GROUPS ---
resource "aws_autoscaling_group" "sonar_asg_az1" {
  name                = "sonarqube-asg-az1"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az1.arn]
  vpc_zone_identifier = [aws_subnet.private[0].id]

  launch_template {
    id      = aws_launch_template.sonar_lt_active.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sonarqube-asg-node-01"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "sonar_asg_az2" {
  name                = "sonarqube-asg-az2"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az2.arn]
  vpc_zone_identifier = [aws_subnet.private[1].id]

  launch_template {
    id      = aws_launch_template.sonar_lt_passive.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sonarqube-asg-node-02"
    propagate_at_launch = true
  }
}
