#!/bin/bash

# =============================================================================
# GitHub Secrets Setup for Datadog Agent Deployment
# =============================================================================
# This script uploads environment variables as GitHub secrets
# for automated Datadog Agent deployment
#
# Usage: ./scripts/setup-secrets.sh [env-file]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_ENV_FILE=".env.datadog"

# Helper functions
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

check_gh_auth() {
    print_step "Checking GitHub CLI authentication..."
    
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI"
        echo "Please run: gh auth login"
        exit 1
    fi
    
    print_success "GitHub CLI authenticated"
}

get_repo_info() {
    print_step "Getting repository information..."
    
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [[ -z "$repo" ]]; then
        print_error "Not in a GitHub repository or repository not found"
        exit 1
    fi
    
    echo "Repository: $repo"
    echo "$repo"
}

load_env_file() {
    local env_file="$1"
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file '$env_file' not found"
        exit 1
    fi
    
    print_step "Loading environment variables from: $env_file"
    
    # Create associative array for secrets
    declare -gA secrets
    local count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Parse key=value pairs
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            # Store in secrets array
            secrets["$key"]="$value"
            ((count++))
        fi
    done < "$env_file"
    
    print_success "Loaded $count environment variables"
    echo
}

validate_required_secrets() {
    print_step "Validating required secrets..."
    
    # Required secrets for Datadog Agent deployment
    local required_secrets=(
        "DD_API_KEY"
        "DD_OPW_API_KEY"
        "DD_OP_PIPELINE_ID"
        "DOCKERHUB_USER"
        "DOCKERHUB_TOKEN"
        "SYNOLOGY_HOST"
        "SYNOLOGY_SSH_PORT"
        "SYNOLOGY_USER"
        "SYNOLOGY_SSH_KEY"
    )
    
    local missing_secrets=()
    local placeholder_secrets=()
    
    for secret in "${required_secrets[@]}"; do
        if [[ -z "${secrets[$secret]}" ]]; then
            missing_secrets+=("$secret")
        elif [[ "${secrets[$secret]}" =~ ^(your-|sk-your-|secret_your-|dd_|change_me|example) ]]; then
            placeholder_secrets+=("$secret")
        fi
    done
    
    # Report validation results
    echo -e "${CYAN}Secret Validation Summary:${NC}"
    echo "  Required secrets: ${#required_secrets[@]}"
    echo "  Found secrets: $((${#required_secrets[@]} - ${#missing_secrets[@]}))"
    echo "  Missing secrets: ${#missing_secrets[@]}"
    echo "  Placeholder values: ${#placeholder_secrets[@]}"
    echo
    
    if [[ ${#missing_secrets[@]} -gt 0 ]]; then
        print_error "Missing required secrets:"
        for secret in "${missing_secrets[@]}"; do
            echo "  - $secret"
        done
        exit 1
    fi
    
    if [[ ${#placeholder_secrets[@]} -gt 0 ]]; then
        print_warning "Secrets with placeholder values:"
        for secret in "${placeholder_secrets[@]}"; do
            echo "  - $secret = ${secrets[$secret]}"
        done
        echo
        
        read -p "Continue uploading secrets with placeholder values? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Please update placeholder values before uploading secrets"
            exit 1
        fi
    fi
    
    print_success "Secret validation completed"
    echo
}

upload_secrets() {
    local repo="$1"
    
    print_step "Uploading secrets to GitHub repository: $repo"
    
    local success_count=0
    local error_count=0
    local skipped_count=0
    
    # Required secrets for Datadog Agent deployment
    local required_secrets=(
        "DD_API_KEY"
        "DD_OPW_API_KEY"
        "DD_OP_PIPELINE_ID"
        "DOCKERHUB_USER"
        "DOCKERHUB_TOKEN"
        "SYNOLOGY_HOST"
        "SYNOLOGY_SSH_PORT"
        "SYNOLOGY_USER"
        "SYNOLOGY_SSH_KEY"
    )
    
    for secret_name in "${required_secrets[@]}"; do
        local secret_value="${secrets[$secret_name]}"
        
        if [[ -z "$secret_value" ]]; then
            print_warning "Skipping empty secret: $secret_name"
            ((skipped_count++))
            continue
        fi
        
        print_step "Uploading: $secret_name"
        
        if gh secret set "$secret_name" --body "$secret_value" --repo "$repo" 2>/dev/null; then
            print_success "✓ $secret_name"
            ((success_count++))
        else
            print_error "✗ Failed to upload $secret_name"
            ((error_count++))
        fi
    done
    
    echo
    echo -e "${CYAN}Upload Summary:${NC}"
    echo "  Successfully uploaded: $success_count"
    echo "  Failed uploads: $error_count"
    echo "  Skipped: $skipped_count"
    echo
    
    if [[ $error_count -gt 0 ]]; then
        print_warning "Some secrets failed to upload. Please check permissions."
        return 1
    fi
    
    print_success "All required secrets uploaded successfully!"
    return 0
}

show_secret_info() {
    local repo="$1"
    
    echo -e "${CYAN}📋 Secret Information:${NC}"
    echo
    echo -e "${CYAN}Datadog Agent Secrets:${NC}"
    echo "  • DD_API_KEY - Your Datadog API key for agent authentication"
    echo "  • DD_OPW_API_KEY - API key for Observability Pipelines Worker"
    echo "  • DD_OP_PIPELINE_ID - Pipeline ID for OPW configuration"
    echo
    echo -e "${CYAN}Infrastructure Secrets:${NC}"
    echo "  • DOCKERHUB_USER - Docker Hub username for image registry"
    echo "  • DOCKERHUB_TOKEN - Docker Hub access token"
    echo "  • SYNOLOGY_HOST - Your Synology NAS IP address"
    echo "  • SYNOLOGY_SSH_PORT - SSH port (usually 22)"
    echo "  • SYNOLOGY_USER - SSH username for deployment"
    echo "  • SYNOLOGY_SSH_KEY - SSH private key for authentication"
    echo
    echo -e "${CYAN}Manage Secrets:${NC}"
    echo "  🔐 View: https://github.com/$repo/settings/secrets/actions"
    echo "  📊 Actions: https://github.com/$repo/actions"
    echo
}

verify_secrets() {
    local repo="$1"
    
    print_step "Verifying uploaded secrets..."
    
    # Get list of secrets from GitHub
    local github_secrets
    if ! github_secrets=$(gh secret list --repo "$repo" 2>/dev/null); then
        print_warning "Could not verify secrets (may require additional permissions)"
        return 0
    fi
    
    # Required secrets
    local required_secrets=(
        "DD_API_KEY"
        "DD_OPW_API_KEY"
        "DD_OP_PIPELINE_ID"
        "DOCKERHUB_USER"
        "DOCKERHUB_TOKEN"
        "SYNOLOGY_HOST"
        "SYNOLOGY_SSH_PORT"
        "SYNOLOGY_USER"
        "SYNOLOGY_SSH_KEY"
    )
    
    local verified_count=0
    
    for secret in "${required_secrets[@]}"; do
        if echo "$github_secrets" | grep -q "^$secret"; then
            ((verified_count++))
        else
            print_warning "Secret not found on GitHub: $secret"
        fi
    done
    
    print_success "Verified $verified_count/${#required_secrets[@]} secrets on GitHub"
    echo
}

main() {
    local env_file="${1:-$DEFAULT_ENV_FILE}"
    
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}Datadog Agent Secrets Setup${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
    
    # Check GitHub CLI authentication
    check_gh_auth
    
    # Get repository information
    local repo
    repo=$(get_repo_info)
    echo
    
    # Load environment file
    load_env_file "$env_file"
    
    # Validate required secrets
    validate_required_secrets
    
    # Upload secrets to GitHub
    if upload_secrets "$repo"; then
        # Verify uploaded secrets
        verify_secrets "$repo"
        
        # Show helpful information
        show_secret_info "$repo"
        
        print_success "🎉 Datadog Agent secrets setup completed!"
        echo
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Run your deployment: ./scripts/deploy.sh"
        echo "  2. Monitor GitHub Actions for build progress"
        echo "  3. Check Synology for deployed Datadog Agent"
    else
        print_error "Secret upload failed. Please check the errors above."
        exit 1
    fi
}

# Run main function
main "$@" 