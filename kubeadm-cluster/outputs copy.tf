output "public_dns_control_plane" {
  value = aws_instance.control-plane.public_dns
}
output "public_dns_worker" {
  value = aws_instance.worker-1.public_dns
}