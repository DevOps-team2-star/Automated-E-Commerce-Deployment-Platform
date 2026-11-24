variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "ecom"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.project))
    error_message = "project: 2-15 chars, lowercase letters, digits and dashes (used in AWS resource names)."
  }
}

variable "owner" {
  type    = string
  default = "devops-team2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_cidr" {
  description = "Public IP of the machine running Jenkins/Ansible, as x.x.x.x/32 (SSH + Kubernetes API)"
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a CIDR like 41.33.12.7/32 and must not be 0.0.0.0/0."
  }
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/ecom-demo.pub"
}

variable "private_key_path" {
  description = "Written into the Ansible inventory"
  type        = string
  default     = "~/.ssh/ecom-demo"
}

variable "agent_count" {
  description = "Number of k3s agent nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.agent_count >= 0 && var.agent_count <= 3
    error_message = "Keep 0-3 agents to control cost."
  }
}

variable "server_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "agent_instance_type" {
  type    = string
  default = "t3.small"
}

variable "enable_rds" {
  description = "false = no RDS (faster, cheaper infra tests; the app then has no database)"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_password" {
  description = "RDS master password (from the Jenkins credential db-password via TF_VAR_db_password)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8 && !can(regex("[/@\" ]", var.db_password))
    error_message = "db_password: at least 8 characters, and no / @ \" or spaces (RDS rules)."
  }
}

variable "aws_endpoint" {
  description = "AWS emulator URL, e.g. http://localhost:4566. Empty = real AWS."
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "Use this AMI instead of looking up Ubuntu 24.04 (emulators have their own fake AMIs)"
  type        = string
  default     = ""
}

variable "enable_alb" {
  description = "false = skip the load balancer (LocalStack's free tier has no ELBv2)"
  type        = bool
  default     = true
}
