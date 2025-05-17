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

# Check if profile exists
if ! aptos config show-profiles | grep -q "$PROFILE"; then
    echo -e "${RED}Error: Profile '$PROFILE' not found.${NC}"
    echo "Please run deploy_devnet.sh first to set up your devnet profile."
    exit 1
fi

# Get the account address from the profile
if [ -z "$ACCOUNT_ADDRESS" ]; then
    ACCOUNT_ADDRESS=$(aptos config show-profiles --profile "$PROFILE" | grep 'account:' | awk '{print $2}')
    echo -e "${GREEN}Using account address: $ACCOUNT_ADDRESS${NC}"
fi

# Test sybil_detection module
echo -e "${YELLOW}Testing sybil_detection module...${NC}"

# Register an address for Sybil detection
echo -e "${YELLOW}Registering address for Sybil detection...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::sybil_detection::register_address" \
    --profile "$PROFILE"

# Update risk threshold
echo -e "${YELLOW}Updating risk threshold...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::sybil_detection::update_risk_threshold" \
    --args u64:75 \
    --profile "$PROFILE"

# Test identity_verification module
echo -e "${YELLOW}Testing identity_verification module...${NC}"

# Add a verifier
echo -e "${YELLOW}Adding a verifier...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::identity_verification::add_verifier" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

# Request verification
echo -e "${YELLOW}Requesting verification...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::identity_verification::request_verification" \
    --args u8:1 "vector<u8>:[1, 2, 3, 4]" \
    --profile "$PROFILE"

# Test reputation_scoring module
echo -e "${YELLOW}Testing reputation_scoring module...${NC}"

# Register address for reputation scoring
echo -e "${YELLOW}Registering address for reputation scoring...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::reputation_scoring::register_address" \
    --profile "$PROFILE"

# Add a scorer
echo -e "${YELLOW}Adding a scorer...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::reputation_scoring::add_scorer" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

# Test indexer_integration module
echo -e "${YELLOW}Testing indexer_integration module...${NC}"

# Register an indexer
echo -e "${YELLOW}Registering an indexer...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::indexer_integration::register_indexer" \
    --args u8:1 string:"TestIndexer" string:"https://test-indexer.com" "vector<u8>:[1, 2, 3, 4]" u8:1 \
    --profile "$PROFILE"

# Test feature_extraction module
echo -e "${YELLOW}Testing feature_extraction module...${NC}"

# Add an extractor
echo -e "${YELLOW}Adding an extractor...${NC}"
aptos move run \
    --function-id "$ACCOUNT_ADDRESS::feature_extraction::add_extractor" \
    --args address:"$ACCOUNT_ADDRESS" \
    --profile "$PROFILE"

echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "${GREEN}AptosSybilShield is working correctly on devnet.${NC}"
