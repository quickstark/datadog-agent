#!/bin/bash

# SNMP Debug Script - Find the source of sysObjectID 1.3.6.1.4.1.8072.3.2.10
# This script helps identify which device is causing the SNMP profile error

echo "🔍 SNMP Device Discovery Debug Script"
echo "======================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if snmpwalk is available
if ! command -v snmpwalk &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Neither snmpwalk nor docker found. Please install net-snmp-utils or run this on a system with docker.${NC}"
    exit 1
fi

# Known devices from your config
DEVICES=(
    "192.168.1.1:quickstark"
    "192.168.1.190:public"
    "192.168.1.100:public"  # Your Synology - adding this to check
    "127.0.0.1:public"      # Localhost check
)

echo -e "${BLUE}Checking known devices for sysObjectID...${NC}"
echo ""

check_device() {
    local ip_port="$1"
    local ip=$(echo "$ip_port" | cut -d: -f1)
    local community=$(echo "$ip_port" | cut -d: -f2)
    
    echo -e "${YELLOW}Checking $ip (community: $community)...${NC}"
    
    # Try with snmpwalk first, then docker if available
    if command -v snmpwalk &> /dev/null; then
        result=$(timeout 10 snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.2.0 2>/dev/null)
    elif command -v docker &> /dev/null; then
        # Use docker with net-snmp image if available
        result=$(timeout 10 docker run --rm --network host alpine/net-snmp snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.2.0 2>/dev/null)
    fi
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        sysoid=$(echo "$result" | awk '{print $4}')
        echo -e "${GREEN}  ✅ Device found: $ip${NC}"
        echo -e "     sysObjectID: $sysoid"
        
        if [[ "$sysoid" == *"1.3.6.1.4.1.8072.3.2.10"* ]]; then
            echo -e "${RED}  🎯 FOUND THE CULPRIT! This is the Linux device causing the error.${NC}"
            
            # Get more details
            echo -e "${YELLOW}  Getting device details...${NC}"
            if command -v snmpwalk &> /dev/null; then
                sysname=$(timeout 5 snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.5.0 2>/dev/null | awk -F'"' '{print $2}')
                sysdesc=$(timeout 5 snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.1.0 2>/dev/null | awk -F'"' '{print $2}')
            elif command -v docker &> /dev/null; then
                sysname=$(timeout 5 docker run --rm --network host alpine/net-snmp snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.5.0 2>/dev/null | awk -F'"' '{print $2}')
                sysdesc=$(timeout 5 docker run --rm --network host alpine/net-snmp snmpwalk -v2c -c "$community" "$ip" 1.3.6.1.2.1.1.1.0 2>/dev/null | awk -F'"' '{print $2}')
            fi
            
            echo -e "     System Name: ${sysname:-Unknown}"
            echo -e "     Description: ${sysdesc:-Unknown}"
            FOUND_DEVICE="$ip"
        fi
        echo ""
    else
        echo -e "${RED}  ❌ No response from $ip${NC}"
        echo ""
    fi
}

FOUND_DEVICE=""

# Check each device
for device in "${DEVICES[@]}"; do
    check_device "$device"
done

echo "======================================="
echo -e "${BLUE}Discovery complete!${NC}"
echo ""

if [ -n "$FOUND_DEVICE" ]; then
    echo -e "${GREEN}🎯 The problematic device is: $FOUND_DEVICE${NC}"
    echo ""
    echo -e "${YELLOW}Solutions:${NC}"
    echo "1. Add this device to your SNMP configuration with a proper profile"
    echo "2. Exclude this device from SNMP monitoring"
    echo "3. Disable SNMP on the device if monitoring is not needed"
    echo ""
    echo -e "${YELLOW}To add to your Datadog SNMP config:${NC}"
    echo "  - ip_address: '$FOUND_DEVICE'"
    echo "    community_string: 'public'  # or the correct community string"
    echo "    tags:"
    echo "      - \"device_type:linux\""
    echo "      - \"snmp_device:linux-server\""
else
    echo -e "${YELLOW}⚠️  Device not found in the checked IPs.${NC}"
    echo ""
    echo -e "${YELLOW}The device might be:${NC}"
    echo "1. A different IP address on your network"
    echo "2. Being discovered through network autodiscovery"
    echo "3. The Datadog Agent container itself"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Check your Datadog Agent logs for the exact IP address"
    echo "2. Scan your network for devices with SNMP enabled"
    echo "3. Check if SNMP autodiscovery is enabled in your Datadog config"
fi

echo ""
echo -e "${BLUE}Additional debugging:${NC}"
echo "- Check Datadog Agent logs: docker logs dd-agent | grep -i snmp"
echo "- Check Agent status: docker exec dd-agent datadog-agent status"
echo "- Network scan: nmap -sU -p 161 192.168.1.0/24" 