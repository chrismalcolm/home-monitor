output "app_url" {
  description = "Public URL of the Flask app"
  value       = "http://${aws_instance.flask_app.public_ip}:5000"
}

output "postgres_user" {
  value = "username" # Replace with actual Terraform variable or hardcoded value
}

output "postgres_password" {
  value = "password" # Replace with actual Terraform variable or hardcoded value
}

output "postgres_host" {
  value = aws_db_instance.postgres.address
}
