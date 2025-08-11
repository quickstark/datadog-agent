# Synology NAS Datadog Agent Compatibility Guide

## Overview

This guide documents the compatibility issues between Datadog Agent and Synology NAS systems, providing comprehensive solutions to prevent container lock-up and enable stable monitoring.

**TL;DR**: Synology's custom Docker implementation conflicts with Datadog Agent's advanced security features. Use the Synology-compatible configuration to avoid unkillable containers.

## 🚨 Critical Issues

### Container Lock-up Problem

**Symptoms**:
- Container cannot be stopped: `tried to kill container, but did not receive an exit event`
- Docker commands hang indefinitely
- Container becomes "zombie" - shows as running but unresponsive
- Deployment workflows fail due to stuck containers

**Root Cause**:
Synology's custom Linux kernel and Docker implementation cannot properly handle certain Linux capabilities and eBPF features used by Datadog Agent's advanced security modules.

## 🔍 Technical Analysis

### Problematic Features

| Feature | Issue | Impact |
|---------|-------|---------|
| **System Probe** | Requires `/sys/kernel/debug` access and eBPF | Kernel namespace corruption |
| **Runtime Security** | Uses eBPF hooks for process monitoring | Container becomes unkillable |
| **Compliance Scanning** | Needs privileged system access | Namespace corruption |
| **Network Monitoring** | Advanced network capabilities | Network namespace issues |

### Problematic Docker Capabilities

| Capability | Purpose | Synology Issue |
|------------|---------|----------------|
| `SYS_ADMIN` | System administration | Namespace corruption |
| `SYS_PTRACE` | Process tracing | Container lock-up |
| `NET_ADMIN` | Network administration | Network namespace issues |
| `IPC_LOCK` | Memory locking | Resource conflicts |

### Problematic Volume Mounts

| Mount | Purpose | Synology Issue |
|-------|---------|----------------|
| `/sys/kernel/debug` | Kernel debugging | Kernel access conflicts |
| `--privileged` flag | Full system access | Complete namespace corruption |

## ✅ Solution: Synology-Compatible Configuration

### 1. Use Synology-Compatible Files

Replace standard files with Synology-compatible versions:

| Standard File | Synology-Compatible | Purpose |
|---------------|-------------------|---------|
| `Dockerfile` | `Dockerfile.synology` | Disabled problematic features |
| `security-agent.yaml` | `security-agent.synology.yaml` | All security features disabled |
| `system-probe.yaml` | `system-probe.synology.yaml` | System probe disabled |
| `deploy.yaml` | `deploy-synology.yaml` | Safe deployment workflow |

### 2. Required Configuration Changes

#### A. Dockerfile Changes

```dockerfile
# ❌ PROBLEMATIC (causes lock-up)
ENV DD_RUNTIME_SECURITY_CONFIG_ENABLED=true \
    DD_COMPLIANCE_CONFIG_ENABLED=true \
    DD_SYSTEM_PROBE_ENABLED=true

# ✅ SYNOLOGY-COMPATIBLE
ENV DD_RUNTIME_SECURITY_CONFIG_ENABLED=false \
    DD_COMPLIANCE_CONFIG_ENABLED=false \
    DD_SYSTEM_PROBE_ENABLED=false
```

#### B. Docker Capabilities Changes

```bash
# ❌ PROBLEMATIC (causes namespace corruption)
--cap-add SYS_ADMIN \
--cap-add SYS_PTRACE \
--cap-add NET_ADMIN \
--privileged

# ✅ SYNOLOGY-COMPATIBLE
--cap-add CHOWN \
--cap-add DAC_OVERRIDE \
--cap-add SETGID \
--cap-add SETUID \
--security-opt no-new-privileges=true
```

#### C. Volume Mount Changes

```bash
# ❌ PROBLEMATIC (causes kernel conflicts)
-v /sys/kernel/debug:/sys/kernel/debug

# ✅ SYNOLOGY-COMPATIBLE (removed problematic mount)
# Only use safe mounts:
-v /var/run/docker.sock:/var/run/docker.sock:ro
-v /proc:/host/proc:ro
-v /sys/fs/cgroup:/host/sys/fs/cgroup:ro
```

#### D. Configuration File Changes

```yaml
# datadog.yaml - Synology-compatible settings
system_probe_config:
  enabled: false  # ❌ NEVER enable on Synology

runtime_security_config:
  enabled: false  # ❌ NEVER enable on Synology

compliance_config:
  enabled: false  # ❌ NEVER enable on Synology

network_config:
  enabled: false  # ❌ NEVER enable on Synology
```

