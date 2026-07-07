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
  bucket        = "sandeep0010demo"
  force_destroy = true 
}

# --- IAM ROLE & PROFILE FOR S3 ACCESS ---
resource "aws_iam_role" "ec2_s3_role" {
  name = "sonarqube-ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
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
  name_prefix            = "sonarqube-az1-template-"
  image_id               = data.aws_ami.ubuntu.id # Uses standard Ubuntu 24.04
  instance_type          = var.sonar_instance_type 
  key_name               = "sonarkey"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s2>/dev/console) 2>&1

# 1. System Requirements & Kernel Optimizations for Elasticsearch
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# 2. Install Dependencies (Java 17, PostgreSQL 16, unzip, AWS CLI)
apt-get update
apt-get install -y openjdk-17-jre unzip awscli postgresql-16 postgresql-contrib-16

# 3. Configure Local Database
sudo -u postgres psql -c "CREATE USER sonar WITH PASSWORD 'sonar_password';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# 4. Download and Install SonarQube (Community Edition)
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip
unzip sonarqube-10.4.1.88267.zip
mv sonarqube-10.4.1.88267 /opt/sonarqube

# 5. Create Dedication User for SonarQube (Elasticsearch cannot run as root)
useradd -r -s /bin/bash sonar
chown -R sonar:sonar /opt/sonarqube

# 6. Configure SonarQube Database Connectivity properties
cat << 'INNER_EOF' > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar_password
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
sonar.web.port=9000
INNER_EOF

# 7. Setup Systemd Service File
cat << 'INNER_EOF' > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
INNER_EOF

# 8. Start Services
systemctl daemon-reload
systemctl enable postgresql
systemctl restart postgresql
systemctl enable sonarqube
systemctl start sonarqube

# 9. Create S3 Backup Sync Cron Job
cat << 'INNER_EOF' > /usr/local/bin/backup_to_s3.sh
#!/bin/bash
BACKUP_NAME="sonar_db_$(date +%F_%R).sql"
sudo -u postgres pg_dump sonarqube > /tmp/$BACKUP_NAME
aws s3 cp /tmp/$BACKUP_NAME s3://sandeep0010demo/backups/$BACKUP_NAME
rm -f /tmp/$BACKUP_NAME
INNER_EOF

chmod +x /usr/local/bin/backup_to_s3.sh
echo "0 * * * * /usr/local/bin/backup_to_s3.sh" | crontab -
EOF
  )
}

# --- LAUNCH TEMPLATE FOR PASSIVE NODE ---
resource "aws_launch_template" "sonar_lt_passive" {
  name_prefix            = "sonarqube-az2-template-"
  image_id               = data.aws_ami.ubuntu.id # Uses standard Ubuntu 24.04
  instance_type          = var.sonar_instance_type 
  key_name               = "sonarkey"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s2>/dev/console) 2>&1

# 1. System Requirements & Kernel Optimizations
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# 2. Install Dependencies
apt-get update
apt-get install -y openjdk-17-jre unzip awscli postgresql-16 postgresql-contrib-16

# 3. Configure Local Database
sudo -u postgres psql -c "CREATE USER sonar WITH PASSWORD 'sonar_password';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# 4. Download and Install SonarQube
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip
unzip sonarqube-10.4.1.88267.zip
mv sonarqube-10.4.1.88267 /opt/sonarqube

# 5. Create Permissions
useradd -r -s /bin/bash sonar
chown -R sonar:sonar /opt/sonarqube

# 6. Configure Properties
cat << 'INNER_EOF' > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar_password
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
sonar.web.port=9000
INNER_EOF

# 7. Setup Systemd Service
cat << 'INNER_EOF' > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
INNER_EOF

systemctl daemon-reload
systemctl enable postgresql
systemctl restart postgresql
systemctl enable sonarqube
systemctl start sonarqube
EOF
  )
}

# --- AUTO SCALING GROUPS ---
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
}
