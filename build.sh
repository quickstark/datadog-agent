#!/bin/bash

# Build script for both Synology DS923+ with AMD Ryzen R1600 and local Mac testing
# This script prepares the Datadog Agent image for AMD64 architecture

# Parse command line arguments
USE_CACHE=true
BUILD_LOCAL=false
RUN_COMPOSE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-cache)
      USE_CACHE=false
      shift
      ;;
    --local)
      BUILD_LOCAL=true
      shift
      ;;
    --run)
      RUN_COMPOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--no-cache] [--local] [--run]"
      exit 1
      ;;
  esac
done

# Configuration
IMAGE_NAME="dd-agent"
IMAGE_TAG="latest"
DESKTOP_PATH="$HOME/Desktop"
OUTPUT_FILE="$DESKTOP_PATH/${IMAGE_NAME}.tar"
PLATFORM="linux/amd64"  # AMD Ryzen R1600 is x86_64/AMD64 architecture
DOCKER_GROUP_ID="65536" # Synology DS923+ Docker group ID

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
if [ "$BUILD_LOCAL" = true ]; then
  echo -e "${BLUE}=========================================================${NC}"
  echo -e "${BLUE}   Datadog Agent Builder for Local Mac Testing (AMD64)   ${NC}"
  echo -e "${BLUE}=========================================================${NC}"
else
  echo -e "${BLUE}=========================================================${NC}"
  echo -e "${BLUE}   Datadog Agent Builder for Synology DS923+ (AMD64)     ${NC}"
  echo -e "${BLUE}=========================================================${NC}"
fi

# Prepare build command based on cache option
BUILD_OPTS="--platform=${PLATFORM} --load"
if [ "$USE_CACHE" = false ]; then
    BUILD_OPTS="${BUILD_OPTS} --no-cache"
    echo -e "\n${YELLOW}Building without cache...${NC}"
else
    echo -e "\n${YELLOW}Building with cache...${NC}"
fi

# Build the image using buildx
echo -e "${YELLOW}Building Docker image...${NC}"
docker buildx build ${BUILD_OPTS} -t ${IMAGE_NAME}:${IMAGE_TAG} .

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"
    
    if [ "$BUILD_LOCAL" = false ]; then
        # Save the image for Synology
        echo -e "\n${YELLOW}Saving image to ${OUTPUT_FILE}...${NC}"
        docker save ${IMAGE_NAME}:${IMAGE_TAG} > ${OUTPUT_FILE}
        
        if [ $? -eq 0 ]; then
            FILE_SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
            echo -e "${GREEN}✓ Image saved (${FILE_SIZE})${NC}"
        else
            echo -e "${RED}✗ Failed to save image${NC}"
            exit 1
        fi
    fi
    
    # Run docker-compose if requested
    if [ "$RUN_COMPOSE" = true ]; then
        echo -e "\n${YELLOW}Starting services with docker-compose...${NC}"
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Services started successfully${NC}"
            echo -e "${BLUE}Use 'docker-compose logs -f' to view logs${NC}"
        else
            echo -e "${RED}✗ Failed to start services${NC}"
            exit 1
        fi
    fi
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi 