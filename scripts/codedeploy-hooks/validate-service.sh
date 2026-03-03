#!/bin/bash
# CodeDeploy ValidateService Hook
# Critical validation phase - if this fails, CodeDeploy will automatically rollback

set -euo pipefail

echo "🔍 CodeDeploy ValidateService: Running comprehensive health checks..."

# Configuration
MAX_RETRIES=10
RETRY_DELAY=15
HEALTH_ENDPOINT="/health"
APP_ENDPOINT="/"

# Function to get ECS task IP
get_task_ip() {
    local cluster="${ECS_CLUSTER:-cicd-node-cluster}"
    local service="${ECS_SERVICE:-cicd-node-service}"
    local region="${AWS_REGION:-eu-central-1}"
    
    aws ecs list-tasks \
        --cluster "$cluster" \
        --service-name "$service" \
        --region "$region" \
        --query 'taskArns[0]' \
        --output text | xargs -I {} \
    aws ecs describe-tasks \
        --cluster "$cluster" \
        --tasks {} \
        --region "$region" \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text | xargs -I {} \
    aws ec2 describe-network-interfaces \
        --network-interface-ids {} \
        --region "$region" \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text
}

# Function to test endpoint
test_endpoint() {
    local url="$1"
    local expected_code="${2:-200}"
    
    local response_code
    response_code=$(curl -f -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "FAILED")
    
    if [ "$response_code" = "$expected_code" ]; then
        return 0
    else
        echo "❌ Endpoint $url returned: $response_code (expected: $expected_code)"
        return 1
    fi
}

# Get the task IP
echo "🔍 Discovering ECS task IP address..."
TASK_IP=$(get_task_ip)

if [ -z "$TASK_IP" ] || [ "$TASK_IP" = "None" ] || [ "$TASK_IP" = "null" ]; then
    echo "❌ VALIDATION FAILED: Could not retrieve ECS task IP"
    exit 1
fi

echo "✅ Found ECS task IP: $TASK_IP"

# Health check with retries
echo "🏥 Testing health endpoint with retries..."
HEALTH_PASSED=false

for i in $(seq 1 $MAX_RETRIES); do
    echo "🔄 Health check attempt $i/$MAX_RETRIES..."
    
    if test_endpoint "http://$TASK_IP:5000$HEALTH_ENDPOINT" 200; then
        echo "✅ Health check PASSED (attempt $i/$MAX_RETRIES)"
        HEALTH_PASSED=true
        break
    fi
    
    if [ $i -lt $MAX_RETRIES ]; then
        echo "⏳ Waiting ${RETRY_DELAY}s before retry..."
        sleep $RETRY_DELAY
    fi
done

if [ "$HEALTH_PASSED" != "true" ]; then
    echo "❌ VALIDATION FAILED: Health endpoint not responding after $MAX_RETRIES attempts"
    echo "🔄 CodeDeploy will automatically rollback to the previous version"
    exit 1
fi

# Test main application endpoint
echo "🌐 Testing main application endpoint..."
if test_endpoint "http://$TASK_IP:5000$APP_ENDPOINT" 200; then
    echo "✅ Application endpoint PASSED"
else
    echo "❌ VALIDATION FAILED: Application endpoint not responding"
    echo "🔄 CodeDeploy will automatically rollback to the previous version"
    exit 1
fi

# Additional validation checks
echo "🔍 Running additional validation checks..."

# Test API endpoints
if test_endpoint "http://$TASK_IP:5000/api/info" 200; then
    echo "✅ API info endpoint PASSED"
else
    echo "❌ VALIDATION FAILED: API info endpoint not responding"
    exit 1
fi

if test_endpoint "http://$TASK_IP:5000/api/emails" 200; then
    echo "✅ API emails endpoint PASSED"
else
    echo "❌ VALIDATION FAILED: API emails endpoint not responding"
    exit 1
fi

# Performance check - response time should be reasonable
echo "⚡ Testing response time..."
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "http://$TASK_IP:5000$HEALTH_ENDPOINT" || echo "999")
RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc -l 2>/dev/null || echo "999")

if (( $(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo "0") )); then
    echo "✅ Response time acceptable: ${RESPONSE_TIME_MS%.*}ms"
else
    echo "⚠️  WARNING: Slow response time: ${RESPONSE_TIME_MS%.*}ms (>5000ms)"
    # Don't fail on slow response, just warn
fi

echo "🎉 ALL VALIDATION CHECKS PASSED!"
echo "✅ New version is healthy and ready for production traffic"
echo "🚀 Blue-green deployment validation completed successfully"

exit 0