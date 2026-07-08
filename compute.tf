resource "aws_launch_template" "sonar_lt" {
  name_prefix   = "sonar-lt-"
  image_id      = "ami-0c55b159cbfafe1f0" # Update with your Ubuntu 24.04 AMI
  instance_type = "t3.medium"
  key_name      = "your-key-name"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}

resource "aws_autoscaling_group" "sonar_asg" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = aws_subnet.private[*].id
  launch_template { id = aws_launch_template.sonar_lt.id, version = "$Latest" }
}
