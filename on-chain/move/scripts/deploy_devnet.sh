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

# Check the project structure
echo -e "${YELLOW}Checking project structure...${NC}"
# Set the correct path to Move.toml
MOVE_TOML_PATH="$MODULE_PATH/Move.toml"
if [ ! -f "$MOVE_TOML_PATH" ]; then
    echo -e "${RED}Error: Move.toml not found at $MOVE_TOML_PATH${NC}"
    # Look for Move.toml in the current directory and subdirectories
    MOVE_TOML_PATH=$(find "$(pwd)" -name "Move.toml" -type f | head -n 1)
    
    if [ -n "$MOVE_TOML_PATH" ]; then
        MODULE_PATH=$(dirname "$MOVE_TOML_PATH")
        echo -e "${GREEN}Found Move.toml at: $MOVE_TOML_PATH${NC}"
        echo -e "${GREEN}Setting MODULE_PATH to: $MODULE_PATH${NC}"
    else
        echo -e "${RED}No Move.toml found. Aborting.${NC}"
        exit 1
    fi
fi

# Check for modular structure
echo -e "${YELLOW}Detecting project structure...${NC}"
if [ -d "$MODULE_PATH/modules" ]; then
    echo -e "${GREEN}Detected modular project structure with separate module directories${NC}"
    PROJECT_STRUCTURE="modular"
elif [ -d "$MODULE_PATH/sources" ]; then
    echo -e "${GREEN}Detected standard project structure with single sources directory${NC}"
    PROJECT_STRUCTURE="standard"
else
    echo -e "${RED}Error: Could not detect a valid project structure.${NC}"
    echo -e "${RED}Expected either a 'modules' directory or a 'sources' directory.${NC}"
    exit 1
fi

# Check if profile exists
echo -e "${YELLOW}Checking for profile '$PROFILE'...${NC}"
if ! aptos config show-profiles | grep -q "$PROFILE"; then
    echo -e "${YELLOW}Profile '$PROFILE' not found. Creating it...${NC}"
    
    # Check if private key is provided
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${YELLOW}No private key provided. Generating a new account...${NC}"
        aptos init --profile "$PROFILE" --network devnet
        
        # Get the account address from the created profile
        # First, save the output to a variable so we can debug it
        PROFILE_INFO=$(aptos config show-profiles --profile "$PROFILE")
        echo -e "${YELLOW}Profile info: $PROFILE_INFO${NC}"
        
        # Try to extract account address - different versions of aptos CLI might format this differently
        if echo "$PROFILE_INFO" | grep -q "Account"; then
            ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "Account" | awk '{print $NF}')
        elif echo "$PROFILE_INFO" | grep -q "account:"; then
            ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "account:" | awk '{print $2}')
        else
            # Check if we can get it directly from profiles.yaml
            if [ -f "$HOME/.aptos/config.yaml" ]; then
                echo -e "${YELLOW}Trying to read account from config file...${NC}"
                ACCOUNT_ADDRESS=$(grep -A 5 "$PROFILE" "$HOME/.aptos/config.yaml" | grep "account_address" | awk '{print $2}')
            fi
        fi
        
        # If still empty, ask the user
        if [ -z "$ACCOUNT_ADDRESS" ]; then
            echo -e "${YELLOW}Could not automatically detect account address. Please enter it manually:${NC}"
            read -p "Enter account address: " ACCOUNT_ADDRESS
        fi
        
        echo -e "${GREEN}Created new account: $ACCOUNT_ADDRESS${NC}"
        
        # Fund the account using faucet
        echo -e "${YELLOW}Funding account from faucet...${NC}"
        # Fix: Explicitly specify the profile with quotes
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
        # Fix: Explicitly specify the profile with quotes
        aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
    fi
