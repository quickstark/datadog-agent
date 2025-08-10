#!/bin/bash

# =============================================================================
# Datadog Agent Cleanup Script
# =============================================================================
# This script handles cleanup of stuck or problematic Datadog Agent deployments
# Usage: ./scripts/cleanup-deployment.sh
#
# This script will:
# 1. Force stop and remove stuck dd-agent containers
# 2. Clean up orphaned volumes and networks
# 3. Prepare the system for a clean re-deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

cleanup_datadog_containers() {
    print_step "Cleaning up Datadog Agent containers..."
    
    # Find all containers with dd-agent in the name
    local containers=$(docker ps -a --filter "name=dd-agent" --format "{{.ID}} {{.Names}} {{.Status}}")
    
    if [[ -z "$containers" ]]; then
        print_success "No dd-agent containers found"
        return 0
    fi
    
    echo -e "${YELLOW}Found dd-agent containers:${NC}"
    echo "$containers"
    echo
    
    # Force kill running containers
    local running_containers=$(docker ps --filter "name=dd-agent" --format "{{.ID}}")
    if [[ -n "$running_containers" ]]; then
        print_step "Force killing running dd-agent containers..."
        echo "$running_containers" | while read container_id; do
            if [[ -n "$container_id" ]]; then
                print_step "Killing container: $container_id"
                docker kill "$container_id" 2>/dev/null || true
                sleep 2
                
                # If still running, try SIGKILL
                if docker ps -q --filter "id=$container_id" | grep -q .; then
                    print_warning "Container still running, sending SIGKILL..."
                    docker kill -s KILL "$container_id" 2>/dev/null || true
                    sleep 3
                fi
            fi
        done
    fi
    
    # Force remove all dd-agent containers
    local all_containers=$(docker ps -a --filter "name=dd-agent" --format "{{.ID}}")
    if [[ -n "$all_containers" ]]; then
        print_step "Force removing all dd-agent containers..."
        echo "$all_containers" | while read container_id; do
            if [[ -n "$container_id" ]]; then
                print_step "Removing container: $container_id"
                docker rm -f "$container_id" 2>/dev/null || true
            fi
        done
    fi
    
    print_success "Container cleanup completed"
}

cleanup_docker_resources() {
    print_step "Cleaning up Docker resources..."
    
    # Remove orphaned volumes
    local orphaned_volumes=$(docker volume ls -q --filter "dangling=true")
    if [[ -n "$orphaned_volumes" ]]; then
        print_step "Removing orphaned volumes..."
        echo "$orphaned_volumes" | xargs docker volume rm 2>/dev/null || true
    fi
    
    # Clean up unused networks (be careful not to remove system networks)
    print_step "Cleaning up unused networks..."
    docker network prune -f 2>/dev/null || true
    
    # Clean up unused images related to datadog
    print_step "Cleaning up unused Datadog images..."
    local dd_images=$(docker images --filter "reference=*dd-agent*" --filter "dangling=true" -q)
    if [[ -n "$dd_images" ]]; then
        echo "$dd_images" | xargs docker rmi -f 2>/dev/null || true
    fi
    
    print_success "Docker resource cleanup completed"
}

verify_cleanup() {
    print_step "Verifying cleanup..."
    
    local remaining_containers=$(docker ps -a --filter "name=dd-agent" --format "{{.Names}}")
    if [[ -n "$remaining_containers" ]]; then
        print_warning "Some dd-agent containers still exist:"
        echo "$remaining_containers"
    else
        print_success "All dd-agent containers removed"
    fi
    
    # Check for any processes that might be holding resources
    local dd_processes=$(pgrep -f "datadog-agent" 2>/dev/null || true)
    if [[ -n "$dd_processes" ]]; then
        print_warning "Datadog agent processes still running:"
        ps -f -p "$dd_processes" 2>/dev/null || true
    else
        print_success "No datadog-agent processes found"
    fi
}

check_docker_status() {
    print_step "Checking Docker daemon status..."
    
    if ! docker version >/dev/null 2>&1; then
        print_error "Docker daemon is not running or accessible"
        return 1
    fi
    
    print_success "Docker daemon is running"
    
    # Show Docker system info
    echo -e "${CYAN}Docker System Info:${NC}"
    docker system df 2>/dev/null || true
    echo
}

main() {
    print_header "Datadog Agent Cleanup Script"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    check_docker_status
    cleanup_datadog_containers
    cleanup_docker_resources
    verify_cleanup
    
    echo
    print_header "Cleanup Complete!"
    echo -e "${GREEN}🎉 Your system is now ready for a clean Datadog Agent deployment${NC}"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Run your deployment script: ./scripts/deploy.sh"
    echo "  2. Monitor the GitHub Actions workflow"
    echo "  3. Check the agent status after deployment"
    echo
    echo -e "${CYAN}If you continue to have issues:${NC}"
    echo "  • Check the GitHub Actions logs for build errors"
    echo "  • Verify your configuration files are valid"
    echo "  • Ensure your secrets are properly set in GitHub"
    echo
}

# Handle script interruption
trap 'echo -e "\n${RED}Cleanup interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"
