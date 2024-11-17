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

# EC2 Instance for Flask App
resource "aws_instance" "flask_app" {
  ami           = "ami-0658158d7ba8fd573"
  instance_type = "t2.micro"

  key_name      = aws_key_pair.flask_key.key_name
  subnet_id     = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.ec2_sg.name]

  user_data = <<-EOT
              #!/bin/bash
              sudo yum update -y
              sudo yum groupinstall -y "Development Tools"
              sudo yum install -y gcc libpq-devel python3-devel git docker
              sudo amazon-linux-extras enable epel
              sudo yum install -y https://repo.ius.io/ius-release-el7.rpm
              sudo yum install -y python312 python312-pip python312-devel
              sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
              sudo alternatives --config python3 <<< 1
              sudo python3 -m ensurepip --upgrade
              sudo pip3 install --upgrade pip
              sudo systemctl start docker
              sudo usermod -a -G docker ec2-user
              git clone https://github.com/chrismalcolm/home-monitor.git /home/ec2-user/app
              cd /home/ec2-user/app
              docker-compose up -d
            EOT
}

# Key Pair for SSH
resource "aws_key_pair" "flask_key" {
  key_name   = "flask-app-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Outputs
output "ec2_instance_public_ip" {
  value = aws_instance.flask_app.public_ip
}
