# DIGIT Application Deployment Configuration Guide

This guide provides step-by-step instructions for configuring and deploying the DIGIT application using GitHub Actions. **We will deploy one environment at a time** to ensure proper setup and testing.

## Prerequisites

- AWS EKS cluster is running and accessible for the target environment
- GitHub repository with appropriate permissions
- AWS IAM user with necessary permissions
- KMS keys for secret encryption

## Phase 1: Development Environment Deployment

### Step 1: GitHub Repository Setup for Development

#### 1.1 Repository Secrets Configuration
Navigate to your GitHub repository → Settings → Secrets and Variables → Actions, and configure the following secrets **for Development environment**:

**Required Secrets for Dev:**
```yaml
AWS_ACCESS_KEY_ID: <Your AWS Access Key>
AWS_SECRET_ACCESS_KEY: <Your AWS Secret Key>
AWS_REGION: ap-south-1
PUBLIC_KMS_KEY_DEV: <Your KMS Key ARN for Dev Environment>
```

#### 1.2 Repository Variables Configuration
Configure the following variables in Settings → Secrets and Variables → Actions → Variables:

```yaml
CLUSTER_NAME_DEV: <Your Dev Cluster Name>
```

### Step 2: Development Environment Configuration

#### 2.1 Configure Development Environment Files
Focus only on the development environment configuration:

**Primary Configuration File:**
- File: `deploy-as-code/charts/environments/selco-dev.yaml`
- File: `deploy-as-code/charts/environments/selco-dev-secrets.yaml`

#### 2.2 Update Development Global Configuration
In your `selco-dev.yaml` file, update the global section:

```yaml
global:
  domain: dev-your-domain.com  # Replace with your Dev domain
  
configmaps:
  egov-config:
    data:
      db-host: "dev-db-endpoint"  # Your Dev RDS endpoint
      db-name: "dev-database-name"
      db-url: "jdbc:postgresql://dev-db-endpoint/dev-database-name"
      # Add other configuration values
```

### Step 3: Development Database Configuration

Update database configurations for development environment:

```yaml
configmaps:
  egov-config:
    data:
      db-host: dev-rds-endpoint.amazonaws.com
      db-name: dev-database-name
      db-url: jdbc:postgresql://dev-rds-endpoint.amazonaws.com/dev-database-name
      db-otel-url: "jdbc:otel:postgresql://dev-rds-endpoint.amazonaws.com/dev-database-name"
```

### Step 4: Development Secret Management

#### 4.1 Create Development Secrets
Create encrypted secrets for development database credentials:

```yaml
# In selco-dev-secrets.yaml (before encryption)
secrets:
  db:
    username: dev-db-username
    password: dev-db-password
    flyway-username: dev-flyway-username
    flyway-password: dev-flyway-password
```

#### 4.2 Encrypt Development Secrets using SOPS
```bash
# Install SOPS (if not already installed)
wget https://github.com/mozilla/sops/releases/download/v3.7.1/sops-v3.7.1.linux
chmod +x sops-v3.7.1.linux
sudo mv sops-v3.7.1.linux /usr/local/bin/sops

# Encrypt development secrets file
sops --encrypt --kms <YOUR_DEV_KMS_KEY_ARN> selco-dev-secrets.yaml > selco-dev-secrets-encrypted.yaml
```

### Step 5: Development Service Configuration

#### 5.1 Update Development Service Hosts
Configure service host mappings in `selco-dev.yaml`:

```yaml
egov-service-host:
  data:
    egov-workflow-v2: http://egov-workflow-v2.core-dev:8080/
    egov-user: http://egov-user.core-dev:8080/
    egov-filestore: http://egov-filestore.core-dev:8080/
    # Add other services as needed
```

### Step 6: Deploy Development Environment

#### 6.1 Trigger Development Deployment
**Manual Trigger:**
1. Go to GitHub Actions tab
2. Select "DIGIT-Install workflow for Dev"
3. Click "Run workflow"
4. Monitor the deployment progress

#### 6.2 Verify Development Deployment
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

### Step 7: Development Environment Testing

#### 7.1 Functional Testing
- Test all core functionalities
- Verify database connectivity
- Check service integrations
- Validate user workflows

#### 7.2 Performance Testing
- Monitor resource usage
- Check response times
- Validate system stability

---

## Best Practices

1. **Environment Isolation**: Always test thoroughly in Development before moving to UAT
2. **Gradual Rollout**: Deploy one environment at a time
3. **Backup Strategy**: Take backups before each deployment
4. **Monitoring**: Monitor each environment continuously
5. **Documentation**: Document any environment-specific configurations

## Security Considerations

1. **Secrets Management**: Always use encrypted secrets with SOPS
2. **Environment Separation**: Use separate KMS keys for each environment
3. **Access Control**: Implement proper RBAC for Kubernetes resources
4. **SSL/TLS**: Ensure all external communications use HTTPS

## Support and Maintenance

For ongoing support:
1. Monitor GitHub Actions workflows regularly
2. Keep dependencies updated
3. Review and rotate secrets periodically
4. Monitor application logs and metrics for each environment

This phased approach ensures stable deployments and easier troubleshooting by focusing on one environment at a time.