locals {
  name = "${var.project}-${terraform.workspace}"
  tags = {
    Project   = var.project
    Owner     = var.owner
    Env       = terraform.workspace
    TTL       = "demo"
    ManagedBy = "terraform"
  }
  repo_root = "${path.module}/../../.."
}

module "network" {
  source   = "../../modules/network"
  name     = local.name
  cidr     = var.vpc_cidr
  az_count = 2
}

module "compute" {
  source               = "../../modules/compute"
  name                 = local.name
  vpc_id               = module.network.vpc_id
  subnet_ids           = module.network.public_subnet_ids
  public_key           = file(pathexpand(var.public_key_path))
  admin_cidr           = var.admin_cidr
  agent_count          = var.agent_count
  server_instance_type = var.server_instance_type
  agent_instance_type  = var.agent_instance_type
}

module "database" {
  source         = "../../modules/database"
  count          = var.enable_rds ? 1 : 0 # switch RDS off for cheap/fast infrastructure tests
  name           = local.name
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnet_ids
  allowed_sg_id  = module.compute.node_sg_id
  password       = var.db_password
  instance_class = var.db_instance_class
}

module "storage" {
  source     = "../../modules/storage"
  name       = local.name
  images_dir = "${local.repo_root}/assets/product-images"
}

module "loadbalancer" {
  source       = "../../modules/loadbalancer"
  name         = local.name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.public_subnet_ids
  instance_ids = module.compute.instance_ids
  node_sg_id   = module.compute.node_sg_id
  node_port    = 30080
}

# ---- Hand-off to Ansible: inventory + variables generated from real resource values ----
resource "local_file" "ansible_inventory" {
  filename        = "${local.repo_root}/ansible/inventory/aws.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    server          = module.compute.server_public_ip
    agents          = module.compute.agent_public_ips
    ssh_user        = "ubuntu"
    ssh_private_key = var.private_key_path
  })
}

resource "local_file" "ansible_vars" {
  filename        = "${local.repo_root}/ansible/group_vars/all/tf.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/tf_vars.tftpl", {
    region          = var.region
    rds_enabled     = var.enable_rds
    rds_host        = one(module.database[*].address)
    rds_port        = one(module.database[*].port)
    rds_user        = one(module.database[*].username)
    rds_db          = one(module.database[*].db_name)
    images_base_url = module.storage.images_base_url
    alb_dns_name    = module.loadbalancer.dns_name
    server_private  = module.compute.server_private_ip
  })
}
