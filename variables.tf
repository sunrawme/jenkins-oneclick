variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"] # <-- Fix here
}

variable "sonar_instance_type" {
  type    = string
  default = "m7i-flex.large"
}

variable "ssh_key_name" {
  description = "The name of the AWS EC2 Key Pair"
  type        = string
  default     = "sandeepkey"
}
