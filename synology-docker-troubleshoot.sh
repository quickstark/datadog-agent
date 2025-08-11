#!/bin/bash

# =============================================================================
# Synology Docker Container Troubleshooting Script
# =============================================================================
# This script helps resolve stuck Docker containers on Synology NAS systems
# 
# Common use cases:
# - Cannot stop containers (zombie state)
# - Cannot remove containers (namespace issues) 
# - "setns process: exit status 1" errors
# - Container name conflicts during deployment
#
# Usage: ./synology-docker-troubleshoot.sh [container-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

# Find Docker command (Synology-specific paths)
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

# Show current Docker status
show_docker_status() {
    print_header "Docker System Status"
    
    print_step "Docker version and info"
    $DOCKER_CMD version --format 'Version: {{.Server.Version}}' 2>/dev/null || print_warning "Could not get Docker version"
    
    print_step "Running containers"
    $DOCKER_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || print_warning "Could not list running containers"
    
    print_step "All containers (including stopped)"
    $DOCKER_CMD ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || print_warning "Could not list all containers"
    
    echo
}

# Analyze stuck containers
analyze_stuck_containers() {
    print_header "Analyzing Stuck Containers"
    
    local container_pattern="${1:-dd-agent}"
    
    print_step "Searching for containers matching pattern: $container_pattern"
    
    # Find containers matching the pattern
    local stuck_containers
    if stuck_containers=$($DOCKER_CMD ps -aq --filter "name=$container_pattern" 2>/dev/null); then
        if [[ -n "$stuck_containers" ]]; then
            echo "Found containers:"
            for container_id in $stuck_containers; do
                local container_info
                container_info=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Names}} ({{.ID}}) - {{.Status}}" 2>/dev/null)
                print_info "$container_info"
                
                # Check if container is responsive
                print_step "Testing container responsiveness: $container_id"
                if timeout 5s $DOCKER_CMD exec "$container_id" echo "responsive" >/dev/null 2>&1; then
                    print_success "Container is responsive"
                else
                    print_warning "Container is unresponsive (likely stuck)"
                    
                    # Check container processes
                    print_step "Checking container processes"
                    if $DOCKER_CMD top "$container_id" >/dev/null 2>&1; then
                        $DOCKER_CMD top "$container_id"
                    else
                        print_warning "Cannot list container processes (confirms stuck state)"
                    fi
                fi
            done
        else
            print_success "No containers found matching pattern: $container_pattern"
        fi
    else
        print_error "Failed to query Docker containers"
        return 1
    fi
    
    echo
}

