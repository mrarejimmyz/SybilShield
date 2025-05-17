"""
Differential Privacy implementation for AptosSybilShield

This module implements differential privacy techniques to protect user information
while still allowing for effective Sybil detection and analytics.
"""

import os
import logging
import numpy as np
import pandas as pd
import random
from typing import Dict, List, Tuple, Any, Optional
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("differential_privacy")

class DifferentialPrivacy:
    """
    Differential Privacy system for protecting user data in analytics.
    
    This implementation provides mechanisms to add controlled noise to data
    to protect individual privacy while maintaining statistical utility.
    """
    
    def __init__(self, epsilon: float = 1.0, delta: float = 1e-5):
        """
        Initialize the differential privacy system.
        
        Args:
            epsilon: Privacy parameter (smaller means more privacy)
            delta: Probability of privacy failure
        """
        self.epsilon = epsilon
        self.delta = delta
        
    def add_laplace_noise(self, value: float, sensitivity: float) -> float:
        """
        Add Laplace noise to a numeric value.
        
        Args:
            value: Original value
            sensitivity: Maximum change in the function if one record changes
            
        Returns:
            Value with noise added
        """
        scale = sensitivity / self.epsilon
        noise = np.random.laplace(0, scale)
        return value + noise
    
    def add_gaussian_noise(self, value: float, sensitivity: float) -> float:
        """
        Add Gaussian noise to a numeric value.
        
        Args:
            value: Original value
            sensitivity: Maximum change in the function if one record changes
            
        Returns:
            Value with noise added
        """
        sigma = np.sqrt(2 * np.log(1.25 / self.delta)) * sensitivity / self.epsilon
        noise = np.random.normal(0, sigma)
        return value + noise
    
    def privatize_counts(self, counts: Dict[str, int], sensitivity: float = 1.0) -> Dict[str, float]:
        """
        Privatize a dictionary of counts.
        
        Args:
            counts: Dictionary mapping categories to counts
            sensitivity: Maximum change in counts if one record changes
            
        Returns:
            Dictionary with privatized counts
        """
        privatized = {}
        for category, count in counts.items():
            privatized[category] = max(0, round(self.add_laplace_noise(count, sensitivity)))
        return privatized
    
    def privatize_dataframe(self, df: pd.DataFrame, numeric_columns: List[str], 
                           sensitivities: Dict[str, float]) -> pd.DataFrame:
        """
        Privatize numeric columns in a DataFrame.
        
        Args:
            df: Input DataFrame
            numeric_columns: List of numeric columns to privatize
            sensitivities: Dictionary mapping column names to sensitivity values
            
        Returns:
            DataFrame with privatized values
        """
        df_private = df.copy()
        
        for column in numeric_columns:
            if column not in df.columns:
                continue
                
            sensitivity = sensitivities.get(column, 1.0)
            
            # Add noise to each value in the column
            df_private[column] = df[column].apply(
                lambda x: self.add_laplace_noise(x, sensitivity) if pd.notnull(x) else x
            )
            
        return df_private
    
    def privatize_aggregates(self, aggregates: Dict[str, float], 
                            sensitivities: Dict[str, float]) -> Dict[str, float]:
        """
        Privatize aggregate statistics.
        
        Args:
            aggregates: Dictionary of aggregate statistics
            sensitivities: Dictionary mapping statistic names to sensitivity values
            
        Returns:
            Dictionary with privatized statistics
        """
        privatized = {}
        
        for stat_name, value in aggregates.items():
            sensitivity = sensitivities.get(stat_name, 1.0)
            privatized[stat_name] = self.add_laplace_noise(value, sensitivity)
            
        return privatized


