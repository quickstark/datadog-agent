# Standalone Datadog Agent for Synology DS923+ (AMD Ryzen)

This repository contains configuration and build scripts for deploying a standalone Datadog Agent on Synology DS923+ with AMD Ryzen R1600 processor. The setup includes infrastructure monitoring, container monitoring, and database integrations (PostgreSQL, MongoDB, SNMP).

## Key Features

- **Platform-specific build** optimized for AMD Ryzen R1600 (x86_64/AMD64 architecture)
- **Pre-configured environment variables** for optimal monitoring
- **Fixed entrypoint.sh execution issue** by setting JAVA_TOOLS environment variable
- **Cross-platform build support** using Docker's buildx
- **Simplified deployment** - only requires setting your API key

## Files

- `build-datadog-agent.sh`: Script to build and export the agent image for Synology DS923+
- `datadog.yaml`: Datadog Agent configuration template with infrastructure monitoring settings
- `postgres.yaml`: PostgreSQL integration configuration 

## Pre-Configured Settings

The image comes with the following settings pre-configured:

- **Infrastructure Monitoring**
  - System metrics collection
  - Process monitoring
  - Container monitoring
  - Docker metrics

- **APM (Application Performance Monitoring)**
  - Trace collection enabled
  - Non-local traffic allowed for distributed tracing

- **Logs Collection**
  - Container logs collection enabled

- **Environment Variables**
  - DD_HOSTNAME="Synology"
  - DD_TAGS="env:dev,deployment:synology"
  - DD_APM_ENABLED="true"
  - DD_APM_NON_LOCAL_TRAFFIC="true"
  - DD_LOGS_ENABLED="true"
  - DD_PROCESS_AGENT_ENABLED="true"
  - DD_CONTAINER_COLLECTION_ENABLED="true"
  - DD_DOCKER_COLLECT_ALL="true"
  - DD_SYSTEM_PROBE_ENABLED="true"
  - DD_DATABASE_MONITORING_ENABLED="true"
  - DD_NON_LOCAL_TRAFFIC="true"
  - DD_LOG_LEVEL="info"
  - JAVA_TOOLS="" (fixes entrypoint.sh exec format error)

## Build Instructions

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/yourusername/datadog-agent.git
   cd datadog-agent
   ```

2. Make the build script executable and run it:
   ```bash
   chmod +x build-datadog-agent.sh
   ./build-datadog-agent.sh
   ```

3. The script will:
   - Create a Dockerfile with all required environment variables
   - Build the image for AMD64 architecture (compatible with Synology DS923+)
   - Save the image to your Desktop as both .tar and .tar.gz files
   - Display deployment instructions

## Deployment on Synology DS923+

1. Transfer either `dd-agent.tar` or `dd-agent.tar.gz` to your Synology NAS

2. In Container Manager:
   - Go to "Registry" → "Import" and select the file
   - Create a new container from this image
   - Configure the following:

3. Required Settings:
   - **Privileged Mode**: Enabled (required for system metrics)
   - **Volume Mappings**:
     - `/var/run/docker.sock:/var/run/docker.sock` (for Docker monitoring)
     - `/proc:/host/proc:ro` (for system metrics)
     - `/sys/fs/cgroup:/host/sys/fs/cgroup:ro` (for cgroup metrics)
     - `/etc/passwd:/etc/passwd:ro` (for user mapping)
   - **Environment Variables**:
     - `DD_API_KEY=your_api_key` (the only environment variable you need to set)

## Troubleshooting

### Exec Format Error

If you encounter an "exec format error" with entrypoint.sh, it indicates an architecture mismatch. The current build is specifically configured for AMD64 architecture used by the Synology DS923+ with AMD Ryzen R1600.

Our build script fixes this issue by:
1. Using the correct platform flag (`--platform=linux/amd64`)
2. Setting the `JAVA_TOOLS=""` environment variable
3. Using Docker buildx for proper cross-platform building

### Missing Infrastructure Metrics

If infrastructure metrics are missing:
1. Verify the container is running in privileged mode
2. Check that all required volume mappings are correctly set
3. Ensure the agent has access to the Docker socket for container monitoring

### Adding Custom Integrations

To add custom integrations:
1. Mount a volume to `/etc/datadog-agent/conf.d/`
2. Place your integration configuration files there

## PostgreSQL Monitoring

The included PostgreSQL configuration can be customized by editing `postgres.yaml`. After making changes, rebuild the image using the build script.

## Verification

To verify that the Datadog Agent is working correctly:

1. SSH into your Synology NAS
2. Run: `docker exec -it dd-agent agent status`
3. Check that all checks are reporting correctly
4. Login to your Datadog dashboard to see metrics from your Synology NAS

## References

- [Datadog Agent Docker Documentation](https://docs.datadoghq.com/containers/docker/)
- [Datadog Agent Configuration](https://docs.datadoghq.com/agent/configuration/)
- [Docker buildx Documentation](https://docs.docker.com/engine/reference/commandline/buildx/)

# Datadog Agent Custom Setup

This repository contains a custom Datadog Agent configuration with PostgreSQL and MongoDB monitoring capabilities.

## Running as Standalone Container

This agent deploys as a single container with all environment variables pre-configured:

```bash
# Build the custom image first
docker build -t dd-agent:latest .

# Run the standalone container
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
