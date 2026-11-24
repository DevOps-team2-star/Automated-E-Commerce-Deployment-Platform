variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Public subnets; the server goes in the first, agents are spread over all"
  type        = list(string)
}

variable "public_key" {
  description = "SSH public key used by Ansible"
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (x.x.x.x/32): allowed to SSH and reach the Kubernetes API"
  type        = string
}

variable "admin_ports" {
  description = "Ports opened to admin_cidr only"
  type        = map(number)
  default     = { ssh = 22, kubernetes-api = 6443 }
}

variable "agent_count" {
  type    = number
  default = 1
}

variable "server_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "agent_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami_id" {
  description = "Explicit AMI id; empty = latest Canonical Ubuntu 24.04"
  type        = string
  default     = ""
}
