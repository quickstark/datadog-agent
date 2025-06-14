# Datadog Agent Refactoring Task List

## Overview
Refactor this project to build **only** the Datadog Agent (removing Observability Pipelines Worker) to create a clean template for single-service deployment.

---

## Phase 1: Analyze Current Configuration
- [x] **1.1** Document all DD_LOGS_CONFIG_LOGS_DD_URL references that point to OPW
  - Found in: Dockerfile, docker-compose.yaml, GitHub Actions
  - **KEEP THESE** - Agent still needs to point to OPW (deployed separately)
- [x] **1.2** Identify all OPW-related environment variables in docker-compose.yaml
  - OPW Service: DD_API_KEY=${DD_OPW_API_KEY}, DD_OP_PIPELINE_ID=${DD_OP_PIPELINE_ID}
  - Agent Config: DD_LOGS_CONFIG_LOGS_DD_URL=http://dd-opw:8282 (KEEP)
- [x] **1.3** List all OPW port mappings and networking dependencies
  - OPW ports: 8282:8282/tcp, 8686:8686/tcp (REMOVE - no OPW service)
  - Agent still expects OPW at dd-opw:8282 (KEEP reference)
- [x] **1.4** Review volume mounts specific to OPW service
  - opw-data volume (REMOVE - no OPW service)

---

## Phase 2: Environment Variables & Configuration Cleanup
- [ ] **2.1** Remove OPW-related variables from `env.example`:
  - `DD_OPW_API_KEY`
  - `DD_OP_PIPELINE_ID`

  - Or remove entirely if not needed for standalone agent
- [ ] **2.2** Update `scripts/setup-secrets.sh` to remove OPW secrets:
  - Remove `DD_OPW_API_KEY` from required_secrets array
  - Remove `DD_OP_PIPELINE_ID` from required_secrets array
  - Update validation messages
- [ ] **2.3** Update `scripts/deploy.sh` to remove OPW references:
  - Remove OPW service mentions from deployment info
  - Remove OPW health check URLs from output
  - Remove OPW container logs commands from troubleshooting

---

## Phase 3: Migrate Docker Compose to Dockerfile
- [ ] **3.1** Extract all Datadog Agent environment variables from `docker-compose.yaml`:
  ```yaml
  - DD_API_KEY=${DD_API_KEY}
  - DD_SITE=datadoghq.com
  - DD_HOSTNAME=Synology
  - DD_APM_ENABLED=true
  - DD_LOGS_ENABLED=true
  - DD_PROCESS_AGENT_ENABLED=true
  - DD_SYSTEM_PROBE_NETWORK_ENABLED=true
  - DD_PROCESS_CONFIG_PROCESS_COLLECTION_ENABLED=true
  - DD_PROCESS_CONFIG_CONTAINER_COLLECTION_ENABLED=true
  - DD_LOGS_CONFIG_USE_HTTP=true
  - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
  - DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
  - DD_ENABLE_METADATA_COLLECTION=true
  - DD_LOG_LEVEL=info
  - DD_CMD_PORT=5002
  - DD_EXPVAR_PORT=5003
  - DD_APM_DD_URL=http://192.168.1.100:3835
  - DD_APM_NON_LOCAL_TRAFFIC=true
  - DD_APM_ENV=dev
  - DD_INVENTORIES_CONFIGURATION_ENABLED=true
  - DD_REMOTE_UPDATES=true
  - DD_TAGS=env:dev,deployment:synology
  ```
- [ ] **3.2** Add all extracted environment variables to `Dockerfile` ENV section
- [ ] **3.3** Add all required port exposures to `Dockerfile`:
  ```dockerfile
  EXPOSE 8125/udp 8126/tcp 2055/udp 2056/udp 4739/udp 6343/udp 514/udp 5002/tcp 5003/tcp
  ```
- [ ] **3.4** Add capability requirements and security options as comments in `Dockerfile`
- [ ] **3.5** Remove `docker-compose.yaml` file entirely

---

## Phase 4: Update GitHub Actions Workflow
- [ ] **4.1** Remove OPW-related secrets from workflow comments:
  - Remove `DD_OPW_API_KEY, DD_OP_PIPELINE_ID` from repository secrets list
- [ ] **4.2** Remove OPW image pulling:
  - Remove `Pull the latest OPW image` step
- [ ] **4.3** Simplify Synology deployment script in workflow:
  - Remove all OPW service management
  - Remove OPW health checks
  - Remove OPW API endpoints
  - Change from docker-compose to direct docker run
