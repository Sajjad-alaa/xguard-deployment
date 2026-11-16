output "proxy_private_address" {
  description = "Private IP address of XGuard Proxy instance"
  value       = aws_instance.xguard_proxy.private_ip
}

output "instance_id" {
  description = "ID of XGuard Proxy instance"
  value       = aws_instance.xguard_proxy.id
}
