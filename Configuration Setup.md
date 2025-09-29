# Selco Application Deployment Configuration Guide

This guide provides step-by-step instructions for configuring and deploying the Selco application using GitHub Actions.

## Prerequisites

- AWS EKS cluster is running and accessible for the target environment
- GitHub repository with appropriate permissions
- AWS IAM user with necessary permissions
- KMS keys for secret encryption

## Step 1: GitHub Repository Setup for Development

### 1.1 Repository Secrets Configuration
Navigate to your GitHub repository → Settings → Secrets and Variables → Actions, and configure the following secrets **for Development environment**:

**Required Secrets for Dev:**
```yaml
AWS_ACCESS_KEY_ID: <Your AWS Access Key>
AWS_SECRET_ACCESS_KEY: <Your AWS Secret Key>
AWS_REGION: ap-south-1
PUBLIC_KMS_KEY_DEV: <Your KMS Key ARN for Dev Environment>
```

### 1.2 Repository Variables Configuration
Configure the following variables in Settings → Secrets and Variables → Actions → Variables:

```yaml
CLUSTER_NAME_DEV: <Your Dev Cluster Name>
```

## Step 2: Configuration Files Setup

### 2.1 Complete selco-dev.yaml Configuration
File location: `deploy-as-code/charts/environments/selco-dev.yaml`

```yaml
global:
  domain: dev-your-domain.com  # Replace with your Dev domain

configmaps:
  egov-config:
    data:
      # Database Configuration
      db-host: "dev-rds-endpoint.amazonaws.com"
      db-name: "dev-database-name"
      db-url: "jdbc:postgresql://dev-rds-endpoint.amazonaws.com/dev-database-name"
      db-otel-url: "jdbc:otel:postgresql://dev-rds-endpoint.amazonaws.com/dev-database-name"

      # Add other configuration values as needed
      # Environment specific configurations
      # API endpoints, external service URLs, etc.

  # Service Host Mappings
  egov-service-host:
    data:
      egov-workflow-v2: http://egov-workflow-v2.core-dev:8080/
      egov-user: http://egov-user.core-dev:8080/
      egov-filestore: http://egov-filestore.core-dev:8080/
      # Add other services as needed for your deployment
```

### 2.2 Complete selco-dev-secrets.yaml Configuration
File location: `deploy-as-code/charts/environments/selco-dev-secrets.yaml`

**Before Encryption (for reference only):**
```yaml
secrets:
  db:
    username: dev-db-username
    password: dev-db-password
    flyway-username: dev-flyway-username
    flyway-password: dev-flyway-password

  # Add other secrets as needed
  # API keys, tokens, certificates, etc.
```

## Step 3: Secret Encryption

### 3.1 Install SOPS (if not already installed)
```bash
wget https://github.com/mozilla/sops/releases/download/v3.7.1/sops-v3.7.1.linux
chmod +x sops-v3.7.1.linux
sudo mv sops-v3.7.1.linux /usr/local/bin/sops
```

### 3.2 Encrypt Development Secrets
```bash
# Encrypt the secrets file using your Dev KMS key
sops --encrypt --kms <YOUR_DEV_KMS_KEY_ARN> selco-dev-secrets.yaml > selco-dev-secrets-encrypted.yaml

# Replace the original file with encrypted version
mv selco-dev-secrets-encrypted.yaml selco-dev-secrets.yaml
```

## Step 4: Deploy Development Environment

### 4.1 Trigger Development Deployment
**Manual Trigger:**
1. Go to GitHub Actions tab
2. Select "DIGIT-Install workflow for Dev"
3. Click "Run workflow"
4. Monitor the deployment progress

### 4.2 Verify Development Deployment
After deployment completion:

1. Check pods are running:
```bash
kubectl get pods -n egov
```

2. Check services:
```bash
kubectl get svc -n egov
```

3. Test application access:
```bash
curl https://dev-your-domain.com/user/health
```

## Step 5: Post-Installation Configuration

### 5.1 DNS Configuration

