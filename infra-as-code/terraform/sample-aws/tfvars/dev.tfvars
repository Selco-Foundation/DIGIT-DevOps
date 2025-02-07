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
kubernetes_version = "1.32"
ami_id = "ami-0f4a7f3d1231aaf54"
instance_type= "r5ad.large"
max_number_of_worker_nodes = "3"
number_of_worker_nodes = 2
min_number_of_worker_nodes = "1"
coredns-version = "v1.11.4-eksbuild.2"
kube-proxy-version = "v1.32.0-eksbuild.2"
aws_ebs_csi_driver = "v1.39.0-eksbuild.1"


# Kubernetes-version: 1.29
# ami: ami-0faa3ede6ae0dc2f3
# version:
# kube-proxy: "v1.29.11-eksbuild.2"
# coredns: "v1.11.4-eksbuild.2"
# aws-ebs-csi-driver: "v1.39.0-eksbuild.1"

# Kubernetes-version: 1.30
# ami: ami-0308b0e27f09b0b25
# version:
# kube-proxy: v1.30.7-eksbuild.2
# coredns: "v1.11.4-eksbuild.2"
# aws-ebs-csi-driver: "v1.39.0-eksbuild.1"

# Kubernetes-version: 1.31
# ami: ami-0133d24dfaa24814a
# version:
# kube-proxy: v1.31.3-eksbuild.2
# coredns: "v1.11.4-eksbuild.2"
# aws-ebs-csi-driver: "v1.39.0-eksbuild.1"

# Kubernetes-version: 1.32
# ami:  ami-0f4a7f3d1231aaf54
# version:
# kube-proxy: v1.32.0-eksbuild.2
# coredns: "v1.11.4-eksbuild.2"
# aws-ebs-csi-driver: "v1.39.0-eksbuild.1"