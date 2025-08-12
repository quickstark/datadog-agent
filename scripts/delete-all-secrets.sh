#!/bin/bash

# Simple script to delete all GitHub secrets
echo "🧹 This will delete ALL GitHub secrets from quickstark/datadog-agent"
echo "📋 Current secrets:"
gh secret list --repo quickstark/datadog-agent

echo ""
echo "⚠️  WARNING: This cannot be undone!"
read -p "Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" = "DELETE" ]; then
    echo "🗑️  Deleting all secrets..."
    
    # Get secret names and delete them one by one
    gh secret list --repo quickstark/datadog-agent | awk 'NR>1 {print $1}' | while read secret; do
        echo "  Deleting: $secret"
        if gh secret delete "$secret" --repo quickstark/datadog-agent; then
            echo "  ✅ Deleted: $secret"
        else
            echo "  ❌ Failed: $secret"
        fi
    done
    
    echo ""
    echo "🎉 All secrets deleted! Run ./scripts/deploy.sh to upload fresh ones."
else
    echo "❌ Deletion cancelled"
fi
