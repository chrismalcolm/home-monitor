output "app_url" {
  description = "Public URL of the Flask app"
  value       = "http://${aws_instance.flask_app.public_ip}:5000"
}
