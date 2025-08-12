#!/bin/bash

# =============================================================================
# Database Configuration Test Script
# =============================================================================
# This script helps test database configuration before deployment
#
# Usage: ./scripts/test-db-config.sh

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

# Load environment variables
load_env() {
    if [[ -f ".env" ]]; then
        print_step "Loading environment variables from .env"
        set -a
        source .env
        set +a
        print_success "Environment variables loaded"
    else
        print_error ".env file not found"
        exit 1
    fi
}

# Test PostgreSQL configuration
test_postgres_config() {
    print_header "Testing PostgreSQL Configuration"
    
    echo "Variables to be used:"
    echo "  POSTGRES_HOST: ${POSTGRES_HOST:-NOT SET}"
    echo "  POSTGRES_PORT: ${POSTGRES_PORT:-NOT SET}"
    echo "  POSTGRES_DATABASE: ${POSTGRES_DATABASE:-NOT SET}"
    echo "  DBM_USER: ${DBM_USER:-NOT SET}"
    echo "  DBM_PASSWORD: ${DBM_PASSWORD:+***SET***}"
    echo
    
    # Check if all required variables are set
    local missing_vars=()
    [[ -z "$POSTGRES_HOST" ]] && missing_vars+=("POSTGRES_HOST")
    [[ -z "$POSTGRES_PORT" ]] && missing_vars+=("POSTGRES_PORT")
    [[ -z "$POSTGRES_DATABASE" ]] && missing_vars+=("POSTGRES_DATABASE")
    [[ -z "$DBM_USER" ]] && missing_vars+=("DBM_USER")
    [[ -z "$DBM_PASSWORD" ]] && missing_vars+=("DBM_PASSWORD")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing PostgreSQL variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Test connection (if psql is available)
    if command -v psql &> /dev/null; then
        print_step "Testing PostgreSQL connection..."
        if PGPASSWORD="$DBM_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$DBM_USER" -d "$POSTGRES_DATABASE" -c "SELECT version();" &> /dev/null; then
            print_success "PostgreSQL connection successful"
        else
            print_warning "PostgreSQL connection failed (but this might be expected if running from different network)"
        fi
    else
        print_warning "psql not available for connection testing"
    fi
    
    print_success "PostgreSQL configuration variables are set"
    return 0
}

# Test SQL Server configuration
test_sqlserver_config() {
    print_header "Testing SQL Server Configuration"
    
    echo "Variables to be used:"
    echo "  SQLSERVER_HOST: ${SQLSERVER_HOST:-NOT SET}"
    echo "  SQLSERVER_PORT: ${SQLSERVER_PORT:-NOT SET}"
    echo "  SQLSERVER_DATABASE: ${SQLSERVER_DATABASE:-NOT SET}"
    echo "  Combined: ${SQLSERVER_HOST:-NOT SET},${SQLSERVER_PORT:-NOT SET}"
    echo "  DBM_USER: ${DBM_USER:-NOT SET}"
    echo "  DBM_PASSWORD: ${DBM_PASSWORD:+***SET***}"
    echo
    
    # Check if all required variables are set
    local missing_vars=()
    [[ -z "$SQLSERVER_HOST" ]] && missing_vars+=("SQLSERVER_HOST")
    [[ -z "$SQLSERVER_PORT" ]] && missing_vars+=("SQLSERVER_PORT")
    [[ -z "$SQLSERVER_DATABASE" ]] && missing_vars+=("SQLSERVER_DATABASE")
    [[ -z "$DBM_USER" ]] && missing_vars+=("DBM_USER")
    [[ -z "$DBM_PASSWORD" ]] && missing_vars+=("DBM_PASSWORD")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing SQL Server variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Test connection (if sqlcmd is available)
    if command -v sqlcmd &> /dev/null; then
        print_step "Testing SQL Server connection..."
        if sqlcmd -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$DBM_USER" -P "$DBM_PASSWORD" -d "$SQLSERVER_DATABASE" -Q "SELECT @@VERSION" &> /dev/null; then
            print_success "SQL Server connection successful to database: $SQLSERVER_DATABASE"
        else
            print_warning "SQL Server connection failed (but this might be expected if running from different network)"
        fi
    else
        print_warning "sqlcmd not available for connection testing"
    fi
    
    print_success "SQL Server configuration variables are set"
    return 0
}

