# AptosSybilShield

AptosSybilShield is a comprehensive Sybil attack detection and prevention system for the Aptos blockchain ecosystem. It combines on-chain verification mechanisms implemented in Move with off-chain analytics powered by machine learning to detect and prevent Sybil attacks.

## Features

- **On-chain Behavior Analysis Engine**
  - Transaction pattern recognition using graph theory
  - Clustering algorithms to identify related addresses
  - Temporal analysis of transaction timing
  - Gas usage patterns analysis

- **Off-chain Identity Verification System**
  - Social media verification with anti-bot measures
  - Decentralized identity integration
  - Proof of personhood protocols
  - Reputation scoring system

- **Machine Learning Sybil Detection Model**
  - Supervised learning using labeled Sybil attack data
  - Unsupervised anomaly detection
  - Feature extraction from on-chain and off-chain data
  - Continuous model improvement through feedback loops

- **Developer API and SDK**
  - Easy integration for Aptos projects
  - Customizable risk scoring thresholds
  - Webhook notifications for suspicious activity
  - Dashboard for monitoring and analytics

- **Privacy-Preserving Implementation**
  - Zero-knowledge proofs for identity verification without revealing personal data
  - Differential privacy techniques to protect user information
  - Decentralized storage of sensitive data

## Aptos Devnet Compatibility

This project is fully compatible with Aptos devnet, allowing for easy testing and demonstration. All components are configured to work with devnet endpoints and can be deployed with minimal setup.

## Project Structure

```
AptosSybilShield/
├── api/                      # API server and SDKs
│   ├── endpoints/            # API endpoints
│   └── sdk/                  # SDKs for different languages
│       ├── js/               # JavaScript SDK
│       └── python/           # Python SDK
├── dashboard/                # Web dashboard
│   └── frontend/             # Dashboard frontend
├── docs/                     # Documentation
│   ├── api/                  # API documentation
│   └── setup/                # Setup guides
├── off-chain/                # Off-chain components
│   ├── identity/             # Identity verification system
│   └── ml/                   # Machine learning components
│       ├── config/           # ML configuration
│       ├── data/             # Data processing
│       └── models/           # ML models
├── on-chain/                 # On-chain components
│   └── move/                 # Move modules
│       ├── modules/          # Move module sources
│       ├── scripts/          # Deployment scripts
│       └── tests/            # Move tests
├── privacy/                  # Privacy-preserving components
│   ├── differential_privacy/ # Differential privacy implementation
│   ├── storage/              # Decentralized storage
│   └── zkp/                  # Zero-knowledge proofs
└── scripts/                  # Helper scripts
```

## Getting Started

For detailed instructions on deploying and testing AptosSybilShield on Aptos devnet, please refer to the [Devnet Deployment Guide](docs/setup/devnet_deployment_guide.md).

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/AptosSybilShield.git
cd AptosSybilShield
```

2. Deploy the Move modules to devnet:
```bash
./on-chain/move/scripts/deploy_devnet.sh
```

3. Set environment variables:
```bash
# Create .env file with your contract address and private key
echo "CONTRACT_ADDRESS=<your_contract_address>" > .env
echo "PRIVATE_KEY=<your_private_key>" >> .env
```

4. Start the services:
```bash
docker-compose up -d
```

5. Run end-to-end tests:
```bash
./scripts/run_e2e_tests.sh
```

## Documentation

- [Devnet Deployment Guide](docs/setup/devnet_deployment_guide.md)
- [API Documentation](docs/api/api_documentation.md)
- [Docker Deployment Guide](docs/setup/docker_deployment_guide.md)
- [Setup Guide](docs/setup/setup_guide.md)

## Aptos-Specific Optimizations

AptosSybilShield leverages several Aptos-specific features:

- Integration with Aptos's Parallel Execution Model
- Optimized for Aptos's high throughput (20K TPS)
- Designed to work with Aptos's sub-second finality
- Move-native implementation for security and efficiency
- Compatibility with Aptos's Shardines execution engine
- Utilizes the Aptos Indexer API for comprehensive historical data analysis

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Aptos Labs for providing the blockchain infrastructure
- The Move language team for creating a secure smart contract language
- The open-source community for various libraries and tools used in this project
