output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnets" {
  value = module.network.private_subnets
}

output "public_subnets" {
  value = module.network.public_subnets
}


output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

# output "es_master_volume_ids" {
#   value = "${module.es-master.volume_ids}"
# }
#
# output "es_data_volume_ids" {
#   value = "${module.es-data-v1.volume_ids}"
# }

# output "db_instance_endpoint" {
#   value = module.db.db_instance_endpoint
# }
#
#
# output "db_instance_name" {
#   description = "The database name"
#   value       = module.db.db_instance_name
# }
#
# output "db_instance_username" {
#   description = "The master username for the database"
#   value       = module.db.db_instance_username
#   sensitive   = true
# }
#
# output "db_instance_port" {
#   description = "The database port"
#   value       = module.db.db_instance_port
# }

output "zone" {
  value = var.availability_zones
}

output "worker_security_group_id" {
  description = "The security group id of worker nodes"
  value       = module.eks.worker_security_group_id
}

output "eks_cluster_iam_role_name" {
  value = module.eks.cluster_iam_role_name
}