else
    echo -e "${GREEN}Using existing profile: $PROFILE${NC}"
    
    # Get the account address from the existing profile
    # First, save the output to a variable so we can debug it
    PROFILE_INFO=$(aptos config show-profiles --profile "$PROFILE")
    echo -e "${YELLOW}Profile info: $PROFILE_INFO${NC}"
    
    # Try to extract account address - different versions of aptos CLI might format this differently
    if echo "$PROFILE_INFO" | grep -q "Account"; then
        ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "Account" | awk '{print $NF}')
    elif echo "$PROFILE_INFO" | grep -q "account:"; then
        ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "account:" | awk '{print $2}')
    else
        # Check if we can get it directly from profiles.yaml
        if [ -f "$HOME/.aptos/config.yaml" ]; then
            echo -e "${YELLOW}Trying to read account from config file...${NC}"
            ACCOUNT_ADDRESS=$(grep -A 5 "$PROFILE" "$HOME/.aptos/config.yaml" | grep "account_address" | awk '{print $2}')
        fi
    fi
    
    # If still empty, ask the user
    if [ -z "$ACCOUNT_ADDRESS" ]; then
        echo -e "${YELLOW}Could not automatically detect account address. Please enter it manually:${NC}"
        read -p "Enter account address: " ACCOUNT_ADDRESS
    fi
    
    echo -e "${GREEN}Account address: $ACCOUNT_ADDRESS${NC}"
    
    # Check account balance
    echo -e "${YELLOW}Checking account balance...${NC}"
    aptos account list --profile "$PROFILE"
    
    # Fund the account using faucet if needed
    echo -e "${YELLOW}Funding account from faucet...${NC}"
    # Fix: Explicitly specify the profile with quotes
    aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
fi

# Update the Move.toml with the account address
echo -e "${YELLOW}Updating Move.toml with account address...${NC}"
# Use sed command appropriate for your environment
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MOVE_TOML_PATH"
else
    # Linux/Windows Git Bash
    sed -i "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MOVE_TOML_PATH"
fi

# Display the Move.toml contents for verification
echo -e "${YELLOW}Move.toml contents after update:${NC}"
cat "$MOVE_TOML_PATH"

# Compile the modules
echo -e "${YELLOW}Compiling Move modules...${NC}"
cd "$MODULE_PATH"
# First check if the --profile flag is supported for compile
if aptos move compile --help | grep -q -- "--profile"; then
    aptos move compile --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"
else
    # Older CLI versions might not support --profile for compile
    aptos move compile --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS"
fi

# Publish the modules
echo -e "${YELLOW}Publishing Move modules to devnet...${NC}"
# First check if the --profile flag is supported for publish
if aptos move publish --help | grep -q -- "--profile"; then
    aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"
else
    # Older CLI versions might use different syntax or require setting network directly
    echo -e "${YELLOW}Using CLI without profile support for publishing...${NC}"
    aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS"
fi

echo -e "${GREEN}AptosSybilShield has been successfully deployed to Aptos devnet!${NC}"
echo -e "${GREEN}Account address: $ACCOUNT_ADDRESS${NC}"

# Initialize the modules
echo -e "${YELLOW}Initializing modules...${NC}"

# Initialize sybil_detection module
echo -e "${YELLOW}Initializing sybil_detection module...${NC}"
# First check if the --profile flag is supported for move run
if aptos move run --help | grep -q -- "--profile"; then
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::sybil_detection::initialize" \
        --profile "$PROFILE" 
else
    # Older CLI versions might use different syntax
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::sybil_detection::initialize"
fi

# Initialize identity_verification module
echo -e "${YELLOW}Initializing identity_verification module...${NC}"
# Use the same command style as determined above
if aptos move run --help | grep -q -- "--profile"; then 
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::identity_verification::initialize" \
        --profile "$PROFILE"
else
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::identity_verification::initialize"
fi

# Initialize reputation_scoring module
echo -e "${YELLOW}Initializing reputation_scoring module...${NC}"
if aptos move run --help | grep -q -- "--profile"; then
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::reputation_scoring::initialize" \
        --profile "$PROFILE"
else
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::reputation_scoring::initialize"
fi

# Initialize indexer_integration module
echo -e "${YELLOW}Initializing indexer_integration module...${NC}"
if aptos move run --help | grep -q -- "--profile"; then
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::indexer_integration::initialize" \
        --profile "$PROFILE"
else
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::indexer_integration::initialize"
fi

# Initialize feature_extraction module
echo -e "${YELLOW}Initializing feature_extraction module...${NC}"
if aptos move run --help | grep -q -- "--profile"; then
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::feature_extraction::initialize" \
        --profile "$PROFILE"
else
    aptos move run \
        --function-id "$ACCOUNT_ADDRESS::feature_extraction::initialize"
fi

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