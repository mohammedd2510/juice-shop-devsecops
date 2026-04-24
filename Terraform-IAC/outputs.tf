output "ec2_host" {
  value = aws_instance.juice.public_dns
}

output "ec2_public_ip" {
  value = aws_instance.juice.public_ip
}

