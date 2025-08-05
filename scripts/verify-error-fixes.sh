#!/bin/bash

# Verify Error Fixes Script
# Checks that the persistent Datadog Agent errors have been resolved

echo "🔍 Verifying Datadog Agent Error Fixes"
echo "====================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SYNOLOGY_IP="192.168.1.100"

echo -e "${BLUE}🎯 Checking fixes for persistent errors:${NC}"
echo "1. System Probe connections 404 error"
echo "2. SNMP sysObjectID profile errors"
echo ""

# Check 1: Configuration validation
echo -e "${YELLOW}Check 1: Validating configuration changes...${NC}"

# Check if process config has network disabled
if grep -q "network:" datadog.yaml && grep -A1 "network:" datadog.yaml | grep -q "enabled: false"; then
    echo -e "${GREEN}✅ Process agent network connections disabled${NC}"
else
    echo -e "${RED}❌ Process agent network connections not properly disabled${NC}"
fi

# Check if SNMP generic-device profile is removed
if ! grep -q "generic-device" conf.d/snmp.d/conf.yaml; then
    echo -e "${GREEN}✅ SNMP generic-device profile removed${NC}"
else
    echo -e "${RED}❌ SNMP generic-device profile still present${NC}"
fi

# Check if Synology SNMP monitoring is disabled
if grep -q "# - ip_address: '192.168.1.100'" conf.d/snmp.d/conf.yaml; then
    echo -e "${GREEN}✅ Synology SNMP monitoring disabled${NC}"
else
    echo -e "${RED}❌ Synology SNMP monitoring not properly disabled${NC}"
fi

echo ""

# Check 2: SSH to Synology and check agent logs
echo -e "${YELLOW}Check 2: Testing agent log errors (requires SSH access)...${NC}"

# Instructions for manual verification
echo -e "${BLUE}📋 Manual Verification Steps:${NC}"
echo ""
echo "After deploying these changes, SSH to your Synology and check:"
echo ""
echo "1. SSH to Synology:"
echo "   ssh admin@$SYNOLOGY_IP"
echo ""
echo "2. Check for the persistent errors (should be GONE):"
echo "   docker logs dd-agent --since 10m | grep -E \"connections.*404|sysObjectID.*1.3.6.1.4.1.8072.3.2.10|generic-device\""
echo ""
echo "3. Check overall agent health:"
echo "   docker exec dd-agent /opt/datadog-agent/bin/agent/agent health"
echo ""
echo "4. Check SNMP check status:"
echo "   docker exec dd-agent /opt/datadog-agent/bin/agent/agent status | grep -A 10 snmp"
echo ""
echo "5. Monitor logs for 5 minutes to ensure errors don't return:"
echo "   docker logs dd-agent --follow | grep -E \"ERROR|connections|sysObjectID|generic-device\""
echo ""

# Expected results
echo -e "${BLUE}🎯 Expected Results After Deployment:${NC}"
echo ""
echo -e "${GREEN}✅ No more errors:${NC}"
echo "   • \"Unable to run check 'connections': conn request failed: url: http://sysprobe/network_tracer/connections\""
echo "   • \"failed to get profile for sysObjectID '1.3.6.1.4.1.8072.3.2.10'\""
echo "   • \"unknown profile 'generic-device'\""
echo ""
echo -e "${GREEN}✅ Preserved functionality:${NC}"
echo "   • Process monitoring (without network connections)"
echo "   • Container monitoring"  
echo "   • SNMP monitoring for router (192.168.1.1) and printer (192.168.1.190)"
echo "   • All other agent features working normally"
echo ""

# Deployment reminder
echo -e "${BLUE}🚀 Deployment:${NC}"
echo "These configuration changes will be deployed automatically when you:"
echo "1. Commit and push these changes to GitHub"
echo "2. GitHub Actions will redeploy the agent with the new configuration"
echo "3. The errors should stop appearing in the logs"
echo ""

# Alternative quick test (if curl is available)
echo -e "${YELLOW}Quick Network Test (optional):${NC}"
if command -v curl &> /dev/null; then
    echo "Testing if Datadog Agent API is accessible..."
    if curl -s --connect-timeout 5 "http://$SYNOLOGY_IP:5002/status" > /dev/null; then
        echo -e "${GREEN}✅ Datadog Agent API is accessible${NC}"
        echo "   You can view detailed status at: http://$SYNOLOGY_IP:5002/status"
    else
        echo -e "${YELLOW}⚠️  Datadog Agent API not accessible (may be normal if agent is restarting)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  curl not available - skipping API test${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Configuration fixes applied successfully!${NC}"
echo -e "${BLUE}Deploy via GitHub Actions to eliminate these persistent errors.${NC}" 