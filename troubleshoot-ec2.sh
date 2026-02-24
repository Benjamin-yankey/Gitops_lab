#!/bin/bash

EC2_IP="52.212.99.167"
KEY_FILE="$1"

echo "Troubleshooting EC2 Connection to $EC2_IP"
echo "================================================"

echo -e "\n1. Testing EC2 reachability..."
if ping -c 3 $EC2_IP > /dev/null 2>&1; then
    echo "[OK] EC2 instance is reachable"
else
    echo "[FAIL] EC2 instance is NOT reachable"
fi

echo -e "\n2. Testing SSH port (22)..."
if nc -zv -w 5 $EC2_IP 22 2>&1 | grep -q succeeded; then
    echo "[OK] SSH port is open"
else
    echo "[FAIL] SSH port is closed or filtered"
fi

echo -e "\n3. Testing application port (5000)..."
if nc -zv -w 5 $EC2_IP 5000 2>&1 | grep -q succeeded; then
    echo "[OK] Port 5000 is open"
else
    echo "[FAIL] Port 5000 is closed or filtered"
fi

if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo -e "\n4. Checking Docker container status..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@$EC2_IP << 'EOF'
        echo "Docker version:"
        docker --version
        
        echo -e "\nDocker containers:"
        docker ps -a
        
        echo -e "\nChecking if port 5000 is listening:"
        sudo netstat -tlnp | grep 5000 || echo "Port 5000 not listening"
        
        echo -e "\nChecking security group (from instance metadata):"
        curl -s http://169.254.169.254/latest/meta-data/security-groups
EOF
else
    echo -e "\n4. [SKIP] Skipping Docker check (no SSH key provided)"
    echo "   Usage: $0 /path/to/key.pem"
fi

echo -e "\n================================================"
echo "Troubleshooting complete!"