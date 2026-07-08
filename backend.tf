terraform {
  backend "s3" {
    bucket         = "sandeep0010demo"
    key            = "sonarqube/infrastructure/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}
