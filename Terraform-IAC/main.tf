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
  }
}

provider "aws" {
  region = var.region
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


# ── IAM role + instance profile for SSM ─────────────────────────
resource "aws_iam_role" "ec2_ssm" {
  name = "juice-shop-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "juice-shop-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name
}


# ── Security group: Juice Shop port 3000 only (SSH removed) ─────
resource "aws_security_group" "juice" {
  name        = "juice-shop-demo"
  description = "Juice Shop demo deploy target"

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


# ── EC2 instance with docker + SSM agent ────────────────────────
resource "aws_instance" "juice" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.juice.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
    systemctl enable --now amazon-ssm-agent
  EOF

  tags = {
    Name = "juice-shop-demo"
  }
}


