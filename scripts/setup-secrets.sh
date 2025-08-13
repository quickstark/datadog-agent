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
DEFAULT_ENV_FILE=".env"

# Temporary file for storing secrets (compatible with all bash versions)
SECRETS_TEMP_FILE=$(mktemp)
trap 'rm -f "$SECRETS_TEMP_FILE"' EXIT

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

# Function to get secret value by key
get_secret() {
    local key="$1"
    grep "^$key=" "$SECRETS_TEMP_FILE" 2>/dev/null | cut -d'=' -f2- | head -1
}

# Function to check if secret exists
has_secret() {
    local key="$1"
    grep -q "^$key=" "$SECRETS_TEMP_FILE" 2>/dev/null
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
    print_step "Getting repository information..." >&2
    
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null | tr -d '\n')
    if [[ -z "$repo" ]]; then
        print_error "Not in a GitHub repository or repository not found" >&2
        exit 1
    fi
    
    echo "Repository: $repo" >&2
    # Return just the repo name without any formatting or newlines
    printf "%s" "$repo"
}

load_env_file() {
    local env_file="$1"
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file '$env_file' not found"
        exit 1
    fi
    
    print_step "Loading environment variables from: $env_file"
    
    # Clear any existing secrets
    > "$SECRETS_TEMP_FILE"
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
            
            # Store in temp file
            echo "$key=$value" >> "$SECRETS_TEMP_FILE"
            ((count++))
        fi
    done < "$env_file"
    
    print_success "Loaded $count environment variables"
    echo
}

validate_required_secrets() {
    print_step "Preparing secrets for upload..."
    
    local total_secrets=0
    
    # Count all secrets in the file
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            ((total_secrets++))
        fi
    done < <(grep "^[^=]*=" "$SECRETS_TEMP_FILE" 2>/dev/null || true)
    
    # Report summary
    echo -e "${CYAN}Secret Upload Summary:${NC}"
    echo "  Total secrets in .env: $total_secrets"
    echo
    
    print_success "All $total_secrets secrets from .env will be uploaded to GitHub"
    echo
}

upload_secrets() {
    local repo="$1"
    
    print_step "Uploading ALL secrets from .env to GitHub repository:"
    echo "  Repository: $repo"
    
    local success_count=0
    local error_count=0
    local skipped_count=0
    local ssh_key_found=false
    
    # Upload ALL secrets from the temp file
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local secret_name="${BASH_REMATCH[1]}"
            local secret_value="${BASH_REMATCH[2]}"
            
            # Skip empty values
            if [[ -z "$secret_value" ]]; then
                print_warning "Skipping empty secret: $secret_name"
                ((skipped_count++))
                continue
            fi
            
            # Special handling for SSH key - skip automatic upload due to formatting issues
            if [[ "$secret_name" == "SYNOLOGY_SSH_KEY" ]]; then
                ssh_key_found=true
                print_warning "Skipping SYNOLOGY_SSH_KEY (requires manual upload)"
                ((skipped_count++))
                continue
            fi
            
            print_step "Uploading: $secret_name"
            
            if gh secret set "$secret_name" --body "$secret_value" --repo "$repo"; then
                print_success "✓ $secret_name"
                ((success_count++))
            else
                print_error "✗ Failed to upload $secret_name"
                ((error_count++))
            fi
        fi
    done < "$SECRETS_TEMP_FILE"
    
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
    
    print_success "All secrets from .env uploaded successfully!"
    
    # Special handling for SSH key
    if [[ "$ssh_key_found" == "true" ]]; then
        echo
        print_warning "📋 MANUAL SETUP REQUIRED:"
        echo "  The SYNOLOGY_SSH_KEY needs to be uploaded manually to GitHub:"
        echo "  1. Go to: https://github.com/$repo/settings/secrets/actions"
        echo "  2. Click 'New repository secret'"
        echo "  3. Name: SYNOLOGY_SSH_KEY"
        echo "  4. Value: Copy your SSH private key content from .env"
        echo "  5. Make sure to include the full key with headers/footers"
        echo
    fi
    
    return 0
}

show_secret_info() {
    local repo="$1"
    
    echo -e "${CYAN}📋 Secret Information:${NC}"
    echo
    echo -e "${CYAN}Datadog Agent Secrets:${NC}"
    echo "  • DD_API_KEY - Your Datadog API key for agent authentication"
    echo "  • Agent sends logs to OPW (deployed separately)"
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
    
    local verified_count=0
    local total_local_secrets=0
    local missing_secrets=()
    
    # Count total secrets in local file and verify each one
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local secret_name="${BASH_REMATCH[1]}"
            local secret_value="${BASH_REMATCH[2]}"
            
            # Skip empty values and SSH key (manually uploaded)
            if [[ -z "$secret_value" || "$secret_name" == "SYNOLOGY_SSH_KEY" ]]; then
                continue
            fi
            
            ((total_local_secrets++))
            
            if echo "$github_secrets" | grep -q "^$secret_name"; then
                ((verified_count++))
            else
                missing_secrets+=("$secret_name")
            fi
        fi
    done < "$SECRETS_TEMP_FILE"
    
    print_success "Verified $verified_count/$total_local_secrets secrets on GitHub"
    
    if [[ ${#missing_secrets[@]} -gt 0 ]]; then
        print_warning "Secrets not found on GitHub:"
        for secret in "${missing_secrets[@]}"; do
            echo "  - $secret"
        done
    fi
    
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