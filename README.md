# Standalone Datadog Agent for Synology DS923+ (AMD Ryzen)

This repository contains configuration and automated deployment scripts for a standalone Datadog Agent on Synology DS923+ with AMD Ryzen R1600 processor. The setup includes infrastructure monitoring, container monitoring, and database integrations with **automated deployment via GitHub Actions**.

## 🎯 Overview

- **Standalone Docker Container** - No docker-compose required
- **Automated Deployment** - Deploy via GitHub Actions to your Synology NAS
- **Pre-configured Monitoring** - Infrastructure, containers, PostgreSQL, MongoDB, SNMP
- **Log Pipeline Integration** - Sends logs to Observability Pipelines Worker (deployed separately)
- **Platform Optimized** - Built for AMD Ryzen R1600 (x86_64/AMD64 architecture)

## 🚀 Quick Start

### 1. Setup Environment Variables

Create a `.env` file in the project root:

```bash
# Copy the template and edit with your values
cp env.example .env
```

Required variables in `.env`:
```bash
# Datadog Configuration
DD_API_KEY=your-datadog-api-key

# Docker Hub (for pushing/pulling custom agent image)
DOCKERHUB_USER=your-dockerhub-username
DOCKERHUB_TOKEN=your-dockerhub-access-token

# Synology NAS Deployment
SYNOLOGY_HOST=192.168.1.100  # Your Synology IP
SYNOLOGY_SSH_PORT=22
SYNOLOGY_USER=your-ssh-username
SYNOLOGY_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
...your SSH private key content...
-----END OPENSSH PRIVATE KEY-----"
```

### 2. Deploy to Synology

```bash
# Run the automated deployment
./scripts/deploy.sh
```

This will:
- ✅ Upload secrets to GitHub (except SSH key)
- ✅ Trigger GitHub Actions workflow
- ✅ Build and deploy the agent to your Synology

### 3. Manual SSH Key Setup

⚠️ **IMPORTANT**: The SSH key must be uploaded manually to GitHub:

1. Go to your repository settings: `https://github.com/your-username/datadog-agent-standalone/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `SYNOLOGY_SSH_KEY`
4. Value: Copy your SSH private key content from `.env` file
5. Make sure to include the full key with `-----BEGIN` and `-----END` headers

## 🔧 How Automated Deployment Works

When you push changes or run the deployment script:

1. **Build Phase**: GitHub Actions builds a custom Datadog Agent Docker image
2. **Copy Phase**: Configuration files are copied to your Synology at `/volume1/docker/datadog-agent/`
3. **Deploy Phase**: Agent is deployed as a standalone container named `dd-agent`
4. **Verify Phase**: Health checks ensure the deployment succeeded

### Trigger Conditions

Deployment automatically triggers on changes to:
- `Dockerfile`
- `datadog.yaml`
- `conf.d/**` (any configuration files)
- `system-probe.yaml`

## 📁 Configuration Files

The following files are synchronized from GitHub to Synology:

- `datadog.yaml` - Main Datadog Agent configuration
- `system-probe.yaml` - System probe configuration
- `conf.d/postgres.d/conf.yaml` - PostgreSQL monitoring
- `conf.d/mongo.d/conf.yaml` - MongoDB monitoring
- `conf.d/snmp.d/conf.yaml` - SNMP monitoring
- `conf.d/syslog.d/conf.yaml` - Syslog monitoring
- `conf.d/network_path.d/conf.yaml` - Network path monitoring

## 🏗️ Container Configuration

The agent runs as a standalone Docker container with these settings:

### Pre-configured Environment Variables:
- **Core**: DD_SITE, DD_HOSTNAME=Synology, DD_TAGS=env:dev,deployment:synology
- **APM**: DD_APM_ENABLED=true, DD_APM_NON_LOCAL_TRAFFIC=true
- **Logs**: DD_LOGS_ENABLED=true, DD_LOGS_CONFIG_LOGS_DD_URL=http://dd-opw:8282
- **Process**: DD_PROCESS_AGENT_ENABLED=true, DD_PROCESS_CONFIG_*=true  
- **Network**: DD_SYSTEM_PROBE_NETWORK_ENABLED=true, DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
- **Metadata**: DD_ENABLE_METADATA_COLLECTION=true, DD_INVENTORIES_CONFIGURATION_ENABLED=true

### Exposed Ports:
- 8125/udp: DogStatsD
- 8126/tcp: APM Traces  
- 2055/udp, 2056/udp, 4739/udp, 6343/udp: NetFlow/sFlow
- 514/udp: Syslog
- 5002/tcp: Agent Command Port
- 5003/tcp: Expvar Port

### Required Capabilities:
- **Privileged Mode**: Required for system monitoring and network probe
- **Critical Volume Mounts**:
  - `/var/run/docker.sock` - Docker container monitoring
  - `/proc` - System process and resource metrics
  - `/sys/fs/cgroup` - Container resource metrics
  - `/sys/kernel/debug` - System probe for network monitoring
  - `/etc/passwd` - User mapping for process monitoring
  - `/volume1/@docker/containers` - Container log collection
- **Configuration Mounts**:
  - `/volume1/docker/datadog-agent/datadog.yaml` - Main configuration
  - `/volume1/docker/datadog-agent/system-probe.yaml` - Network probe config
  - `/volume1/docker/datadog-agent/conf.d/` - Integration configurations
- **Security Capabilities**: SYS_ADMIN, NET_ADMIN, SYS_PTRACE, and others
- **Network**: Host network access for complete monitoring

## 🔍 Monitoring & Verification

### Check Deployment Status:
```bash
# View GitHub Actions workflow
https://github.com/your-username/datadog-agent-standalone/actions

# SSH to Synology and check container
ssh user@your-synology
docker ps | grep dd-agent
docker logs dd-agent
```

### Verify Agent Status:
- **Agent Status**: `http://your-synology:5002/status`
- **Agent Command**: `docker exec dd-agent datadog-agent status`
- **Container Logs**: `docker logs dd-agent`
- **Datadog Dashboard**: Check for metrics from your Synology

### Log Pipeline:
- Agent sends logs to OPW at `http://dd-opw:8282`
- **Note**: OPW (Observability Pipelines Worker) is deployed separately

## 🛠️ Manual Operations

If needed, you can run operations manually:

```bash
# SSH to your Synology
ssh user@your-synology

# Navigate to the agent directory
cd /volume1/docker/datadog-agent

# Check container status
docker ps | grep dd-agent

# View agent logs
docker logs dd-agent

# Restart the agent
docker restart dd-agent

# Check agent status
docker exec dd-agent datadog-agent status
```

## 🚨 Troubleshooting

### Common Issues:

1. **SSH Connection Failed**
   - Verify SSH key is correctly uploaded to GitHub secrets
   - Check Synology SSH settings and firewall
   - Ensure SSH user has Docker permissions

2. **Agent Not Receiving Data**
   - Verify DD_API_KEY is correct
   - Check container is running in privileged mode
   - Ensure all required volume mounts are present

3. **Log Pipeline Issues**
   - Verify OPW is running separately at `http://dd-opw:8282`
   - Check network connectivity between agent and OPW

4. **Build Failures**
   - Check Docker Hub credentials in GitHub secrets
   - Verify Dockerfile syntax
   - Review GitHub Actions logs

### Deployment Validation:
```bash
# Validate YAML syntax
yamllint datadog.yaml
yamllint conf.d/**/*.yaml

# Test Docker build locally
docker build -t dd-agent:test .

