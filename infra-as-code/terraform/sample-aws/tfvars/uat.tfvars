#Backend-config
bucket = "selco-uat-asset"
key    = "digit-bootcamp-setup/terraform.tfstate"
region = "ap-south-1"
dynamodb_table = "selco-uat-asset"
encrypt = true


#Network
vpc_cidr_block = "192.168.0.0/16"

#DB
db_name = "selcoproddb"
db_username = "selcoprod"
engine_version = "14.12"

#EKS
cluster_name = "selco-prod"
kubernetes_version = "1.28"
instance_type= "r5.xlarge"
max_number_of_worker_nodes = "4"
number_of_worker_nodes = "3"
min_number_of_worker_nodes = "2"