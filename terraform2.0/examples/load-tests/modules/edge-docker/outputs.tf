output "edge_private_address" {
  value = aws_instance.xguard_edge.private_ip
}

output "instance_id" {
  value = aws_instance.xguard_edge.id
}
