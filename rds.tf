
resource "aws_db_instance" "gitlab" {
  identifier           = "gitlab"
  instance_class       = "db.t3.medium"
  allocated_storage    = 5
  engine               = "postgres"
  engine_version       = "13.1"
  name                 = "devopsdb"
  username             = var.username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.gitlab_db_subnet_group.name
  parameter_group_name = aws_db_parameter_group.gitlab.name
  publicly_accessible  = true
  skip_final_snapshot  = false

  tags = {
    Owner = var.ownerTag
  }
}
resource "aws_db_subnet_group" "gitlab_db_subnet_group" {
  name       = "gitlab_db_subnet_group"
  subnet_ids = ["subnet-0c735a58768e0fcd9", "subnet-04eaaa75a7b053324"]

  tags = {
    Name  = "My DB subnet group"
    Owner = var.ownerTag
  }
}
resource "aws_db_parameter_group" "gitlab" {
  name   = "gitlab-db"
  family = "postgres13"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}