#### Get Load Balancer Endpoint
First, retrieve the load balancer endpoint created by your ingress controller:

```bash
# Get the ingress controller service
kubectl get svc -n ingress-nginx

# Get the load balancer hostname/IP
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

#### Create CNAME Record
Create a CNAME record in your DNS server to map your domain to the load balancer endpoint:

**DNS Configuration Example:**
```
Type: CNAME
Name: dev-your-domain.com (or *)
Value: <load-balancer-endpoint-from-above-command>
TTL: 300 (or as per your DNS provider)
```

**For wildcard subdomains (recommended for DIGIT):**
```
Type: CNAME
Name: *.dev-your-domain.com
Value: <load-balancer-endpoint>
TTL: 300
```

### 5.2 Certificate Manager Verification

#### Check cert-manager pods
```bash
# Verify cert-manager is running
kubectl get pods -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### Verify SSL Certificate Creation
```bash
# Check if certificates are created
kubectl get certificates -n egov

# Check certificate details
kubectl describe certificate <certificate-name> -n egov

# Check certificate status
kubectl get certificaterequests -n egov
```

#### Test SSL Certificate
```bash
# Test SSL connection
openssl s_client -connect dev-your-domain.com:443 -servername dev-your-domain.com

# Or use curl to verify SSL
curl -I https://dev-your-domain.com/user/health
```

### 5.3 Application Access Verification
Once DNS and SSL are configured, verify application access:

```bash
# Test main application endpoint
curl https://dev-your-domain.com/user/health

# Test other service endpoints
curl https://dev-your-domain.com/egov-workflow-v2/health
curl https://dev-your-domain.com/filestore/health
```

## Step 6: Localization & User Creation

### 6.1 Localization Setup

#### Access Localization Service
```bash
# Check localization service status
kubectl get pods -n <namespace> | grep localization

# Access localization API
curl https://dev-your-domain.com/localization/messages/v1/_search
```

#### Configure Locale Data
For localization configuration, refer to the complete Postman collections:
[Selco Foundation Scripts - Postman Collections](https://github.com/Selco-Foundation/Scripts/tree/main/postman%20collection)

This repository contains all the necessary Postman collections for:
1. **Upsert Localization**: Complete API calls for uploading and managing locale files
2. **User Management**: Comprehensive user creation and management APIs
3. **Other Core Services**: Additional service configurations

Import the relevant collections into Postman and update the environment variables with your domain and configuration details.

### 6.2 User Creation & Admin Setup

#### Access User Management
```bash
# Check user service status
kubectl get pods -n <namespace> | grep egov-user

# Test user service endpoint
curl https://dev-your-domain.com/user/users/_search
```

#### Create System Admin User
For complete user creation workflows, refer to the user management Postman collections:
[User Management Collections](https://github.com/Selco-Foundation/Scripts/tree/main/postman%20collection)

The collections include:
- **User Creation**: API calls for creating system administrators and regular users
- **Role Management**: Setting up user roles and permissions
- **User Verification**: Testing and validating user creation

Import the user management collection into Postman and configure the following environment variables:
- `base_url`: Your domain (e.g., https://dev-your-domain.com)
- `tenant_id`: Your tenant identifier
- Other variables as specified in the collection

### 6.3 Final Verification Checklist

- [ ] DNS CNAME record is properly configured
- [ ] SSL certificates are issued and valid
- [ ] Application endpoints are accessible via HTTPS
- [ ] cert-manager is working properly
- [ ] Localization service is running and configured using Postman collections
- [ ] System admin user is created using Postman collections
- [ ] All core services are responding to health checks

## Configuration Summary

All configuration changes are now consolidated into two main files:

1. **selco-dev.yaml**: Contains all non-sensitive configuration including database connections, service hosts, and environment-specific settings
2. **selco-dev-secrets.yaml**: Contains all sensitive information like database credentials and API keys (must be encrypted with SOPS)

Make sure to update both files with your actual values before deployment and complete all post-installation steps for a fully functional environment.