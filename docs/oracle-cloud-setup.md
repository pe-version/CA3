# Oracle Cloud Infrastructure (OCI) Setup Guide

## Why Oracle Cloud for CA3?

**FREE FOREVER Resources**:
- VM.Standard.A1.Flex: 4 OCPUs (ARM), 24GB RAM total - **ALWAYS FREE**
- 200GB block storage - **ALWAYS FREE**
- 10TB outbound transfer/month - **ALWAYS FREE**

**For CA3**: We'll use 1 instance with 4 OCPU, 12GB RAM (half of the free allowance)

---


## Step 1: Create Oracle Cloud Account (10 minutes)

1. Go to: https://www.oracle.com/cloud/free/

2. Click **"Start for free"**

3. Fill in registration:
   - Email address
   - Country (United States)
   - First/Last name

4. Verify email (check spam folder)

5. Complete registration:
   - Choose **"Individual"** (not business)
   - Home region: **"US Midwest (Chicago)"** - us-chicago-1
     - ✅ You already selected this - great choice for Midwest US
     - Low latency (~10-20ms if you're in Central US)
     - All features identical to other regions
   - Add credit card (for verification only - you won't be charged for Free Tier)

6. Wait 2-5 minutes for account provisioning

7. Login to: https://cloud.oracle.com/

---

## Step 2: Create Compartment (3 minutes)

Compartments organize resources (like AWS resource groups).

1. In OCI Console, click hamburger menu (≡) → **Identity & Security** → **Compartments**

2. Click **"Create Compartment"**

3. Fill in:
   - Name: `CA3-Metals-Pipeline`
   - Description: `Container orchestration assignment`
   - Parent: `(root)` (default)

4. Click **"Create Compartment"**

5. **IMPORTANT**: Copy the Compartment OCID (looks like `ocid1.compartment.oc1..aaaa...`)
   - You'll need this for Terraform

---

## Step 3: Create API Key for Terraform (5 minutes)

Terraform needs API credentials to manage OCI resources.

### Generate API Key Pair

```bash
# On your local machine
mkdir -p ~/.oci
cd ~/.oci

# Generate private key (without passphrase for simplicity)
openssl genrsa -out oci_api_key.pem 2048

# Generate public key
openssl rsa -pubout -in oci_api_key.pem -out oci_api_key_public.pem

# Set correct permissions
chmod 600 oci_api_key.pem
chmod 644 oci_api_key_public.pem

# Display public key (you'll upload this to OCI)
cat oci_api_key_public.pem
```

### Upload Public Key to OCI

1. In OCI Console, click **Profile icon** (top right) → **User Settings**

2. Scroll to **API Keys** section → Click **"Add API Key"**

3. Select **"Paste Public Key"**

4. Copy/paste contents of `oci_api_key_public.pem` (including the BEGIN/END lines)

5. Click **"Add"**

6. **Configuration File Preview** appears - copy this info:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaa...
   fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
   tenancy=ocid1.tenancy.oc1..aaaaaa...
   region=us-chicago-1
   key_file=~/.oci/oci_api_key.pem
   ```

7. Save this to `~/.oci/config`:
   ```bash
   cat > ~/.oci/config <<'EOF'
   [DEFAULT]
   user=<paste your user OCID>
   fingerprint=<paste your fingerprint>
   tenancy=<paste your tenancy OCID>
   region=us-chicago-1
   key_file=~/.oci/oci_api_key.pem
   EOF

   chmod 600 ~/.oci/config
   ```

---

## Step 4: Create SSH Key for VM Access (2 minutes)

```bash
# Generate SSH key for VM access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oci_ca3 -N ""

# Display public key (you'll use this in Terraform)
cat ~/.ssh/oci_ca3.pub
```

---

## Step 5: Get Required OCIDs

You need these values for Terraform:

### 1. Tenancy OCID
- In OCI Console: **Profile icon** → **Tenancy: <name>**
- Copy the OCID (starts with `ocid1.tenancy.oc1..`)

### 2. User OCID
- In OCI Console: **Profile icon** → **User Settings**
- Copy the OCID (starts with `ocid1.user.oc1..`)

### 3. Compartment OCID
- From Step 2 above (starts with `ocid1.compartment.oc1..`)

### 4. Availability Domain
- In OCI Console: **Hamburger menu** → **Governance** → **Limits, Quotas and Usage**
- Click **"Compute"** → **"VM.Standard.A1.Flex"**
- Note which Availability Domain has quota (usually `AD-1`, `AD-2`, or `AD-3`)
- **Format for us-chicago-1**: `YXRh:US-CHICAGO-1-AD-1` (or `-AD-2`, `-AD-3`)
- Format for other regions:
  - us-ashburn-1: `iKTz:US-ASHBURN-AD-1`
  - us-phoenix-1: `PHX-AD-1`

---

## Step 6: Verify Free Tier Eligibility

Check you have ARM capacity available:

1. **Hamburger menu** → **Governance** → **Limits, Quotas and Usage**

2. Select **Service**: `Compute`

3. Find **"VM.Standard.A1.Flex - OCPU Count"**:
   - Available: Should show `4` or higher
   - Used: Should show `0`

4. If Available = 0:
   - Try different Availability Domains
   - Wait a few hours (capacity issues are temporary)
   - Contact Oracle Support (they prioritize Free Tier users)

---

## Troubleshooting

### "Out of host capacity"
- Try creating instance in different AD (AD-1, AD-2, AD-3)
- Try different times of day (lower demand = better chance)
- Oracle usually provisions new capacity within 24 hours

### "Service limit exceeded"
- You may have existing instances - delete them first
- Check all regions (you might have instances in another region)

### API key not working
- Verify fingerprint matches: `openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c`
- Ensure no trailing whitespace in `~/.oci/config`

---

## Next Steps

Once you complete the above:

1. Have these ready for Terraform:
   - ✅ Tenancy OCID
   - ✅ User OCID
   - ✅ Compartment OCID
   - ✅ Availability Domain name
   - ✅ SSH public key content (`~/.ssh/oci_ca3.pub`)
   - ✅ API key at `~/.oci/oci_api_key.pem`
   - ✅ Config file at `~/.oci/config`

2. Return to the main workflow - we'll create Terraform configs next

---

## Cost Verification

**Before deploying, verify you're using Free Tier**:

In OCI Console:
1. **Hamburger menu** → **Governance** → **Cost Management** → **Cost Analysis**
2. After deployment, check cost is $0.00
3. Free Tier resources show as **"Always Free"** badge

**Our configuration uses**:
- VM.Standard.A1.Flex: 4 OCPU, 12GB RAM ✅ FREE (within 4 OCPU + 24GB limit)
- 50GB boot volume ✅ FREE (within 200GB limit)
- Public IP ✅ FREE (2 IPs included)

**Total cost: $0.00/month indefinitely**

---

## Security Notes

**Important**: Your `~/.oci/oci_api_key.pem` is sensitive!
- Never commit to Git
- Keep permissions at 600
- Back up securely

Add to `.gitignore`:
```
.oci/
*.pem
```
