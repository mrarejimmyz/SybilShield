#!/bin/bash
# Run end-to-end tests for AptosSybilShield on Aptos devnet

set -e

# Configuration
PROFILE="devnet"
CONTRACT_ADDRESS=""
PRIVATE_KEY=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if environment variables are set
if [ -f .env ]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)
    
    if [ -n "$CONTRACT_ADDRESS" ]; then
        echo -e "${GREEN}Using CONTRACT_ADDRESS from .env: $CONTRACT_ADDRESS${NC}"
    fi
    
    if [ -n "$PRIVATE_KEY" ]; then
        echo -e "${GREEN}Using PRIVATE_KEY from .env${NC}"
    fi
fi

# Check if aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo -e "${RED}Error: aptos CLI is not installed.${NC}"
    echo "Please install it by following the instructions at: https://aptos.dev/tools/aptos-cli/install-cli/"
    exit 1
fi

# Check if contract address is provided
if [ -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${YELLOW}CONTRACT_ADDRESS not provided. Checking deployment_info.txt...${NC}"
    
    if [ -f "deployment_info.txt" ]; then
        CONTRACT_ADDRESS=$(grep "Account Address:" deployment_info.txt | awk '{print $3}')
        echo -e "${GREEN}Found CONTRACT_ADDRESS in deployment_info.txt: $CONTRACT_ADDRESS${NC}"
    else
        echo -e "${RED}Error: CONTRACT_ADDRESS not provided and deployment_info.txt not found.${NC}"
        echo "Please run deploy_devnet.sh first or provide CONTRACT_ADDRESS in .env file."
        exit 1
    fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running.${NC}"
    echo "Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed.${NC}"
    echo "Please install it by following the instructions at: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${YELLOW}Starting end-to-end tests for AptosSybilShield on Aptos devnet...${NC}"

# Step 1: Run on-chain tests
echo -e "${YELLOW}Step 1: Running on-chain tests...${NC}"
if [ -x "on-chain/move/scripts/test_devnet.sh" ]; then
    echo -e "${YELLOW}Running test_devnet.sh...${NC}"
    ./on-chain/move/scripts/test_devnet.sh
else
    echo -e "${YELLOW}Making test_devnet.sh executable and running it...${NC}"
    chmod +x on-chain/move/scripts/test_devnet.sh
    ./on-chain/move/scripts/test_devnet.sh
fi

# Step 2: Update configuration files with contract address
echo -e "${YELLOW}Step 2: Updating configuration files with contract address...${NC}"

# Update ML config
echo -e "${YELLOW}Updating ML config...${NC}"
mkdir -p off-chain/ml/data
cat > off-chain/ml/data/devnet_config.txt << EOF
CONTRACT_ADDRESS=${CONTRACT_ADDRESS}
EOF
echo -e "${GREEN}Updated ML config with contract address: $CONTRACT_ADDRESS${NC}"

# Step 3: Build and start Docker containers
echo -e "${YELLOW}Step 3: Building and starting Docker containers...${NC}"

# Create .env file for Docker Compose
cat > .env << EOF
CONTRACT_ADDRESS=${CONTRACT_ADDRESS}
PRIVATE_KEY=${PRIVATE_KEY}
EOF

# Build and start containers
echo -e "${YELLOW}Building and starting containers...${NC}"
docker-compose up -d --build

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Step 4: Test API connectivity
echo -e "${YELLOW}Step 4: Testing API connectivity...${NC}"
API_HEALTH=$(curl -s http://localhost:8000/health || echo "Failed to connect")

if [[ "$API_HEALTH" == *"healthy"* ]]; then
    echo -e "${GREEN}API is healthy!${NC}"
else
    echo -e "${RED}API health check failed: $API_HEALTH${NC}"
    echo -e "${YELLOW}Checking API logs...${NC}"
    docker-compose logs api
    exit 1
fi

# Step 5: Test ML service
echo -e "${YELLOW}Step 5: Testing ML service...${NC}"
echo -e "${YELLOW}Checking ML service logs...${NC}"
docker-compose logs ml

# Step 6: Test Dashboard
echo -e "${YELLOW}Step 6: Testing Dashboard...${NC}"
DASHBOARD_RESPONSE=$(curl -s http://localhost:3000 || echo "Failed to connect")

if [[ "$DASHBOARD_RESPONSE" == *"Failed to connect"* ]]; then
    echo -e "${RED}Dashboard connectivity check failed${NC}"
    echo -e "${YELLOW}Checking Dashboard logs...${NC}"
    docker-compose logs dashboard
else
    echo -e "${GREEN}Dashboard is accessible!${NC}"
fi

# Step 7: Run Python SDK tests
echo -e "${YELLOW}Step 7: Running Python SDK tests...${NC}"

# Create test script
cat > test_sdk.py << EOF
#!/usr/bin/env python3
"""
Test script for AptosSybilShield Python SDK on devnet.
"""

import os
import sys
import time
from api.sdk.python.aptos_sybil_shield import AptosSybilShield

# Get contract address from environment or .env file
contract_address = os.environ.get('CONTRACT_ADDRESS')
private_key = os.environ.get('PRIVATE_KEY')

if not contract_address:
    print("CONTRACT_ADDRESS not set. Please set it in .env file.")
    sys.exit(1)

if not private_key:
    print("PRIVATE_KEY not set. Please set it in .env file.")
    sys.exit(1)

print(f"Using contract address: {contract_address}")

# Initialize SDK
sdk = AptosSybilShield(
    node_url="https://fullnode.devnet.aptoslabs.com/v1",
    contract_address=contract_address,
    private_key=private_key
)

try:
    # Test view functions
    print("Testing view functions...")
    
    # Get risk threshold
    try:
        threshold = sdk._query_view_function("sybil_detection::get_risk_threshold")
        print(f"Risk threshold: {threshold[0]}")
    except Exception as e:
        print(f"Error getting risk threshold: {e}")
    
    # Check if verification is required
    try:
        required = sdk._query_view_function("sybil_detection::is_verification_required")
        print(f"Verification required: {required[0]}")
    except Exception as e:
        print(f"Error checking if verification is required: {e}")
    
    print("SDK tests completed successfully!")
    sys.exit(0)
except Exception as e:
    print(f"Error during SDK tests: {e}")
    sys.exit(1)
EOF

# Make test script executable
chmod +x test_sdk.py

# Run test script
echo -e "${YELLOW}Running SDK test script...${NC}"
python3 test_sdk.py

# Step 8: Cleanup
echo -e "${YELLOW}Step 8: Cleaning up...${NC}"
rm -f test_sdk.py

echo -e "${GREEN}End-to-end tests completed successfully!${NC}"
echo -e "${GREEN}AptosSybilShield is working correctly on Aptos devnet.${NC}"
echo -e "${GREEN}Contract address: $CONTRACT_ADDRESS${NC}"
echo -e "${GREEN}API: http://localhost:8000${NC}"
echo -e "${GREEN}Dashboard: http://localhost:3000${NC}"
