# Datadog Agent Automated Deployment

This repository now supports automated deployment of a custom Datadog Agent to your Synology NAS using GitHub Actions.

## 🚀 How It Works

When you push changes to the `main` branch that affect Datadog configuration files, the workflow will:

1. **Build** a custom Datadog Agent Docker image with PostgreSQL support
2. **Push** the image to Docker Hub
3. **Copy** all configuration files from GitHub to your Synology
4. **Deploy** the updated agent using docker-compose
5. **Track** the deployment in Datadog

## 📁 Configuration Files Managed

The following files are automatically synchronized from GitHub to Synology:

- `datadog.yaml` - Main Datadog Agent configuration
- `system-probe.yaml` - System probe configuration
- `conf.d/postgres.d/conf.yaml` - PostgreSQL monitoring
- `conf.d/mongo.d/conf.yaml` - MongoDB monitoring
- `conf.d/snmp.d/conf.yaml` - SNMP monitoring
- `conf.d/syslog.d/conf.yaml` - Syslog monitoring
- `conf.d/network_path.d/conf.yaml` - Network path monitoring
- `conf.d/networkdevice.d/conf.yaml` - Network device monitoring

## 🔧 Required GitHub Secrets

Set these secrets in your GitHub repository settings:

### Docker Hub
- `DOCKERHUB_USERNAME` - Your Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

### Synology Access
- `SYNOLOGY_HOST` - Your Synology IP address
- `SYNOLOGY_SSH_PORT` - SSH port (usually 22)
- `SYNOLOGY_USER` - SSH username
- `SYNOLOGY_SSH_KEY` - SSH private key for authentication

### Datadog Configuration
- `DD_API_KEY` - Your Datadog API key
- `DD_OPW_API_KEY` - Observability Pipelines Worker API key
- `DD_OP_PIPELINE_ID` - Your OPW Pipeline ID

## 🎯 Trigger Conditions

The deployment workflow triggers when you push changes to:
- `Dockerfile`
- `datadog.yaml`
- `docker-compose.yaml`
- `conf.d/**` (any files in conf.d directory)
- `system-probe.yaml`

## 📦 Deployment Process

1. **Validation**: All YAML files are validated for syntax errors
2. **Build**: Custom Docker image built with PostgreSQL dependencies
3. **Copy**: Configuration files copied to `/volume1/docker/datadog-agent/`
4. **Deploy**: Services restarted with new configurations
5. **Verify**: Health checks ensure services are running properly

## 🔍 Monitoring

- Agent status: `http://your-synology:5002/status`
- OPW API: `http://your-synology:8686`
- Deployments are tracked in Datadog under the `infrastructure` environment

## 🛠 Manual Operations

If you need to run operations manually:

```bash
# SSH to your Synology
ssh user@your-synology

# Navigate to the agent directory
cd /volume1/docker/datadog-agent

# Check service status
docker-compose ps

# View logs
docker-compose logs dd-agent
docker-compose logs dd-opw

# Restart services
docker-compose restart

# Pull latest images manually
docker-compose pull
docker-compose up -d
```

## 🔄 Benefits Over Manual Deployment

- **Consistency**: Same process every time
- **Version Control**: All configs tracked in Git
- **Rollback**: Easy to revert changes
- **Validation**: Automatic syntax checking
- **Tracking**: Deployment history in Datadog
- **Flexibility**: Update configs without rebuilding Docker image

## 🚨 Troubleshooting

Common issues and solutions:

1. **SSH Connection Failed**: Check SSH key and Synology SSH settings
2. **Docker Permission Denied**: Ensure SSH user has Docker access
3. **Configuration Errors**: Check YAML syntax validation step
4. **Port Conflicts**: Verify no other services use the same ports
5. **Volume Mount Issues**: Ensure `/volume1/docker/` directory exists

## 📈 Next Steps

Consider these enhancements:
- Add configuration drift detection
- Implement blue-green deployments
- Add Slack/email notifications
- Create configuration templates for different environments 