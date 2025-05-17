"""
AptosSybilShield ML Environment Setup

This script sets up the necessary environment for the machine learning components
of the AptosSybilShield project, including installing dependencies and configuring
paths for model training and inference.
"""

import os
import sys
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("ml_setup")

def setup_environment():
    """Set up the ML environment with necessary directories and configurations."""
    logger.info("Setting up ML environment...")
    
    # Define required packages
    requirements = [
        "numpy",
        "pandas",
        "scikit-learn",
        "tensorflow",
        "matplotlib",
        "seaborn",
        "networkx",
        "aptos-sdk",
        "requests",
        "python-dotenv",
        "joblib"
    ]
    
    # Create a requirements.txt file
    with open("requirements.txt", "w") as f:
        for req in requirements:
            f.write(f"{req}\n")
    
    logger.info("Created requirements.txt with necessary dependencies")
    
    # Create necessary directories if they don't exist
    directories = [
        "models",
        "data/raw",
        "data/processed",
        "data/features",
        "training/logs",
        "training/checkpoints",
        "config"
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        logger.info(f"Created directory: {directory}")
    
    # Create a basic configuration file
    config = {
        "model_path": "models",
        "data_path": "data",
        "training_path": "training",
        "log_level": "INFO",
        "random_seed": 42,
        "test_size": 0.2,
        "validation_size": 0.1,
        "batch_size": 64,
        "epochs": 100,
        "early_stopping_patience": 10,
        "learning_rate": 0.001
    }
    
    # Write config to file
    with open("config/ml_config.py", "w") as f:
        f.write("\"\"\"Configuration for ML components\"\"\"\n\n")
        f.write("# ML configuration\n")
        for key, value in config.items():
            if isinstance(value, str):
                f.write(f"{key} = \"{value}\"\n")
            else:
                f.write(f"{key} = {value}\n")
    
    logger.info("Created ML configuration file")
    
    # Create an empty __init__.py file to make the directory a package
    for dir_path in [".", "models", "data", "training", "config"]:
        init_file = os.path.join(dir_path, "__init__.py")
        with open(init_file, "w") as f:
            f.write("# AptosSybilShield ML package\n")
    
    logger.info("Created __init__.py files for Python packages")
    
    return True

if __name__ == "__main__":
    setup_environment()
    logger.info("ML environment setup complete!")
