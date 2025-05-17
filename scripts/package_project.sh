#!/bin/bash
# Package AptosSybilShield project for delivery

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Packaging AptosSybilShield project for delivery...${NC}"

# Create output directory
OUTPUT_DIR="AptosSybilShield_Devnet_Ready"
mkdir -p "$OUTPUT_DIR"

# Copy all project files
echo -e "${YELLOW}Copying project files...${NC}"
cp -r api dashboard docs off-chain on-chain privacy scripts .gitignore docker-compose.yml Dockerfile docker-entrypoint.sh README.md todo.md "$OUTPUT_DIR/"

# Create a sample .env file
echo -e "${YELLOW}Creating sample .env file...${NC}"
cat > "$OUTPUT_DIR/.env.sample" << EOF
# AptosSybilShield Environment Variables
# Rename this file to .env and fill in your values

# Contract address on Aptos devnet
CONTRACT_ADDRESS=

# Private key for transaction signing (without 0x prefix)
PRIVATE_KEY=
EOF

# Create a quick start guide
echo -e "${YELLOW}Creating quick start guide...${NC}"
cat > "$OUTPUT_DIR/QUICK_START.md" << EOF
# AptosSybilShield Quick Start Guide

This guide provides the essential steps to get AptosSybilShield up and running on Aptos devnet.

## Step 1: Prerequisites

Ensure you have the following installed:
- [Aptos CLI](https://aptos.dev/tools/aptos-cli/install-cli/)
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/downloads)

## Step 2: Deploy Move Modules to Devnet

```bash
# Make the deployment script executable
chmod +x on-chain/move/scripts/deploy_devnet.sh

# Run the deployment script
./on-chain/move/scripts/deploy_devnet.sh
```

Take note of the contract address displayed at the end of the deployment.

## Step 3: Set Environment Variables

```bash
# Rename .env.sample to .env
cp .env.sample .env

# Edit .env with your contract address and private key
nano .env
```

## Step 4: Start the Services

```bash
# Build and start all services
docker-compose up -d
```

## Step 5: Run End-to-End Tests

```bash
# Make the test script executable
chmod +x scripts/run_e2e_tests.sh

# Run the tests
./scripts/run_e2e_tests.sh
```

## Step 6: Access the Dashboard

Open your browser and navigate to:
```
http://localhost:3000
```

## For More Information

See the full documentation in the docs directory:
- [Devnet Deployment Guide](docs/setup/devnet_deployment_guide.md)
- [API Documentation](docs/api/api_documentation.md)
- [Docker Deployment Guide](docs/setup/docker_deployment_guide.md)
EOF

# Create a zip file
echo -e "${YELLOW}Creating zip file...${NC}"
zip -r "${OUTPUT_DIR}.zip" "$OUTPUT_DIR"

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf "$OUTPUT_DIR"

echo -e "${GREEN}Packaging complete!${NC}"
echo -e "${GREEN}Project packaged as ${OUTPUT_DIR}.zip${NC}"
