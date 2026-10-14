output "public_web_ip" {
  description = "Public IP address of the web server running Nginx"
  value       = aws_instance.public_web.public_ip
}