## 🛠️ Implementation Guide

### Step 1: Deploy Synology-Compatible Configuration

1. **Use the Synology-compatible workflow**:
   ```bash
   # Triggers the deploy-synology.yaml workflow
   git push origin main
   ```

2. **Or deploy manually**:
   ```bash
   docker run -d --name dd-agent-synology \
     --restart unless-stopped \
     --network host \
     -e DD_API_KEY=your_key \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -v /proc:/host/proc:ro \
     -v /sys/fs/cgroup:/host/sys/fs/cgroup:ro \
     -v /volume1/docker/datadog-agent-synology/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro \
     --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add SETGID --cap-add SETUID \
     --security-opt no-new-privileges=true \
     your_dockerhub_user/dd-agent-synology:latest
   ```

### Step 2: Test with Minimal Configuration

1. **Test basic functionality**:
   ```bash
   ./scripts/test-minimal-config.sh --api-key YOUR_KEY
   ```

2. **Verify container stability**:
   ```bash
   docker ps | grep dd-agent
   docker exec dd-agent-synology datadog-agent health
   ```

### Step 3: Recover from Stuck Containers

1. **Use the recovery script**:
   ```bash
   ./scripts/synology-recovery.sh --non-destructive
   ```

2. **Or use the troubleshooting script**:
   ```bash
   ./synology-docker-troubleshoot.sh dd-agent
   ```

## 🔧 Available Tools

### Recovery Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `synology-recovery.sh` | Non-destructive recovery methods | `./scripts/synology-recovery.sh --health-check` |
| `synology-docker-troubleshoot.sh` | Force removal of stuck containers | `./synology-docker-troubleshoot.sh dd-agent` |
| `test-minimal-config.sh` | Test minimal configuration | `./scripts/test-minimal-config.sh --api-key KEY` |

### Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `datadog-minimal.yaml` | Ultra-minimal test config | `/datadog-minimal.yaml` |
| `Dockerfile.synology` | Synology-compatible image | `/Dockerfile.synology` |
| `security-agent.synology.yaml` | Disabled security features | `/security-agent.synology.yaml` |
| `system-probe.synology.yaml` | Disabled system probe | `/system-probe.synology.yaml` |

### Deployment Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `deploy-synology.yaml` | Synology-compatible deployment | Manual or push to main |
| `deploy.yaml` | Standard deployment (avoid on Synology) | Legacy - use for reference only |

## 📊 Feature Comparison

### What Works on Synology

| Feature | Status | Notes |
|---------|--------|-------|
| ✅ Basic monitoring | Full support | Container, system metrics |
| ✅ APM tracing | Full support | Application performance monitoring |
| ✅ Log collection | Full support | Container and application logs |
| ✅ Database monitoring | Full support | PostgreSQL, SQL Server, etc. |
| ✅ SNMP monitoring | Full support | Network device monitoring |
| ✅ Custom metrics | Full support | DogStatsD, custom checks |
| ✅ Alerting | Full support | All Datadog alerting features |

### What Doesn't Work on Synology

| Feature | Status | Reason |
|---------|--------|--------|
| ❌ System Probe | Incompatible | Requires eBPF and kernel debug access |
| ❌ Runtime Security | Incompatible | eBPF hooks corrupt namespaces |
| ❌ Compliance Scanning | Incompatible | Privileged system access conflicts |
| ❌ Network Performance Monitoring | Incompatible | Advanced network capabilities |
| ❌ Container Security | Limited | Basic monitoring only, no runtime protection |

## 🚨 Emergency Procedures

### If Container Gets Stuck

1. **Immediate Response**:
   ```bash
   # Try graceful methods first
   ./scripts/synology-recovery.sh --restart-attempt
   ```

2. **If Graceful Methods Fail**:
   ```bash
   # Force removal (last resort)
   ./synology-docker-troubleshoot.sh dd-agent
   ```

3. **If Docker Becomes Unresponsive**:
   ```bash
   # On Synology DSM, restart Docker service
   sudo systemctl restart docker
   # Or via DSM web interface: Package Center > Docker > Stop/Start
   ```

### Prevention Strategies

1. **Always Use Synology-Compatible Configuration**
2. **Never Enable Problematic Features** (see list above)
3. **Monitor Container Resource Usage**
4. **Test Configuration Changes in Minimal Mode First**
5. **Keep Backup of Working Configuration**

