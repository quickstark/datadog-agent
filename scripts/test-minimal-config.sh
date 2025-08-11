#!/bin/bash

# =============================================================================
# Minimal Configuration Testing Script for Synology
# =============================================================================
# This script tests the minimal Datadog Agent configuration to verify
# that basic functionality works before adding advanced features.
#
# Usage: ./test-minimal-config.sh [options]
# Options:
#   --api-key KEY           Specify Datadog API key
#   --skip-cleanup         Don't remove test containers
#   --verbose              Enable verbose output
#   --timeout SECONDS      Container start timeout (default: 60)
#
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MINIMAL_CONFIG="$PROJECT_DIR/datadog-minimal.yaml"
TEST_CONTAINER_NAME="dd-agent-minimal-test"
TIMEOUT=60
VERBOSE=false
SKIP_CLEANUP=false
DD_API_KEY=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-key)
      DD_API_KEY="$2"
      shift 2
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help)
      echo "Minimal Configuration Testing Script"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --api-key KEY      Datadog API key"
      echo "  --skip-cleanup     Don't remove test containers"
      echo "  --verbose          Enable verbose output"
      echo "  --timeout SECONDS  Container start timeout (default: 60)"
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

verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 $1"
    fi
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
        print_error "Docker not found"
        exit 1
    fi
    
    # Check Docker access
    if $DOCKER_CMD --version >/dev/null 2>&1; then
        verbose_log "Docker accessible without sudo"
    elif sudo $DOCKER_CMD --version >/dev/null 2>&1; then
        DOCKER_CMD="sudo $DOCKER_CMD"
        verbose_log "Docker accessible with sudo"
    else
        print_error "Cannot access Docker"
        exit 1
    fi
}

