#!/bin/bash

# =============================================================================
# GitHub Secrets Cleanup Script
# =============================================================================
# This script removes ALL secrets from the GitHub repository
# Use with caution - this will delete all existing secrets!
#
# Usage: ./scripts/cleanup-github-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            "" ) 
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            * ) echo "Please answer yes or no.";;
        esac
    done
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
    
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null | tr -d '\n')
    if [[ -z "$repo" ]]; then
        print_error "Not in a GitHub repository or repository not found"
        exit 1
    fi
    
    print_success "Repository: $repo"
    echo "$repo"
}

list_existing_secrets() {
    local repo="$1"
    
    print_step "Listing existing secrets in repository: $repo"
    
    local secrets
    if ! secrets=$(gh secret list --repo "$repo"); then
        print_warning "Could not list secrets (may require additional permissions)"
        return 1
    fi
    
    if [[ -z "$secrets" ]]; then
        print_warning "No secrets found in repository"
        return 1
    fi
    
    echo -e "${CYAN}Current secrets:${NC}"
    echo "$secrets" | while IFS= read -r line; do
        local secret_name=$(echo "$line" | awk '{print $1}')
        echo "  • $secret_name"
    done
    echo
    
    return 0
}

delete_all_secrets() {
    local repo="$1"
    
    print_step "Getting list of secrets to delete..."
    
    local secrets
    if ! secrets=$(gh secret list --repo "$repo"); then
        print_error "Could not list secrets"
        return 1
    fi
    
    if [[ -z "$secrets" ]]; then
        print_success "No secrets to delete"
        return 0
    fi
    
    local secret_names=()
    while IFS= read -r line; do
        local secret_name=$(echo "$line" | awk '{print $1}')
        secret_names+=("$secret_name")
    done <<< "$secrets"
    
    if [[ ${#secret_names[@]} -eq 0 ]]; then
        print_success "No secrets to delete"
        return 0
    fi
    
    echo -e "${YELLOW}About to delete ${#secret_names[@]} secrets:${NC}"
    for secret_name in "${secret_names[@]}"; do
        echo "  • $secret_name"
    done
    echo
    
    if ! prompt_yes_no "Are you sure you want to delete ALL these secrets? This action cannot be undone!"; then
        print_warning "Secret deletion cancelled"
        return 1
    fi
    
    local success_count=0
    local error_count=0
    
    for secret_name in "${secret_names[@]}"; do
        print_step "Deleting: $secret_name"
        
        if gh secret delete "$secret_name" --repo "$repo" &>/dev/null; then
            print_success "✓ Deleted $secret_name"
            ((success_count++))
        else
            print_error "✗ Failed to delete $secret_name"
            ((error_count++))
        fi
    done
    
    echo
    echo -e "${CYAN}Deletion Summary:${NC}"
    echo "  Successfully deleted: $success_count"
    echo "  Failed deletions: $error_count"
    echo
    
    if [[ $error_count -gt 0 ]]; then
        print_warning "Some secrets failed to delete. Please check permissions."
        return 1
    fi
    
    print_success "All secrets deleted successfully!"
    return 0
}

main() {
    print_header "GitHub Secrets Cleanup"
    
    # Check GitHub CLI authentication
    check_gh_auth
    echo
    
    # Get repository information
    local repo
    repo=$(get_repo_info)
    echo
    
    # List existing secrets
    if ! list_existing_secrets "$repo"; then
        print_success "No secrets to clean up!"
        exit 0
    fi
    
    # Confirm deletion
    print_warning "⚠️  WARNING: This will DELETE ALL secrets from your GitHub repository!"
    print_warning "⚠️  This action CANNOT be undone!"
    echo
    
    if ! prompt_yes_no "Do you want to proceed with deleting ALL secrets?"; then
        print_warning "Operation cancelled"
        exit 0
    fi
    
    echo
    
    # Delete all secrets
    if delete_all_secrets "$repo"; then
        echo
        print_success "🎉 GitHub secrets cleanup completed!"
        echo
        echo -e "${CYAN}Next steps:${NC}"
        echo "1. Run: ./scripts/deploy.sh to upload fresh secrets from .env"
        echo "2. Verify secrets are uploaded: gh secret list"
        echo "3. Trigger deployment workflow"
    else
        print_error "Secret cleanup failed. Please check the errors above."
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Cleanup interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"
