# AptosSybilShield Setup Guide

This guide provides detailed instructions for setting up and running the AptosSybilShield project.

## Environment Setup

### Prerequisites

- Aptos CLI (version 1.0.0 or higher)
- Python 3.8+
- Node.js 14+
- Docker (optional, for containerized deployment)

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/AptosSybilShield.git
cd AptosSybilShield
```

### Step 2: Set Up Python Environment

```bash
# Create a virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies for ML components
cd off-chain/ml
pip install -r requirements.txt

# Run setup script
python setup.py
```

### Step 3: Set Up Node.js Environment

```bash
# Install JavaScript dependencies
cd ../../api/sdk/js
npm install
```

### Step 4: Compile Move Modules

```bash
# Install Aptos CLI if not already installed
# Follow instructions at https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli

# Compile Move modules
cd ../../../on-chain/move
aptos move compile
```

## Running the Components

### Running the API Server

```bash
cd ../../api/endpoints
python api_server.py
```

The API server will be available at `http://localhost:8000`.

### Running the ML Pipeline

```bash
cd ../../off-chain/ml
python -m models.feature_extraction
```

### Testing the SDKs

#### JavaScript SDK

```bash
cd ../../api/sdk/js
node -e "
const AptosSybilShield = require('./aptos-sybil-shield');
const client = new AptosSybilShield({
  apiKey: 'test_api_key',
  baseUrl: 'http://localhost:8000'
});
client.healthCheck().then(console.log).catch(console.error);
"
```

#### Python SDK

```bash
cd ../python
python -c "
from aptos_sybil_shield import AptosSybilShield
client = AptosSybilShield(api_key='test_api_key', base_url='http://localhost:8000')
print(client.health_check())
"
```

## Deploying Move Modules

### To Local Testnet

```bash
cd ../../../on-chain/move
aptos move publish --named-addresses aptos_sybil_shield=default
```

### To Devnet

```bash
aptos move publish --named-addresses aptos_sybil_shield=default --network devnet
```

### To Mainnet (Production)

```bash
aptos move publish --named-addresses aptos_sybil_shield=<your-address> --network mainnet
```

## Configuration

### API Server Configuration

Create a `.env` file in the `api/endpoints` directory:

```
API_PORT=8000
API_HOST=0.0.0.0
DATABASE_URL=sqlite:///aptos_sybil_shield.db
LOG_LEVEL=INFO
```

### ML Configuration

The ML configuration is located in `off-chain/ml/config/ml_config.py`. You can modify this file to adjust parameters such as:

- Model paths
- Training parameters
- Feature extraction settings

## Troubleshooting

### Common Issues

1. **Move Compilation Errors**
   - Ensure you have the latest version of the Aptos CLI
   - Check that all dependencies are correctly specified

2. **API Server Connection Issues**
   - Verify that the server is running on the expected port
   - Check firewall settings if accessing remotely

3. **ML Pipeline Errors**
   - Ensure all Python dependencies are installed
   - Check that the data directories exist and have proper permissions

### Getting Help

If you encounter issues not covered in this guide, please:

1. Check the documentation in the `docs` directory
2. Look for similar issues in the project repository
3. Contact the project maintainers

## Next Steps

After setting up the project, you can:

1. Integrate the SDK into your application
2. Customize the risk scoring thresholds
3. Train the ML models with your own data
4. Extend the system with additional verification methods
