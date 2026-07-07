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
    path                = "/"
    port                = "9000"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-499" 
  }
}

resource "aws_lb_target_group" "sonar_tg_az2" {
  name     = "sonarqube-tg-az2"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path                = "/"
    port                = "9000"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-499" 
  }
}

# --- ALB LISTENERS & HOST ROUTING RULES ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sonar_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.sonar_tg_az1.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.sonar_tg_az2.arn
        weight = 50
      }
      
      stickiness {
        enabled  = true
        duration = 86400
      }
    }
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

# --- LAUNCH TEMPLATE FOR AZ1 NODE ---
resource "aws_launch_template" "sonar_lt_active" {
  name_prefix            = "sonarqube-az1-template-"
  image_id               = "ami-02c66bc635e6563a2" 
  instance_type          = var.sonar_instance_type 
  key_name               = "sonarkey"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
# 1. Increase memory mapping limits for internal Elasticsearch engine
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# 2. Force configuration properties to target the local database
sed -i 's|^sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube|g' /opt/sonarqube/conf/sonar.properties

# 3. Reload daemon and restart clean local stack
systemctl daemon-reload
systemctl restart postgresql
systemctl restart sonarqube
EOF
  )
}

# --- LAUNCH TEMPLATE FOR AZ2 NODE ---
resource "aws_launch_template" "sonar_lt_passive" {
  name_prefix            = "sonarqube-az2-template-"
  image_id               = "ami-0f592c70a4fec5862" 
  instance_type          = var.sonar_instance_type 
  key_name               = "sonarkey"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
# 1. Increase memory mapping limits for internal Elasticsearch engine
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# 2. Force configuration properties to target the local database
sed -i 's|^sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube|g' /opt/sonarqube/conf/sonar.properties

# 3. Reload daemon and restart clean local stack
systemctl daemon-reload
systemctl restart postgresql
systemctl restart sonarqube
EOF
  )
}

# --- AUTO SCALING GROUPS ---
resource "aws_autoscaling_group" "sonar_asg_az1" {
  name                = "sonarqube-asg-az1"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az1.arn]
  vpc_zone_identifier = [aws_subnet.private[0].id]
  
  health_check_grace_period = 600

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
  
  health_check_grace_period = 600

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

# --- NOTIFICATIONS (SNS) ---
resource "aws_sns_topic" "sonar_alerts" {
  name = "sonarqube-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.sonar_alerts.arn
  protocol  = "email"
  endpoint  = "sunraw541@gmail.com" 
}

# --- MONITORING ALARMS (CLOUDWATCH) ---
resource "aws_cloudwatch_metric_alarm" "node1_unhealthy" {
  alarm_name          = "sonarqube-node01-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Triggers if Node 1 drops out of the Load Balancer target group."
  alarm_actions       = [aws_sns_topic.sonar_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.sonar_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.sonar_tg_az1.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "node2_unhealthy" {
  alarm_name          = "sonarqube-node02-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Triggers if Node 2 drops out of the Load Balancer target group."
  alarm_actions       = [aws_sns_topic.sonar_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.sonar_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.sonar_tg_az2.arn_suffix
  }
}
