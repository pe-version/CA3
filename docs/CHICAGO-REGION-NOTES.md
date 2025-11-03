# Oracle Cloud Chicago Region (us-chicago-1) - Quick Reference

## Your Region Configuration

✅ **Selected Region**: US Midwest (Chicago) - `us-chicago-1`

---

## Impact Analysis

### What's Different from Default (us-ashburn-1)?

| Aspect | Chicago (us-chicago-1) | Ashburn (us-ashburn-1) | Notes |
|--------|------------------------|------------------------|-------|
| **Free tier** | ✅ Same | ✅ Same | 4 OCPU + 24GB RAM forever |
| **ARM capacity** | ✅ Same | ✅ Same | VM.Standard.A1.Flex available |
| **Latency** | ~10-20ms (if Midwest US) | ~30-50ms (if Midwest US) | **Chicago is better for you!** |
| **Features** | ✅ Identical | ✅ Identical | All services available |
| **Pricing** | $0.00 (free tier) | $0.00 (free tier) | Both FREE |

### Configuration Values You Need

When filling in `terraform.tfvars`:

```hcl
region = "us-chicago-1"

# Availability Domain format for Chicago:
availability_domain = "YXRh:US-CHICAGO-1-AD-1"
# Or: YXRh:US-CHICAGO-1-AD-2
# Or: YXRh:US-CHICAGO-1-AD-3
```

**Check which AD has capacity**:
1. OCI Console → Governance → Limits, Quotas and Usage
2. Service: Compute
3. Resource: VM.Standard.A1.Flex - OCPU Count
4. Look for "Available" > 0 in AD-1, AD-2, or AD-3

---

## ~/.oci/config File

Your config file should look like this:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaa<your-user-id>
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..aaaaaa<your-tenancy-id>
region=us-chicago-1
key_file=~/.oci/oci_api_key.pem
```

**⚠️ Important**: Make sure `region=us-chicago-1` (NOT `us-ashburn-1`)

---

## Availability Domain String Format

The format is different per region:

### Chicago (us-chicago-1)
```
YXRh:US-CHICAGO-1-AD-1
YXRh:US-CHICAGO-1-AD-2
YXRh:US-CHICAGO-1-AD-3
```

### Other Regions (for reference)
```
# Ashburn (us-ashburn-1)
iKTz:US-ASHBURN-AD-1

# Phoenix (us-phoenix-1)
PHX-AD-1

# San Jose (us-sanjose-1)
qIZq:US-SANJOSE-1-AD-1
```

**How to find your exact string**:
1. OCI Console → Compute → Instances
2. Click "Create Instance"
3. Under "Placement", the dropdown shows exact AD strings for your region

---

## terraform.tfvars Example (Chicago)

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaaaa..."
compartment_ocid = "ocid1.compartment.oc1..aaaaaaa..."
availability_domain = "YXRh:US-CHICAGO-1-AD-1"  # Check which AD has capacity!
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2E..."
```

---

## Latency Comparison (from various US locations)

| Your Location | Chicago Latency | Ashburn Latency | Winner |
|---------------|-----------------|-----------------|--------|
| Chicago, IL | ~5ms | ~30ms | 🏆 Chicago |
| Detroit, MI | ~10ms | ~25ms | 🏆 Chicago |
| Minneapolis, MN | ~15ms | ~35ms | 🏆 Chicago |
| Kansas City, MO | ~15ms | ~35ms | 🏆 Chicago |
| New York, NY | ~30ms | ~5ms | Ashburn |
| San Francisco, CA | ~50ms | ~70ms | 🏆 Chicago |

**If you're anywhere in the Central US**, Chicago is the best choice!

---

## Troubleshooting

### "Can't find Availability Domain in Terraform"

**Error**:
```
Error: 404-NotAuthorizedOrNotFound, Authorization failed or requested resource not found
```

**Solution**: Wrong AD format. For Chicago, use:
```
availability_domain = "YXRh:US-CHICAGO-1-AD-1"
```

NOT:
```
availability_domain = "US-CHICAGO-1-AD-1"  # ❌ Missing prefix
availability_domain = "iKTz:US-CHICAGO-1-AD-1"  # ❌ Wrong prefix (that's Ashburn)
```

### "Out of host capacity"

Try different ADs:
```bash
# In terraform.tfvars, try each:
availability_domain = "YXRh:US-CHICAGO-1-AD-1"
# If that fails, try:
availability_domain = "YXRh:US-CHICAGO-1-AD-2"
# If that fails, try:
availability_domain = "YXRh:US-CHICAGO-1-AD-3"
```

### "How do I verify my region?"

```bash
# Check your OCI config:
grep region ~/.oci/config

# Should show:
# region=us-chicago-1

# If it shows us-ashburn-1, edit it:
vi ~/.oci/config
# Change: region=us-ashburn-1
# To:     region=us-chicago-1
```

---

## Deployment Command (No Changes Needed!)

Your deployment process is identical:

```bash
cd ~/Downloads/CA2

# Verify setup (checks region automatically)
./scripts/verify-oci-setup.sh

# Deploy (uses region from terraform.tfvars)
./scripts/oracle-deploy.sh
```

The scripts automatically use `us-chicago-1` from your configuration.

---

## Summary

✅ **Chicago region is perfectly fine** - actually better if you're in Central US!
✅ **All documentation updated** to reflect us-chicago-1
✅ **Zero functional differences** from Ashburn
✅ **Still 100% FREE** with Always Free tier
✅ **Probably lower latency** for you
✅ **No action needed** beyond following the normal setup guide

**Bottom line**: You made a good choice! Chicago might actually be **faster** for you than Ashburn.

---

## Next Steps

Continue with the normal setup process - everything works identically:

1. Generate API keys → [docs/oracle-cloud-setup.md](oracle-cloud-setup.md#step-3)
2. Create terraform.tfvars → Use `YXRh:US-CHICAGO-1-AD-1` format
3. Deploy → `./scripts/oracle-deploy.sh`

No special Chicago-specific steps required!
