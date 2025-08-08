        # Stage 1: Builder
        FROM datadog/agent:latest AS builder

        # Install PostgreSQL dependencies
        RUN pip3 install --no-cache-dir psycopg2-binary

        # Stage 2: Final
        FROM datadog/agent:latest

        # Set required labels
        LABEL maintainer="Dirk" \
            description="Custom Datadog Agent with PostgreSQL and MongoDB monitoring"

        # Set environment variables to match docker-compose configuration
        ENV DD_SITE=datadoghq.com \
            DD_HOSTNAME=Synology \
            DD_APM_ENABLED=true \
            DD_LOGS_ENABLED=true \
            DD_PROCESS_AGENT_ENABLED=true \
            DD_SYSTEM_PROBE_NETWORK_ENABLED=false \
            DD_RUNTIME_SECURITY_CONFIG_ENABLED=true \
            DD_COMPLIANCE_CONFIG_ENABLED=true \
            DD_PROCESS_CONFIG_PROCESS_COLLECTION_ENABLED=true \
            DD_PROCESS_CONFIG_CONTAINER_COLLECTION_ENABLED=true \
            DD_LOGS_CONFIG_LOGS_DD_URL=http://192.168.1.100:8282 \
            DD_LOGS_CONFIG_USE_HTTP=true \
            DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true \
            DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true \
            DD_ENABLE_METADATA_COLLECTION=true \
            DD_LOG_LEVEL=info \
            DD_CMD_PORT=5002 \
            DD_EXPVAR_PORT=5003 \
            DD_APM_DD_URL=http://192.168.1.100:3835 \
            DD_APM_NON_LOCAL_TRAFFIC=true \
            DD_APM_ENV=dev \
            DD_INVENTORIES_CONFIGURATION_ENABLED=true \
            DD_REMOTE_UPDATES=true \
            DD_SYSTEM_PROBE_ENABLED=true \
            DD_TAGS=env:dev,deployment:synology \
            PUID=1026 \
            PGID=100 \
            TZ=America/Chicago \
            ACCEPT_EULA=Y

        # Install PostgreSQL and SQL Server (ODBC via FreeTDS) dependencies in the final stage
        RUN pip3 install --no-cache-dir psycopg2-binary \
         && apt-get update \
         && apt-get install -y --no-install-recommends unixodbc unixodbc-dev freetds-dev freetds-bin tdsodbc \
         && pip3 install --no-cache-dir pyodbc \
         && rm -rf /var/lib/apt/lists/*

        # Note: Configuration files are now managed via volume mounts during deployment
    # This allows for easier updates without rebuilding the Docker image
    # The following directories will be mounted at runtime:
    # - /volume1/docker/datadog-agent/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro
    # - /volume1/docker/datadog-agent/system-probe.yaml:/etc/datadog-agent/system-probe.yaml:ro
    # - /volume1/docker/datadog-agent/conf.d:/etc/datadog-agent/conf.d:ro

        # Expose all ports to match docker-compose configuration
        EXPOSE 8125/udp 8126/tcp 2055/udp 2056/udp 4739/udp 6343/udp 514/udp 514/tcp 5002/tcp 5003/tcp 

        # Set healthcheck
        HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD ["/opt/datadog-agent/bin/agent/agent", "health"]

        # Define volume mount points for Docker runtime
        # These are critical for agent functionality and must be mounted at runtime
        VOLUME ["/var/run/docker.sock", "/host/proc", "/host/sys/fs/cgroup", "/sys/kernel/debug", "/etc/passwd", "/var/lib/docker/containers"]
        
        # Runtime volume mount requirements (must be specified with docker run):
        # - /var/run/docker.sock:/var/run/docker.sock:ro (Docker monitoring)
        # - /proc:/host/proc:ro (System metrics)
        # - /sys/fs/cgroup:/host/sys/fs/cgroup:ro (Container metrics) 
        # - /sys/kernel/debug:/sys/kernel/debug (System probe)
        # - /etc/passwd:/etc/passwd:ro (User mapping)
        # - /volume1/@docker/containers:/var/lib/docker/containers:ro (Container logs)
        # - /volume1/docker/datadog-agent/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro
        # - /volume1/docker/datadog-agent/system-probe.yaml:/etc/datadog-agent/system-probe.yaml:ro
        # - /volume1/docker/datadog-agent/conf.d:/etc/datadog-agent/conf.d:ro
        #
        # Container should be run with --privileged flag for full functionality
        # Required capabilities when not using --privileged:
        # --cap-add SYS_ADMIN --cap-add SYS_RESOURCE --cap-add SYS_PTRACE
        # --cap-add NET_ADMIN --cap-add NET_BROADCAST --cap-add NET_RAW
        # --cap-add IPC_LOCK --cap-add CHOWN
        # Required security options:
        # --security-opt apparmor:unconfined