# Dockerfile.move - Optimized with robust account extraction and Move.toml fix
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

# Ensure Aptos CLI is in PATH
RUN which aptos || { \
    echo "Aptos CLI not found in PATH, creating symlink"; \
    find / -name aptos -type f -executable 2>/dev/null | head -n 1 | xargs -I{} ln -sf {} /usr/local/bin/aptos; \
    }

# Verify Aptos CLI is installed
RUN aptos --version

# Set working directory
WORKDIR /aptos-sybil-shield

# Create the expected directory structure
RUN mkdir -p /aptos-sybil-shield/on-chain/move/sources
RUN mkdir -p /aptos-sybil-shield/on-chain/move/scripts

# Copy the Move.toml file
COPY on-chain/move/Move.toml /aptos-sybil-shield/on-chain/move/

# Create a script to prepare the sources directory and handle deployment
RUN cat <<'ENDOFSCRIPT' > /aptos-sybil-shield/deploy.sh
#!/bin/bash
set -e


export APTOS_PROMPT_DISABLED=true

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
# Deploy AptosSybilShield to Aptos devnet - Optimized Version

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

# Helper functions
log_info() {
    echo -e "${YELLOW}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
    return 1
}

check_prerequisites() {
    # Check if aptos CLI is installed
    if ! command -v aptos &> /dev/null; then
        log_error "Error: aptos CLI is not installed."
        echo "Please install it by following the instructions at: https://aptos.dev/tools/aptos-cli/install-cli/"
        exit 1
    fi
}

