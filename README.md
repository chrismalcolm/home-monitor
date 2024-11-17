# Home Monitor

Home Monitor is a Flask-based web application with an intuitive HTML interface designed to help you manage household tasks. It allows users to:
- Add tasks with recurring intervals.
- Track task completions and manage records.
- View and manage tasks through a user-friendly interface.

This project also integrates monitoring using Prometheus and PostgreSQL Exporter, with plans to expand to Grafana for enhanced visualization.

---

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup and Run Locally](#setup-and-run-locally)
- [Deploy to AWS](#deploy-to-aws)
  - [Setting up Terraform](#setting-up-terraform)
  - [Main Infrastructure (`main.tf`)](#main-infrastructure-maintf)
  - [Monitoring Infrastructure (`monitoring.tf`)](#monitoring-infrastructure-monitoringtf)
- [Future Enhancements](#future-enhancements)

---

## Features
1. **Task Management**:

- Add tasks with details such as name, interval, and description.
- Mark tasks as completed and log completion dates.

2. **User Interface**:

- Simple and intuitive web-based interface for managing tasks.

3. **Monitoring**:

- Prometheus monitors the app and PostgreSQL database.
- PostgreSQL Exporter gathers metrics from the database.

## Prerequisites

### Local Development
1. **Docker**:
   - [Install Docker](https://docs.docker.com/get-docker/)

2. **SSH Key** (for deploying to AWS):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

## AWS CLI:

### Install AWS CLI
Follow the [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

---

## Terraform:

### Install Terraform
Follow the [Terraform installation guide](https://developer.hashicorp.com/terraform/install).

---

## AWS Setup for CI/CD

1. In your GitHub repository:
   - Go to **Settings > Secrets and Variables > Actions**.
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_REGION` (e.g., `eu-north-1`).

---

## Setup and Run Locally

### Clone the Repository:
```bash
git clone https://github.com/your-repo/home-monitor.git
cd home-monitor
```
Build the Docker Image:

```bash
docker build -t home-monitor .
Run the Application:
```

```bash
docker run -d -p 5000:5000 --name my-home-monitor home-monitor
Access the Application:
```

Open your browser and navigate to http://localhost:5000.

## Deploy to AWS
### Setting up Terraform
Navigate to the Terraform directory:

bash
Copy code
cd terraform
Initialize Terraform:

bash
Copy code
terraform init
Apply Terraform Configuration:

This deploys both the application and monitoring infrastructure.
bash
Copy code
terraform apply
Review the plan and type yes to confirm.

### Main Infrastructure (main.tf)
This Terraform configuration handles:

EC2 Instances:

Application server running the Flask app.
PostgreSQL database for task storage.
RDS PostgreSQL Database:

Provides a managed relational database for the application.
S3 Buckets (optional for backups/logs).

Key Notes:
EC2 instances are configured with a security group to allow access to the application and database.
The app's Docker container is deployed automatically on the EC2 instance.

### Monitoring Infrastructure (monitoring.tf)
This Terraform configuration sets up:

Prometheus:
Monitors the Flask app and PostgreSQL database.
PostgreSQL Exporter:
Collects database metrics.
Future Plans:
Grafana:
For advanced visualization of metrics.
Verify Deployment
Application:

Access the Flask app via the public IP provided by Terraform output.
URL format: http://<public-ip>:5000.
Prometheus:

Access Prometheus at http://<prometheus-ip>:9090.
PostgreSQL Metrics:

Check Prometheus targets for PostgreSQL Exporter.
Metrics should appear with the prefix pg_.
Troubleshooting
Metrics Not Showing in Prometheus:

Check the Prometheus logs for errors:
bash
Copy code
docker logs prometheus
Verify PostgreSQL Exporter connectivity using psql from the EC2 instance.
Connection Issues:

Ensure the security groups are correctly configured (e.g., ports 5000, 9090, 9187, and 5432 are open as required).

## Future Enhancements
Grafana Integration:

Add Grafana dashboards for enhanced monitoring and visualization.
Scalability:

Use load balancers and auto-scaling for the Flask app.
Backup Mechanism:

Automate database backups using AWS S3 and RDS snapshots.
Alerting:

Configure alerting with Prometheus for task and system metrics.
Feel free to contribute or open issues to suggest improvements!