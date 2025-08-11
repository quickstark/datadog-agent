#!/bin/bash

# =============================================================================
# Synology Datadog Agent Recovery Script
# =============================================================================
# Non-destructive recovery methods for Datadog Agent containers on Synology NAS
# 
# This script provides multiple recovery strategies without forcing container 
# destruction, preventing data loss and configuration issues.
#
# Usage: ./synology-recovery.sh [options]
# Options:
#   --container-name NAME    Specify container name pattern (default: dd-agent)
#   --non-destructive       Only use non-destructive methods
#   --health-check          Perform health checks only
#   --restart-attempt       Attempt graceful restart only
#   --minimal-mode          Deploy minimal configuration for testing
#
# =============================================================================

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATADOG_DIR="/volume1/docker/datadog-agent"
# Use the same directory for Synology-compatible config
SYNOLOGY_DATADOG_DIR="/volume1/docker/datadog-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default configuration
CONTAINER_PATTERN="dd-agent"
NON_DESTRUCTIVE_ONLY=false
HEALTH_CHECK_ONLY=false
RESTART_ATTEMPT_ONLY=false
MINIMAL_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --container-name)
      CONTAINER_PATTERN="$2"
      shift 2
      ;;
    --non-destructive)
      NON_DESTRUCTIVE_ONLY=true
      shift
      ;;
    --health-check)
      HEALTH_CHECK_ONLY=true
      shift
      ;;
    --restart-attempt)
      RESTART_ATTEMPT_ONLY=true
      shift
      ;;
    --minimal-mode)
      MINIMAL_MODE=true
      shift
      ;;
    --help|-h)
      echo "Synology Datadog Agent Recovery Script"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --container-name NAME    Container name pattern (default: dd-agent)"
      echo "  --non-destructive       Only use non-destructive methods"
      echo "  --health-check          Perform health checks only"
      echo "  --restart-attempt       Attempt graceful restart only"
      echo "  --minimal-mode          Deploy minimal configuration"
      echo "  --help                  Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

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

print_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Find Docker command
find_docker_command() {
    if [ -f /usr/local/bin/docker ]; then
        DOCKER_CMD="/usr/local/bin/docker"
    elif [ -f /usr/bin/docker ]; then
        DOCKER_CMD="/usr/bin/docker"
    elif command -v docker >/dev/null 2>&1; then
        DOCKER_CMD="docker"
    else
        print_error "Docker not found on this system"
        exit 1
    fi
    
    # Check if we need sudo
    if $DOCKER_CMD --version >/dev/null 2>&1; then
        print_success "Docker accessible without sudo: $DOCKER_CMD"
    elif sudo $DOCKER_CMD --version >/dev/null 2>&1; then
        print_info "Docker requires sudo access"
        DOCKER_CMD="sudo $DOCKER_CMD"
    else
        print_error "Cannot access Docker"
        exit 1
    fi
}