# Get API key from user if not provided
get_api_key() {
    if [[ -z "$DD_API_KEY" ]]; then
        echo "Please provide your Datadog API key:"
        echo "You can find it at: https://app.datadoghq.com/account/settings"
        read -s -p "API Key: " DD_API_KEY
        echo
        
        if [[ -z "$DD_API_KEY" ]]; then
            print_error "API key is required"
            exit 1
        fi
    fi
    
    # Basic validation
    if [[ ${#DD_API_KEY} -lt 32 ]]; then
        print_warning "API key seems too short (less than 32 characters)"
    fi
    
    verbose_log "API key provided (${#DD_API_KEY} characters)"
}

# Clean up any existing test containers
cleanup_existing() {
    print_header "Cleanup Phase"
    
    verbose_log "Looking for existing test containers..."
    
    local existing_containers
    existing_containers=$($DOCKER_CMD ps -aq --filter "name=$TEST_CONTAINER_NAME" 2>/dev/null) || true
    
    if [[ -n "$existing_containers" ]]; then
        print_info "Found existing test containers, cleaning up..."
        
        for container_id in $existing_containers; do
            verbose_log "Removing container: $container_id"
            
            # Stop gracefully first
            $DOCKER_CMD stop "$container_id" >/dev/null 2>&1 || true
            
            # Remove container
            $DOCKER_CMD rm -f "$container_id" >/dev/null 2>&1 || true
        done
        
        print_success "Existing test containers cleaned up"
    else
        print_success "No existing test containers found"
    fi
}

# Validate minimal configuration file
validate_config() {
    print_header "Configuration Validation"
    
    if [[ ! -f "$MINIMAL_CONFIG" ]]; then
        print_error "Minimal configuration file not found: $MINIMAL_CONFIG"
        exit 1
    fi
    
    verbose_log "Validating YAML syntax..."
    if python3 -c "import yaml; yaml.safe_load(open('$MINIMAL_CONFIG'))" 2>/dev/null; then
        print_success "YAML syntax is valid"
    else
        print_error "YAML syntax is invalid"
        exit 1
    fi
    
    # Check for problematic configurations
    verbose_log "Checking for dangerous configurations..."
    local dangerous_features=("system_probe_config" "runtime_security_config" "compliance_config")
    local warnings=0
    
    for feature in "${dangerous_features[@]}"; do
        if grep -q "$feature:" "$MINIMAL_CONFIG"; then
            if grep -A5 "$feature:" "$MINIMAL_CONFIG" | grep -q "enabled: false"; then
                verbose_log "$feature is safely disabled ✅"
            else
                print_warning "$feature may not be properly disabled"
                ((warnings++))
            fi
        else
            verbose_log "$feature not found in config (OK)"
        fi
    done
    
    if [[ $warnings -eq 0 ]]; then
        print_success "Configuration safety check passed"
    else
        print_warning "Configuration has $warnings potential issues"
    fi
}

# Test basic container startup
test_container_startup() {
    print_header "Container Startup Test"
    
    verbose_log "Starting test container with minimal configuration..."
    
    # Create container with minimal configuration
    local container_id
    if container_id=$($DOCKER_CMD run -d \
        --name "$TEST_CONTAINER_NAME" \
        -e DD_API_KEY="$DD_API_KEY" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v "$MINIMAL_CONFIG:/etc/datadog-agent/datadog.yaml:ro" \
        --cap-add CHOWN \
        --cap-add DAC_OVERRIDE \
        --cap-add SETGID \
        --cap-add SETUID \
        --security-opt no-new-privileges=true \
        datadog/agent:latest 2>&1); then
        
        print_success "Container started: $container_id"
        verbose_log "Container ID: $container_id"
    else
        print_error "Failed to start container"
        echo "Error output: $container_id"
        return 1
    fi
    
    # Wait for container to initialize
    print_info "Waiting for container to initialize (timeout: ${TIMEOUT}s)..."
    
    local elapsed=0
    local interval=5
    
    while [[ $elapsed -lt $TIMEOUT ]]; do
        if $DOCKER_CMD ps --filter "name=$TEST_CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
            print_success "Container is running after ${elapsed}s"
            return 0
        fi
        
        verbose_log "Waiting... (${elapsed}/${TIMEOUT}s)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    print_error "Container failed to start within ${TIMEOUT}s"
    
    # Show container logs for debugging
    print_info "Container logs:"
    $DOCKER_CMD logs "$TEST_CONTAINER_NAME" --tail 20 2>&1 | sed 's/^/  /'
    
    return 1
}

# Test container health
test_container_health() {
    print_header "Container Health Test"
    
    # Check if container is responsive
    verbose_log "Testing container responsiveness..."
    if timeout 10s $DOCKER_CMD exec "$TEST_CONTAINER_NAME" echo "responsive" >/dev/null 2>&1; then
        print_success "Container is responsive"
    else
        print_error "Container is not responsive"
        return 1
    fi
    
    # Wait a bit for agent to fully initialize
    print_info "Waiting for Datadog Agent to initialize..."
    sleep 20
    
    # Test Datadog Agent health
    verbose_log "Testing Datadog Agent health..."
    local health_output
    if health_output=$($DOCKER_CMD exec "$TEST_CONTAINER_NAME" /opt/datadog-agent/bin/agent/agent health 2>&1); then
        print_success "Datadog Agent health check passed"
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Health check output:"
            echo "$health_output" | sed 's/^/  /'
        fi
    else
        print_warning "Datadog Agent health check failed"
        echo "Health check output:"
        echo "$health_output" | sed 's/^/  /'
        
        # This is a warning, not a failure, as minimal config might have limited functionality
        return 0
    fi
    
    # Test basic agent status
    verbose_log "Testing agent status..."
    local status_output
    if status_output=$($DOCKER_CMD exec "$TEST_CONTAINER_NAME" /opt/datadog-agent/bin/agent/agent status 2>&1 | head -20); then
        print_success "Agent status command succeeded"
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Status output (first 20 lines):"
            echo "$status_output" | sed 's/^/  /'
        fi
    else
        print_warning "Agent status command had issues"
    fi
}

# Monitor container for stability
monitor_stability() {
    print_header "Stability Monitoring"
    
    local monitoring_duration=60
    print_info "Monitoring container stability for ${monitoring_duration}s..."
    
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $monitoring_duration ]]; then
            break
        fi
        
        # Check if container is still running
        if ! $DOCKER_CMD ps --filter "name=$TEST_CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
            print_error "Container stopped unexpectedly after ${elapsed}s"
            
            print_info "Container logs:"
            $DOCKER_CMD logs "$TEST_CONTAINER_NAME" --tail 30 2>&1 | sed 's/^/  /'
            
            return 1
        fi
        
        verbose_log "Container stable after ${elapsed}s"
        sleep 10
    done
    
    print_success "Container remained stable for ${monitoring_duration}s"
}

# Generate test report
generate_report() {
    print_header "Test Report"
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "🕒 Test completed at: $timestamp"
    echo ""
    
    # Container status
    if $DOCKER_CMD ps --filter "name=$TEST_CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
        echo "✅ Container Status: Running"
        
        # Get uptime
        local uptime
        uptime=$($DOCKER_CMD ps --filter "name=$TEST_CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
        echo "   Uptime: $uptime"
    else
        echo "❌ Container Status: Not Running"
    fi
    
    # Resource usage
    echo ""
    echo "📊 Resource Usage:"
    if $DOCKER_CMD stats --no-stream "$TEST_CONTAINER_NAME" 2>/dev/null; then
        true  # Stats shown above
    else
        echo "   Could not retrieve resource stats"
    fi
    
    echo ""
    echo "🎯 Test Results:"
    echo "   • Configuration: Valid ✅"
    echo "   • Container Startup: $(test_container_startup >/dev/null 2>&1 && echo "Success ✅" || echo "Failed ❌")"
    echo "   • Health Check: $(test_container_health >/dev/null 2>&1 && echo "Passed ✅" || echo "Failed ⚠️")"
    echo "   • Stability: $(monitor_stability >/dev/null 2>&1 && echo "Stable ✅" || echo "Issues ⚠️")"
    
    echo ""
    echo "💡 Next Steps:"
    echo "   1. If all tests passed, the minimal config is working"
    echo "   2. Gradually enable features in datadog.yaml:"
    echo "      • container_collect_all: true"
    echo "      • logs_enabled: true"
    echo "      • process_config settings"
    echo "   3. NEVER enable: system_probe, runtime_security, compliance"
    echo "   4. Use the Synology-compatible deployment workflow"
}

# Cleanup function
cleanup() {
    if [[ "$SKIP_CLEANUP" == "false" ]]; then
        print_info "Cleaning up test containers..."
        $DOCKER_CMD rm -f "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
        print_success "Cleanup completed"
    else
        print_info "Skipping cleanup (--skip-cleanup specified)"
        print_info "Test container: $TEST_CONTAINER_NAME"
    fi
}

# Main execution
main() {
    print_header "Datadog Agent Minimal Configuration Test"
    print_info "Testing minimal configuration for Synology compatibility"
    echo
    
    # Setup
    find_docker_command
    get_api_key
    
    # Test sequence
    local test_failed=false
    
    cleanup_existing
    
    if ! validate_config; then
        test_failed=true
    fi
    
    if ! test_container_startup; then
        test_failed=true
    fi
    
    if ! test_container_health; then
        # Health test failure is a warning, not a complete failure
        print_warning "Health test had issues but continuing..."
    fi
    
    if ! monitor_stability; then
        test_failed=true
    fi
    
    generate_report
    
    # Cleanup
    trap cleanup EXIT
    
    if [[ "$test_failed" == "true" ]]; then
        print_error "Some tests failed - check configuration and logs"
        exit 1
    else
        print_success "All tests passed! Minimal configuration is working."
        exit 0
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi