# AptosSybilShield Devnet Deployment Guide

This guide provides step-by-step instructions for deploying and demonstrating the AptosSybilShield project on Aptos devnet.

## Prerequisites

- [Aptos CLI](https://aptos.dev/tools/aptos-cli/install-cli/) installed
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) installed
- [Git](https://git-scm.com/downloads) installed
- Basic familiarity with blockchain concepts and command line tools

## Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/AptosSybilShield.git
cd AptosSybilShield
```

## Step 2: Deploy the Move Modules to Devnet

The first step is to deploy the Move modules to Aptos devnet. This will create the on-chain components of AptosSybilShield.

```bash
# Make the deployment script executable
chmod +x on-chain/move/scripts/deploy_devnet.sh

# Run the deployment script
./on-chain/move/scripts/deploy_devnet.sh
```

The script will:
1. Create a new Aptos account on devnet if needed
2. Fund the account using the devnet faucet
3. Compile and publish the Move modules
4. Initialize all modules
5. Save deployment information to `deployment_info.txt`

**Important**: Take note of the contract address displayed at the end of the deployment. You'll need this for the next steps.

## Step 3: Set Environment Variables

Create a `.env` file in the project root directory with the following content:

```
CONTRACT_ADDRESS=<your_contract_address>
PRIVATE_KEY=<your_private_key>
```

Replace `<your_contract_address>` with the address from Step 2, and `<your_private_key>` with the private key of your devnet account.

## Step 4: Build and Start the Docker Containers

```bash
# Build and start all services
docker-compose up -d
```

This will start the following services:
- API Server (port 8000)
- ML Service
- Dashboard (port 3000)

## Step 5: Verify Deployment

### Check API Server

```bash
curl http://localhost:8000/health
```

You should see a response indicating the API server is running and connected to devnet.

### Access the Dashboard

Open your browser and navigate to:
```
http://localhost:3000
```

The dashboard should display and be connected to your devnet deployment.

## Step 6: Run Tests on Devnet

To verify that all components are working correctly, run the test script:

```bash
# Make the test script executable
chmod +x on-chain/move/scripts/test_devnet.sh

# Run the test script
./on-chain/move/scripts/test_devnet.sh
```

This script will:
1. Register your address for Sybil detection
2. Update risk threshold
3. Test identity verification
4. Test reputation scoring
5. Test indexer integration
6. Test feature extraction

## Step 7: Demonstrate Key Features

### 1. Sybil Detection

Use the Python SDK to interact with the Sybil detection module:

```python
from api.sdk.python.aptos_sybil_shield import AptosSybilShield

# Initialize SDK with your contract address and private key
sdk = AptosSybilShield(
    contract_address="<your_contract_address>",
    private_key="<your_private_key>"
)

# Register an address for Sybil detection
tx_hash = sdk.register_address_for_sybil_detection()
print(f"Registered for Sybil detection: {tx_hash}")

# Update risk score for an address
tx_hash = sdk.update_risk_score(
    target_addr="<target_address>",
    new_score=75,
    factor_type=1,  # Transaction pattern
    factor_score=80,
    factor_confidence=90
)
print(f"Updated risk score: {tx_hash}")

# Check if address is flagged
is_flagged = sdk.is_flagged("<target_address>")
print(f"Is address flagged: {is_flagged}")
```

### 2. Identity Verification

```python
# Request verification
tx_hash = sdk.request_verification(
    verification_type=1,  # Social verification
    verification_data=b"verification_data"
)
print(f"Requested verification: {tx_hash}")

# Verify identity (as a verifier)
tx_hash = sdk.verify_identity(
    target_addr="<target_address>",
    verification_result=True,
    proof=b"verification_proof"
)
print(f"Verified identity: {tx_hash}")

# Check if address is verified
is_verified = sdk.is_verified("<target_address>")
print(f"Is address verified: {is_verified}")
```

### 3. Reputation Scoring

```python
# Register for reputation scoring
tx_hash = sdk.register_address_for_reputation()
print(f"Registered for reputation scoring: {tx_hash}")

# Update category score
tx_hash = sdk.update_category_score(
    target_addr="<target_address>",
    category=1,  # Transaction history
    new_score=85,
    reason=b"Active user with consistent transactions"
)
print(f"Updated category score: {tx_hash}")

# Get overall score
score = sdk.get_overall_score("<target_address>")
print(f"Overall reputation score: {score}")
```

## Step 8: Monitoring and Logs

### View API Logs

```bash
docker-compose logs -f api
```

### View ML Service Logs

```bash
docker-compose logs -f ml
```

### View Dashboard Logs

```bash
docker-compose logs -f dashboard
```

## Step 9: Cleanup

When you're done with the demonstration, you can stop and remove the containers:

```bash
docker-compose down
```

## Troubleshooting

### Contract Address Issues

If you encounter issues with the contract address:

1. Verify the address in `deployment_info.txt`
2. Ensure the `.env` file has the correct CONTRACT_ADDRESS
3. Try redeploying the Move modules with:
   ```bash
   ./on-chain/move/scripts/deploy_devnet.sh
   ```

### API Connection Issues

If the API can't connect to devnet:

1. Check if devnet is accessible:
   ```bash
   curl https://fullnode.devnet.aptoslabs.com/v1
   ```
2. Verify the environment variables in docker-compose.yml
3. Restart the API service:
   ```bash
   docker-compose restart api
   ```

### Transaction Failures

If transactions fail:

1. Ensure your account has enough funds:
   ```bash
   aptos account list --profile devnet
   ```
2. Fund your account if needed:
   ```bash
   aptos account fund-with-faucet --account <your_address> --profile devnet
   ```
3. Check transaction status on the [Aptos Explorer](https://explorer.aptoslabs.com/?network=devnet)

## Additional Resources

- [Aptos Developer Documentation](https://aptos.dev/)
- [Aptos Explorer (Devnet)](https://explorer.aptoslabs.com/?network=devnet)
- [Aptos CLI Documentation](https://aptos.dev/tools/aptos-cli/)
- [AptosSybilShield API Documentation](./docs/api/api_documentation.md)
