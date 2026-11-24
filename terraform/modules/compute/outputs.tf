output "node_sg_id" {
  value = aws_security_group.node.id
}

output "server_public_ip" {
  value = aws_instance.server.public_ip
}

output "server_private_ip" {
  value = aws_instance.server.private_ip
}

output "agent_public_ips" {
  value = aws_instance.agent[*].public_ip
}

# Map with keys known at plan time (needed by for_each in the loadbalancer module)
output "instance_ids" {
  value = merge(
    { server = aws_instance.server.id },
    { for i, a in aws_instance.agent : "agent-${i + 1}" => a.id }
  )
}

output "ami_name" {
  value = data.aws_ami.ubuntu.name
}
