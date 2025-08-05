# Standalone Datadog Agent for Synology DS923+ (AMD Ryzen)

This repository provides a **automated deployment via Git Actions** of a standalone Datadog Agent on Synology DS923+ with AMD Ryzen R1600 processor. The setup includes examples of various aspects of monitoring containerized workloads in the datadog.yaml.

## 🎯 Overview

- **Git Actions Workflow** - Push code to deploy automatically
- **Conf Examples** - Infrastructure, containers, PostgreSQL, MongoDB, SNMP
- **Log Pipeline Integration** - Sends logs to Observability Pipelines Worker (deployed separately)
- **Platform Optimized** - Built for AMD Ryzen R1600 (x86_64/AMD64 architecture)
- **Health Monitoring** - Automatic deployment verification and rollback

## 🚀 Quick Start

### 1. Fork & Clone Repository

```bash
git clone https://github.com/your-username/datadog-agent.git
cd datadog-agent
```

### 2. Setup GitHub Secrets

Add these secrets to your GitHub repository at `Settings → Secrets and variables → Actions`:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `DD_API_KEY` | Your Datadog API key | `your-datadog-api-key` |
| `DOCKERHUB_USER` | Docker Hub username | `your-dockerhub-username` |
| `DOCKERHUB_TOKEN` | Docker Hub access token | `your-dockerhub-token` |
| `SYNOLOGY_HOST` | Your Synology IP address | `192.168.1.100` |
| `SYNOLOGY_USER` | SSH username for Synology | `your-ssh-username` |
| `SYNOLOGY_SSH_PORT` | SSH port (usually 22) | `22` |
| `SYNOLOGY_SSH_KEY` | Your SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

### 3. Configure Your Environment

1. **Edit `datadog.yaml`** - Update hostnames, IPs, and tags for your environment
2. **Configure integrations** in `conf.d/` directories:
   - `postgres.d/conf.yaml` - PostgreSQL monitoring
   - `mongo.d/conf-backup.yaml` - MongoDB monitoring (currently disabled)
   - `snmp.d/conf.yaml` - SNMP device monitoring
3. **Commit and push** your changes

### 4. Automated Deployment

**That's it!** GitHub Actions will automatically:
- ✅ Build custom Datadog Agent Docker image
- ✅ Deploy configuration files to your Synology
- ✅ Start the agent container with health checks
- ✅ Mark deployment in Datadog for tracking

## 🔧 How GitOps Deployment Works

### Trigger Conditions
Deployment automatically triggers on changes to:
- `Dockerfile`
- `datadog.yaml`
- `conf.d/**/*.yaml` (any configuration files)
- `system-probe.yaml`

### Deployment Flow
1. **Build Phase**: Custom Datadog Agent Docker image built and pushed to Docker Hub
2. **Copy Phase**: Configuration files copied to `/volume1/docker/datadog-agent/` on Synology
3. **Deploy Phase**: Agent deployed as standalone container named `dd-agent`
4. **Verify Phase**: Health checks ensure deployment succeeded
5. **Track Phase**: Deployment marked in Datadog with metadata

### Monitor Deployment
- **GitHub Actions**: `https://github.com/your-username/datadog-agent/actions`
- **Agent Status**: `http://your-synology:5002/status`
- **Container Logs**: SSH to Synology and run `docker logs dd-agent`

## 📁 Configuration Files

All configuration is managed via Git and automatically deployed:

```
├── datadog.yaml                     # Main agent configuration
├── system-probe.yaml               # Network probe configuration  
├── conf.d/
│   ├── postgres.d/conf.yaml        # PostgreSQL monitoring
│   ├── mongo.d/conf-backup.yaml    # MongoDB monitoring (disabled)
│   ├── snmp.d/conf.yaml            # SNMP device monitoring
│   ├── syslog.d/conf.yaml          # Syslog monitoring
│   └── network_path.d/conf.yaml    # Network path monitoring
└── scripts/
    └── debug-snmp.sh               # SNMP troubleshooting script
```

## 🏗️ Container Architecture

The agent runs as a **standalone Docker container** with:

