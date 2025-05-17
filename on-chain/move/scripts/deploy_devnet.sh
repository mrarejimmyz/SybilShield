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

find_move_toml() {
    # Set the correct path to Move.toml
    local move_toml="$MODULE_PATH/Move.toml"
    if [ ! -f "$move_toml" ]; then
        log_info "Move.toml not found at $move_toml"
        # Look for Move.toml in the current directory and subdirectories
        local found_toml=$(find "$(pwd)" -name "Move.toml" -type f | head -n 1)
        
        if [ -n "$found_toml" ]; then
            MODULE_PATH=$(dirname "$found_toml")
            log_success "Found Move.toml at: $found_toml"
            log_success "Setting MODULE_PATH to: $MODULE_PATH"
            return 0
        else
            log_error "No Move.toml found. Aborting."
            exit 1
        fi
    fi
    return 0
}

detect_project_structure() {
    log_info "Detecting project structure..."
    if [ -d "$MODULE_PATH/modules" ]; then
        log_success "Detected modular project structure with separate module directories"
        PROJECT_STRUCTURE="modular"
    elif [ -d "$MODULE_PATH/sources" ]; then
        log_success "Detected standard project structure with single sources directory"
        PROJECT_STRUCTURE="standard"
    else
        log_error "Error: Could not detect a valid project structure."
        echo "Expected either a 'modules' directory or a 'sources' directory."
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
    # Use sed command appropriate for the OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MODULE_PATH/Move.toml"
    else
        # Linux/Windows Git Bash
        sed -i "s/aptos_sybil_shield = \"_\"/aptos_sybil_shield = \"$ACCOUNT_ADDRESS\"/" "$MODULE_PATH/Move.toml"
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
        aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS" --profile "$PROFILE"
    else
        # Older CLI versions
        log_info "Using CLI without profile support for publishing..."
        aptos move publish --named-addresses aptos_sybil_shield="$ACCOUNT_ADDRESS"
    fi
    
    log_success "AptosSybilShield has been successfully deployed to Aptos devnet!"
    log_success "Account address: $ACCOUNT_ADDRESS"
}

initialize_module() {
    local module_name=$1
    log_info "Initializing ${module_name} module..."
    
    # Check if the --profile flag is supported
    if aptos move run --help | grep -q -- "--profile"; then
        aptos move run \
            --function-id "$ACCOUNT_ADDRESS::${module_name}::initialize" \
            --profile "$PROFILE"
    else
        # Older CLI versions
        aptos move run \
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
    find_move_toml
    detect_project_structure
    setup_profile
    update_move_toml
    compile_modules
    publish_modules
    initialize_modules
    save_deployment_info
}

# Execute main function
main
