variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones (RDS subnet groups need at least 2)"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}
