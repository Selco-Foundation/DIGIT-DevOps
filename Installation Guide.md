# AWS EKS Infrastructure Installation Guide

## Overview
This guide provides step-by-step instructions to deploy an AWS EKS cluster using Terraform. The infrastructure includes VPC, subnets, EKS cluster, and worker nodes.

## Prerequisites

### 1. Required Tools
- **AWS CLI** 
- **Terraform** 
- **kubectl** (compatible with your EKS version)
- **Git**

### 2. AWS Account Requirements
- AWS account with appropriate permissions
- IAM user/role with the following managed policies:
    - `AmazonEKSClusterPolicy`
    - `AmazonEKSWorkerNodePolicy`
    - `AmazonEKS_CNI_Policy`
    - `AmazonEC2ContainerRegistryReadOnly`
    - `AmazonVPCFullAccess`
    - `AmazonEC2FullAccess`
    - `IAMFullAccess` (for creating service roles)
    - `AutoScalingFullAccess`
- Service-linked roles will be created automatically

**Note**: For production environments, consider using more restrictive policies following the principle of least privilege.

### 3. S3 Backend Setup
- Create an S3 bucket for Terraform state storage
- Enable versioning on the S3 bucket
- Create a DynamoDB table for state locking (optional but recommended)

## Cost Estimation
Approximate monthly costs for the default configuration:
- EKS Control Plane: ~$73
- EC2 Instances (3x r5a.xlarge): ~$310 ($0.143/hour × 24h × 30 days × 3 instances)
- EBS Storage (GP3): ~$12/month ( 130GB × $0.091)
- NAT Gateway: ~$45 ($0.056/hour + $0.056/GB processed)
- Classic Load Balancer: ~$18 ($0.0266/hour)
- Data Transfer: Variable
- **Total**: ~$458/month (excluding RDS, data transfer, and 18% GST)

**Note**: Costs may vary based on actual usage, region, and data transfer. Consider using Reserved instances for cost optimization.


## Installation Steps

### Step 1: Clone the Repository
```bash
git clone https://github.com/Selco-Foundation/DIGIT-DevOps.git
cd Selco/DIGIT-DevOps/infra-as-code/terraform/sample-aws
```

### Step 2: Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region
```

### Step 3: Configure Terraform Backend
Create a `backend.tf` file or configure the S3 backend:
```bash
terraform init -backend-config="bucket=your-terraform-state-bucket" \
               -backend-config="key=eks-cluster/terraform.tfstate" \
               -backend-config="region=ap-south-1" \
               -backend-config="dynamodb_table=table_name" \
               -backend-config="encrypt=true" \
               -reconfigure
```

### Step 4: Create Variables File
Create a `terraform.tfvars` file with your environment specific configuration:

```hcl
# Cluster Configuration
cluster_name = "your-cluster-name"
kubernetes_version = "1.28"                 # Current stable version
kubeconfig_name = "your-kubeconfig"

# Network Configuration
vpc_cidr_block = "10.0.0.0/16"             # VPC CIDR block
availability_zones = ["us-west-2a", "us-west-2b"]  # AZs for high availability

# Worker Node Configuration  
node_name = "worker-nodes"
instance_type = "t3.medium"                 # Adjust based on workload requirements
number_of_worker_nodes = 2                 # Desired capacity
min_number_of_worker_nodes = 1             # Minimum for auto-scaling
max_number_of_worker_nodes = 5             # Maximum for auto-scaling
ami_id = "ami-0abcdef1234567890"           # Use latest EKS-optimized AMI ID for your region

# EKS Addons Versions
kube-proxy-version = "v1.28.2-eksbuild.2"
coredns-version = "v1.10.1-eksbuild.4"
aws_ebs_csi_driver = "v1.24.1-eksbuild.1"

# Database Configuration (if enabled)
create_rds = false
db_instance_class = "db.t3.medium"
engine_version = "14.10"
db_username = "postgres"
db_name = "your-database"

```

### Step 5: Plan the Deployment
```bash
terraform plan -var-file=./tfvars/<file_name>
```
Review the planned resources carefully before proceeding.

### Step 6: Apply the Configuration
```bash
terraform apply -var-file=./tfvars/<file_name>
```
Type `yes` when prompted to confirm the deployment.

### Step 7: Configure kubectl
After successful deployment, configure kubectl to connect to your EKS cluster:
```bash
aws eks update-kubeconfig --region us-west-2 --name your-cluster-name
```

### Step 8: Verify the Installation
```bash
# Check cluster status
kubectl get nodes

# Check EKS addons
kubectl get pods -n kube-system

# Verify EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

## Troubleshooting

### Common Issues
1. **Authentication Errors**
   ```bash
   # Verify AWS credentials
   aws sts get-caller-identity
   ```

2. **EKS Access Denied**
   ```bash
   # Check IAM permissions
   aws iam get-user
   aws eks describe-cluster --name your-cluster-name
   ```

3. **Node Group Issues**
   ```bash
   # Check node group status
   kubectl get nodes
   aws eks describe-nodegroup --cluster-name your-cluster-name --nodegroup-name worker-nodes
   ```

4. **Addon Installation Failures**
   ```bash
   # Check addon status
   aws eks describe-addon --cluster-name your-cluster-name --addon-name aws-ebs-csi-driver
   
   # Update addon if needed
   aws eks update-addon --cluster-name your-cluster-name --addon-name aws-ebs-csi-driver
   ```

## Security Considerations
- Implement Pod Security Standards
- Configure RBAC properly
- Regularly update EKS addons and worker node AMIs

## Maintenance Tasks

### Regular Updates
```bash
# Update EKS cluster version
aws eks update-cluster-version --name your-cluster-name --kubernetes-version 1.28

# Update node group AMI
aws eks update-nodegroup-version --cluster-name your-cluster-name --nodegroup-name worker-nodes

# Update addons
aws eks update-addon --cluster-name your-cluster-name --addon-name aws-ebs-csi-driver
```

### Monitoring
```bash
# Check cluster health
kubectl get componentstatuses

# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## Clean Up Resources
```bash
# Destroy infrastructure when no longer needed
terraform destroy -var-file=./tfvars/<file_name>
```

**Warning**: This will permanently delete all resources. Ensure you have backups of any important data.

## Additional Resources
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)