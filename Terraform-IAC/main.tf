terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket = "my-terraform-state-bucket-route"
    key    = "juice-shop-devsecops/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ── Generate SSH keypair on the fly ─────────────────────────────
resource "tls_private_key" "juice" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "juice" {
  key_name   = "juice-shop-demo"
  public_key = tls_private_key.juice.public_key_openssh
}

# ── Latest Amazon Linux 2023 AMI ────────────────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── Security group: SSH + Juice Shop port 3000 ──────────────────
resource "aws_security_group" "juice" {
  name        = "juice-shop-demo"
  description = "Juice Shop demo deploy target"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── EC2 instance with docker installed via user_data ────────────
resource "aws_instance" "juice" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.juice.key_name
  vpc_security_group_ids = [aws_security_group.juice.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "juice-shop-demo"
  }
}
