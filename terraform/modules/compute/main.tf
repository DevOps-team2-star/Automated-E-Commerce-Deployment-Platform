# k3s nodes: 1 server + var.agent_count agents (Ubuntu 24.04), configured later by Ansible.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = var.public_key
}

resource "aws_security_group" "node" {
  name        = "${var.name}-nodes"
  description = "k3s nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-nodes" }
  # No inline rules: all rules are separate resources, because the loadbalancer module adds one too.
  # (Mixing inline rules and rule resources on one group makes Terraform remove the other rules.)
}

# SSH for Ansible and 6443 for kubectl/Jenkins - from your IP only. for_each over a map variable.
resource "aws_vpc_security_group_ingress_rule" "admin" {
  for_each          = var.admin_ports
  security_group_id = aws_security_group.node.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  description       = each.key
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  security_group_id            = aws_security_group.node.id
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "-1"
  description                  = "node-to-node: k3s API, flannel VXLAN, kubelet, pods"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.node.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "all outbound (apt, k3s install, Docker Hub pulls)"
}

# The ALB -> NodePort 30080 rule lives in the loadbalancer module (it owns the ALB security group).

locals {
  root_volume = {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.node.id]
  key_name               = aws_key_pair.this.key_name

  root_block_device {
    volume_type           = local.root_volume.volume_type
    volume_size           = local.root_volume.volume_size
    delete_on_termination = local.root_volume.delete_on_termination
    encrypted             = local.root_volume.encrypted
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = { Name = "${var.name}-k3s-server", Role = "k3s-server" }
}

resource "aws_instance" "agent" {
  count                  = var.agent_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.agent_instance_type
  subnet_id              = var.subnet_ids[(count.index + 1) % length(var.subnet_ids)] # spread across AZs
  vpc_security_group_ids = [aws_security_group.node.id]
  key_name               = aws_key_pair.this.key_name

  root_block_device {
    volume_type           = local.root_volume.volume_type
    volume_size           = local.root_volume.volume_size
    delete_on_termination = local.root_volume.delete_on_termination
    encrypted             = local.root_volume.encrypted
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.name}-k3s-agent-${count.index + 1}", Role = "k3s-agent" }
}
