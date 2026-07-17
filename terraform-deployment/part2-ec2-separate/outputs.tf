output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "frontend_url" {
  value = "http://${aws_instance.frontend.public_ip}:3000"
}

output "backend_url" {
  value = "http://${aws_instance.backend.public_ip}:5000/api/tasks"
}
