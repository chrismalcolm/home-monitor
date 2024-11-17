# Security Group for Prometheus EC2
resource "aws_security_group" "prometheus_sg" {
  name   = "prometheus-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22 # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090 # Prometheus
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to external access for testing; restrict later
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for PostgreSQL Exporter
resource "aws_security_group" "postgres_exporter_sg" {
  name   = "postgres-exporter-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22 # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9187 # PostgreSQL Exporter
    to_port     = 9187
    protocol    = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id] # Allow Prometheus to access
  }

  ingress {
    from_port   = 5432 # PostgreSQL Database
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# PostgreSQL Exporter Deployment on EC2
resource "aws_instance" "postgres_exporter" {
  ami           = "ami-0658158d7ba8fd573" # Amazon Linux 2
  instance_type = "t3.micro"
  key_name      = aws_key_pair.flask_key.key_name
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.postgres_exporter_sg.id]

  user_data = <<-EOT
          #!/bin/bash
          sudo yum update -y
          sudo amazon-linux-extras enable docker
          sudo yum install -y docker
          sudo service docker start
          sudo usermod -a -G docker ec2-user
          docker run -d --name postgres-exporter -p 9187:9187 \
          -e DATA_SOURCE_NAME="postgresql://username:password@terraform-20241117013917092000000005.c1gcsgwk6uur.eu-north-1.rds.amazonaws.com:5432/postgres?sslmode=disable" \
          prometheus/postgres-exporter
        EOT

  user_data_replace_on_change = true

  tags = {
    Name = "postgres-exporter"
  }
}

# Prometheus EC2 Instance
resource "aws_instance" "prometheus" {
  ami           = "ami-0658158d7ba8fd573" # Amazon Linux 2
  instance_type = "t3.micro"
  key_name      = aws_key_pair.flask_key.key_name
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOT
          #!/bin/bash
          sudo yum update -y
          sudo amazon-linux-extras enable docker
          sudo yum install -y docker
          sudo service docker start
          sudo usermod -a -G docker ec2-user

          # Create Prometheus configuration
          cat <<EOF > /home/ec2-user/prometheus.yml
          global:
            scrape_interval: 10s
          scrape_configs:
            - job_name: "postgres-exporter"
              static_configs:
                - targets: ["${aws_instance.postgres_exporter.private_ip}:9187"]
          EOF

          # Run Prometheus
          docker run -d --name prometheus -p 9090:9090 \
          -v /home/ec2-user/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
          prom/prometheus
        EOT

  user_data_replace_on_change = true

  tags = {
    Name = "prometheus-instance"
  }

}

# Outputs for Monitoring Setup
output "prometheus_url" {
  value = "http://${aws_instance.prometheus.public_ip}:9090"
}
