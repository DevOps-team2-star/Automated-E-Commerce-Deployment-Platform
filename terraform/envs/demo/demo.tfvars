# Demo environment. admin_cidr and db_password are passed by Jenkins (TF_VAR_admin_cidr, TF_VAR_db_password).
region               = "eu-central-1"
project              = "ecom"
agent_count          = 1
server_instance_type = "t3.medium"
agent_instance_type  = "t3.small"
enable_rds           = true
db_instance_class    = "db.t4g.micro"
