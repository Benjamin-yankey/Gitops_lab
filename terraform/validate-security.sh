#!/bin/bash
# Security Configuration Validator

set -e

echo "Security Configuration Validator"
echo "===================================="
echo ""

ERRORS=0
WARNINGS=0

if [ ! -f "terraform.tfvars" ]; then
    echo "[ERROR] terraform.tfvars not found"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] terraform.tfvars found"
    
    if grep -q 'allowed_ips.*=.*\["0.0.0.0/0"\]' terraform.tfvars; then
        echo "[ERROR] allowed_ips is set to 0.0.0.0/0 (CRITICAL SECURITY RISK)"
        echo "   Fix: Set to your IP address (e.g., [\"$(curl -s ifconfig.me)/32\"])"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] allowed_ips is restricted"
    fi
    
    if grep -q 'app_allowed_ips.*=.*\["0.0.0.0/0"\]' terraform.tfvars; then
        echo "[ERROR] app_allowed_ips is set to 0.0.0.0/0 (CRITICAL SECURITY RISK)"
        echo "   Fix: Set to your IP address or load balancer"
        ERRORS=$((ERRORS + 1))
    elif ! grep -q 'app_allowed_ips' terraform.tfvars; then
        echo "[ERROR] app_allowed_ips not set in terraform.tfvars"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] app_allowed_ips is configured"
    fi
    
    if ! grep -q 'jenkins_admin_password' terraform.tfvars; then
        echo "[ERROR] jenkins_admin_password not set"
        ERRORS=$((ERRORS + 1))
    else
        echo "[OK] jenkins_admin_password is configured"
    fi
fi

echo ""
echo "Security Checks Summary:"
echo "------------------------"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "[FAIL] Security validation FAILED. Fix errors before deploying."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "[WARN] Security validation passed with warnings."
    exit 0
else
    echo "[PASS] Security validation PASSED. Safe to deploy."
    exit 0
fi