### Environment Variables (Pre-configured):
- **Core**: `DD_HOSTNAME=Synology`, `DD_TAGS=env:dev,deployment:synology`
- **APM**: `DD_APM_ENABLED=true`, `DD_APM_DD_URL=http://192.168.1.100:3835`
- **Logs**: `DD_LOGS_ENABLED=true`, `DD_LOGS_CONFIG_LOGS_DD_URL=http://192.168.1.100:8282`
- **Process**: `DD_PROCESS_AGENT_ENABLED=true`
- **Network**: `DD_SYSTEM_PROBE_NETWORK_ENABLED=true`

### Exposed Ports:
- `8125/udp`: DogStatsD metrics
- `8126/tcp`: APM traces
- `2055-2056/udp, 4739/udp, 6343/udp`: NetFlow/sFlow/IPFIX
- `514/udp`: Syslog
- `5002/tcp`: Agent command port
- `5003/tcp`: Agent expvar port

### Volume Mounts:
- Docker socket for container monitoring
- Host filesystem for system metrics
- Configuration directory for integration settings

## 🔍 Monitoring & Verification

### Check Deployment Status:
```bash
# View GitHub Actions workflow
https://github.com/your-username/datadog-agent/actions

# SSH to Synology and check status
ssh your-user@your-synology
docker ps | grep dd-agent
docker exec dd-agent datadog-agent status
```

### Verify Integrations:
```bash
# Check specific integrations
docker exec dd-agent datadog-agent status | grep -A 10 postgres
docker exec dd-agent datadog-agent status | grep -A 10 snmp
```

### Debug SNMP Issues:
```bash
# Run the debug script to identify SNMP devices
./scripts/debug-snmp.sh
```

## 🛠️ Troubleshooting

### Common Issues:

**1. SSH Connection Failed**
- Verify SSH key is correctly uploaded to GitHub secrets
- Check Synology SSH settings (`Control Panel → Terminal & SNMP → Enable SSH`)
- Ensure SSH user has Docker permissions

**2. Agent Not Collecting Data**
- Verify `DD_API_KEY` is correct in GitHub secrets
- Check container is running: `docker ps | grep dd-agent`
- Review agent logs: `docker logs dd-agent`

**3. SNMP Profile Errors**
- Run debug script: `./scripts/debug-snmp.sh`
- Check device configurations in `conf.d/snmp.d/conf.yaml`
- Verify SNMP community strings

**4. Build Failures**
- Check Docker Hub credentials in GitHub secrets
- Verify YAML syntax: `yamllint datadog.yaml`
- Review GitHub Actions logs

### Emergency Manual Operations:
```bash
# SSH to Synology for manual operations
ssh your-user@your-synology
cd /volume1/docker/datadog-agent

# Restart agent
docker restart dd-agent

# View configuration
cat datadog.yaml
ls -la conf.d/
```

## 📈 Benefits of This GitOps Setup

- **🔄 Automated**: Push code → Automatic deployment
- **📊 Tracked**: Every deployment logged in Datadog
- **🔒 Secure**: Secrets managed via GitHub
- **✅ Verified**: Health checks ensure successful deployment
- **🔧 Consistent**: Same deployment process every time
- **🚀 Fast**: Parallel operations and efficient caching
- **📈 Scalable**: Easy to replicate across multiple Synology devices

## 🔄 Template Usage

This repository serves as a **production-ready template** for deploying standalone Datadog Agents via GitOps. Key features:

- Modular configuration structure
- Comprehensive monitoring coverage
- Automated deployment pipeline
- Built-in troubleshooting tools
- Integration with Observability Pipelines Worker

## 🔗 Integration Notes

### Observability Pipelines Worker (OPW)
- **Logs**: Agent sends logs to OPW at `http://192.168.1.100:8282`
- **APM**: Traces sent via HAProxy at `http://192.168.1.100:3835`
- **Remote Config**: Configuration updates via `http://192.168.1.100:3846`
- **Note**: OPW is deployed separately in its own repository

### Network Monitoring
- **NetFlow/sFlow**: Listens on ports 2055, 2056, 4739, 6343
- **SNMP**: Monitors network devices (router, printer, NAS)
- **Network Path**: Monitors connectivity to external services

## 📚 References

- [Datadog Agent Docker Documentation](https://docs.datadoghq.com/containers/docker/)
- [Datadog Agent Configuration](https://docs.datadoghq.com/agent/configuration/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Synology Docker Documentation](https://www.synology.com/en-us/dsm/packages/Docker)