# Comprehensive health check
perform_health_check() {
    print_header "Comprehensive Health Check"
    
    local container_ids
    container_ids=$($DOCKER_CMD ps -aq --filter "name=$CONTAINER_PATTERN" 2>/dev/null)
    
    if [[ -z "$container_ids" ]]; then
        print_warning "No containers found matching pattern: $CONTAINER_PATTERN"
        return 1
    fi
    
    local healthy_containers=0
    local total_containers=0
    
    for container_id in $container_ids; do
        ((total_containers++))
        local container_name
        container_name=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
        
        print_step "Checking container: $container_name ($container_id)"
        
        # Check if container is running
        if $DOCKER_CMD ps --filter "id=$container_id" --format "{{.Status}}" | grep -q "Up"; then
            print_info "  Status: Running ✅"
            
            # Check responsiveness
            if timeout 5s $DOCKER_CMD exec "$container_id" echo "responsive" >/dev/null 2>&1; then
                print_info "  Responsiveness: OK ✅"
                
                # Check Datadog Agent health
                if $DOCKER_CMD exec "$container_id" /opt/datadog-agent/bin/agent/agent health >/dev/null 2>&1; then
                    print_info "  Agent Health: OK ✅"
                    ((healthy_containers++))
                    
                    # Check specific integrations
                    print_step "  Testing integrations..."
                    $DOCKER_CMD exec "$container_id" datadog-agent check postgres 2>/dev/null | head -3 | grep -q "OK" && print_info "    PostgreSQL: OK ✅" || print_warning "    PostgreSQL: Issues ⚠️"
                    $DOCKER_CMD exec "$container_id" datadog-agent check sqlserver 2>/dev/null | head -3 | grep -q "OK" && print_info "    SQL Server: OK ✅" || print_warning "    SQL Server: Issues ⚠️"
                    
                else
                    print_warning "  Agent Health: Failed ❌"
                    print_info "    Recent logs:"
                    $DOCKER_CMD logs "$container_id" --tail 5 2>/dev/null | sed 's/^/    /'
                fi
            else
                print_warning "  Responsiveness: Unresponsive ❌"
            fi
        else
            print_warning "  Status: Not running ❌"
            local status
            status=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Status}}" 2>/dev/null)
            print_info "    Current status: $status"
        fi
        
        echo
    done
    
    print_info "Health Check Summary:"
    print_info "  Total containers: $total_containers"
    print_info "  Healthy containers: $healthy_containers"
    
    if [[ $healthy_containers -gt 0 ]]; then
        print_success "At least one healthy container found"
        return 0
    else
        print_error "No healthy containers found"
        return 1
    fi
}

# Non-destructive restart attempt
attempt_graceful_restart() {
    print_header "Non-Destructive Restart Attempt"
    
    local container_ids
    container_ids=$($DOCKER_CMD ps -aq --filter "name=$CONTAINER_PATTERN" 2>/dev/null)
    
    if [[ -z "$container_ids" ]]; then
        print_warning "No containers found to restart"
        return 1
    fi
    
    for container_id in $container_ids; do
        local container_name
        container_name=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
        
        print_step "Attempting graceful restart: $container_name"
        
        # Check current status
        local current_status
        current_status=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Status}}" 2>/dev/null)
        print_info "  Current status: $current_status"
        
        # If container is running, try graceful restart
        if $DOCKER_CMD ps --filter "id=$container_id" --format "{{.Status}}" | grep -q "Up"; then
            print_step "  Sending graceful restart signal..."
            
            # Method 1: Docker restart command (preferred for non-destructive)
            if $DOCKER_CMD restart "$container_id" 2>/dev/null; then
                print_success "  Docker restart command succeeded"
                
                # Wait and verify
                sleep 10
                if $DOCKER_CMD ps --filter "id=$container_id" --format "{{.Status}}" | grep -q "Up"; then
                    print_success "  Container restarted successfully ✅"
                    
                    # Test responsiveness
                    sleep 5
                    if timeout 10s $DOCKER_CMD exec "$container_id" /opt/datadog-agent/bin/agent/agent health >/dev/null 2>&1; then
                        print_success "  Health check passed after restart ✅"
                    else
                        print_warning "  Health check failed after restart ⚠️"
                    fi
                else
                    print_warning "  Container failed to start after restart ⚠️"
                fi
            else
                print_warning "  Docker restart command failed"
                
                # Method 2: Signal-based restart (if container supports it)
                print_step "  Trying signal-based restart..."
                if $DOCKER_CMD exec "$container_id" supervisorctl restart all 2>/dev/null; then
                    print_success "  Signal-based restart initiated"
                elif $DOCKER_CMD exec "$container_id" pkill -HUP datadog-agent 2>/dev/null; then
                    print_success "  Sent HUP signal to agent"
                else
                    print_warning "  Signal-based restart not available"
                fi
            fi
        else
            # Container is not running, try to start it
            print_step "  Container not running, attempting start..."
            if $DOCKER_CMD start "$container_id" 2>/dev/null; then
                print_success "  Container start command succeeded"
                
                sleep 10
                if $DOCKER_CMD ps --filter "id=$container_id" --format "{{.Status}}" | grep -q "Up"; then
                    print_success "  Container started successfully ✅"
                else
                    print_warning "  Container failed to stay running ⚠️"
                    print_info "    Recent logs:"
                    $DOCKER_CMD logs "$container_id" --tail 10 2>/dev/null | sed 's/^/    /'
                fi
            else
                print_error "  Failed to start container"
            fi
        fi
        
        echo
    done
}

