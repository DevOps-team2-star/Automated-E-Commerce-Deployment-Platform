output "shop_url" {
  description = "Public URL of the shop (ALB)"
  value       = "http://${module.loadbalancer.dns_name}"
}

output "server_public_ip" {
  value = module.compute.server_public_ip
}

output "agent_public_ips" {
  value = module.compute.agent_public_ips
}

output "rds_endpoint" {
  value = one(module.database[*].address)
}

output "images_bucket" {
  value = module.storage.bucket
}

output "images_base_url" {
  value = module.storage.images_base_url
}

output "ami" {
  value = module.compute.ami_name
}
