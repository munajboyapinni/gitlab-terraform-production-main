variable "username" {
  default = "tt-devops"
}
variable "db_password" {
  description = "RDS root user password"
  type       = string
  sensitive   = true
}