# Configuration validation and repair
validate_and_repair_config() {
    print_header "Configuration Validation and Repair"
    
    local config_issues=0
    
    # Check main configuration directory
    if [[ -d "$SYNOLOGY_DATADOG_DIR" ]]; then
        print_step "Checking Synology-compatible configuration..."
        
        # Validate YAML files
        for yaml_file in "$SYNOLOGY_DATADOG_DIR"/*.yaml; do
            if [[ -f "$yaml_file" ]]; then
                local filename
                filename=$(basename "$yaml_file")
                print_step "  Validating $filename..."
                
                if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                    print_success "    $filename syntax is valid ✅"
                    
                    # Check for problematic configurations
                    if [[ "$filename" == "datadog.yaml" ]]; then
                        if grep -q "system_probe_config:" "$yaml_file" && grep -A5 "system_probe_config:" "$yaml_file" | grep -q "enabled: false"; then
                            print_success "    System probe properly disabled ✅"
                        else
                            print_warning "    System probe configuration may be problematic ⚠️"
                            ((config_issues++))
                        fi
                        
                        if grep -q "runtime_security_config:" "$yaml_file" && grep -A5 "runtime_security_config:" "$yaml_file" | grep -q "enabled: false"; then
                            print_success "    Runtime security properly disabled ✅"
                        else
                            print_warning "    Runtime security configuration may be problematic ⚠️"
                            ((config_issues++))
                        fi
                    fi
                else
                    print_error "    $filename has syntax errors ❌"
                    ((config_issues++))
                fi
            fi
        done
        
        # Check database configurations
        for db_config in "$SYNOLOGY_DATADOG_DIR/conf.d"/*/*.yaml; do
            if [[ -f "$db_config" ]]; then
                local config_name
                config_name=$(basename "$(dirname "$db_config")")/$(basename "$db_config")
                print_step "  Validating $config_name..."
                
                if python3 -c "import yaml; yaml.safe_load(open('$db_config'))" 2>/dev/null; then
                    print_success "    $config_name is valid ✅"
                else
                    print_error "    $config_name has syntax errors ❌"
                    ((config_issues++))
                fi
            fi
        done
        
    elif [[ -d "$DATADOG_DIR" ]]; then
        print_step "Checking legacy configuration..."
        print_warning "Found legacy configuration directory"
        print_info "Consider migrating to Synology-compatible configuration"
    else
        print_error "No configuration directory found"
        ((config_issues++))
    fi
    
    if [[ $config_issues -eq 0 ]]; then
        print_success "Configuration validation passed ✅"
        return 0
    else
        print_error "Configuration validation found $config_issues issues ❌"
        
        if [[ "$NON_DESTRUCTIVE_ONLY" == "false" ]]; then
            print_info "Would you like to attempt configuration repair? [y/N]"
            read -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                repair_configuration
            fi
        fi
        return 1
    fi
}

