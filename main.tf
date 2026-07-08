# --- DYNAMIC AMIs (Grabs standard, vanilla Ubuntu 24.04) ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- AWS S3 BUCKET FOR STORAGE ---
resource "aws_s3_bucket" "sonar_backup" {
  bucket        = "sandeep0010demo2"
  force_destroy = false # Never force wipe during cleanups

  # Prevent Terraform from destroying this resource
 
}



resource "aws_iam_role_policy" "s3_write_policy" {
  name = "s3-write-permissions"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.sonar_backup.arn}",
          "${aws_s3_bucket.sonar_backup.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "sonarqube-ec2-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
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
    description = "PostgreSQL Replication Sync"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "SSH from Bastion"
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
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
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
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-499"
  }
}

# --- ALB LISTENER ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sonar_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.sonar_tg_az1.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.sonar_tg_az2.arn
        weight = 0
      }
      stickiness {
        enabled  = true
        duration = 86400
      }
    }
  }
}

# --- LAUNCH TEMPLATE FOR ACTIVE NODE ---
resource "aws_launch_template" "sonar_lt_active" {
  name_prefix   = "sonarqube-az1-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.sonar_instance_type
  key_name      = "sandeepkey" # REPLACE WITH YOUR REAL KEY NAME
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
EOF
  )
}

# --- LAUNCH TEMPLATE FOR PASSIVE NODE ---
resource "aws_launch_template" "sonar_lt_passive" {
  name_prefix   = "sonarqube-az2-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.sonar_instance_type
  key_name      = "sandeepkey" # REPLACE WITH YOUR REAL KEY NAME
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
EOF
  )
}
# # --- AUTO SCALING GROUPS ---
resource "aws_autoscaling_group" "sonar_asg_az1" {
  name                = "sonarqube-asg-az1"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az1.arn]
  vpc_zone_identifier = [aws_subnet.private[0].id]

  launch_template {
    id      = aws_launch_template.sonar_lt_active.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "Active-Sonarqube"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "sonar_asg_az2" {
  name                = "sonarqube-asg-az2"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.sonar_tg_az2.arn]
  vpc_zone_identifier = [aws_subnet.private[1].id]

  launch_template {
    id      = aws_launch_template.sonar_lt_passive.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "Passive-SonarQube"
    propagate_at_launch = true
  }
}

# --- AUTOMATED ANSIBLE CONFIGURATION ---
data "aws_instances" "asg_instances_az1" {
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.sonar_asg_az1.name
  }
  depends_on = [aws_autoscaling_group.sonar_asg_az1]
}

data "aws_instances" "asg_instances_az2" {
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.sonar_asg_az2.name
  }
  depends_on = [aws_autoscaling_group.sonar_asg_az2]
}

resource "null_resource" "ansible_trigger" {
  depends_on = [
    aws_autoscaling_group.sonar_asg_az1, 
    aws_autoscaling_group.sonar_asg_az2,
    aws_instance.bastion 
  ]
  
  triggers = { always_run = "${timestamp()}" }

  provisioner "local-exec" {
    environment = {
      LC_ALL = "C.UTF-8"
      LANG   = "C.UTF-8"
    }
    
    command = <<EOT
      echo "Setting correct permissions for SSH key..."
      chmod 400 /var/lib/jenkins/workspace/demo/sandeepkey.pem
      
      echo "Generating inventory file..."
      echo "[sonarqube_nodes]" > inventory.ini
      
      # Use --output text and then format the output specifically to handle spaces/tabs
      aws ec2 describe-instances \
        --filters "Name=tag:aws:autoscaling:groupName,Values=sonarqube-asg-az1,sonarqube-asg-az2" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].PrivateIpAddress" \
        --output text | tr '\t' '\n' >> inventory.ini
      
      echo "Waiting for SSH to be ready..."
      # Use a loop to check if instances are actually reachable
      count=0
      while [ $count -lt 10 ]; do
        if ansible -i inventory.ini sonarqube_nodes -m ping --ssh-common-args="-F ./ssh.cfg -o BatchMode=yes" > /dev/null 2>&1; then
          echo "Instances are reachable!"
          break
        fi
        echo "Waiting for SSH... (attempt $((count+1))/10)"
        sleep 20
        count=$((count+1))
      done
      
      echo "Running Ansible Playbook..."
      ansible-playbook -i "./inventory.ini" playbook.yml \
        --ssh-common-args="-F ./ssh.cfg -o BatchMode=yes" -vvv
    EOT
  }
}
# --- SNS TOPIC FOR ALERTS ---
resource "aws_sns_topic" "sonar_alerts" {
  name = "sonarqube-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.sonar_alerts.arn
  protocol  = "email"
  endpoint  = "sunraw541@gmail.com"
}

# --- CLOUDWATCH ALARM (High CPU Usage) ---
resource "aws_cloudwatch_metric_alarm" "sonar_cpu_alarm" {
  alarm_name          = "sonarqube-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.sonar_alerts.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sonar_asg_az1.name
  }
}
