#
# Variables Configuration. Check for REPLACE to substitute custom values. Check the description of each
# tag for more information
#

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default = "selco-prod" #REPLACE
}

variable "vpc_cidr_block" {
  description = "CIDR block"
  default = "192.168.0.0/16"
}


variable "network_availability_zones" {
  description = "Configure availability zones configuration for VPC. Leave as default for India. Recommendation is to have subnets in at least two availability zones"
  default = ["ap-south-1b", "ap-south-1a"] #REPLACE IF NEEDED
}

variable "availability_zones" {
  description = "Amazon EKS runs and scales the Kubernetes control plane across multiple AWS Availability Zones to ensure high availability. Specify a comma separated list to have a cluster spanning multiple zones. Note that this will have cost implications"
  default = ["ap-south-1b"] #REPLACE IF NEEDED
}

variable "kubernetes_version" {
  description = "kubernetes version"
  default = "1.28"
}

variable "instance_type" {
  description = "eGov recommended below instance type as a default"
  default = "r5.xlarge"
}

variable "override_instance_types" {
  description = "Arry of instance types for SPOT instances"
  default = ["r5a.large", "r5ad.large", "r5d.large", "m4.xlarge"]

}

variable "number_of_worker_nodes" {
  description = "eGov recommended below worker node counts as default"
  default = "3" #REPLACE IF NEEDED
}

variable "ssh_key_name" {
  description = "ssh key name, not required if your using spot instance types"
  default = "selco-prod-ssh-key" #REPLACE
}


variable "db_name" {
  description = "RDS DB name. Make sure there are no hyphens or other special characters in the DB name. Else, DB creation will fail"
  default = "selcoproddb" #REPLACE
}

variable "db_username" {
  description = "RDS database user name"
  default = "selcoprod" #REPLACE
}

#DO NOT fill in here. This will be asked at runtime
variable "db_password" {}

variable "public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrluFaPQAaBhtK2WGi2KrHaenSljN1SkKNlXiHefUbFZFiR+GqMwL8TN7n7+APFxLh666+ioALA/xHj8bE/0UMs9xXabd2JOO224RZ9WF0nJF1XeTu8vSa0EEhDAl0kQYr2wtGd2c3u59lIVxIx7u779sWsO1npkKF9dO5UIC0T6r47tIHsPnQSn+D64luA03IaokPEKHi1h8QUQvsDFIpJrQvlEgy5wxY7sV4Ws+n0XJR3RbtOdZifj3T93sxE3zHJSBQ9Hcf+qGizRPjTZ2y3EqskU4P9Atgd0U3KGqviEQOxidwIKdTH9UpD0TzPyPZtdi8Z34bRHHDH47j2OAf"
  description = "ssh key"
}

## change ssh key_name eg. digit-quickstart_your-name