class PrivacyPreservingAnalytics:
    """
    Privacy-preserving analytics for AptosSybilShield.
    
    This class provides methods for performing analytics on user data
    while preserving privacy through differential privacy techniques.
    """
    
    def __init__(self, dp_system: DifferentialPrivacy):
        """
        Initialize the privacy-preserving analytics system.
        
        Args:
            dp_system: Differential privacy system
        """
        self.dp_system = dp_system
        
    def compute_risk_distribution(self, risk_scores: List[int]) -> Dict[str, Any]:
        """
        Compute the distribution of risk scores with privacy guarantees.
        
        Args:
            risk_scores: List of risk scores (0-100)
            
        Returns:
            Dictionary with privatized distribution statistics
        """
        # Create bins for the distribution
        bins = {
            "low_risk": 0,
            "medium_risk": 0,
            "high_risk": 0,
            "very_high_risk": 0
        }
        
        # Count scores in each bin
        for score in risk_scores:
            if score < 25:
                bins["low_risk"] += 1
            elif score < 50:
                bins["medium_risk"] += 1
            elif score < 75:
                bins["high_risk"] += 1
            else:
                bins["very_high_risk"] += 1
        
        # Privatize the counts
        private_bins = self.dp_system.privatize_counts(bins)
        
        # Calculate total (might not match original due to noise)
        total = sum(private_bins.values())
        
        # Calculate percentages
        percentages = {
            category: (count / total * 100) if total > 0 else 0
            for category, count in private_bins.items()
        }
        
        # Calculate basic statistics with privacy
        if risk_scores:
            stats = {
                "mean": np.mean(risk_scores),
                "median": np.median(risk_scores),
                "std": np.std(risk_scores),
                "min": min(risk_scores),
                "max": max(risk_scores)
            }
            
            sensitivities = {
                "mean": 1.0 / len(risk_scores),  # Sensitivity of mean
                "median": 1.0,  # Sensitivity of median (approximate)
                "std": 1.0,  # Sensitivity of std (approximate)
                "min": 0.0,  # Min doesn't change much with one record
                "max": 0.0   # Max doesn't change much with one record
            }
            
            private_stats = self.dp_system.privatize_aggregates(stats, sensitivities)
        else:
            private_stats = {
                "mean": 0,
                "median": 0,
                "std": 0,
                "min": 0,
                "max": 0
            }
        
        return {
            "counts": private_bins,
            "percentages": percentages,
            "statistics": private_stats,
            "privacy_params": {
                "epsilon": self.dp_system.epsilon,
                "delta": self.dp_system.delta
            }
        }
    
    def compute_verification_statistics(self, verification_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Compute statistics about verification processes with privacy guarantees.
        
        Args:
            verification_data: List of verification records
            
        Returns:
            Dictionary with privatized verification statistics
        """
        # Count verifications by type and status
        type_counts = {}
        status_counts = {
            "pending": 0,
            "verified": 0,
            "failed": 0,
            "expired": 0
        }
        
        for record in verification_data:
            # Count by type
            v_type = record.get("verification_type", "unknown")
            if v_type not in type_counts:
                type_counts[v_type] = 0
            type_counts[v_type] += 1
            
            # Count by status
            status = record.get("status", "unknown")
            if status in status_counts:
                status_counts[status] += 1
        
        # Privatize the counts
        private_type_counts = self.dp_system.privatize_counts(type_counts)
        private_status_counts = self.dp_system.privatize_counts(status_counts)
        
        # Calculate success rate with privacy
        total_completed = status_counts["verified"] + status_counts["failed"]
        success_rate = (status_counts["verified"] / total_completed * 100) if total_completed > 0 else 0
        
        # Add noise to success rate
        private_success_rate = self.dp_system.add_laplace_noise(success_rate, 1.0 / max(1, total_completed))
        private_success_rate = max(0, min(100, private_success_rate))  # Clamp to valid range
        
        return {
            "verification_types": private_type_counts,
            "verification_statuses": private_status_counts,
            "success_rate": private_success_rate,
            "privacy_params": {
                "epsilon": self.dp_system.epsilon,
                "delta": self.dp_system.delta
            }
        }
    
    def privatize_feature_importance(self, feature_importance: Dict[str, float]) -> Dict[str, float]:
        """
        Privatize feature importance scores.
        
        Args:
            feature_importance: Dictionary mapping features to importance scores
            
        Returns:
            Dictionary with privatized importance scores
        """
        # Determine sensitivity based on the range of importance values
        values = list(feature_importance.values())
        max_value = max(values) if values else 1.0
        sensitivity = max_value * 0.01  # Small fraction of the maximum value
        
        privatized = {}
        for feature, importance in feature_importance.items():
            # Add noise to importance score
            private_importance = self.dp_system.add_laplace_noise(importance, sensitivity)
            privatized[feature] = max(0, private_importance)  # Ensure non-negative
            
        return privatized
    
    def generate_privacy_preserving_report(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate a privacy-preserving analytics report.
        
        Args:
            data: Dictionary containing various data for the report
            
        Returns:
            Dictionary with privatized report data
        """
        report = {
            "generated_at": datetime.now().isoformat(),
            "privacy_level": f"ε={self.dp_system.epsilon}, δ={self.dp_system.delta}"
        }
        
        # Process risk scores if available
        if "risk_scores" in data and data["risk_scores"]:
            report["risk_distribution"] = self.compute_risk_distribution(data["risk_scores"])
        
        # Process verification data if available
        if "verifications" in data and data["verifications"]:
            report["verification_statistics"] = self.compute_verification_statistics(data["verifications"])
        
        # Process feature importance if available
        if "feature_importance" in data and data["feature_importance"]:
            report["feature_importance"] = self.privatize_feature_importance(data["feature_importance"])
        
        return report


if __name__ == "__main__":
    # Example usage
    dp_system = DifferentialPrivacy(epsilon=0.5)  # Stronger privacy
    analytics = PrivacyPreservingAnalytics(dp_system)
    
    # Generate some sample data
    risk_scores = [random.randint(0, 100) for _ in range(1000)]
    
    # Generate sample verification data
    verification_types = ["social_twitter", "did_web", "pop_captcha"]
    statuses = ["pending", "verified", "failed", "expired"]
    
    verifications = []
    for _ in range(500):
        verifications.append({
            "verification_type": random.choice(verification_types),
            "status": random.choice(statuses),
            "timestamp": datetime.now().isoformat()
        })
    
    # Generate sample feature importance
    feature_importance = {
        "transaction_count": 0.8,
        "account_age": 0.6,
        "unique_receivers": 0.5,
        "gas_price_volatility": 0.4,
        "transaction_frequency": 0.3
    }
    
    # Generate a privacy-preserving report
    report_data = {
        "risk_scores": risk_scores,
        "verifications": verifications,
        "feature_importance": feature_importance
    }
    
    report = analytics.generate_privacy_preserving_report(report_data)
    
    print("Privacy-Preserving Analytics Report:")
    print(f"Generated at: {report['generated_at']}")
    print(f"Privacy level: {report['privacy_level']}")
    
    if "risk_distribution" in report:
        print("\nRisk Distribution:")
        for category, count in report["risk_distribution"]["counts"].items():
            print(f"  {category}: {count:.1f} ({report['risk_distribution']['percentages'][category]:.1f}%)")
    
    if "verification_statistics" in report:
        print("\nVerification Statistics:")
        print("  Types:")
        for v_type, count in report["verification_statistics"]["verification_types"].items():
            print(f"    {v_type}: {count:.1f}")
        print("  Success rate: {:.1f}%".format(report["verification_statistics"]["success_rate"]))
    
    if "feature_importance" in report:
        print("\nPrivatized Feature Importance:")
        for feature, importance in sorted(report["feature_importance"].items(), key=lambda x: x[1], reverse=True):
            print(f"  {feature}: {importance:.4f}")