- [ ] **4.4** Update docker run command in workflow to use standalone container:
  ```bash
  docker run -d \
    --name dd-agent \
    --privileged \
    --restart unless-stopped \
    --network host \
    -e DD_API_KEY=${{ secrets.DD_API_KEY }} \
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
    ${{ secrets.DOCKERHUB_USER }}/dd-agent:latest
  ```
- [ ] **4.5** Remove docker-compose dependency from workflow
- [ ] **4.6** Update health checks to only validate Datadog Agent

---

## Phase 5: Create New GitHub Repository
- [ ] **5.1** Use MCP to create new GitHub repository:
  - Repository name: `datadog-agent-standalone`
  - Description: "Standalone Datadog Agent for Synology deployment"
  - Private: false (template repository)
- [ ] **5.2** Configure repository settings:
  - Enable GitHub Actions
  - Set up branch protection for main branch
  - Add repository topics: `datadog`, `monitoring`, `synology`, `docker`

---

## Phase 6: Update Documentation
- [ ] **6.1** Update `README.md`:
  - Remove all OPW references
  - Update architecture description to single-service
  - Remove docker-compose instructions
  - Add direct Docker run instructions
  - Update port mappings to only include Datadog Agent ports
  - Remove OPW API endpoints from verification section
- [ ] **6.2** Update `README-DEPLOYMENT.md`:
  - Remove OPW-related environment variables
  - Remove OPW service monitoring instructions
  - Update troubleshooting to only include agent issues
  - Remove OPW log checking commands
- [ ] **6.3** Create new deployment guide for standalone agent
- [ ] **6.4** Update all script comments and help text

---

## Phase 7: Clean Up Supporting Files
- [ ] **7.1** Update `setup-synology.sh`:
  - Remove OPW API endpoint references
  - Remove OPW environment variable requirements
  - Update health check URLs
- [ ] **7.2** Update `setup-volume.sh` if it exists:
  - Remove OPW volume creation
- [ ] **7.3** Clean up any remaining shell scripts:
  - Remove OPW references from `build.sh`
  - Update any other utility scripts

---

## Phase 8: Update Deployment Scripts
- [ ] **8.1** Modify `scripts/deploy.sh`:
  - Remove docker-compose dependency
  - Update to use direct Docker deployment
  - Remove OPW monitoring endpoints
  - Update post-deployment verification steps
- [ ] **8.2** Update deployment monitoring:
  - Remove OPW service status checks
  - Simplify to only monitor Datadog Agent
- [ ] **8.3** Update deployment marking in Datadog:
  - Remove OPW service from deployment tracking
  - Update service name to reflect standalone agent

---

## Phase 9: Testing & Validation
- [ ] **9.1** Validate Dockerfile builds successfully:
  ```bash
  docker build -t dd-agent:test .
  ```
- [ ] **9.2** Test environment variable substitution
- [ ] **9.3** Verify all OPW references removed:
  ```bash
  grep -r -i "opw\|observability.*pipelines" . --exclude-dir=.git
  ```
- [ ] **9.4** Test deployment script dry-run
- [ ] **9.5** Validate GitHub Actions workflow syntax

---

## Phase 10: Repository Migration
- [ ] **10.1** Push changes to new repository
- [ ] **10.2** Update GitHub secrets in new repository:
  - `DD_API_KEY`
  - `DOCKERHUB_USER`
  - `DOCKERHUB_TOKEN`
  - `SYNOLOGY_HOST`
  - `SYNOLOGY_SSH_PORT`
  - `SYNOLOGY_USER`
  - `SYNOLOGY_SSH_KEY`
- [ ] **10.3** Test end-to-end deployment in new repository
- [ ] **10.4** Update any external references to point to new repository

---

## Phase 11: Final Template Cleanup
- [ ] **11.1** Add template-specific README sections:
  - Clear setup instructions
  - Customization guidelines
  - Environment variable reference
- [ ] **11.2** Create example configurations:
  - Sample `.env.datadog` file
  - Example integration configurations
- [ ] **11.3** Add GitHub repository template configuration
- [ ] **11.4** Tag initial release: `v1.0.0-standalone`

---

## Success Criteria
- ✅ No OPW references remain in codebase
- ✅ Dockerfile contains all necessary environment variables
- ✅ GitHub Actions deploys standalone agent successfully
- ✅ Deployment script works without docker-compose
- ✅ All documentation updated and accurate
- ✅ New repository created and functional
- ✅ Template can be easily customized for other deployments

---

## Notes
- Keep all existing monitoring configurations (PostgreSQL, MongoDB, SNMP, etc.)
- Maintain Synology-specific optimizations
- Preserve existing security configurations
- Log aggregation will go directly to Datadog (no OPW intermediary) 