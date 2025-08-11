#!/bin/bash

# =============================================================================
# Manual Synology-Compatible Deployment Script
# =============================================================================
# Quick deployment script for testing the corrected Synology-compatible 
# configuration without using GitHub Actions workflow.
#
# Usage: ./deploy-manual.sh --api-key YOUR_API_KEY [options]
# Options:
#   --api-key KEY           Datadog API key (required)
#   --dockerhub-user USER   DockerHub username (default: auto-detect)
#   --skip-build           Skip Docker image build
#   --cleanup-first        Clean up existing containers first
#   --test-mode            Use minimal configuration for testing
#
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DD_API_KEY=""
DOCKERHUB_USER=""
SKIP_BUILD=false
CLEANUP_FIRST=false
TEST_MODE=false
DATADOG_DIR="/volume1/docker/datadog-agent"
CONTAINER_NAME="dd-agent"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-key)
      DD_API_KEY="$2"
      shift 2
      ;;
    --dockerhub-user)
      DOCKERHUB_USER="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --cleanup-first)
      CLEANUP_FIRST=true
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      shift
      ;;
    --help)
      echo "Manual Synology-Compatible Deployment"
      echo "Usage: $0 --api-key YOUR_API_KEY [options]"
      echo "Options:"
      echo "  --api-key KEY         Datadog API key (required)"
      echo "  --dockerhub-user USER DockerHub username"
      echo "  --skip-build         Skip Docker image build"
      echo "  --cleanup-first      Clean up existing containers first"
      echo "  --test-mode          Use minimal configuration for testing"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Validation
if [[ -z "$DD_API_KEY" ]]; then
    print_error "Datadog API key is required. Use --api-key YOUR_KEY"
    exit 1
fi

if [[ -z "$DOCKERHUB_USER" ]]; then
    # Try to auto-detect from docker config
    if command -v docker >/dev/null 2>&1; then
        DOCKERHUB_USER=$(docker info 2>/dev/null | grep "Username:" | awk '{print $2}' || echo "")
    fi
    
    if [[ -z "$DOCKERHUB_USER" ]]; then
        print_error "DockerHub username required. Use --dockerhub-user YOUR_USERNAME"
        exit 1
    fi
    
    print_info "Auto-detected DockerHub user: $DOCKERHUB_USER"
fi

# Find Docker command
find_docker_command() {
    if [ -f /usr/local/bin/docker ]; then
        DOCKER_CMD="/usr/local/bin/docker"
    elif [ -f /usr/bin/docker ]; then
        DOCKER_CMD="/usr/bin/docker"
    elif command -v docker >/dev/null 2>&1; then
        DOCKER_CMD="docker"
    else
        print_error "Docker not found"
        exit 1
    fi
    
    # Check Docker access
    if $DOCKER_CMD --version >/dev/null 2>&1; then
        print_success "Docker accessible: $DOCKER_CMD"
    elif sudo $DOCKER_CMD --version >/dev/null 2>&1; then
        DOCKER_CMD="sudo $DOCKER_CMD"
        print_success "Docker accessible with sudo: $DOCKER_CMD"
    else
        print_error "Cannot access Docker"
        exit 1
    fi
}

# Cleanup existing containers
cleanup_containers() {
    print_header "Container Cleanup"
    
    local containers
    containers=$($DOCKER_CMD ps -aq --filter "name=$CONTAINER_NAME" 2>/dev/null) || true
    
    if [[ -n "$containers" ]]; then
        print_info "Found existing containers, cleaning up..."
        for container_id in $containers; do
            print_info "Removing container: $container_id"
            $DOCKER_CMD stop "$container_id" >/dev/null 2>&1 || true
            $DOCKER_CMD rm -f "$container_id" >/dev/null 2>&1 || true
        done
        print_success "Cleanup completed"
    else
        print_success "No existing containers found"
    fi
}

# Create Synology-compatible configuration
create_config() {
    print_header "Configuration Setup"
    
    print_info "Creating Synology-compatible configuration..."
    
    # Create directory structure
    if ! mkdir -p "$DATADOG_DIR/conf.d"/{postgres.d,sqlserver.d,snmp.d} 2>/dev/null; then
        print_warning "Directory creation requires permissions"
        print_info "Creating configuration in /tmp for testing..."
        DATADOG_DIR="/tmp/datadog-agent-test"
        mkdir -p "$DATADOG_DIR/conf.d"/{postgres.d,sqlserver.d,snmp.d}
    fi
    
    # Choose configuration based on test mode
    if [[ "$TEST_MODE" == "true" ]]; then
        print_info "Creating minimal test configuration..."
        cat > "$DATADOG_DIR/datadog.yaml" << 'EOF'
# Minimal Synology Test Configuration
dd_url: https://app.datadoghq.com
api_key: PLACEHOLDER_API_KEY
hostname: Synology-Test

log_level: info
logs_enabled: false

# CRITICAL: Disable ALL problematic features
system_probe_config:
  enabled: false
runtime_security_config:
  enabled: false
compliance_config:
  enabled: false
network_config:
  enabled: false

# Minimal monitoring
listeners:
  - name: docker
container_collect_all: false
enable_metadata_collection: false
EOF
    else
        print_info "Creating full Synology-compatible configuration..."
        cat > "$DATADOG_DIR/datadog.yaml" << 'EOF'
# Synology-Compatible Datadog Configuration
dd_url: https://app.datadoghq.com
api_key: PLACEHOLDER_API_KEY
hostname: Synology

tags:
  - env:dev
  - deployment:synology
  - mode:synology-compatible

log_level: info
logs_enabled: true
apm_config:
  enabled: true

# CRITICAL: Disable problematic features
system_probe_config:
  enabled: false
runtime_security_config:
  enabled: false
compliance_config:
  enabled: false
network_config:
  enabled: false

# Safe process monitoring
process_config:
  process_collection:
    enabled: true
  container_collection:
    enabled: true
  network:
    enabled: false

# Docker monitoring
listeners:
  - name: docker
container_collect_all: true
container_image_enabled: true
EOF
    fi
    
    # Substitute API key
    sed -i "s/PLACEHOLDER_API_KEY/$DD_API_KEY/g" "$DATADOG_DIR/datadog.yaml"
    
    print_success "Configuration created at: $DATADOG_DIR"
}