# Test configuration file substitution
test_config_substitution() {
    print_header "Testing Configuration File Substitution"
    
    # Create temporary files with substituted values
    local temp_dir=$(mktemp -d)
    
    # Test PostgreSQL config
    if [[ -f "conf.d/postgres.d/conf.yaml" ]]; then
        print_step "Testing PostgreSQL config substitution..."
        cp "conf.d/postgres.d/conf.yaml" "$temp_dir/postgres.yaml"
        
        # Substitute variables
        sed -i "s/\${POSTGRES_HOST}/$POSTGRES_HOST/g" "$temp_dir/postgres.yaml"
        sed -i "s/\${POSTGRES_PORT}/$POSTGRES_PORT/g" "$temp_dir/postgres.yaml"
        sed -i "s/\${POSTGRES_DATABASE}/$POSTGRES_DATABASE/g" "$temp_dir/postgres.yaml"
        sed -i "s/\${DBM_USER}/$DBM_USER/g" "$temp_dir/postgres.yaml"
        sed -i "s/\${DBM_PASSWORD}/$DBM_PASSWORD/g" "$temp_dir/postgres.yaml"
        
        # Check if any variables remain unsubstituted
        if grep -q '\${' "$temp_dir/postgres.yaml"; then
            print_warning "Some variables not substituted in PostgreSQL config:"
            grep '\${' "$temp_dir/postgres.yaml" || true
        else
            print_success "All PostgreSQL variables substituted correctly"
        fi
        
        # Validate YAML syntax
        if command -v python3 &> /dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('$temp_dir/postgres.yaml'))" &> /dev/null; then
                print_success "PostgreSQL config YAML syntax is valid"
            else
                print_error "PostgreSQL config YAML syntax is invalid"
            fi
        fi
    fi
    
    # Test SQL Server config
    if [[ -f "conf.d/sqlserver.d/conf.yaml" ]]; then
        print_step "Testing SQL Server config substitution..."
        cp "conf.d/sqlserver.d/conf.yaml" "$temp_dir/sqlserver.yaml"
        
        # Substitute variables
        sed -i "s/\${SQLSERVER_HOST}/$SQLSERVER_HOST/g" "$temp_dir/sqlserver.yaml"
        sed -i "s/\${SQLSERVER_PORT}/$SQLSERVER_PORT/g" "$temp_dir/sqlserver.yaml"
        sed -i "s/\${SQLSERVER_DATABASE}/$SQLSERVER_DATABASE/g" "$temp_dir/sqlserver.yaml"
        sed -i "s/\${DBM_USER}/$DBM_USER/g" "$temp_dir/sqlserver.yaml"
        sed -i "s/\${DBM_PASSWORD}/$DBM_PASSWORD/g" "$temp_dir/sqlserver.yaml"
        
        # Check if any variables remain unsubstituted
        if grep -q '\${' "$temp_dir/sqlserver.yaml"; then
            print_warning "Some variables not substituted in SQL Server config:"
            grep '\${' "$temp_dir/sqlserver.yaml" || true
        else
            print_success "All SQL Server variables substituted correctly"
        fi
        
        # Validate YAML syntax
        if command -v python3 &> /dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('$temp_dir/sqlserver.yaml'))" &> /dev/null; then
                print_success "SQL Server config YAML syntax is valid"
            else
                print_error "SQL Server config YAML syntax is invalid"
            fi
        fi
        
        echo
        print_step "Preview of substituted SQL Server config:"
        echo "---"
        head -15 "$temp_dir/sqlserver.yaml"
        echo "---"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

main() {
    print_header "Database Configuration Test"
    
    load_env
    
    local postgres_ok=true
    local sqlserver_ok=true
    
    test_postgres_config || postgres_ok=false
    echo
    test_sqlserver_config || sqlserver_ok=false
    echo
    test_config_substitution
    echo
    
    if [[ "$postgres_ok" == "true" && "$sqlserver_ok" == "true" ]]; then
        print_success "🎉 All database configurations look good!"
        echo
        echo "Next steps:"
        echo "1. Run: ./scripts/deploy.sh"
        echo "2. Check GitHub secrets are uploaded correctly"
        echo "3. Monitor the deployment workflow"
    else
        print_error "Some database configurations have issues"
        echo
        echo "Please fix the missing variables in your .env file and try again"
        exit 1
    fi
}

main "$@"
