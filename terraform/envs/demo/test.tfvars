# Cheaper variant for Lab 7-E (workspace "test"): no RDS, no agents, smaller server.
region               = "eu-central-1"
project              = "ecom"
agent_count          = 0
server_instance_type = "t3.small"
enable_rds           = false
