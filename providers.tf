terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Comment this section out completely:
  # backend "s3" {
  #   bucket         = "sandeep001rawatdemo"
  #   key            = "jenkins/terraform.tfstate"
  #   region         = "us-east-1"
  # }
}
