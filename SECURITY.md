# 🔐 Security Notice

## ⚠️ **IMPORTANT SECURITY UPDATE**

**Previous versions of this repository contained hardcoded API keys in `docker-compose.yaml`.**

### 🚨 **If you cloned this repo before this security fix:**

1. **Immediately rotate your Datadog API keys:**
   - Go to [Datadog API Keys](https://app.datadoghq.com/organization-settings/api-keys)
   - Delete the exposed keys
   - Generate new ones

2. **Check your git history:**
   ```bash
   # Search for exposed keys in git history
   git log --all --full-history -- docker-compose.yaml
   ```

3. **Consider the repository compromised:**
   - If this was a public repository, assume the keys were exposed
   - Audit your Datadog account for any unauthorized activity

## ✅ **Current Security Measures**

### **Environment Variables**
- All secrets are now stored in environment variables
- `docker-compose.yaml` uses `${VARIABLE}` syntax
- No hardcoded secrets in any committed files

### **GitHub Secrets**
- API keys stored securely in GitHub repository secrets
- Secrets are injected during deployment only
- Never logged or exposed in workflow outputs

### **Local Development**
- Use `.env.datadog` file (gitignored)
- Copy from `env.example` template
- Never commit actual environment files

### **File Permissions**
- `.env` files have restricted permissions (600)
- Configuration files are read-only in containers
- SSH keys are properly secured

## 🛡️ **Best Practices**

### **For Contributors:**
1. **Never commit secrets** - Use environment variables
2. **Use `.env` files** - Keep them local and gitignored
3. **Rotate keys regularly** - Especially after any potential exposure
4. **Review PRs carefully** - Check for accidentally committed secrets

### **For Deployment:**
1. **Use the deployment script** - `./scripts/deploy.sh`
2. **Verify secrets are set** - Script validates before deployment
3. **Monitor access logs** - Check Datadog for unauthorized usage
4. **Use least privilege** - Only grant necessary permissions

## 🔍 **Detecting Secrets in Code**

### **Pre-commit Hooks**
Consider adding tools like:
- `detect-secrets`
- `git-secrets`
- `truffleHog`

### **Manual Checks**
```bash
# Search for potential API keys
grep -r "DD_API_KEY=" . --exclude-dir=.git
grep -r "sk-" . --exclude-dir=.git
grep -r "secret" . --exclude-dir=.git
```

## 📞 **Incident Response**

If you discover exposed secrets:

1. **Immediately rotate** all potentially exposed keys
2. **Check access logs** in Datadog for unauthorized usage
3. **Update all deployments** with new keys
4. **Document the incident** for future prevention

## 🔗 **Resources**

- [Datadog API Key Management](https://docs.datadoghq.com/account_management/api-app-keys/)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)

---

**Remember: Security is everyone's responsibility. When in doubt, ask for a security review.** 