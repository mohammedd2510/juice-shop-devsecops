output "ec2_host" {
  value = aws_instance.juice.public_dns
}

output "ec2_public_ip" {
  value = aws_instance.juice.public_ip
}

output "ssh_private_key" {
  value     = tls_private_key.juice.private_key_openssh
  sensitive = true
}
