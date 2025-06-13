#!/bin/bash

# Setup script for Datadog Agent volume configuration
# This script prepares the volume directory structure on Synology NAS

VOLUME_DIR="/volume1/docker/datadog-agent"

echo "Setting up Datadog Agent volume directory structure..."

# Create the main directory structure
echo "Creating directory structure..."
mkdir -p "$VOLUME_DIR/conf.d/postgres.d"
mkdir -p "$VOLUME_DIR/conf.d/mongo.d"
mkdir -p "$VOLUME_DIR/conf.d/snmp.d"
mkdir -p "$VOLUME_DIR/conf.d/syslog.d"

# Copy the main configuration file
echo "Copying datadog.yaml..."
cp datadog.yaml "$VOLUME_DIR/"

# Copy the check configurations
echo "Copying check configurations..."
cp conf.d/postgres.d/conf.yaml "$VOLUME_DIR/conf.d/postgres.d/"
cp conf.d/mongo.d/conf-backup.yaml "$VOLUME_DIR/conf.d/mongo.d/conf.yaml"
cp conf.d/snmp.d/conf.yaml "$VOLUME_DIR/conf.d/snmp.d/"
cp conf.d/syslog.d/conf.yaml "$VOLUME_DIR/conf.d/syslog.d/"

# Set proper permissions
echo "Setting permissions..."
chmod 644 "$VOLUME_DIR/datadog.yaml"
chmod 644 "$VOLUME_DIR/conf.d/postgres.d/conf.yaml"
chmod 644 "$VOLUME_DIR/conf.d/mongo.d/conf.yaml"
chmod 644 "$VOLUME_DIR/conf.d/snmp.d/conf.yaml"
chmod 644 "$VOLUME_DIR/conf.d/syslog.d/conf.yaml"
chmod -R 755 "$VOLUME_DIR/conf.d"

echo "✅ Volume setup complete!"
echo ""
echo "Next steps:"
echo "1. Run this script on your Synology NAS to create the directory structure"
echo "2. Update your Docker Compose to use the volume mapping"
echo "3. Restart your Datadog Agent container"
echo ""
echo "To check if configuration is working:"
echo "- SNMP: docker exec dd-agent datadog-agent status | grep -A 10 snmp"
echo "- Syslog: docker exec dd-agent datadog-agent status | grep -A 10 syslog"
echo "- NetFlow: Check Datadog UI for network monitoring data"
echo ""
echo "Directory structure created at: $VOLUME_DIR"
echo "├── datadog.yaml"
echo "└── conf.d/"
echo "    ├── postgres.d/"
echo "    │   └── conf.yaml"
echo "    └── mongo.d/"
echo "        └── conf.yaml"
echo ""
echo "NetFlow ports exposed:"
echo "- 2055/udp (NetFlow 9)"
echo "- 2056/udp (NetFlow 5)" 
echo "- 4739/udp (IPFIX)"
echo "- 6343/udp (sFlow 5)"
echo ""
echo "Syslog port exposed:"
echo "- 514/udp (Syslog)"
echo ""
echo "Configure your UniFi router to send NetFlow data to:"
echo "- IP: <your-synology-ip>"
echo "- Port: 2055 (for NetFlow 9) or 2056 (for NetFlow 5)" 