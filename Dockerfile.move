# Dockerfile.move - Guaranteed line ending fix approach
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    libssl-dev \
    libclang-dev \
    pkg-config \
    python3 \
    python3-pip \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Install Rust and Cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Aptos CLI
RUN curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Set working directory
WORKDIR /aptos-sybil-shield

# Create the expected directory structure
RUN mkdir -p /aptos-sybil-shield/on-chain/move/sources

# Copy the Move.toml file
COPY on-chain/move/Move.toml /aptos-sybil-shield/on-chain/move/

# Create a script to prepare the sources directory and handle deployment
RUN cat <<'ENDOFSCRIPT' > /aptos-sybil-shield/deploy.sh
#!/bin/bash
set -e

echo "Preparing Move sources directory..."

# Clear the sources directory
rm -rf /aptos-sybil-shield/on-chain/move/sources/*

# Copy all module files to the sources directory
for module in feature_extraction identity_verification indexer_integration reputation_scoring sybil_detection; do
  echo "Copying $module module..."
  if [ -d "/modules/$module/sources/" ]; then
    cp -v /modules/$module/sources/* /aptos-sybil-shield/on-chain/move/sources/
  else
    echo "WARNING: Module directory /modules/$module/sources/ not found"
  fi
done

echo "Source files prepared. Directory listing:"
ls -la /aptos-sybil-shield/on-chain/move/sources/

# Create deploy_devnet.sh script with guaranteed Unix line endings
echo "Creating deployment script with guaranteed Unix line endings..."
cat > /aptos-sybil-shield/on-chain/move/scripts/deploy_devnet.sh << 'EOF'
#!/bin/bash
# Deploy AptosSybilShield to Aptos devnet

set -e

# Configuration
PROFILE="devnet"
MODULE_PATH="$(pwd)/on-chain/move"
ACCOUNT_ADDRESS=""
PRIVATE_KEY=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo -e "${RED}Error: aptos CLI is not installed.${NC}"
    echo "Please install it by following the instructions at: https://aptos.dev/tools/aptos-cli/install-cli/"
    exit 1
fi

# Check if profile exists
if ! aptos config show-profiles | grep -q "$PROFILE"; then
    echo -e "${YELLOW}Profile '$PROFILE' not found. Creating it...${NC}"
    
    # Check if private key is provided
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${YELLOW}No private key provided. Generating a new account...${NC}"
        aptos init --profile "$PROFILE" --network devnet
        
        # Get the account address from the created profile
        ACCOUNT_ADDRESS=$(aptos config show-profiles --profile "$PROFILE" | grep 'account:' | awk '{print $2}')
        echo -e "${GREEN}Created new account: $ACCOUNT_ADDRESS${NC}"
        
        # Fund the account using faucet
        echo -e "${YELLOW}Funding account from faucet...${NC}"
        aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
    else
        # Use provided private key
        echo -e "${YELLOW}Using provided private key...${NC}"
        if [ -z "$ACCOUNT_ADDRESS" ]; then
            echo -e "${RED}Error: Account address must be provided when using a private key.${NC}"
            exit 1
        fi
        
        aptos init --profile "$PROFILE" --private-key "$PRIVATE_KEY" --network devnet
        
        # Fund the account using faucet
        echo -e "${YELLOW}Funding account from faucet...${NC}"
        aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
    fi
else
    echo -e "${GREEN}Using existing profile: $PROFILE${NC}"
    
    # Get the account address from the existing profile
    ACCOUNT_ADDRESS=$(aptos config show-profiles --profile "$PROFILE" | grep 'account:' | awk '{print $2}')
    echo -e "${GREEN}Account address: $ACCOUNT_ADDRESS${NC}"
    
    # Check account balance
    echo -e "${YELLOW}Checking account balance...${NC}"
    aptos account list --profile "$PROFILE"
    
    # Fund the account using faucet if needed
    echo -e "${YELLOW}Funding account from faucet...${NC}"
    aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
fi

# Update the Move.toml with the account address
echo -e "${YELLOW}Updating Move.toml with account address...${NC}"
sed -i "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MODULE_PATH/Move.toml"

# Compile the modules
echo -e "${YELLOW}Compiling Move modules...${NC}"
cd "$MODULE_PATH"
aptos move compile --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"

# Publish the modules
echo -e "${YELLOW}Publishing Move modules to devnet...${NC}"
aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"

echo -e "${GREEN}AptosSybilShield has been successfully deployed to Aptos devnet!${NC}"
echo -e "${GREEN}Account address: $ACCOUNT_ADDRESS${NC}"

# Initialize the modules
echo -e "${YELLOW}Initializing modules...${NC}"

# Initialize sybil_detection module
echo -e "${YELLOW}Initializing sybil_detection module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::sybil_detection::initialize" \
    --profile "$PROFILE"

# Initialize identity_verification module
echo -e "${YELLOW}Initializing identity_verification module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::identity_verification::initialize" \
    --profile "$PROFILE"

# Initialize reputation_scoring module
echo -e "${YELLOW}Initializing reputation_scoring module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::reputation_scoring::initialize" \
    --profile "$PROFILE"

# Initialize indexer_integration module
echo -e "${YELLOW}Initializing indexer_integration module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::indexer_integration::initialize" \
    --profile "$PROFILE"

# Initialize feature_extraction module
echo -e "${YELLOW}Initializing feature_extraction module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::feature_extraction::initialize" \
    --profile "$PROFILE"

echo -e "${GREEN}All modules have been initialized successfully!${NC}"
echo -e "${GREEN}AptosSybilShield is now ready to use on devnet.${NC}"

# Save deployment information
DEPLOYMENT_INFO="deployment_info.txt"
echo "AptosSybilShield Deployment Information" > "$DEPLOYMENT_INFO"
echo "=======================================" >> "$DEPLOYMENT_INFO"
echo "Network: Aptos Devnet" >> "$DEPLOYMENT_INFO"
echo "Account Address: $ACCOUNT_ADDRESS" >> "$DEPLOYMENT_INFO"
echo "Deployment Date: $(date)" >> "$DEPLOYMENT_INFO"
echo "Modules:" >> "$DEPLOYMENT_INFO"
echo "  - sybil_detection" >> "$DEPLOYMENT_INFO"
echo "  - identity_verification" >> "$DEPLOYMENT_INFO"
echo "  - reputation_scoring" >> "$DEPLOYMENT_INFO"
echo "  - indexer_integration" >> "$DEPLOYMENT_INFO"
echo "  - feature_extraction" >> "$DEPLOYMENT_INFO"

echo -e "${GREEN}Deployment information saved to $DEPLOYMENT_INFO${NC}"
EOF

# Make the script executable
chmod +x /aptos-sybil-shield/on-chain/move/scripts/deploy_devnet.sh

# Create test_devnet.sh script with guaranteed Unix line endings
echo "Creating test script with guaranteed Unix line endings..."
cat > /aptos-sybil-shield/on-chain/move/scripts/test_devnet.sh << 'EOF'
#!/bin/bash
# Test AptosSybilShield on Aptos devnet

set -e

# Configuration
PROFILE="devnet"
ACCOUNT_ADDRESS=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo -e "${RED}Error: aptos CLI is not installed.${NC}"
    echo "Please install it by following the instructions at: https://aptos.dev/tools/aptos-cli/install-cli/"
    exit 1
fi

# Get the account address from the existing profile
ACCOUNT_ADDRESS=$(aptos config show-profiles --profile "$PROFILE" | grep 'account:' | awk '{print $2}')
echo -e "${GREEN}Using account address: $ACCOUNT_ADDRESS${NC}"

# Test sybil_detection module
echo -e "${YELLOW}Testing sybil_detection module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::sybil_detection::register_address" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully registered address for Sybil detection.${NC}"

# Test updating risk threshold
echo -e "${YELLOW}Testing risk threshold update...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::sybil_detection::update_risk_threshold" \
    --args u64:75 \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully updated risk threshold.${NC}"

# Test identity_verification module
echo -e "${YELLOW}Testing identity_verification module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::identity_verification::request_verification" \
    --args u8:1 vector\<u8\>:"verification_data" \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully requested verification.${NC}"

# Test reputation_scoring module
echo -e "${YELLOW}Testing reputation_scoring module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::reputation_scoring::register_address" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully registered address for reputation scoring.${NC}"

# Test indexer_integration module
echo -e "${YELLOW}Testing indexer_integration module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::indexer_integration::register_indexer" \
    --args address:"$ACCOUNT_ADDRESS" vector\<u8\>:"indexer_url" \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully registered indexer.${NC}"

# Test feature_extraction module
echo -e "${YELLOW}Testing feature_extraction module...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::feature_extraction::extract_features" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

echo -e "${GREEN}Successfully extracted features.${NC}"

echo -e "${GREEN}All tests completed successfully!${NC}"
EOF

# Make the script executable
chmod +x /aptos-sybil-shield/on-chain/move/scripts/test_devnet.sh

# Run the deployment script
echo "Running deployment script..."
cd /aptos-sybil-shield
./on-chain/move/scripts/deploy_devnet.sh

# Copy deployment info to shared volume if deployment was successful
if [ -f deployment_info.txt ]; then
  cp -v deployment_info.txt /shared/deployment_info.txt
  echo "Deployment information saved to shared volume"
fi
ENDOFSCRIPT

# Fix line endings in the deploy script and make it executable
RUN dos2unix /aptos-sybil-shield/deploy.sh && \
    chmod +x /aptos-sybil-shield/deploy.sh

# Set the entrypoint
ENTRYPOINT ["/aptos-sybil-shield/deploy.sh"]
