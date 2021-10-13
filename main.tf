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
  profile = "tt-devops"
  region =  "us-east-2"

}

resource "aws_key_pair" "gitlab_server_key" {
  key_name   = var.generated_key_name
  public_key =  tls_private_key.dev_key.public_key_openssh

  provisioner "local-exec" {    # Generate "terraform-key-pair.pem" in current directory
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
  ami           = "ami-0443305dabd4be2bc"
  instance_type = "t2.medium"
  key_name = var.generated_key_name
  subnet_id = "subnet-0e45020447775dc7e"
  tags = {
    Name = var.instance_name
    Owner = var.ownerTag
  }

}


resource "aws_security_group" "gitlab_security_group" {
  name = "Gitlab Security Group"
  description = "Gitlab Security Group"
  vpc_id      = "vpc-05d66555d35008729"
  ingress {
    description      = "custom port for accessing gitlab"
    from_port        = 8000  
    to_port          = 8000
    protocol         = "tcp"
    cidr_blocks      = var.ip_address
  }


  ingress {
    description      = "secure web connection"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.ip_address
  }

  ingress {
    description      = "insecure web connection"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = var.ip_address
  }

  ingress{
    description      = "ssh port for accessing gitlab"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.ip_address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GitlabSG"
    Owner = var.ownerTag
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.gitlab_security_group.id
  network_interface_id = aws_instance.gitlab_server.primary_network_interface_id
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "my-gitlab-elb-log-bucket"
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "gitlab_bucket" {
  bucket = "gitlab-bkt"
  acl    = "private"

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log/"
  }
}
resource "aws_elb" "gitlab_elb" {
  name               = "gitlab-elb"
  availability_zones = ["us-east-2"]

  access_logs {
    bucket  = aws_s3_bucket.gitlab_bucket.bucket
    bucket_prefix = "gitlab_elb"
    enabled = true
  }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = [aws_instance.gitlab_server.id]
  cross_zone_load_balancing   = false
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "gitlab-terraform-elb"
    Owner = var.ownerTag
  }
}

resource "aws_elb_attachment" "gitlab_lb_attachtment" {
  elb      = aws_elb.gitlab_elb.id
  instance = aws_instance.gitlab_server.id

}