# Check secrets setup
./scripts/setup-secrets.sh
```

## 📈 Benefits of This Setup

- **GitOps Workflow**: All configuration changes tracked in Git
- **Automated Deployment**: Push to deploy, no manual steps
- **Consistency**: Same deployment process every time
- **Rollback Ready**: Easy to revert changes
- **Validation**: Automatic syntax checking
- **Monitoring**: Deployment tracking in Datadog
- **Standalone**: No docker-compose complexity

## 🔄 Template Usage

This repository serves as a clean template for deploying standalone Datadog Agents. The Observability Pipelines Worker has been separated to its own deployment for modularity.

## 📚 References

- [Datadog Agent Docker Documentation](https://docs.datadoghq.com/containers/docker/)
- [Datadog Agent Configuration](https://docs.datadoghq.com/agent/configuration/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker buildx Documentation](https://docs.docker.com/engine/reference/commandline/buildx/)

# Datadog Agent Custom Setup

This repository contains a custom Datadog Agent configuration with PostgreSQL and MongoDB monitoring capabilities.

## Running as Standalone Container

This agent deploys as a single container with all environment variables pre-configured:

```bash
# Build the custom image first
docker build -t dd-agent:latest .

# Run the standalone container with all required volumes
docker run -d \
  --name dd-agent \
  --privileged \
  --restart unless-stopped \
  --network host \
  -e DD_API_KEY=${DD_API_KEY} \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /proc:/host/proc:ro \
  -v /sys/fs/cgroup:/host/sys/fs/cgroup:ro \
  -v /sys/kernel/debug:/sys/kernel/debug \
  -v /etc/passwd:/etc/passwd:ro \
  -v /volume1/@docker/containers:/var/lib/docker/containers:ro \
  -v /volume1/docker/datadog-agent/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro \
  -v /volume1/docker/datadog-agent/system-probe.yaml:/etc/datadog-agent/system-probe.yaml:ro \
  -v /volume1/docker/datadog-agent/conf.d:/etc/datadog-agent/conf.d:ro \
  --cap-add SYS_ADMIN \
  --cap-add SYS_RESOURCE \
  --cap-add SYS_PTRACE \
  --cap-add NET_ADMIN \
  --cap-add NET_BROADCAST \
  --cap-add NET_RAW \
  --cap-add IPC_LOCK \
  --cap-add CHOWN \
  --security-opt apparmor:unconfined \
  dd-agent:latest
```

### Important Notes:

- **Privileged Mode**: The `--privileged` flag is required for system monitoring
- **Host Network**: Uses `--network host` for complete network monitoring
- **Docker Socket**: Mount `/var/run/docker.sock` to enable container monitoring
- **Host Filesystem**: Mount `/proc`, `/sys/fs/cgroup`, and `/etc/passwd` for system monitoring
- **Container Logs**: Adjust the `/volume1/@docker/containers` path to match your Docker containers directory
- **API Key**: Replace `DD_API_KEY` with your actual Datadog API key
- **Log Pipeline**: Agent sends logs to OPW at `http://dd-opw:8282` (deploy OPW separately)

### Environment Variables Included:

The Dockerfile includes all required environment variables:
- **Core**: DD_SITE, DD_HOSTNAME, DD_API_KEY (from runtime)
- **APM**: DD_APM_ENABLED, DD_APM_NON_LOCAL_TRAFFIC, DD_APM_DD_URL
- **Logs**: DD_LOGS_ENABLED, DD_LOGS_CONFIG_LOGS_DD_URL (points to OPW)
- **Process**: DD_PROCESS_AGENT_ENABLED, DD_PROCESS_CONFIG_*
- **Network**: DD_SYSTEM_PROBE_NETWORK_ENABLED, DD_DOGSTATSD_NON_LOCAL_TRAFFIC
- **Metadata**: DD_ENABLE_METADATA_COLLECTION, DD_INVENTORIES_CONFIGURATION_ENABLED
- **Tags**: DD_TAGS=env:dev,deployment:synology

### Exposed Ports:

- 8125/udp: DogStatsD
- 8126/tcp: APM Traces  
- 2055/udp, 2056/udp, 4739/udp, 6343/udp: NetFlow/sFlow
- 514/udp: Syslog
- 5002/tcp: Agent Command Port
- 5003/tcp: Expvar Port
