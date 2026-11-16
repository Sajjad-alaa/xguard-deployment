output "edge_private_address" {
  description = "Private IP address of XGuard Edge instance"
  value       = aws_instance.xguard_edge.private_ip
}

output "instance_id" {
  description = "ID of XGuard Edge instance"
  value       = aws_instance.xguard_edge.id
}