# Deploy container
deploy_container() {
    print_header "Container Deployment"
    
    print_info "Deploying Synology-compatible Datadog Agent..."
    
    # Use existing dd-agent image or datadog/agent
    local image="$DOCKERHUB_USER/dd-agent:latest"
    
    # Check if custom image exists, fallback to standard
    if ! $DOCKER_CMD pull "$image" 2>/dev/null; then
        print_warning "Custom image not found, using datadog/agent:latest"
        image="datadog/agent:latest"
        $DOCKER_CMD pull "$image"
    fi
    
    # Deploy with Synology-safe configuration
    if $DOCKER_CMD run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        --network host \
        -e DD_API_KEY="$DD_API_KEY" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /proc:/host/proc:ro \
        -v /sys/fs/cgroup:/host/sys/fs/cgroup:ro \
        -v /etc/passwd:/etc/passwd:ro \
        -v /volume1/@docker/containers:/var/lib/docker/containers:ro \
        -v "$DATADOG_DIR/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro" \
        --cap-add CHOWN \
        --cap-add DAC_OVERRIDE \
        --cap-add SETGID \
        --cap-add SETUID \
        --security-opt no-new-privileges=true \
        --label "deployment.mode=synology-compatible" \
        --label "deployment.method=manual" \
        --label "deployment.timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        "$image" 2>&1; then
        
        print_success "Container deployed successfully!"
    else
        print_error "Deployment failed"
        return 1
    fi
}

# Verify deployment
verify_deployment() {
    print_header "Deployment Verification"
    
    print_info "Waiting for container to initialize..."
    sleep 30
    
    # Check if container is running
    if $DOCKER_CMD ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
        print_success "Container is running"
        
        # Check agent health
        print_info "Testing agent health..."
        if $DOCKER_CMD exec "$CONTAINER_NAME" /opt/datadog-agent/bin/agent/agent health 2>/dev/null; then
            print_success "Agent health check passed"
        else
            print_warning "Agent health check failed, but container is running"
            print_info "Recent logs:"
            $DOCKER_CMD logs "$CONTAINER_NAME" --tail 10
        fi
    else
        print_error "Container failed to start"
        print_info "Container status:"
        $DOCKER_CMD ps -a --filter "name=$CONTAINER_NAME"
        print_info "Container logs:"
        $DOCKER_CMD logs "$CONTAINER_NAME" --tail 20
        return 1
    fi
}

# Generate report
generate_report() {
    print_header "Deployment Report"
    
    echo "🕒 Deployment completed at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "📊 Configuration:"
    echo "   • Container name: $CONTAINER_NAME"
    echo "   • Configuration: $([ "$TEST_MODE" == "true" ] && echo "Minimal test mode" || echo "Full Synology-compatible")"
    echo "   • Directory: $DATADOG_DIR"
    echo ""
    echo "🎯 Verification Commands:"
    echo "   docker ps | grep dd-agent"
    echo "   docker logs dd-agent"
    echo "   docker exec dd-agent datadog-agent health"
    echo "   docker exec dd-agent datadog-agent status"
    echo ""
    echo "🔧 Management Commands:"
    echo "   Stop:    docker stop dd-agent"
    echo "   Restart: docker restart dd-agent"
    echo "   Remove:  docker rm -f dd-agent"
    echo ""
    
    # Check for problematic log patterns
    print_info "Checking for problematic patterns in logs..."
    local logs
    logs=$($DOCKER_CMD logs "$CONTAINER_NAME" --tail 50 2>&1)
    
    if echo "$logs" | grep -q "SYS-PROBE"; then
        print_warning "⚠️  System probe messages found in logs - this should not happen!"
    else
        print_success "✅ No system probe messages found - configuration is working correctly"
    fi
    
    if echo "$logs" | grep -q "eBPF\|runtime_security"; then
        print_warning "⚠️  Runtime security messages found - may cause issues"
    else
        print_success "✅ No runtime security messages found"
    fi
}

# Main execution
main() {
    print_header "Manual Synology-Compatible Deployment"
    print_info "Mode: $([ "$TEST_MODE" == "true" ] && echo "Test mode" || echo "Full deployment")"
    echo
    
    find_docker_command
    
    if [[ "$CLEANUP_FIRST" == "true" ]]; then
        cleanup_containers
    fi
    
    create_config
    deploy_container
    verify_deployment
    generate_report
    
    print_success "Manual deployment completed successfully!"
}

# Run main function
main "$@"