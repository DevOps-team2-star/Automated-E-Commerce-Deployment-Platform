variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Public subnets (at least two AZs)"
  type        = list(string)
}

variable "instance_ids" {
  description = "Map name => EC2 instance id to register as targets"
  type        = map(string)
}

variable "node_sg_id" {
  type = string
}

variable "node_port" {
  description = "NodePort of the nginx Service on every node"
  type        = number
  default     = 30080
}

variable "public_ports" {
  description = "Ports the ALB accepts from the internet"
  type        = list(number)
  default     = [80]
}