# Configuration repair function
repair_configuration() {
    print_header "Configuration Repair"
    
    print_step "Creating backup of current configuration..."
    local backup_dir="/volume1/docker/datadog-config-backup-$(date +%Y%m%d-%H%M%S)"
    if ! mkdir -p "$backup_dir" 2>/dev/null; then
        backup_dir="/tmp/datadog-config-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        print_info "Using temporary backup location: $backup_dir"
    fi
    
    if [[ -d "$SYNOLOGY_DATADOG_DIR" ]]; then
        cp -r "$SYNOLOGY_DATADOG_DIR"/* "$backup_dir/" 2>/dev/null || print_warning "Partial backup created"
        print_success "Backup created at: $backup_dir"
    fi
    
    print_step "Repairing configuration files..."
    
    # Ensure Synology-compatible directory exists
    mkdir -p "$SYNOLOGY_DATADOG_DIR/conf.d"/{postgres.d,sqlserver.d,snmp.d} 2>/dev/null || print_warning "Directory creation failed, continuing..."
    
    # Create minimal working configuration if missing
    if [[ ! -f "$SYNOLOGY_DATADOG_DIR/datadog.yaml" ]]; then
        print_step "Creating minimal datadog.yaml..."
        cat > "$SYNOLOGY_DATADOG_DIR/datadog.yaml" << 'EOF'
# Minimal Synology-Compatible Datadog Configuration
dd_url: https://app.datadoghq.com
api_key: ${DD_API_KEY}  # Will be substituted during deployment
hostname: Synology

tags:
  - env:dev
  - mode:synology-compatible
  - config:minimal

# Basic settings
log_level: info
logs_enabled: true
enable_metadata_collection: true

# CRITICAL: Disable problematic features for Synology
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
EOF
        print_success "Minimal datadog.yaml created"
    fi
    
    # Set proper permissions if possible
    find "$SYNOLOGY_DATADOG_DIR" -name "*.yaml" -exec chmod 644 {} \; 2>/dev/null || print_warning "Permission setting skipped"
    
    print_success "Configuration repair completed"
}

# Deploy minimal configuration for testing
deploy_minimal_config() {
    print_header "Deploying Minimal Test Configuration"
    
    print_step "Creating minimal test configuration..."
    
    local test_dir="$SYNOLOGY_DATADOG_DIR-test"
    mkdir -p "$test_dir" 2>/dev/null || {
        echo "⚠️  Permission denied creating test directory, using /tmp"
        test_dir="/tmp/datadog-agent-test"
        mkdir -p "$test_dir"
    }
    
    # Create ultra-minimal configuration for testing
    cat > "/tmp/minimal-datadog.yaml" << 'EOF'
# Ultra-Minimal Synology Test Configuration
dd_url: https://app.datadoghq.com
api_key: ${DD_API_KEY}
hostname: Synology-Test

log_level: debug
logs_enabled: false  # Disable to reduce load

# Disable ALL advanced features
system_probe_config:
  enabled: false
runtime_security_config:
  enabled: false  
compliance_config:
  enabled: false
network_config:
  enabled: false
apm_config:
  enabled: false
process_config:
  process_collection:
    enabled: false
  container_collection:
    enabled: false

# Minimal Docker monitoring only
listeners:
  - name: docker
container_collect_all: false
enable_metadata_collection: false
EOF
    
    mv "/tmp/minimal-datadog.yaml" "$test_dir/datadog.yaml"
    # Set appropriate permissions if possible
    chmod 644 "$test_dir/datadog.yaml" 2>/dev/null || echo "Using default permissions"
    
    print_success "Minimal test configuration created at: $test_dir"
    print_info "Use this configuration for troubleshooting container startup issues"
}

# Resource usage monitoring
monitor_resources() {
    print_header "Resource Usage Monitoring"
    
    print_step "System resource usage:"
    echo "  Disk usage:"
    df -h /volume1 2>/dev/null | grep volume1 || df -h /
    
    echo "  Memory usage:"
    free -h
    
    echo "  Docker resources:"
    $DOCKER_CMD system df 2>/dev/null || print_warning "Could not get Docker resource usage"
    
    print_step "Container resource usage:"
    local container_ids
    container_ids=$($DOCKER_CMD ps -q --filter "name=$CONTAINER_PATTERN" 2>/dev/null)
    
    if [[ -n "$container_ids" ]]; then
        for container_id in $container_ids; do
            local container_name
            container_name=$($DOCKER_CMD ps --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
            echo "  Container: $container_name"
            
            # Get resource stats if available
            if $DOCKER_CMD stats --no-stream "$container_id" 2>/dev/null | grep -v "CONTAINER"; then
                true  # Stats displayed above
            else
                print_warning "    Could not get container stats"
            fi
        done
    else
        print_info "No running containers found"
    fi
}

# Generate recovery report
generate_recovery_report() {
    print_header "Recovery Report"
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "🕒 Recovery Analysis - $timestamp"
    echo ""
    echo "📊 System Status:"
    
    # Container status
    local containers
    containers=$($DOCKER_CMD ps -a --filter "name=$CONTAINER_PATTERN" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "   Datadog Containers:"
        echo "$containers" | sed 's/^/     /'
    else
        echo "   ❌ No Datadog containers found"
    fi
    
    # Configuration status  
    if [[ -d "$SYNOLOGY_DATADOG_DIR" ]]; then
        echo "   ✅ Synology-compatible configuration found"
    elif [[ -d "$DATADOG_DIR" ]]; then
        echo "   ⚠️  Legacy configuration found"
    else
        echo "   ❌ No configuration found"
    fi
    
    echo ""
    echo "🔧 Recommended Actions:"
    
    # Health check passed?
    if perform_health_check >/dev/null 2>&1; then
        echo "   ✅ System appears healthy - no action needed"
    else
        echo "   🚨 Issues detected - recommended actions:"
        echo "     1. Try graceful restart: $0 --restart-attempt"
        echo "     2. Validate configuration: $0 --health-check"
        echo "     3. Deploy minimal config: $0 --minimal-mode"
        echo "     4. Check logs: docker logs <container_name>"
    fi
    
    echo ""
    echo "💡 Recovery Options:"
    echo "   • Non-destructive: $0 --non-destructive"
    echo "   • Health check only: $0 --health-check"
    echo "   • Minimal test mode: $0 --minimal-mode"
    echo "   • Full troubleshoot: ./synology-docker-troubleshoot.sh"
}

# Main execution flow
main() {
    print_header "Synology Datadog Agent Recovery"
    print_info "Mode: $([ "$NON_DESTRUCTIVE_ONLY" == "true" ] && echo "Non-destructive only" || echo "Full recovery")"
    print_info "Target pattern: $CONTAINER_PATTERN"
    echo
    
    # Initialize Docker command
    find_docker_command
    
    # Execute based on options
    if [[ "$HEALTH_CHECK_ONLY" == "true" ]]; then
        perform_health_check
        exit $?
    fi
    
    if [[ "$RESTART_ATTEMPT_ONLY" == "true" ]]; then
        attempt_graceful_restart
        exit $?
    fi
    
    if [[ "$MINIMAL_MODE" == "true" ]]; then
        deploy_minimal_config
        print_info "Minimal configuration deployed. Use with:"
        print_info "  docker run ... -v $SYNOLOGY_DATADOG_DIR-test/datadog.yaml:/etc/datadog-agent/datadog.yaml:ro ..."
        exit 0
    fi
    
    # Full recovery sequence
    local recovery_success=true
    
    print_step "Step 1: Health Check"
    if ! perform_health_check; then
        recovery_success=false
        
        print_step "Step 2: Configuration Validation"
        validate_and_repair_config
        
        print_step "Step 3: Graceful Restart Attempt"
        if ! attempt_graceful_restart; then
            recovery_success=false
        fi
        
        print_step "Step 4: Resource Monitoring"
        monitor_resources
    fi
    
    print_step "Step 5: Recovery Report"
    generate_recovery_report
    
    if [[ "$recovery_success" == "true" ]]; then
        print_success "Recovery completed successfully!"
        exit 0
    else
        print_warning "Recovery partially successful or issues remain"
        print_info "Consider using more aggressive recovery methods if needed"
        exit 2
    fi
}

# Check if running as script or being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi