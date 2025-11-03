#!/bin/bash
# Oracle Cloud Infrastructure Setup Verification Script
# Run this to check if you're ready to deploy

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Oracle Cloud Infrastructure Setup Verification         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# Check 1: Terraform installed
echo -n "Checking Terraform installation... "
if command -v terraform &> /dev/null; then
    VERSION=$(terraform version | head -n1 | cut -d' ' -f2)
    echo -e "${GREEN}✓ Installed ($VERSION)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install: brew install terraform"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: kubectl installed
echo -n "Checking kubectl installation... "
if command -v kubectl &> /dev/null; then
    VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Installed ($VERSION)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install: brew install kubectl"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: OCI config file
echo -n "Checking OCI config file... "
if [ -f ~/.oci/config ]; then
    echo -e "${GREEN}✓ Found${NC}"

    # Verify config contains required fields
    if grep -q "user=" ~/.oci/config && grep -q "fingerprint=" ~/.oci/config && grep -q "tenancy=" ~/.oci/config; then
        echo -e "  ${GREEN}✓ Contains required fields${NC}"
    else
        echo -e "  ${RED}✗ Missing required fields${NC}"
        echo "    Required: user, fingerprint, tenancy, region, key_file"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Expected at: ~/.oci/config"
    echo "  Follow: docs/oracle-cloud-setup.md"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: OCI API key
echo -n "Checking OCI API private key... "
if [ -f ~/.oci/oci_api_key.pem ]; then
    echo -e "${GREEN}✓ Found${NC}"

    # Check permissions
    PERMS=$(stat -f "%A" ~/.oci/oci_api_key.pem 2>/dev/null || stat -c "%a" ~/.oci/oci_api_key.pem 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo -e "  ${GREEN}✓ Correct permissions (600)${NC}"
    else
        echo -e "  ${YELLOW}⚠ Permissions are $PERMS, should be 600${NC}"
        echo "    Fix: chmod 600 ~/.oci/oci_api_key.pem"
    fi

    # Verify it's a valid RSA key
    if openssl rsa -in ~/.oci/oci_api_key.pem -check -noout &>/dev/null; then
        echo -e "  ${GREEN}✓ Valid RSA key${NC}"
    else
        echo -e "  ${RED}✗ Invalid or corrupt key${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Expected at: ~/.oci/oci_api_key.pem"
    echo "  Generate: openssl genrsa -out ~/.oci/oci_api_key.pem 2048"
    ERRORS=$((ERRORS + 1))
fi

# Check 5: OCI API public key
echo -n "Checking OCI API public key... "
if [ -f ~/.oci/oci_api_key_public.pem ]; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${YELLOW}⚠ Not found (optional)${NC}"
    echo "  Generate: openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem"
fi

# Check 6: SSH key for instance
echo -n "Checking SSH key for instance... "
if [ -f ~/.ssh/oci_ca3 ]; then
    echo -e "${GREEN}✓ Found${NC}"

    # Check if public key exists
    if [ -f ~/.ssh/oci_ca3.pub ]; then
        echo -e "  ${GREEN}✓ Public key exists${NC}"
    else
        echo -e "  ${RED}✗ Public key not found${NC}"
        echo "    Regenerate: ssh-keygen -y -f ~/.ssh/oci_ca3 > ~/.ssh/oci_ca3.pub"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Generate: ssh-keygen -t rsa -b 4096 -f ~/.ssh/oci_ca3 -N \"\""
    ERRORS=$((ERRORS + 1))
fi

# Check 7: terraform.tfvars
echo -n "Checking terraform.tfvars... "
if [ -f terraform-oci/terraform.tfvars ]; then
    echo -e "${GREEN}✓ Found${NC}"

    # Check if it contains required variables
    MISSING=""
    grep -q "tenancy_ocid" terraform-oci/terraform.tfvars || MISSING="$MISSING tenancy_ocid"
    grep -q "user_ocid" terraform-oci/terraform.tfvars || MISSING="$MISSING user_ocid"
    grep -q "compartment_ocid" terraform-oci/terraform.tfvars || MISSING="$MISSING compartment_ocid"
    grep -q "availability_domain" terraform-oci/terraform.tfvars || MISSING="$MISSING availability_domain"
    grep -q "ssh_public_key" terraform-oci/terraform.tfvars || MISSING="$MISSING ssh_public_key"

    if [ -z "$MISSING" ]; then
        echo -e "  ${GREEN}✓ All required variables present${NC}"
    else
        echo -e "  ${RED}✗ Missing variables:$MISSING${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Create: cp terraform-oci/terraform.tfvars.example terraform-oci/terraform.tfvars"
    echo "  Then edit with your OCIDs"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: Fingerprint match
echo -n "Checking API key fingerprint match... "
if [ -f ~/.oci/config ] && [ -f ~/.oci/oci_api_key.pem ]; then
    CONFIG_FP=$(grep "fingerprint=" ~/.oci/config | cut -d'=' -f2 | tr -d ' ')
    KEY_FP=$(openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem 2>/dev/null | openssl md5 -c | cut -d'=' -f2 | tr -d ' ')

    if [ "$CONFIG_FP" = "$KEY_FP" ]; then
        echo -e "${GREEN}✓ Fingerprints match${NC}"
    else
        echo -e "${RED}✗ Fingerprints don't match${NC}"
        echo "  Config: $CONFIG_FP"
        echo "  Key:    $KEY_FP"
        echo "  Re-upload public key to OCI Console"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Skipped (missing config or key)${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! You're ready to deploy.${NC}"
    echo ""
    echo "Next step:"
    echo "  cd ~/Downloads/CA2"
    echo "  ./scripts/oracle-deploy.sh"
    echo ""
else
    echo -e "${RED}❌ Found $ERRORS issue(s). Please fix them before deploying.${NC}"
    echo ""
    echo "For help, see:"
    echo "  docs/oracle-cloud-setup.md"
    echo ""
    exit 1
fi
