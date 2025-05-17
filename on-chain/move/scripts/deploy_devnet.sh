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
