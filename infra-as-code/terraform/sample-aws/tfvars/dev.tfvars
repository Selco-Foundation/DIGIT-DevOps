#Backend-config
bucket = "selco-dev-githubactions-bucket"
key    = "digit-bootcamp-setup/terraform.tfstate"
region = "ap-south-1"
dynamodb_table = "selco-dev-githubactions-bucket"
encrypt = true


#Network
vpc_cidr_block = "192.168.0.0/16"

#DB
db_name = "selcodevdb"
db_username = "selco_dev_admin"
engine_version = "14.12"
db_instance_class = "db.t3.medium"

#EKS
cluster_name = "selco-dev"
kubernetes_version = "1.29"
instance_type= "r5ad.large"
max_number_of_worker_nodes = "3"
number_of_worker_nodes = "3"
min_number_of_worker_nodes = "1"