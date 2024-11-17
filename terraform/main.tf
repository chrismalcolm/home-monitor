terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region = "eu-north-1"
}

# Networking: VPC, Subnets, Security Groups
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = "flask-app-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "flask-app-ec2-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "flask-app-rds-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.micro"
  db_name              = "home_monitor_db"
  username             = "username"
  password             = "password"
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnets.name
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "flask-app-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# IAM Role and Policy for EC2 to Access ECR
resource "aws_iam_role" "ec2_role" {
  name               = "flask-app-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_ecr_policy" {
  name   = "flask-app-ecr-policy"
  role   = aws_iam_role.ec2_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the IAM Role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "flask-app-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance for Flask App
resource "aws_instance" "flask_app" {
  ami           = "ami-0658158d7ba8fd573"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.flask_key.key_name
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOT
              #!/bin/bash
              # Update and install Docker
              sudo yum update -y
              sudo amazon-linux-extras enable docker
              sudo yum install -y docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
            EOT
}

# Create Elastic IP
resource "aws_eip" "flask_eip" {
  instance = aws_instance.flask_app.id
}

# Key Pair for SSH
resource "aws_key_pair" "flask_key" {
  key_name   = "flask-app-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
