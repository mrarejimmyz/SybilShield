"""
Configuration module for AptosSybilShield ML components

This module contains configuration settings for the ML components,
specifically adapted for Aptos devnet.
"""

import os
from pathlib import Path

# Base paths
base_path = Path(os.path.dirname(os.path.abspath(__file__))).parent
data_path = os.path.join(base_path, "data")
models_path = os.path.join(base_path, "models", "saved")
logs_path = os.path.join(base_path, "logs")

# Ensure directories exist
os.makedirs(data_path, exist_ok=True)
os.makedirs(models_path, exist_ok=True)
os.makedirs(logs_path, exist_ok=True)

# Aptos devnet configuration
APTOS_DEVNET_URL = "https://fullnode.devnet.aptoslabs.com/v1"
APTOS_DEVNET_FAUCET_URL = "https://faucet.devnet.aptoslabs.com"
APTOS_INDEXER_URL = "https://indexer-devnet.aptoslabs.com/v1/graphql"

# Contract address on devnet - will be updated by deployment script
CONTRACT_ADDRESS = ""  # This will be populated during deployment

# Feature extraction configuration
FEATURE_EXTRACTION = {
    "time_window_days": 30,
    "min_transactions": 5,
    "max_addresses_per_batch": 100,
    "cache_ttl_seconds": 3600,
}

# ML model configuration
MODEL_CONFIG = {
    "model_type": "random_forest",
    "train_test_split": 0.2,
    "random_state": 42,
    "n_estimators": 100,
    "max_depth": 10,
    "feature_importance_threshold": 0.01,
}

# Sybil detection thresholds
SYBIL_THRESHOLDS = {
    "high_risk": 0.8,
    "medium_risk": 0.5,
    "low_risk": 0.2,
}

# Indexer configuration
INDEXER_CONFIG = {
    "sync_interval_seconds": 300,
    "max_retries": 3,
    "timeout_seconds": 30,
    "batch_size": 50,
}

# Devnet-specific settings
DEVNET_CONFIG = {
    "use_faucet": True,
    "fund_amount": 100000000,  # 1 APT in octas
    "gas_unit_price": 100,
    "max_gas_amount": 10000,
    "transaction_timeout_seconds": 30,
    "poll_interval_seconds": 1,
}

# Update configuration for devnet deployment
def update_contract_address(address):
    """Update the contract address for devnet deployment"""
    global CONTRACT_ADDRESS
    CONTRACT_ADDRESS = address
    
    # Save to a file for persistence
    config_file = os.path.join(base_path, "data", "devnet_config.txt")
    with open(config_file, "w") as f:
        f.write(f"CONTRACT_ADDRESS={address}\n")
    
    print(f"Updated contract address to: {address}")
    return True

# Load contract address if available
def load_contract_address():
    """Load the contract address from the config file if available"""
    global CONTRACT_ADDRESS
    config_file = os.path.join(base_path, "data", "devnet_config.txt")
    
    if os.path.exists(config_file):
        with open(config_file, "r") as f:
            for line in f:
                if line.startswith("CONTRACT_ADDRESS="):
                    CONTRACT_ADDRESS = line.strip().split("=")[1]
                    print(f"Loaded contract address: {CONTRACT_ADDRESS}")
                    return CONTRACT_ADDRESS
    
    return None

# Try to load the contract address on module import
load_contract_address()
