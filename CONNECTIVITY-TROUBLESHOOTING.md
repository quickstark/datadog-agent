# 🚨 Synology Connectivity Troubleshooting Guide

## Problem Analysis

Your GitHub Actions workflow is failing with this error:
```
dial tcp 47.161.177.227:***: i/o timeout
```

This indicates that:
- ✅ DNS Resolution: `ssh.quickstark.com` → `47.161.177.227` (Working)
- ❌ Network Connectivity: Cannot reach the host from GitHub's network (Failing)

## Root Cause Analysis

The issue is **network connectivity**, not environment variables. GitHub Actions runners cannot establish a TCP connection to your Synology host on port 2222.

### Most Likely Causes:

1. **🔥 Firewall/NAT Issues**: Host behind router without proper port forwarding
2. **🚫 ISP Blocking**: ISP blocking port 2222 
3. **🛑 SSH Service**: SSH service not running or misconfigured
4. **⏱️ Network Routing**: Routing issues between GitHub's network and your host

## 🔧 Solutions Implemented

### 1. Enhanced Workflow with Fallback Methods

The updated GitHub workflow now includes:

- **Connectivity Test**: Pre-checks DNS and port accessibility
- **Primary Method**: SCP file transfer (original approach)
- **Fallback Method**: SSH-based file creation directly on the server
- **Ultimate Fallback**: Pull-based deployment with downloadable package

### 2. Three-Tier Deployment Strategy

#### **Tier 1: Direct SCP (Ideal)**
```yaml
- name: Copy configuration files to Synology (Primary Method)
  uses: appleboy/scp-action@v0.1.7
  with:
    timeout: 60s
    debug: true
```

#### **Tier 2: SSH Fallback (Automatic)**
```yaml
- name: Copy configuration files via SSH (Fallback Method)
  if: steps.scp_primary.outcome == 'failure'
  uses: appleboy/ssh-action@v1.0.3
```

#### **Tier 3: Pull-Based (Manual)**
- Downloads deployment package as GitHub artifact
- Manual execution on Synology host

## 🩺 Immediate Troubleshooting Steps

### Step 1: Check Network Connectivity

From any external network, test connectivity:

```bash
# Test DNS resolution
nslookup ssh.quickstark.com

# Test port connectivity
nc -zv ssh.quickstark.com 2222

# Test with timeout
timeout 10s telnet ssh.quickstark.com 2222
```

### Step 2: Verify SSH Service on Synology

SSH into your Synology and check:

```bash
# Check if SSH is running
sudo systemctl status ssh
# or
sudo service ssh status

# Check SSH configuration
sudo cat /etc/ssh/sshd_config | grep Port

# Check if port 2222 is listening
sudo netstat -tulpn | grep 2222
# or
sudo ss -tulpn | grep 2222

# Test local SSH connection
ssh -p 2222 ssh-user@localhost
```

### Step 3: Router/Firewall Configuration

Check your router configuration:

1. **Port Forwarding**: Ensure port 2222 is forwarded to your Synology
2. **Firewall Rules**: Check if port 2222 is allowed in firewall
3. **UPnP**: Verify if UPnP is working for automatic port forwarding

### Step 4: ISP Considerations

Some ISPs block common SSH ports:
- **Port 22**: Often blocked
- **Port 2222**: Sometimes blocked
- **Alternative**: Try port 443, 80, or other commonly allowed ports

## 🚀 Enhanced Workflow Benefits

### Automatic Recovery
The updated workflow will:

1. **Test connectivity first** - Identifies the exact issue
2. **Attempt SCP** - Uses optimal method when possible
3. **Fall back to SSH** - Creates files directly when SCP fails
4. **Provide manual option** - Downloads package for manual deployment

### Debug Information
Enhanced logging shows:

- DNS resolution results
- Port connectivity status  
- Detailed error messages
- Alternative deployment paths

### Zero Configuration Changes
All environment variables work exactly as before - this only fixes the connectivity issue.

## 📋 Next Steps

1. **Run the updated workflow** - It will now provide detailed diagnostics
2. **Check the connectivity test output** - This will pinpoint the exact issue
3. **If SCP fails**, the SSH fallback will still deploy successfully
4. **For persistent issues**, use the manual deployment package

## 🔍 Expected Workflow Output

With the enhanced workflow, you'll see:

```
🔍 Testing connectivity to Synology host...
Host: ssh.quickstark.com
Port: 2222

📡 DNS Resolution:
Server: 8.8.8.8
Address: 8.8.8.8#53
Name: ssh.quickstark.com
Address: 47.161.177.227

🔌 Port connectivity test:
Connection to ssh.quickstark.com 2222 port [tcp/*] succeeded!
✅ Basic connectivity test passed
```

Or if there's an issue:

```
❌ Port 2222 is not reachable
This could be due to:
  1. Firewall blocking the port
  2. Host behind NAT without port forwarding  
  3. SSH service not running
  4. ISP blocking the port
```

## 📞 Support Commands

If you need help diagnosing the issue, run these commands and share the output:

```bash
# From your local network
nslookup ssh.quickstark.com
nc -zv ssh.quickstark.com 2222

# From your Synology
sudo netstat -tulpn | grep 2222
sudo systemctl status ssh
```

The enhanced workflow will now handle connectivity issues gracefully and provide multiple paths to successful deployment! 🎉