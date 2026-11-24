variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets in at least two AZs"
  type        = list(string)
}

variable "allowed_sg_id" {
  description = "Security group allowed to connect on 5432 (the k3s nodes)"
  type        = string
}

variable "username" {
  type    = string
  default = "shopadmin"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}
