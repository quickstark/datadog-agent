#!/bin/bash

# Setup script for Synology Datadog Agent deployment
# This script prepares the Synology environment and syncs configuration files

# Configuration
SYNOLOGY_HOST="${SYNOLOGY_HOST:-192.168.1.100}"
SYNOLOGY_USER="${SYNOLOGY_USER:-dirk}"
SYNOLOGY_SSH_PORT="${SYNOLOGY_SSH_PORT:-22}"
REMOTE_DIR="/volume1/docker/datadog-agent"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Synology Datadog Agent Setup Script        ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "${YELLOW}SSH key not found. Please generate one:${NC}"
    echo "ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
    echo "Then copy it to Synology:"
    echo "ssh-copy-id -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST"
    exit 1
fi

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection to Synology...${NC}"
if ! ssh -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${RED}❌ SSH connection failed${NC}"
    echo "Please ensure:"
    echo "1. SSH is enabled on your Synology"
    echo "2. Your SSH key is copied to Synology"
    echo "3. Host/port/username are correct"
    exit 1
fi
echo -e "${GREEN}✅ SSH connection successful${NC}"

# Create remote directory structure
echo -e "${YELLOW}Creating remote directory structure...${NC}"
ssh -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST "
    sudo mkdir -p $REMOTE_DIR/conf.d/{postgres.d,mongo.d,network_path.d,networkdevice.d,snmp.d,syslog.d}
    sudo chown -R $SYNOLOGY_USER:users $REMOTE_DIR
    chmod 755 $REMOTE_DIR
    chmod -R 755 $REMOTE_DIR/conf.d
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Directory structure created${NC}"
else
    echo -e "${RED}❌ Failed to create directory structure${NC}"
    exit 1
fi

# Sync configuration files
echo -e "${YELLOW}Syncing configuration files...${NC}"

# Sync main configuration files
scp -P $SYNOLOGY_SSH_PORT datadog.yaml $SYNOLOGY_USER@$SYNOLOGY_HOST:$REMOTE_DIR/
scp -P $SYNOLOGY_SSH_PORT system-probe.yaml $SYNOLOGY_USER@$SYNOLOGY_HOST:$REMOTE_DIR/

# Sync conf.d directory
scp -r -P $SYNOLOGY_SSH_PORT conf.d/* $SYNOLOGY_USER@$SYNOLOGY_HOST:$REMOTE_DIR/conf.d/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Configuration files synced${NC}"
else
    echo -e "${RED}❌ Failed to sync configuration files${NC}"
    exit 1
fi

# Set proper permissions
echo -e "${YELLOW}Setting file permissions...${NC}"
ssh -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST "
    chmod 644 $REMOTE_DIR/datadog.yaml
    chmod 644 $REMOTE_DIR/system-probe.yaml
    find $REMOTE_DIR/conf.d -name '*.yaml' -exec chmod 644 {} \;
    ls -la $REMOTE_DIR/
    ls -la $REMOTE_DIR/conf.d/
"

echo -e "${GREEN}✅ File permissions set${NC}"

# Check Docker setup on Synology
echo -e "${YELLOW}Checking Docker setup on Synology...${NC}"
ssh -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST "
    if command -v docker >/dev/null 2>&1; then
        echo 'Docker is installed'
        docker --version
    elif [ -f /usr/local/bin/docker ]; then
        echo 'Docker found at /usr/local/bin/docker'
        /usr/local/bin/docker --version
    else
        echo 'Docker not found. Please install Docker on Synology.'
        exit 1
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo 'Docker Compose is available'
        docker-compose --version
    elif docker compose version >/dev/null 2>&1; then
        echo 'Docker Compose (V2) is available'
        docker compose version
    else
        echo 'Docker Compose not found. Please install Docker Compose.'
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker setup verified${NC}"
else
    echo -e "${RED}❌ Docker setup issues detected${NC}"
    exit 1
fi

# Display next steps
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}                Setup Complete!                 ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Add the following secrets to your GitHub repository:"
echo "   - SYNOLOGY_HOST (your Synology IP address)"
echo "   - SYNOLOGY_USER (your SSH username)"
echo "   - SYNOLOGY_SSH_PORT (usually 22)"
echo "   - SSH_PRIVATE_KEY (your private SSH key content)"
echo "   - DOCKERHUB_USERNAME (your Docker Hub username)"
echo "   - DOCKERHUB_TOKEN (your Docker Hub access token)"
echo "   - DD_API_KEY (your Datadog API key)"
echo "   - DD_OPW_API_KEY (your OPW API key)"
echo "   - DD_OP_PIPELINE_ID (your OPW Pipeline ID)"
echo ""
echo "2. Test the manual deployment first:"
echo "   ssh -p $SYNOLOGY_SSH_PORT $SYNOLOGY_USER@$SYNOLOGY_HOST"
echo "   cd $REMOTE_DIR"
echo "   docker-compose up -d"
echo ""
echo "3. Push your changes to trigger the automated deployment!"
echo ""
echo -e "${YELLOW}Configuration files are now synced to:${NC}"
echo "   $SYNOLOGY_HOST:$REMOTE_DIR"
echo ""
echo -e "${YELLOW}You can monitor the deployment at:${NC}"
echo "   http://$SYNOLOGY_HOST:5002/status (Datadog Agent)"
echo "   http://$SYNOLOGY_HOST:8686 (OPW API)" 