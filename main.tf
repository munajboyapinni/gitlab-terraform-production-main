terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"

}

resource "aws_key_pair" "gitlab_server_key" {
  key_name   = var.generated_key_name
  public_key = tls_private_key.dev_key.public_key_openssh

  provisioner "local-exec" { # Generate "terraform-key-pair.pem" in current directory
    command = "echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.generated_key_name}'.pem"
  }
  tags = {
    Owner = var.ownerTag
  }
}
resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_instance" "gitlab_server" {
  ami           = "ami-0000280ed4ae3b00c"
  instance_type = "t2.medium"
  key_name      = "gitlab-production-version"
  associate_public_ip_address = true
  subnet_id     = "subnet-0e45020447775dc7e"
  tags = {
    Name  = var.instance_name
    Owner = var.ownerTag
  }

}

resource "aws_security_group" "gitlab_security_group" {
  name        = "Gitlab Security Group"
  description = "Gitlab Security Group"
  vpc_id      = var.vpc_id
  ingress {
    description = "custom port for accessing gitlab"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }


  ingress {
    description = "secure web connection"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }

  ingress {
    description = "insecure web connection"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }

  ingress {
    description = "ssh port for accessing gitlab"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.ip_address
  }

  tags = {
    Name  = "GitlabSG"
    Owner = var.ownerTag
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.gitlab_security_group.id
  network_interface_id = aws_instance.gitlab_server.primary_network_interface_id
}

resource "aws_s3_bucket" "tt_gitlab_log_bucket" {
  bucket = "my-gitlab-elb-log-bucket001"
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "tt_gitlab_bucket" {
  bucket = "gitlablogbucket"
  acl    = "private"

  logging {
    target_bucket = aws_s3_bucket.tt_gitlab_log_bucket.id
    target_prefix = "gitlab-server-log/"
  }
}
