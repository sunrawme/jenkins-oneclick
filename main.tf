# ==============================================================================
# --- SECURITY GROUPS ---
# ==============================================================================

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

resource "aws_security_group" "efs_sg" {
  name   = "efs-security-group"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

# ==============================================================================
# --- STORAGE LAYER (EFS) ---
# ==============================================================================

resource "aws_efs_file_system" "sonar_shared" {
  creation_token = "sonar-shared-efs"
  tags           = { Name = "SonarQube-EFS" }
}

resource "aws_efs_mount_target" "alpha" {
  count           = 2
  file_system_id  = aws_efs_file_system.sonar_shared.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# ==============================================================================
# --- COMPUTE & LOAD BALANCING (WITH RULES & ASG) ---
# ==============================================================================

resource "aws_lb" "sonar_alb" {
  name               = "sonarqube-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

# Target Group 1 - Pinned to AZ1
resource "aws_lb_target_group" "sonar_tg_az1" {
  name     = "sonarqube-tg-az1"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path                = "/api/system/status"
    port                = "9000"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# Target Group 2 - Pinned to AZ2
resource "aws_lb_target_group" "sonar_tg_az2" {
  name     = "sonarqube-tg-az2"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path                = "/api/system/status"
    port                = "9000"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# Main Application Load Balancer HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sonar_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  # Default action path per diagram: forward to TG-AZ1
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_tg_az1.arn
  }
}

# Rule A: Host-Based Routing Rule for sonar1.company.com -> TG-AZ1
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

# Rule B: Host-Based Routing Rule for sonar2.company.com -> TG-AZ2
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

# Base OS Lookup Image data resource
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# Shared Launch Template for Auto Scaling Groups
resource "aws_launch_template" "sonar_lt" {
  name_prefix   = "sonarqube-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = "jenkins-ssh-key"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              snap wait system seed.loaded
              systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sonarqube-asg-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group 1: Pinned to Private Subnet 1 (AZ-1)
resource "aws_autoscaling_group" "sonar_asg_az1" {
  name                = "sonarqube-asg-az1"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az1.id]
  vpc_zone_identifier = [aws_subnet.private[0].id]

  launch_template {
    id      = aws_launch_template.sonar_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "SonarQube-01 (co-located DB)"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "active"
    propagate_at_launch = true
  }
}

# Auto Scaling Group 2: Pinned to Private Subnet 2 (AZ-2)
resource "aws_autoscaling_group" "sonar_asg_az2" {
  name                = "sonarqube-asg-az2"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az2.id]
  vpc_zone_identifier = [aws_subnet.private[1].id]

  launch_template {
    id      = aws_launch_template.sonar_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "SonarQube-02 (co-located DB)"
    propagate_at_launch = true
  }

  tag {
    key                 = "Value"
    value               = "passive"
    propagate_at_launch = true
  }
}

# ==============================================================================
# --- MONITORING & ALERTS ---
# ==============================================================================

resource "aws_sns_topic" "alerts" {
  name = "sonarqube-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "sunraw541@gmail.com"
}

# Target Group Unhealthy Host Count Tracking Alarm (Tracks both TGs)
resource "aws_cloudwatch_metric_alarm" "tg1_unhealthy" {
  alarm_name          = "sonarqube-tg-az1-unhealthy-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.sonar_tg_az1.arn_suffix
    LoadBalancer = aws_lb.sonar_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "tg2_unhealthy" {
  alarm_name          = "sonarqube-tg-az2-unhealthy-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.sonar_tg_az2.arn_suffix
    LoadBalancer = aws_lb.sonar_alb.arn_suffix
  }
}

# Group-Wide CPU Utilization Tracking Alarms
resource "aws_cloudwatch_metric_alarm" "asg_az1_cpu" {
  alarm_name          = "sonarqube-asg-az1-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Monitors average CPU load across ASG Pinned to AZ1"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sonar_asg_az1.name
  }
}

resource "aws_cloudwatch_metric_alarm" "asg_az2_cpu" {
  alarm_name          = "sonarqube-asg-az2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Monitors average CPU load across ASG Pinned to AZ2"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sonar_asg_az2.name
  }
}

# ==============================================================================
# --- IAM ROLE FOR SSM ---
# ==============================================================================

resource "aws_iam_role" "ec2_ssm_role" {
  name = "sonarqube-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "sonarqube-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
