resource "aws_key_pair" "gitlab_runner_server_key" {
  key_name   = var.gitlab_runer_generated_key_name
  public_key = tls_private_key.dev_key.public_key_openssh

  provisioner "local-exec" { # Generate "terraform-key-pair.pem" in current directory
    command = "echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.gitlab_runer_generated_key_name}'.pem"
  }
  tags = {
    Owner = var.ownerTag
  }
}
resource "tls_private_key" "gitlab_runner_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_instance" "gitlab_runner_server" {
  ami           = "ami-00dfe2c7ce89a450b"
  instance_type = "t2.micro"
  key_name      = "gitlab-runner"
  subnet_id     = "subnet-0e45020447775dc7e"
  tags = {
    Name  = "Gitlab-Runner"
    Owner = var.ownerTag
  }

}


resource "aws_security_group" "gitlab_runner_security_group" {
  name        = "Gitlab runner Security Group"
  description = "Gitlab runner Security Group"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "secure web connection"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }

  ingress {
    description = "secure web connection"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24"]
  }

  ingress {
    description = "insecure web connection"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }
  ingress {
    description = "insecure web connection"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24"]
  }

  ingress {
    description = "ssh port for accessing gitlab"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_address
  }
  ingress {
    description = "ssh port for accessing gitlab"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Gitlab-runner-SG"
    Owner = var.ownerTag
  }
}

resource "aws_network_interface_sg_attachment" "gitlab_runner_sg_attachment" {
  security_group_id    = aws_security_group.gitlab_runner_security_group.id
  network_interface_id = aws_instance.gitlab_runner_server.primary_network_interface_id
}