# Enhanced function to extract account address from CLI output
extract_account_from_init_output() {
    local init_output=$1
    local extracted_address=""
    
    # Look for the account address in the CLI output - multiple formats
    # Format 1: "Account 0x123... is not funded"
    if echo "$init_output" | grep -q "Account 0x"; then
        extracted_address=$(echo "$init_output" | grep "Account 0x" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
    # Format 2: "Aptos CLI is now set up for account 0x123... as profile"
    elif echo "$init_output" | grep -q "set up for account"; then
        extracted_address=$(echo "$init_output" | grep "set up for account" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
    # Format 3: Look for any 0x... hex string that looks like an address
    elif echo "$init_output" | grep -q "0x[a-fA-F0-9]\{1,\}"; then
        extracted_address=$(echo "$init_output" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
    fi
    
    echo "$extracted_address"
}

setup_profile() {
    log_info "Checking for profile '$PROFILE'..."
    if ! aptos config show-profiles | grep -q "$PROFILE"; then
        log_info "Profile '$PROFILE' not found. Creating it..."
        
        if [ -z "$PRIVATE_KEY" ]; then
            log_info "No private key provided. Generating a new account..."
            # Capture the full output of the init command
            INIT_OUTPUT=$(aptos init --profile "$PROFILE" --network devnet 2>&1)
            echo "$INIT_OUTPUT"
            
            # Extract account address directly from init output
            EXTRACTED_ADDRESS=$(extract_account_from_init_output "$INIT_OUTPUT")
            
            if [ -n "$EXTRACTED_ADDRESS" ]; then
                ACCOUNT_ADDRESS=$EXTRACTED_ADDRESS
                log_success "Extracted account address from init output: $ACCOUNT_ADDRESS"
            else
                # Fallback to other methods if extraction failed
                get_account_address
            fi
            
            # Verify we have an account address before proceeding
            if [ -z "$ACCOUNT_ADDRESS" ]; then
                log_error "Failed to determine account address after initialization. Aborting."
                exit 1
            fi
            
            log_success "Created new account: $ACCOUNT_ADDRESS"
        else
            # Use provided private key
            log_info "Using provided private key..."
            if [ -z "$ACCOUNT_ADDRESS" ]; then
                log_error "Error: Account address must be provided when using a private key."
                exit 1
            fi
            
            aptos init --profile "$PROFILE" --private-key "$PRIVATE_KEY" --network devnet
        fi
        
        # Fund the account using faucet with explicit account address
        fund_account
    else
        log_success "Using existing profile: $PROFILE"
        get_account_address
        log_success "Account address: $ACCOUNT_ADDRESS"
        
        # Check account balance
        log_info "Checking account balance..."
        aptos account list --profile "$PROFILE"
        
        # Fund the account using faucet
        fund_account
    fi
}

get_account_address() {
    # Get the account address from the profile
    PROFILE_INFO=$(aptos config show-profiles --profile "$PROFILE" 2>&1)
    
    # Try different formats based on CLI version
    if echo "$PROFILE_INFO" | grep -q "Account"; then
        ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "Account" | awk '{print $NF}')
    elif echo "$PROFILE_INFO" | grep -q "account:"; then
        ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "account:" | awk '{print $2}')
    elif echo "$PROFILE_INFO" | grep -q "0x[a-fA-F0-9]\{1,\}"; then
        # Extract any hex address format
        ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
    else
        # Try to read from config file
        if [ -f "$HOME/.aptos/config.yaml" ]; then
            log_info "Trying to read account from config file..."
            ACCOUNT_ADDRESS=$(grep -A 5 "$PROFILE" "$HOME/.aptos/config.yaml" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
        fi
    fi
    
    # If still empty, ask the user
    if [ -z "$ACCOUNT_ADDRESS" ]; then
        log_info "Could not automatically detect account address. Please enter it manually:"
        read -p "Enter account address: " ACCOUNT_ADDRESS
    fi
}

fund_account() {
    # Verify we have an account address before attempting to fund
    if [ -z "$ACCOUNT_ADDRESS" ]; then
        log_error "Error: Cannot fund account - account address is empty."
        exit 1
    fi
    
    log_info "Funding account from faucet for address: $ACCOUNT_ADDRESS"
    aptos account fund-with-faucet --account "$ACCOUNT_ADDRESS" --profile "$PROFILE"
    
    # Verify funding was successful
    log_info "Verifying account balance after funding..."
    aptos account list --profile "$PROFILE"
}

update_move_toml() {
    log_info "Updating Move.toml with account address..."
    
    # Create a backup of the original Move.toml
    cp "$MODULE_PATH/Move.toml" "$MODULE_PATH/Move.toml.bak"
    
    # First, check if the file contains the placeholder
    if grep -q 'aptos_sybil_shield = "_"' "$MODULE_PATH/Move.toml"; then
        log_info "Found placeholder in Move.toml, replacing it..."
        # Replace the placeholder with the actual address
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MODULE_PATH/Move.toml"
        else
            # Linux/Windows Git Bash
            sed -i "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MODULE_PATH/Move.toml"
        fi
    else
        log_info "No placeholder found, updating any existing address..."
        # Replace any existing address in the [addresses] section
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' -E "s/(aptos_sybil_shield = \")(0x[a-fA-F0-9]+)(\")/\1$ACCOUNT_ADDRESS\3/" "$MODULE_PATH/Move.toml"
        else
            # Linux/Windows Git Bash
            sed -i -E "s/(aptos_sybil_shield = \")(0x[a-fA-F0-9]+)(\")/\1$ACCOUNT_ADDRESS\3/" "$MODULE_PATH/Move.toml"
        fi
    fi
    
    # Also update the dev-addresses section if it exists
    if grep -q '\[dev-addresses\]' "$MODULE_PATH/Move.toml"; then
        log_info "Updating dev-addresses section..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' -E "/\[dev-addresses\]/,/^\[/ s/(aptos_sybil_shield = \")(0x[a-fA-F0-9]+|0xcafe)(\")/\1$ACCOUNT_ADDRESS\3/" "$MODULE_PATH/Move.toml"
        else
            # Linux/Windows Git Bash
            sed -i -E "/\[dev-addresses\]/,/^\[/ s/(aptos_sybil_shield = \")(0x[a-fA-F0-9]+|0xcafe)(\")/\1$ACCOUNT_ADDRESS\3/" "$MODULE_PATH/Move.toml"
        fi
    fi
    
    log_info "Move.toml contents after update:"
    cat "$MODULE_PATH/Move.toml"
}

compile_modules() {
    log_info "Compiling Move modules..."
    cd "$MODULE_PATH"
    # Check if the --profile flag is supported
    if aptos move compile --help | grep -q -- "--profile"; then
        aptos move compile --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"
    else
        # Older CLI versions
        aptos move compile --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS"
    fi
}

publish_modules() {
    log_info "Publishing Move modules to devnet..."
    # Check if the --profile flag is supported
    if aptos move publish --help | grep -q -- "--profile"; then
        yes | aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"
    else
        # Older CLI versions
        log_info "Using CLI without profile support for publishing..."
        yes | aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS"
    fi
    
    log_success "AptosSybilShield has been successfully deployed to Aptos devnet!"
    log_success "Account address: $ACCOUNT_ADDRESS"
}


initialize_module() {
    local module_name=$1
    log_info "Initializing ${module_name} module..."
    
    # Check if the --profile flag is supported
    if aptos move run --help | grep -q -- "--profile"; then
        yes | aptos move run \
            --function-id "$ACCOUNT_ADDRESS::${module_name}::initialize" \
            --profile "$PROFILE"
    else
        # Older CLI versions
        yes | aptos move run \
            --function-id "$ACCOUNT_ADDRESS::${module_name}::initialize"
    fi
}


initialize_modules() {
    log_info "Initializing modules..."
    
    # List of modules to initialize
    local modules=("sybil_detection" "identity_verification" "reputation_scoring" "indexer_integration" "feature_extraction")
    
    for module in "${modules[@]}"; do
        initialize_module "$module"
    done
    
    log_success "All modules have been initialized successfully!"
    log_success "AptosSybilShield is now ready to use on devnet."
}

save_deployment_info() {
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
    
    log_success "Deployment information saved to $DEPLOYMENT_INFO"
}

# Main execution flow
main() {
    check_prerequisites
    setup_profile
    update_move_toml
    compile_modules
    publish_modules
    initialize_modules
    save_deployment_info
}

# Execute main function
main
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
PROFILE_INFO=$(aptos config show-profiles --profile "$PROFILE" 2>&1)
    
# Try different formats based on CLI version
if echo "$PROFILE_INFO" | grep -q "Account"; then
    ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "Account" | awk '{print $NF}')
elif echo "$PROFILE_INFO" | grep -q "account:"; then
    ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep "account:" | awk '{print $2}')
elif echo "$PROFILE_INFO" | grep -q "0x[a-fA-F0-9]\{1,\}"; then
    # Extract any hex address format
    ACCOUNT_ADDRESS=$(echo "$PROFILE_INFO" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
else
    # Try to read from config file
    if [ -f "$HOME/.aptos/config.yaml" ]; then
        echo -e "${YELLOW}Trying to read account from config file...${NC}"
        ACCOUNT_ADDRESS=$(grep -A 5 "$PROFILE" "$HOME/.aptos/config.yaml" | grep -o "0x[a-fA-F0-9]\{1,\}" | head -1)
    fi
fi

# If still empty, ask the user
if [ -z "$ACCOUNT_ADDRESS" ]; then
    echo -e "${YELLOW}Could not automatically detect account address. Please enter it manually:${NC}"
    read -p "Enter account address: " ACCOUNT_ADDRESS
fi

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