## 🔍 Troubleshooting Guide

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Container won't start | Wrong capabilities | Use Synology-compatible Docker run command |
| Container becomes unresponsive | Problematic features enabled | Check configuration for disabled features |
| High resource usage | Too many features enabled | Start with minimal config, add features gradually |
| Database connections fail | Wrong configuration format | Check conf.d files for proper YAML format |

### Diagnostic Commands

```bash
# Check container status
docker ps -a | grep dd-agent

# Check container logs
docker logs dd-agent-synology --tail 50

# Check agent health
docker exec dd-agent-synology datadog-agent health

# Check configuration
docker exec dd-agent-synology datadog-agent config

# Test database connections
docker exec dd-agent-synology datadog-agent check postgres
docker exec dd-agent-synology datadog-agent check sqlserver
```

## 📝 Configuration Templates

### Minimal Configuration Template

Use `datadog-minimal.yaml` as a starting point:

```yaml
# Ultra-minimal configuration for testing
dd_url: https://app.datadoghq.com
api_key: ${DD_API_KEY}
hostname: Synology-Test

# Disable ALL advanced features
system_probe_config:
  enabled: false
runtime_security_config:
  enabled: false
compliance_config:
  enabled: false
network_config:
  enabled: false

# Basic Docker monitoring only
listeners:
  - name: docker
container_collect_all: false  # Start minimal
```

### Production Configuration Template

Use the standard `datadog.yaml` with Synology-compatible settings:

```yaml
# Production-ready Synology configuration
dd_url: https://app.datadoghq.com
api_key: ${DD_API_KEY}
hostname: Synology

# Enable safe features
logs_enabled: true
apm_config:
  enabled: true
process_config:
  process_collection:
    enabled: true
  container_collection:
    enabled: true

# CRITICAL: Keep these disabled
system_probe_config:
  enabled: false
runtime_security_config:
  enabled: false
compliance_config:
  enabled: false
```

## 🎯 Best Practices

### Do's ✅

1. **Always test with minimal configuration first**
2. **Use Synology-compatible deployment workflow**
3. **Monitor container resource usage**
4. **Keep configuration backups**
5. **Enable features gradually**
6. **Use non-destructive recovery methods first**

### Don'ts ❌

1. **Never enable system probe, runtime security, or compliance on Synology**
2. **Never use `--privileged` flag**
3. **Never mount `/sys/kernel/debug`**
4. **Never add `SYS_ADMIN`, `SYS_PTRACE`, or `NET_ADMIN` capabilities**
5. **Never ignore container health checks**
6. **Never force-kill containers as first response**

## 🚀 Upgrade Path

### From Legacy to Synology-Compatible

1. **Backup current configuration**:
   ```bash
   cp -r /volume1/docker/datadog-agent /volume1/docker/datadog-agent-backup-$(date +%Y%m%d)
   ```

2. **Deploy Synology-compatible version**:
   - Use `deploy-synology.yaml` workflow
   - Or follow manual deployment steps

3. **Verify functionality**:
   ```bash
   ./scripts/test-minimal-config.sh --api-key YOUR_KEY
   ```

4. **Gradually enable features**:
   - Start with container monitoring
   - Add log collection
   - Enable database monitoring
   - Test each step

### Rollback Plan

If Synology-compatible version has issues:

1. **Stop new container**:
   ```bash
   docker stop dd-agent-synology
   ```

2. **Restore backup configuration**:
   ```bash
   cp -r /volume1/docker/datadog-agent-backup-YYYYMMDD/* /volume1/docker/datadog-agent/
   ```

3. **Deploy legacy version** (with caution):
   ```bash
   # Only if you're sure it won't cause lock-up
   # Monitor closely for container responsiveness
   ```

## 🔗 References

- [Datadog Agent Configuration Documentation](https://docs.datadoghq.com/agent/configuration/)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [Synology DSM Docker Support](https://www.synology.com/en-us/dsm/packages/Docker)

## 📞 Support

If you encounter issues:

1. **Check this compatibility guide first**
2. **Use the provided recovery scripts**
3. **Review container logs for specific errors**
4. **Test with minimal configuration**
5. **Document any new compatibility issues for future reference**

---

**Last Updated**: January 2025  
**Compatibility**: Synology DSM 7.x, Datadog Agent 7.x  
**Status**: Production-ready for Synology NAS systems