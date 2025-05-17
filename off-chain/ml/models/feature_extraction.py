"""
Feature extraction module for AptosSybilShield

This module handles the extraction of features from on-chain data for use in
Sybil detection models. It processes transaction data, account information,
and other blockchain metrics to create feature vectors for ML models.
"""

import os
import logging
import pandas as pd
import numpy as np
import networkx as nx
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Any, Optional

# Import configuration
from config.ml_config import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("feature_extraction")

class OnChainFeatureExtractor:
    """
    Extracts features from on-chain data for Sybil detection.
    
    This class processes blockchain data to extract features related to
    transaction patterns, clustering, temporal behavior, and gas usage.
    """
    
    def __init__(self, indexer_client=None):
        """
        Initialize the feature extractor.
        
        Args:
            indexer_client: Client for accessing the Aptos indexer
        """
        self.indexer_client = indexer_client
        self.graph = nx.DiGraph()  # Directed graph for transaction analysis
        
    def extract_transaction_features(self, address: str, time_window: int = 30) -> Dict[str, float]:
        """
        Extract features related to transaction patterns.
        
        Args:
            address: The account address to analyze
            time_window: Time window in days for analysis
            
        Returns:
            Dictionary of transaction-related features
        """
        logger.info(f"Extracting transaction features for {address}")
        
        # In a real implementation, we would query the indexer for transaction data
        # For hackathon purposes, we'll simulate this with placeholder logic
        
        # Placeholder for transaction data
        # In production, this would come from the indexer
        tx_count_sent = 0
        tx_count_received = 0
        unique_receivers = set()
        unique_senders = set()
        tx_values = []
        tx_intervals = []
        
        # Calculate features
        features = {
            "tx_count_sent": tx_count_sent,
            "tx_count_received": tx_count_received,
            "unique_receivers_count": len(unique_receivers),
            "unique_senders_count": len(unique_senders),
            "tx_value_mean": np.mean(tx_values) if tx_values else 0,
            "tx_value_std": np.std(tx_values) if tx_values else 0,
            "tx_value_max": max(tx_values) if tx_values else 0,
            "tx_interval_mean": np.mean(tx_intervals) if tx_intervals else 0,
            "tx_interval_std": np.std(tx_intervals) if tx_intervals else 0,
            "tx_interval_min": min(tx_intervals) if tx_intervals else 0,
            "tx_sent_received_ratio": tx_count_sent / max(tx_count_received, 1),
        }
        
        return features
    
    def extract_clustering_features(self, address: str) -> Dict[str, float]:
        """
        Extract features related to address clustering.
        
        Args:
            address: The account address to analyze
            
        Returns:
            Dictionary of clustering-related features
        """
        logger.info(f"Extracting clustering features for {address}")
        
        # In a real implementation, we would build a transaction graph
        # and compute various graph metrics
        
        # Placeholder for graph metrics
        features = {
            "degree_centrality": 0.0,
            "betweenness_centrality": 0.0,
            "clustering_coefficient": 0.0,
            "pagerank": 0.0,
            "strongly_connected_component_size": 0,
            "weakly_connected_component_size": 0,
            "k_core": 0,
            "local_clustering_coefficient": 0.0,
        }
        
        return features
    
    def extract_temporal_features(self, address: str, time_window: int = 30) -> Dict[str, float]:
        """
        Extract features related to temporal patterns.
        
        Args:
            address: The account address to analyze
            time_window: Time window in days for analysis
            
        Returns:
            Dictionary of temporal-related features
        """
        logger.info(f"Extracting temporal features for {address}")
        
        # In a real implementation, we would analyze transaction timestamps
        
        # Placeholder for temporal metrics
        features = {
            "activity_hours_entropy": 0.0,
            "activity_days_entropy": 0.0,
            "burst_rate": 0.0,
            "dormant_periods": 0,
            "activity_consistency": 0.0,
            "periodic_pattern_strength": 0.0,
            "time_between_txs_mean": 0.0,
            "time_between_txs_std": 0.0,
        }
        
        return features
    
    def extract_gas_usage_features(self, address: str, time_window: int = 30) -> Dict[str, float]:
        """
        Extract features related to gas usage patterns.
        
        Args:
            address: The account address to analyze
            time_window: Time window in days for analysis
            
        Returns:
            Dictionary of gas usage-related features
        """
        logger.info(f"Extracting gas usage features for {address}")
        
        # In a real implementation, we would analyze gas usage from transactions
        
        # Placeholder for gas usage metrics
        features = {
            "gas_price_mean": 0.0,
            "gas_price_std": 0.0,
            "gas_used_mean": 0.0,
            "gas_used_std": 0.0,
            "gas_price_volatility": 0.0,
            "gas_limit_utilization": 0.0,
            "gas_price_percentile_90": 0.0,
            "gas_used_percentile_90": 0.0,
        }
        
        return features
    
    def extract_all_features(self, address: str, time_window: int = 30) -> Dict[str, float]:
        """
        Extract all features for an address.
        
        Args:
            address: The account address to analyze
            time_window: Time window in days for analysis
            
        Returns:
            Dictionary of all features
        """
        logger.info(f"Extracting all features for {address}")
        
        # Extract features from different categories
        tx_features = self.extract_transaction_features(address, time_window)
        clustering_features = self.extract_clustering_features(address)
        temporal_features = self.extract_temporal_features(address, time_window)
        gas_features = self.extract_gas_usage_features(address, time_window)
        
        # Combine all features
        all_features = {
            **tx_features,
            **clustering_features,
            **temporal_features,
            **gas_features
        }
        
        # Add feature extraction timestamp
        all_features["extraction_timestamp"] = datetime.now().timestamp()
        
        return all_features
    
    def save_features(self, address: str, features: Dict[str, float], output_dir: str = None) -> str:
        """
        Save extracted features to a file.
        
        Args:
            address: The account address
            features: Dictionary of features
            output_dir: Directory to save features
            
        Returns:
            Path to the saved features file
        """
        if output_dir is None:
            output_dir = os.path.join(data_path, "features")
            
        os.makedirs(output_dir, exist_ok=True)
        
        # Create a DataFrame from features
        df = pd.DataFrame([features])
        
        # Save to CSV
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{address}_{timestamp}.csv"
        filepath = os.path.join(output_dir, filename)
        
        df.to_csv(filepath, index=False)
        logger.info(f"Features saved to {filepath}")
        
        return filepath
    
    def load_features(self, filepath: str) -> Dict[str, float]:
        """
        Load features from a file.
        
        Args:
            filepath: Path to the features file
            
        Returns:
            Dictionary of features
        """
        df = pd.read_csv(filepath)
        features = df.iloc[0].to_dict()
        logger.info(f"Features loaded from {filepath}")
        
        return features


class FeatureBatchProcessor:
    """
    Process features in batches for multiple addresses.
    """
    
    def __init__(self, extractor: OnChainFeatureExtractor):
        """
        Initialize the batch processor.
        
        Args:
            extractor: Feature extractor instance
        """
        self.extractor = extractor
        
    def process_batch(self, addresses: List[str], time_window: int = 30) -> Dict[str, Dict[str, float]]:
        """
        Process features for a batch of addresses.
        
        Args:
            addresses: List of addresses to process
            time_window: Time window in days for analysis
            
        Returns:
            Dictionary mapping addresses to their features
        """
        results = {}
        
        for address in addresses:
            try:
                features = self.extractor.extract_all_features(address, time_window)
                results[address] = features
            except Exception as e:
                logger.error(f"Error processing features for {address}: {e}")
                
        return results
    
    def save_batch_features(self, batch_results: Dict[str, Dict[str, float]], output_dir: str = None) -> str:
        """
        Save batch features to a file.
        
        Args:
            batch_results: Dictionary mapping addresses to their features
            output_dir: Directory to save features
            
        Returns:
            Path to the saved batch file
        """
        if output_dir is None:
            output_dir = os.path.join(data_path, "features", "batch")
            
        os.makedirs(output_dir, exist_ok=True)
        
        # Create a DataFrame from batch results
        rows = []
        for address, features in batch_results.items():
            row = {"address": address, **features}
            rows.append(row)
            
        df = pd.DataFrame(rows)
        
        # Save to CSV
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"batch_{timestamp}.csv"
        filepath = os.path.join(output_dir, filename)
        
        df.to_csv(filepath, index=False)
        logger.info(f"Batch features saved to {filepath}")
        
        return filepath


if __name__ == "__main__":
    # Example usage
    extractor = OnChainFeatureExtractor()
    
    # Extract features for a sample address
    sample_address = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    features = extractor.extract_all_features(sample_address)
    
    # Save features
    extractor.save_features(sample_address, features)
    
    # Process a batch
    batch_processor = FeatureBatchProcessor(extractor)
    sample_addresses = [
        "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    ]
    batch_results = batch_processor.process_batch(sample_addresses)
    batch_processor.save_batch_features(batch_results)
