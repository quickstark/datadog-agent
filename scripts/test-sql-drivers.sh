#!/bin/bash

# Test different SQL Server driver configurations
# This script helps test driver compatibility without breaking the deployment

echo "🧪 Testing SQL Server Driver Configurations"
echo "=========================================="

# Check current ODBC drivers available in container
echo "📋 Available ODBC drivers:"
if docker exec dd-agent odbcinst -q -d 2>/dev/null; then
    docker exec dd-agent odbcinst -q -d
else
    echo "⚠️  Container not running or ODBC not accessible"
fi

echo ""
echo "🔍 FreeTDS configuration:"
if docker exec dd-agent cat /etc/odbcinst.ini 2>/dev/null; then
    docker exec dd-agent cat /etc/odbcinst.ini | grep -A5 "FreeTDS"
else
    echo "⚠️  Cannot access ODBC configuration"
fi

echo ""
echo "🧪 Testing SQL Server connection with current driver:"
if docker exec dd-agent datadog-agent check sqlserver 2>/dev/null; then
    echo "✅ Current FreeTDS driver is working"
else
    echo "❌ Current driver has issues"
fi

echo ""
echo "💡 Driver Options:"
echo "1. FreeTDS (current) - Basic connectivity, limited DBM features"
echo "2. Microsoft ODBC Driver 18 - Best DBM support, requires Dockerfile change"
echo "3. SQL Server Native Client - Windows-focused, complex setup"
echo ""
echo "📊 For better APM correlation, Microsoft ODBC Driver 18 is recommended."