# Advanced cleanup for stuck containers
advanced_cleanup() {
    local container_pattern="${1:-dd-agent}"
    
    print_header "Advanced Container Cleanup"
    print_warning "This will forcefully remove containers matching: $container_pattern"
    
    read -p "Continue with cleanup? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled by user"
        return 0
    fi
    
    # Get list of containers to clean up
    local containers_to_clean
    if containers_to_clean=$($DOCKER_CMD ps -aq --filter "name=$container_pattern" 2>/dev/null); then
        if [[ -n "$containers_to_clean" ]]; then
            for container_id in $containers_to_clean; do
                local container_name
                container_name=$($DOCKER_CMD ps -a --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
                
                print_step "Cleaning up container: $container_name ($container_id)"
                
                # Method 1: Standard stop with timeout
                print_info "Attempting graceful stop (30s timeout)..."
                if timeout 30s $DOCKER_CMD stop "$container_id" 2>/dev/null; then
                    print_success "Container stopped gracefully"
                else
                    print_warning "Graceful stop failed or timed out"
                    
                    # Method 2: Force kill
                    print_info "Force killing container..."
                    $DOCKER_CMD kill "$container_id" 2>/dev/null || print_warning "Kill command failed"
                    sleep 3
                fi
                
                # Method 3: Force remove
                print_info "Force removing container..."
                if $DOCKER_CMD rm -f "$container_id" 2>/dev/null; then
                    print_success "Container removed successfully"
                else
                    print_error "Failed to remove container $container_id"
                    
                    # Method 4: System-level process cleanup
                    print_step "Attempting system-level cleanup..."
                    
                    # Find related processes
                    if pgrep -f "$container_name\|$container_id" >/dev/null 2>&1; then
                        print_info "Found related processes, attempting cleanup..."
                        pkill -f "$container_name\|$container_id" 2>/dev/null || print_warning "Process cleanup failed"
                        sleep 3
                        
                        # Try removal again
                        $DOCKER_CMD rm -f "$container_id" 2>/dev/null && print_success "Container removed after process cleanup" || print_error "Container still stuck"
                    fi
                fi
            done
        else
            print_success "No containers found to clean up"
        fi
    else
        print_error "Failed to get container list for cleanup"
    fi
    
    echo
}

# Docker daemon health check and repair
check_docker_daemon() {
    print_header "Docker Daemon Health Check"
    
    print_step "Testing Docker daemon responsiveness"
    if timeout 10s $DOCKER_CMD info >/dev/null 2>&1; then
        print_success "Docker daemon is responsive"
    else
        print_warning "Docker daemon appears unresponsive"
        
        print_step "Checking Docker service status"
        if systemctl is-active docker >/dev/null 2>&1; then
            print_info "Docker service is active"
        else
            print_warning "Docker service may not be running properly"
            print_info "Try restarting Docker service:"
            echo "  sudo systemctl restart docker"
        fi
        
        print_step "Checking for resource constraints"
        print_info "Disk usage:"
        df -h /var/lib/docker 2>/dev/null || df -h / 
        
        print_info "Memory usage:"
        free -h
        
        return 1
    fi
    
    echo
}

# Generate recovery recommendations
generate_recommendations() {
    print_header "Recovery Recommendations"
    
    print_info "For persistent Docker issues on Synology:"
    echo
    echo "🔧 Immediate Actions:"
    echo "  1. Run this script with specific container pattern:"
    echo "     ./synology-docker-troubleshoot.sh dd-agent"
    echo "  2. Use advanced cleanup to force remove stuck containers"
    echo "  3. Check Docker daemon health"
    echo
    echo "🛠️  If problems persist:"
    echo "  1. Restart Docker service:"
    echo "     sudo systemctl restart docker"
    echo "  2. Reboot Synology NAS (last resort):"
    echo "     sudo reboot"
    echo "  3. Check Synology DSM Docker package:"
    echo "     - Package Center > Docker > Update if available"
    echo
    echo "⚠️  Prevention:"
    echo "  1. Avoid abruptly stopping containers"
    echo "  2. Monitor resource usage (disk space, memory)"
    echo "  3. Regular Docker cleanup:"
    echo "     docker system prune -f"
    echo "  4. Use proper container restart policies"
    echo
    echo "📚 Synology-specific considerations:"
    echo "  - Use /volume1/docker/ for persistent storage"
    echo "  - Ensure sufficient space in Docker root"
    echo "  - Consider using Docker Compose for complex deployments"
    echo
}

# Main troubleshooting workflow
main() {
    local container_pattern="${1:-dd-agent}"
    
    print_header "Synology Docker Container Troubleshooting"
    print_info "Target container pattern: $container_pattern"
    echo
    
    # Initialize Docker command
    find_docker_command
    
    # Show current status
    show_docker_status
    
    # Analyze stuck containers
    analyze_stuck_containers "$container_pattern"
    
    # Check Docker daemon health
    check_docker_daemon
    
    # Offer cleanup options
    echo
    print_warning "Available actions:"
    echo "  1. Advanced cleanup (force remove stuck containers)"
    echo "  2. Show recommendations only"
    echo "  3. Exit"
    echo
    
    read -p "Choose action [1/2/3]: " -n 1 -r
    echo
    case $REPLY in
        1)
            advanced_cleanup "$container_pattern"
            print_success "Cleanup completed. You can now retry deployment."
            ;;
        2)
            generate_recommendations
            ;;
        3)
            print_info "Troubleshooting session ended"
            ;;
        *)
            print_warning "Invalid choice, showing recommendations"
            generate_recommendations
            ;;
    esac
}

# Check if running as script or being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi