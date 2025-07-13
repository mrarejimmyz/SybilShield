"""
Improved Feature extraction module for AptosSybilShield

This module implements actual feature extraction logic from on-chain data for use in
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
from collections import defaultdict, Counter
import hashlib
import json

# Import configuration
from config.ml_config import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("improved_feature_extraction")

class ImprovedOnChainFeatureExtractor:
    """
    Improved feature extractor that processes real blockchain data for Sybil detection.
    
    This class processes blockchain data to extract features related to
    transaction patterns, clustering, temporal behavior, and gas usage.
    """
    
    def __init__(self, indexer_client=None):
        """
        Initialize the improved feature extractor.
        
        Args:
            indexer_client: Client for accessing the Aptos indexer
        """
        self.indexer_client = indexer_client
        self.graph = nx.DiGraph()  # Directed graph for transaction analysis
        self.address_cache = {}  # Cache for processed addresses
        
    def _parse_transaction_data(self, transactions: List[Dict]) -> Dict[str, Any]:
        """
        Parse raw transaction data into structured format.
        
        Args:
            transactions: List of transaction objects from indexer
            
        Returns:
            Dictionary with parsed transaction data
        """
        if not transactions:
            return {
                'tx_count': 0,
                'unique_counterparts': set(),
                'tx_values': [],
                'tx_intervals': [],
                'gas_used': [],
                'gas_prices': [],
                'tx_types': [],
                'timestamps': [],
                'success_rate': 0.0
            }
        
        parsed_data = {
            'tx_count': len(transactions),
            'unique_counterparts': set(),
            'tx_values': [],
            'tx_intervals': [],
            'gas_used': [],
            'gas_prices': [],
            'tx_types': [],
            'timestamps': [],
            'success_count': 0
        }
        
        # Sort transactions by timestamp
        sorted_txs = sorted(transactions, key=lambda x: x.get('timestamp', 0))
        
        prev_timestamp = None
        for tx in sorted_txs:
            # Extract counterpart addresses
            if 'sender' in tx and tx['sender']:
                parsed_data['unique_counterparts'].add(tx['sender'])
            if 'receiver' in tx and tx['receiver']:
                parsed_data['unique_counterparts'].add(tx['receiver'])
            
            # Extract gas information
            if 'gas_used' in tx and tx['gas_used']:
                parsed_data['gas_used'].append(float(tx['gas_used']))
            if 'gas_unit_price' in tx and tx['gas_unit_price']:
                parsed_data['gas_prices'].append(float(tx['gas_unit_price']))
            
            # Extract transaction type
            if 'type' in tx:
                parsed_data['tx_types'].append(tx['type'])
            
            # Extract timestamp and calculate intervals
            if 'timestamp' in tx:
                timestamp = tx['timestamp']
                parsed_data['timestamps'].append(timestamp)
                
                if prev_timestamp is not None:
                    interval = abs(timestamp - prev_timestamp)
                    parsed_data['tx_intervals'].append(interval)
                
                prev_timestamp = timestamp
            
            # Count successful transactions
            if tx.get('status') == 'success':
                parsed_data['success_count'] += 1
        
        # Calculate success rate
        parsed_data['success_rate'] = (
            parsed_data['success_count'] / parsed_data['tx_count'] 
            if parsed_data['tx_count'] > 0 else 0.0
        )
        
        return parsed_data
    
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
        
        # Get transaction data from indexer
        transactions = []
        if self.indexer_client:
            try:
                transactions = self.indexer_client.get_account_transactions(
                    address, limit=1000
                )
            except Exception as e:
                logger.error(f"Error fetching transactions for {address}: {e}")
        
        # Parse transaction data
        parsed_data = self._parse_transaction_data(transactions)
        
        # Calculate transaction features
        features = {
            "tx_count_total": parsed_data['tx_count'],
            "unique_counterparts_count": len(parsed_data['unique_counterparts']),
            "tx_success_rate": parsed_data['success_rate'],
        }
        
        # Gas usage features
        if parsed_data['gas_used']:
            features.update({
                "gas_used_mean": np.mean(parsed_data['gas_used']),
                "gas_used_std": np.std(parsed_data['gas_used']),
                "gas_used_max": np.max(parsed_data['gas_used']),
                "gas_used_min": np.min(parsed_data['gas_used']),
                "gas_used_median": np.median(parsed_data['gas_used']),
            })
        else:
            features.update({
                "gas_used_mean": 0.0,
                "gas_used_std": 0.0,
                "gas_used_max": 0.0,
                "gas_used_min": 0.0,
                "gas_used_median": 0.0,
            })
        
        # Gas price features
        if parsed_data['gas_prices']:
            features.update({
                "gas_price_mean": np.mean(parsed_data['gas_prices']),
                "gas_price_std": np.std(parsed_data['gas_prices']),
                "gas_price_volatility": np.std(parsed_data['gas_prices']) / max(np.mean(parsed_data['gas_prices']), 1e-8),
            })
        else:
            features.update({
                "gas_price_mean": 0.0,
                "gas_price_std": 0.0,
                "gas_price_volatility": 0.0,
            })
        
        # Transaction interval features
        if parsed_data['tx_intervals']:
            features.update({
                "tx_interval_mean": np.mean(parsed_data['tx_intervals']),
                "tx_interval_std": np.std(parsed_data['tx_intervals']),
                "tx_interval_min": np.min(parsed_data['tx_intervals']),
                "tx_interval_max": np.max(parsed_data['tx_intervals']),
            })
        else:
            features.update({
                "tx_interval_mean": 0.0,
                "tx_interval_std": 0.0,
                "tx_interval_min": 0.0,
                "tx_interval_max": 0.0,
            })
        
        # Transaction type diversity
        if parsed_data['tx_types']:
            type_counts = Counter(parsed_data['tx_types'])
            features.update({
                "tx_type_diversity": len(type_counts),
                "tx_type_entropy": self._calculate_entropy(list(type_counts.values())),
            })
        else:
            features.update({
                "tx_type_diversity": 0.0,
                "tx_type_entropy": 0.0,
            })
        
        return features
    
    def extract_clustering_features(self, address: str) -> Dict[str, float]:
        """
        Extract features related to address clustering using graph analysis.
        
        Args:
            address: The account address to analyze
            
        Returns:
            Dictionary of clustering-related features
        """
        logger.info(f"Extracting clustering features for {address}")
        
        # Build transaction graph if not already built
        self._build_transaction_graph(address)
        
        features = {}
        
        if address in self.graph:
            # Calculate centrality measures
            try:
                # Degree centrality
                features["degree_centrality"] = nx.degree_centrality(self.graph).get(address, 0.0)
                
                # Betweenness centrality (computationally expensive, use approximation)
                if self.graph.number_of_nodes() < 1000:
                    features["betweenness_centrality"] = nx.betweenness_centrality(self.graph).get(address, 0.0)
                else:
                    # Use approximation for large graphs
                    features["betweenness_centrality"] = nx.betweenness_centrality(
                        self.graph, k=min(100, self.graph.number_of_nodes())
                    ).get(address, 0.0)
                
                # Clustering coefficient
                features["clustering_coefficient"] = nx.clustering(self.graph, address)
                
                # PageRank
                pagerank_scores = nx.pagerank(self.graph, max_iter=50)
                features["pagerank"] = pagerank_scores.get(address, 0.0)
                
                # Connected component analysis
                if self.graph.is_directed():
                    # Strongly connected components
                    scc = list(nx.strongly_connected_components(self.graph))
                    scc_size = 0
                    for component in scc:
                        if address in component:
                            scc_size = len(component)
                            break
                    features["strongly_connected_component_size"] = scc_size
                    
                    # Weakly connected components
                    wcc = list(nx.weakly_connected_components(self.graph))
                    wcc_size = 0
                    for component in wcc:
                        if address in component:
                            wcc_size = len(component)
                            break
                    features["weakly_connected_component_size"] = wcc_size
                else:
                    # For undirected graphs
                    cc = list(nx.connected_components(self.graph))
                    cc_size = 0
                    for component in cc:
                        if address in component:
                            cc_size = len(component)
                            break
                    features["connected_component_size"] = cc_size
                    features["strongly_connected_component_size"] = cc_size
                    features["weakly_connected_component_size"] = cc_size
                
                # K-core analysis
                try:
                    k_core = nx.core_number(self.graph.to_undirected())
                    features["k_core"] = k_core.get(address, 0)
                except:
                    features["k_core"] = 0
                
                # Local clustering coefficient
                features["local_clustering_coefficient"] = nx.clustering(self.graph, address)
                
            except Exception as e:
                logger.error(f"Error calculating graph metrics for {address}: {e}")
                # Set default values if calculation fails
                features.update({
                    "degree_centrality": 0.0,
                    "betweenness_centrality": 0.0,
                    "clustering_coefficient": 0.0,
                    "pagerank": 0.0,
                    "strongly_connected_component_size": 0,
                    "weakly_connected_component_size": 0,
                    "k_core": 0,
                    "local_clustering_coefficient": 0.0,
                })
        else:
            # Address not in graph, set all features to 0
            features.update({
                "degree_centrality": 0.0,
                "betweenness_centrality": 0.0,
                "clustering_coefficient": 0.0,
                "pagerank": 0.0,
                "strongly_connected_component_size": 0,
                "weakly_connected_component_size": 0,
                "k_core": 0,
                "local_clustering_coefficient": 0.0,
            })
        
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
        
        # Get transaction data
        transactions = []
        if self.indexer_client:
            try:
                transactions = self.indexer_client.get_account_transactions(
                    address, limit=1000
                )
            except Exception as e:
                logger.error(f"Error fetching transactions for {address}: {e}")
        
        if not transactions:
            return {
                "activity_hours_entropy": 0.0,
                "activity_days_entropy": 0.0,
                "burst_rate": 0.0,
                "dormant_periods": 0,
                "activity_consistency": 0.0,
                "periodic_pattern_strength": 0.0,
                "time_between_txs_mean": 0.0,
                "time_between_txs_std": 0.0,
            }
        
        # Extract timestamps
        timestamps = []
        for tx in transactions:
            if 'timestamp' in tx:
                timestamps.append(tx['timestamp'])
        
        if not timestamps:
            return {
                "activity_hours_entropy": 0.0,
                "activity_days_entropy": 0.0,
                "burst_rate": 0.0,
                "dormant_periods": 0,
                "activity_consistency": 0.0,
                "periodic_pattern_strength": 0.0,
                "time_between_txs_mean": 0.0,
                "time_between_txs_std": 0.0,
            }
        
        # Convert timestamps to datetime objects
        try:
            if isinstance(timestamps[0], str):
                datetimes = [datetime.fromisoformat(ts.replace('Z', '+00:00')) for ts in timestamps]
            else:
                datetimes = [datetime.fromtimestamp(ts) for ts in timestamps]
        except:
            # Fallback: assume timestamps are already in correct format
            datetimes = timestamps
        
        # Sort by time
        datetimes.sort()
        
        # Extract hour and day patterns
        hours = [dt.hour for dt in datetimes]
        days = [dt.weekday() for dt in datetimes]  # 0=Monday, 6=Sunday
        
        # Calculate entropy for activity patterns
        hour_counts = Counter(hours)
        day_counts = Counter(days)
        
        features = {
            "activity_hours_entropy": self._calculate_entropy(list(hour_counts.values())),
            "activity_days_entropy": self._calculate_entropy(list(day_counts.values())),
        }
        
        # Calculate time intervals between transactions
        intervals = []
        for i in range(1, len(datetimes)):
            interval = (datetimes[i] - datetimes[i-1]).total_seconds()
            intervals.append(interval)
        
        if intervals:
            features.update({
                "time_between_txs_mean": np.mean(intervals),
                "time_between_txs_std": np.std(intervals),
            })
            
            # Detect burst activity (many transactions in short time)
            short_intervals = [i for i in intervals if i < 3600]  # Less than 1 hour
            features["burst_rate"] = len(short_intervals) / len(intervals)
            
            # Detect dormant periods (long gaps between transactions)
            long_intervals = [i for i in intervals if i > 86400 * 7]  # More than 1 week
            features["dormant_periods"] = len(long_intervals)
            
            # Activity consistency (inverse of coefficient of variation)
            mean_interval = np.mean(intervals)
            std_interval = np.std(intervals)
            features["activity_consistency"] = 1.0 / (1.0 + std_interval / max(mean_interval, 1e-8))
            
            # Periodic pattern strength (using autocorrelation)
            features["periodic_pattern_strength"] = self._calculate_periodicity(intervals)
        else:
            features.update({
                "time_between_txs_mean": 0.0,
                "time_between_txs_std": 0.0,
                "burst_rate": 0.0,
                "dormant_periods": 0,
                "activity_consistency": 0.0,
                "periodic_pattern_strength": 0.0,
            })
        
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
        
        # Get transaction data
        transactions = []
        if self.indexer_client:
            try:
                transactions = self.indexer_client.get_account_transactions(
                    address, limit=1000
                )
            except Exception as e:
                logger.error(f"Error fetching transactions for {address}: {e}")
        
        # Parse gas data
        gas_used = []
        gas_prices = []
        
        for tx in transactions:
            if 'gas_used' in tx and tx['gas_used']:
                gas_used.append(float(tx['gas_used']))
            if 'gas_unit_price' in tx and tx['gas_unit_price']:
                gas_prices.append(float(tx['gas_unit_price']))
        
        features = {}
        
        # Gas usage statistics
        if gas_used:
            features.update({
                "gas_used_mean": np.mean(gas_used),
                "gas_used_std": np.std(gas_used),
                "gas_used_median": np.median(gas_used),
                "gas_used_percentile_90": np.percentile(gas_used, 90),
                "gas_used_percentile_10": np.percentile(gas_used, 10),
                "gas_used_range": np.max(gas_used) - np.min(gas_used),
                "gas_used_coefficient_variation": np.std(gas_used) / max(np.mean(gas_used), 1e-8),
            })
        else:
            features.update({
                "gas_used_mean": 0.0,
                "gas_used_std": 0.0,
                "gas_used_median": 0.0,
                "gas_used_percentile_90": 0.0,
                "gas_used_percentile_10": 0.0,
                "gas_used_range": 0.0,
                "gas_used_coefficient_variation": 0.0,
            })
        
        # Gas price statistics
        if gas_prices:
            features.update({
                "gas_price_mean": np.mean(gas_prices),
                "gas_price_std": np.std(gas_prices),
                "gas_price_median": np.median(gas_prices),
                "gas_price_percentile_90": np.percentile(gas_prices, 90),
                "gas_price_volatility": np.std(gas_prices) / max(np.mean(gas_prices), 1e-8),
            })
            
            # Gas price optimization behavior
            unique_prices = len(set(gas_prices))
            features["gas_price_diversity"] = unique_prices / len(gas_prices)
        else:
            features.update({
                "gas_price_mean": 0.0,
                "gas_price_std": 0.0,
                "gas_price_median": 0.0,
                "gas_price_percentile_90": 0.0,
                "gas_price_volatility": 0.0,
                "gas_price_diversity": 0.0,
            })
        
        # Gas efficiency metrics
        if gas_used and gas_prices:
            total_gas_cost = [u * p for u, p in zip(gas_used, gas_prices)]
            features.update({
                "total_gas_cost_mean": np.mean(total_gas_cost),
                "total_gas_cost_std": np.std(total_gas_cost),
                "gas_efficiency_score": np.mean(gas_used) / max(np.mean(gas_prices), 1e-8),
            })
        else:
            features.update({
                "total_gas_cost_mean": 0.0,
                "total_gas_cost_std": 0.0,
                "gas_efficiency_score": 0.0,
            })
        
        return features
    
    def _build_transaction_graph(self, address: str, max_depth: int = 2):
        """
        Build a transaction graph for network analysis.
        
        Args:
            address: The central address to build graph around
            max_depth: Maximum depth for graph expansion
        """
        if address in self.address_cache:
            return
        
        # Get transactions for the address
        transactions = []
        if self.indexer_client:
            try:
                transactions = self.indexer_client.get_account_transactions(
                    address, limit=500
                )
            except Exception as e:
                logger.error(f"Error fetching transactions for graph building: {e}")
                return
        
        # Add nodes and edges to graph
        self.graph.add_node(address)
        
        for tx in transactions:
            sender = tx.get('sender')
            receiver = tx.get('receiver')
            
            if sender and receiver:
                self.graph.add_edge(sender, receiver, 
                                  weight=1, 
                                  timestamp=tx.get('timestamp', 0))
        
        # Mark as processed
        self.address_cache[address] = True
    
    def _calculate_entropy(self, values: List[float]) -> float:
        """
        Calculate Shannon entropy of a list of values.
        
        Args:
            values: List of values
            
        Returns:
            Shannon entropy
        """
        if not values:
            return 0.0
        
        total = sum(values)
        if total == 0:
            return 0.0
        
        probabilities = [v / total for v in values]
        entropy = -sum(p * np.log2(p) for p in probabilities if p > 0)
        
        return entropy
    
    def _calculate_periodicity(self, intervals: List[float]) -> float:
        """
        Calculate periodicity strength using autocorrelation.
        
        Args:
            intervals: List of time intervals
            
        Returns:
            Periodicity strength (0-1)
        """
        if len(intervals) < 10:
            return 0.0
        
        try:
            # Simple autocorrelation at lag 1
            mean_interval = np.mean(intervals)
            numerator = sum((intervals[i] - mean_interval) * (intervals[i+1] - mean_interval) 
                          for i in range(len(intervals)-1))
            denominator = sum((interval - mean_interval)**2 for interval in intervals)
            
            if denominator == 0:
                return 0.0
            
            autocorr = numerator / denominator
            return abs(autocorr)  # Return absolute value as strength measure
        except:
            return 0.0
    
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
        
        # Add metadata
        all_features["extraction_timestamp"] = datetime.now().timestamp()
        all_features["time_window_days"] = time_window
        all_features["address_hash"] = hashlib.sha256(address.encode()).hexdigest()[:16]
        
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
        filename = f"{address[:8]}_{timestamp}.csv"
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


# Utility functions for feature engineering
def create_synthetic_training_data(n_samples: int = 1000, n_features: int = 50) -> Tuple[pd.DataFrame, pd.Series]:
    """
    Create synthetic training data for testing purposes.
    
    Args:
        n_samples: Number of samples to generate
        n_features: Number of features to generate
        
    Returns:
        Tuple of (features DataFrame, labels Series)
    """
    logger.info(f"Creating synthetic training data with {n_samples} samples and {n_features} features")
    
    np.random.seed(42)
    
    # Generate feature names based on actual feature extraction
    feature_names = [
        "tx_count_total", "unique_counterparts_count", "tx_success_rate",
        "gas_used_mean", "gas_used_std", "gas_price_mean", "gas_price_volatility",
        "tx_interval_mean", "tx_interval_std", "degree_centrality", "betweenness_centrality",
        "clustering_coefficient", "pagerank", "activity_hours_entropy", "burst_rate",
        "time_between_txs_mean", "gas_efficiency_score"
    ]
    
    # Extend with additional synthetic features if needed
    while len(feature_names) < n_features:
        feature_names.append(f"synthetic_feature_{len(feature_names)}")
    
    feature_names = feature_names[:n_features]
    
    # Generate legitimate accounts (80% of data)
    n_legitimate = int(0.8 * n_samples)
    legitimate_features = np.random.normal(0, 1, (n_legitimate, n_features))
    
    # Generate Sybil accounts (20% of data) with different patterns
    n_sybil = n_samples - n_legitimate
    sybil_features = np.random.normal(0, 1, (n_sybil, n_features))
    
    # Make Sybil accounts have distinctive patterns
    # Higher transaction frequency but lower diversity
    sybil_features[:, 0] *= 2  # Higher tx_count_total
    sybil_features[:, 1] *= 0.5  # Lower unique_counterparts_count
    sybil_features[:, 9] *= 1.5  # Higher degree_centrality (more connected)
    sybil_features[:, 13] *= 0.3  # Lower activity_hours_entropy (more predictable)
    
    # Combine features and labels
    X = np.vstack([legitimate_features, sybil_features])
    y = np.hstack([np.zeros(n_legitimate), np.ones(n_sybil)])
    
    # Create DataFrame and Series
    X_df = pd.DataFrame(X, columns=feature_names)
    y_series = pd.Series(y, name='is_sybil')
    
    logger.info(f"Created synthetic dataset with {n_legitimate} legitimate and {n_sybil} Sybil samples")
    
    return X_df, y_series


if __name__ == "__main__":
    # Example usage
    extractor = ImprovedOnChainFeatureExtractor()
    
    # Create synthetic data for testing
    X, y = create_synthetic_training_data(n_samples=1000, n_features=30)
    
    # Save synthetic data
    output_dir = os.path.join(data_path, "synthetic")
    os.makedirs(output_dir, exist_ok=True)
    
    X.to_csv(os.path.join(output_dir, "features.csv"), index=False)
    y.to_csv(os.path.join(output_dir, "labels.csv"), index=False)
    
    logger.info("Synthetic training data created and saved")
    
    # Extract features for a sample address (without indexer client)
    sample_address = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    features = extractor.extract_all_features(sample_address)
    
    # Save features
    extractor.save_features(sample_address, features)
    
    logger.info("Feature extraction example completed")

