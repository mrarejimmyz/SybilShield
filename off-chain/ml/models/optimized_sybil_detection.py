"""
Optimized Sybil detection models for AptosSybilShield

This module implements optimized machine learning models for Sybil detection,
including supervised classification and unsupervised anomaly detection approaches.
Optimizations include model simplification, feature caching, and batch processing.
"""

import os
import logging
import numpy as np
import pandas as pd
import joblib
import time
from typing import Dict, List, Tuple, Any, Optional
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
import tensorflow as tf
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import Dense, Dropout, Input
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from functools import lru_cache

# Import configuration
from config.ml_config import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("sybil_detection_models")

# Feature cache with TTL
class FeatureCache:
    """
    Cache for preprocessed features with time-to-live functionality.
    """
    
    def __init__(self, ttl_seconds: int = 3600):
        """
        Initialize the feature cache.
        
        Args:
            ttl_seconds: Time-to-live in seconds for cache entries
        """
        self.cache = {}
        self.ttl_seconds = ttl_seconds
    
    def get(self, key: str) -> Optional[np.ndarray]:
        """
        Get a value from the cache if it exists and is not expired.
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found or expired
        """
        if key in self.cache:
            entry = self.cache[key]
            if time.time() - entry['timestamp'] < self.ttl_seconds:
                return entry['value']
            else:
                # Remove expired entry
                del self.cache[key]
        return None
    
    def set(self, key: str, value: np.ndarray) -> None:
        """
        Set a value in the cache with current timestamp.
        
        Args:
            key: Cache key
            value: Value to cache
        """
        self.cache[key] = {
            'value': value,
            'timestamp': time.time()
        }
    
    def clear(self) -> None:
        """Clear the entire cache."""
        self.cache = {}
    
    def remove_expired(self) -> None:
        """Remove all expired entries from the cache."""
        now = time.time()
        keys_to_delete = []
        
        for key, entry in self.cache.items():
            if now - entry['timestamp'] >= self.ttl_seconds:
                keys_to_delete.append(key)
        
        for key in keys_to_delete:
            del self.cache[key]


class SybilDetectionModel:
    """
    Base class for Sybil detection models.
    """
    
    def __init__(self, model_name: str = "sybil_detector"):
        """
        Initialize the Sybil detection model.
        
        Args:
            model_name: Name of the model
        """
        self.model_name = model_name
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = None
        self.feature_cache = FeatureCache()
        self.batch_size = 64  # Default batch size for batch predictions
        
    def save_model(self, output_dir: str = None) -> str:
        """
        Save the trained model to disk.
        
        Args:
            output_dir: Directory to save the model
            
        Returns:
            Path to the saved model
        """
        if output_dir is None:
            output_dir = os.path.join(model_path)
            
        os.makedirs(output_dir, exist_ok=True)
        
        # Create a model package with model and scaler
        model_package = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'model_name': self.model_name
        }
        
        # Save to disk
        filepath = os.path.join(output_dir, f"{self.model_name}.joblib")
        joblib.dump(model_package, filepath)
        logger.info(f"Model saved to {filepath}")
        
        return filepath
    
    def load_model(self, filepath: str) -> None:
        """
        Load a trained model from disk.
        
        Args:
            filepath: Path to the saved model
        """
        model_package = joblib.load(filepath)
        
        self.model = model_package['model']
        self.scaler = model_package['scaler']
        self.feature_names = model_package['feature_names']
        self.model_name = model_package['model_name']
        
        logger.info(f"Model loaded from {filepath}")
    
    def preprocess_features(self, features: Dict[str, float]) -> np.ndarray:
        """
        Preprocess features for model input with caching.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Preprocessed feature array
        """
        # Generate cache key
        cache_key = str(sorted(features.items()))
        
        # Check cache first
        cached_features = self.feature_cache.get(cache_key)
        if cached_features is not None:
            return cached_features
        
        # Ensure all expected features are present
        if self.feature_names is not None:
            # Create a new dictionary with only the required features
            processed_features = {}
            for feature in self.feature_names:
                processed_features[feature] = features.get(feature, 0.0)
        else:
            processed_features = features
        
        # Convert to array
        feature_array = np.array([list(processed_features.values())])
        
        # Scale features
        scaled_features = self.scaler.transform(feature_array)
        
        # Cache the result
        self.feature_cache.set(cache_key, scaled_features)
        
        return scaled_features
    
    def batch_preprocess_features(self, features_list: List[Dict[str, float]]) -> np.ndarray:
        """
        Preprocess multiple feature sets in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            Batch of preprocessed feature arrays
        """
        if not features_list:
            return np.array([])
        
        # Process each set of features
        processed_arrays = []
        for features in features_list:
            processed_arrays.append(self.preprocess_features(features))
        
        # Combine into a single batch
        return np.vstack(processed_arrays)
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Make a prediction for the given features.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        raise NotImplementedError("Subclasses must implement predict method")
    
    def batch_predict(self, features_list: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Make predictions for multiple sets of features in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            List of prediction result dictionaries
        """
        raise NotImplementedError("Subclasses must implement batch_predict method")


class OptimizedSupervisedSybilDetector(SybilDetectionModel):
    """
    Optimized supervised learning model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "optimized_supervised_sybil_detector"):
        """
        Initialize the optimized supervised Sybil detector.
        
        Args:
            model_name: Name of the model
        """
        super().__init__(model_name)
    
    def train(self, X: pd.DataFrame, y: pd.Series, test_size: float = 0.2) -> Dict[str, Any]:
        """
        Train the supervised model with feature importance analysis.
        
        Args:
            X: Feature matrix
            y: Target labels (0 for legitimate, 1 for Sybil)
            test_size: Proportion of data to use for testing
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training optimized supervised model with {len(X)} samples")
        
        # Store feature names
        self.feature_names = list(X.columns)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_seed
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Create and train model with optimized parameters
        self.model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            min_samples_split=5,
            min_samples_leaf=2,
            max_features='sqrt',
            bootstrap=True,
            random_state=random_seed,
            n_jobs=-1  # Use all available cores
        )
        
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate model
        y_pred = self.model.predict(X_test_scaled)
        y_prob = self.model.predict_proba(X_test_scaled)[:, 1]
        
        # Calculate metrics
        report = classification_report(y_test, y_pred, output_dict=True)
        conf_matrix = confusion_matrix(y_test, y_pred)
        auc = roc_auc_score(y_test, y_prob)
        
        # Analyze feature importance
        feature_importance = dict(zip(self.feature_names, self.model.feature_importances_))
        sorted_importance = sorted(feature_importance.items(), key=lambda x: x[1], reverse=True)
        
        # Identify top features (those that account for 90% of importance)
        cumulative_importance = 0
        top_features = []
        importance_threshold = 0.9  # 90% of total importance
        
        for feature, importance in sorted_importance:
            top_features.append(feature)
            cumulative_importance += importance
            if cumulative_importance >= importance_threshold:
                break
        
        # Store top features for optimized prediction
        self.top_features = top_features
        
        results = {
            'accuracy': report['accuracy'],
            'precision': report['1']['precision'],
            'recall': report['1']['recall'],
            'f1_score': report['1']['f1-score'],
            'auc': auc,
            'confusion_matrix': conf_matrix.tolist(),
            'feature_importance': feature_importance,
            'top_features': top_features,
            'top_features_coverage': cumulative_importance
        }
        
        logger.info(f"Training complete. Accuracy: {results['accuracy']:.4f}, AUC: {results['auc']:.4f}")
        logger.info(f"Using {len(top_features)} top features covering {cumulative_importance:.2f} of importance")
        
        return results
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Predict whether an address is a Sybil with optimized feature processing.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features with caching
        scaled_features = self.preprocess_features(features)
        
        # Make prediction
        is_sybil = bool(self.model.predict(scaled_features)[0])
        sybil_probability = float(self.model.predict_proba(scaled_features)[0, 1])
        
        # Get feature importance for this prediction
        if hasattr(self.model, 'feature_importances_'):
            importance = dict(zip(self.feature_names, self.model.feature_importances_))
            top_features = sorted(importance.items(), key=lambda x: x[1], reverse=True)[:5]
        else:
            top_features = []
        
        result = {
            'is_sybil': is_sybil,
            'sybil_probability': sybil_probability,
            'risk_score': int(sybil_probability * 100),
            'top_features': top_features,
            'model_name': self.model_name,
            'timestamp': time.time()
        }
        
        return result
    
    def batch_predict(self, features_list: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Make predictions for multiple addresses in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            List of prediction result dictionaries
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        if not features_list:
            return []
        
        # Preprocess features in batch
        scaled_features_batch = self.batch_preprocess_features(features_list)
        
        # Make batch predictions
        is_sybil_batch = self.model.predict(scaled_features_batch)
        sybil_probability_batch = self.model.predict_proba(scaled_features_batch)[:, 1]
        
        # Get feature importance once
        if hasattr(self.model, 'feature_importances_'):
            importance = dict(zip(self.feature_names, self.model.feature_importances_))
            top_features = sorted(importance.items(), key=lambda x: x[1], reverse=True)[:5]
        else:
            top_features = []
        
        # Create result for each prediction
        results = []
        timestamp = time.time()
        
        for i in range(len(features_list)):
            result = {
                'is_sybil': bool(is_sybil_batch[i]),
                'sybil_probability': float(sybil_probability_batch[i]),
                'risk_score': int(sybil_probability_batch[i] * 100),
                'top_features': top_features,
                'model_name': self.model_name,
                'timestamp': timestamp
            }
            results.append(result)
        
        return results


class OptimizedUnsupervisedSybilDetector(SybilDetectionModel):
    """
    Optimized unsupervised anomaly detection model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "optimized_unsupervised_sybil_detector", contamination: float = 0.1):
        """
        Initialize the optimized unsupervised Sybil detector.
        
        Args:
            model_name: Name of the model
            contamination: Expected proportion of Sybil accounts
        """
        super().__init__(model_name)
        self.contamination = contamination
    
    def train(self, X: pd.DataFrame) -> Dict[str, Any]:
        """
        Train the unsupervised model with optimized parameters.
        
        Args:
            X: Feature matrix
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training optimized unsupervised model with {len(X)} samples")
        
        # Store feature names
        self.feature_names = list(X.columns)
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X)
        
        # Create and train model with optimized parameters
        self.model = IsolationForest(
            contamination=self.contamination,
            random_state=random_seed,
            n_estimators=100,
            max_samples='auto',
            max_features=0.8,  # Use 80% of features
            bootstrap=True,
            n_jobs=-1  # Use all available cores
        )
        
        self.model.fit(X_scaled)
        
        # Get anomaly scores
        scores = self.model.decision_function(X_scaled)
        predictions = self.model.predict(X_scaled)
        
        # Convert predictions: -1 for anomalies (Sybil), 1 for normal
        # Convert to 1 for Sybil, 0 for normal to match supervised convention
        predictions = (predictions == -1).astype(int)
        
        results = {
            'anomaly_ratio': np.mean(predictions),
            'mean_score': np.mean(scores),
            'min_score': np.min(scores),
            'max_score': np.max(scores)
        }
        
        logger.info(f"Training complete. Anomaly ratio: {results['anomaly_ratio']:.4f}")
        
        return results
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Predict whether an address is a Sybil using optimized anomaly detection.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features with caching
        scaled_features = self.preprocess_features(features)
        
        # Make prediction
        # -1 for anomalies (Sybil), 1 for normal
        raw_prediction = self.model.predict(scaled_features)[0]
        is_sybil = (raw_prediction == -1)
        
        # Get anomaly score
        # Lower score means more anomalous
        anomaly_score = self.model.decision_function(scaled_features)[0]
        
        # Convert to probability-like score (0 to 1)
        # More negative score means more anomalous, so we invert and normalize
        # Typical range is -0.5 to 0.5, but can vary
        sybil_probability = max(0, min(1, 0.5 - anomaly_score))
        
        result = {
            'is_sybil': bool(is_sybil),
            'sybil_probability': float(sybil_probability),
            'risk_score': int(sybil_probability * 100),
            'anomaly_score': float(anomaly_score),
            'model_name': self.model_name,
            'timestamp': time.time()
        }
        
        return result
    
    def batch_predict(self, features_list: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Make predictions for multiple addresses in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            List of prediction result dictionaries
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        if not features_list:
            return []
        
        # Preprocess features in batch
        scaled_features_batch = self.batch_preprocess_features(features_list)
        
        # Make batch predictions
        raw_predictions = self.model.predict(scaled_features_batch)
        anomaly_scores = self.model.decision_function(scaled_features_batch)
        
        # Create result for each prediction
        results = []
        timestamp = time.time()
        
        for i in range(len(features_list)):
            is_sybil = (raw_predictions[i] == -1)
            anomaly_score = anomaly_scores[i]
            sybil_probability = max(0, min(1, 0.5 - anomaly_score))
            
            result = {
                'is_sybil': bool(is_sybil),
                'sybil_probability': float(sybil_probability),
                'risk_score': int(sybil_probability * 100),
                'anomaly_score': float(anomaly_score),
                'model_name': self.model_name,
                'timestamp': timestamp
            }
            results.append(result)
        
        return results


class OptimizedDeepLearningSybilDetector(SybilDetectionModel):
    """
    Optimized deep learning model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "optimized_deep_learning_sybil_detector"):
        """
        Initialize the optimized deep learning Sybil detector.
        
        Args:
            model_name: Name of the model
        """
        super().__init__(model_name)
    
    def build_model(self, input_dim: int) -> None:
        """
        Build a simplified neural network model.
        
        Args:
            input_dim: Number of input features
        """
        # Simplified model with fewer layers and neurons
        model = Sequential([
            Dense(32, activation='relu', input_shape=(input_dim,)),
            Dropout(0.2),
            Dense(16, activation='relu'),
            Dense(1, activation='sigmoid')
        ])
        
        model.compile(
            optimizer='adam',
            loss='binary_crossentropy',
            metrics=['accuracy', tf.keras.metrics.AUC()]
        )
        
        self.model = model
    
    def train(self, X: pd.DataFrame, y: pd.Series, test_size: float = 0.2, 
              validation_size: float = 0.1, epochs: int = 50, batch_size: int = 64) -> Dict[str, Any]:
        """
        Train the optimized deep learning model.
        
        Args:
            X: Feature matrix
            y: Target labels (0 for legitimate, 1 for Sybil)
            test_size: Proportion of data to use for testing
            validation_size: Proportion of training data to use for validation
            epochs: Number of training epochs (reduced from 100 to 50)
            batch_size: Batch size for training
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training optimized deep learning model with {len(X)} samples")
        
        # Store feature names
        self.feature_names = list(X.columns)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_seed
        )
        
        # Further split training data for validation
        X_train, X_val, y_train, y_val = train_test_split(
            X_train, y_train, test_size=validation_size, random_state=random_seed
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_val_scaled = self.scaler.transform(X_val)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Build simplified model
        self.build_model(X_train_scaled.shape[1])
        
        # Set up callbacks
        callbacks = [
            EarlyStopping(
                monitor='val_loss',
                patience=early_stopping_patience,
                restore_best_weights=True
            ),
            ModelCheckpoint(
                filepath=os.path.join(training_path, 'checkpoints', f"{self.model_name}_best.h5"),
                monitor='val_loss',
                save_best_only=True
            )
        ]
        
        # Train model
        history = self.model.fit(
            X_train_scaled, y_train,
            validation_data=(X_val_scaled, y_val),
            epochs=epochs,
            batch_size=batch_size,
            callbacks=callbacks,
            verbose=1
        )
        
        # Evaluate model
        test_results = self.model.evaluate(X_test_scaled, y_test, verbose=0)
        y_pred_prob = self.model.predict(X_test_scaled, verbose=0)
        y_pred = (y_pred_prob > 0.5).astype(int)
        
        # Calculate metrics
        report = classification_report(y_test, y_pred, output_dict=True)
        conf_matrix = confusion_matrix(y_test, y_pred)
        auc = roc_auc_score(y_test, y_pred_prob)
        
        results = {
            'accuracy': test_results[1],
            'loss': test_results[0],
            'auc': test_results[2],
            'precision': report['1']['precision'],
            'recall': report['1']['recall'],
            'f1_score': report['1']['f1-score'],
            'confusion_matrix': conf_matrix.tolist(),
            'training_history': {
                'loss': history.history['loss'],
                'val_loss': history.history['val_loss'],
                'accuracy': history.history['accuracy'],
                'val_accuracy': history.history['val_accuracy']
            }
        }
        
        logger.info(f"Training complete. Accuracy: {results['accuracy']:.4f}, AUC: {results['auc']:.4f}")
        
        return results
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Predict whether an address is a Sybil using the optimized deep learning model.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features with caching
        scaled_features = self.preprocess_features(features)
        
        # Make prediction
        sybil_probability = float(self.model.predict(scaled_features, verbose=0)[0][0])
        is_sybil = sybil_probability >= 0.5
        
        result = {
            'is_sybil': bool(is_sybil),
            'sybil_probability': sybil_probability,
            'risk_score': int(sybil_probability * 100),
            'model_name': self.model_name,
            'timestamp': time.time()
        }
        
        return result
    
    def batch_predict(self, features_list: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Make predictions for multiple addresses in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            List of prediction result dictionaries
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        if not features_list:
            return []
        
        # Preprocess features in batch
        scaled_features_batch = self.batch_preprocess_features(features_list)
        
        # Make batch predictions
        sybil_probabilities = self.model.predict(scaled_features_batch, verbose=0).flatten()
        
        # Create result for each prediction
        results = []
        timestamp = time.time()
        
        for i in range(len(features_list)):
            sybil_probability = float(sybil_probabilities[i])
            is_sybil = sybil_probability >= 0.5
            
            result = {
                'is_sybil': bool(is_sybil),
                'sybil_probability': sybil_probability,
                'risk_score': int(sybil_probability * 100),
                'model_name': self.model_name,
                'timestamp': timestamp
            }
            results.append(result)
        
        return results


# Model factory for easy model creation
def create_model(model_type: str, **kwargs) -> SybilDetectionModel:
    """
    Factory function to create the appropriate model.
    
    Args:
        model_type: Type of model to create
        **kwargs: Additional arguments for model initialization
        
    Returns:
        Initialized model instance
    """
    if model_type == "supervised":
        return OptimizedSupervisedSybilDetector(**kwargs)
    elif model_type == "unsupervised":
        return OptimizedUnsupervisedSybilDetector(**kwargs)
    elif model_type == "deep_learning":
        return OptimizedDeepLearningSybilDetector(**kwargs)
    else:
        raise ValueError(f"Unknown model type: {model_type}")


# Ensemble model that combines multiple detection models
class SybilDetectionEnsemble:
    """
    Ensemble model that combines predictions from multiple Sybil detection models.
    """
    
    def __init__(self, models: List[SybilDetectionModel], weights: Optional[List[float]] = None):
        """
        Initialize the ensemble.
        
        Args:
            models: List of Sybil detection models
            weights: Optional weights for each model (must sum to 1)
        """
        self.models = models
        
        if weights is None:
            # Equal weights if not specified
            self.weights = [1.0 / len(models)] * len(models)
        else:
            assert len(weights) == len(models), "Number of weights must match number of models"
            assert abs(sum(weights) - 1.0) < 1e-6, "Weights must sum to 1"
            self.weights = weights
        
        self.feature_cache = FeatureCache()
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Make an ensemble prediction.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with ensemble prediction results
        """
        # Check cache first
        cache_key = f"ensemble_{str(sorted(features.items()))}"
        cached_result = self.feature_cache.get(cache_key)
        if cached_result is not None:
            return cached_result
        
        # Get predictions from all models
        predictions = []
        for model in self.models:
            predictions.append(model.predict(features))
        
        # Combine predictions using weights
        weighted_probability = 0.0
        for i, pred in enumerate(predictions):
            weighted_probability += pred['sybil_probability'] * self.weights[i]
        
        is_sybil = weighted_probability >= 0.5
        risk_score = int(weighted_probability * 100)
        
        # Collect model names and their individual predictions
        model_predictions = {}
        for i, pred in enumerate(predictions):
            model_predictions[pred['model_name']] = {
                'is_sybil': pred['is_sybil'],
                'sybil_probability': pred['sybil_probability'],
                'risk_score': pred['risk_score'],
                'weight': self.weights[i]
            }
        
        result = {
            'is_sybil': bool(is_sybil),
            'sybil_probability': float(weighted_probability),
            'risk_score': risk_score,
            'model_predictions': model_predictions,
            'ensemble_size': len(self.models),
            'timestamp': time.time()
        }
        
        # Cache the result
        self.feature_cache.set(cache_key, result)
        
        return result
    
    def batch_predict(self, features_list: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Make ensemble predictions for multiple addresses in batch.
        
        Args:
            features_list: List of feature dictionaries
            
        Returns:
            List of ensemble prediction result dictionaries
        """
        if not features_list:
            return []
        
        # Get batch predictions from all models
        all_model_predictions = []
        for model in self.models:
            all_model_predictions.append(model.batch_predict(features_list))
        
        # Combine predictions for each address
        results = []
        timestamp = time.time()
        
        for i in range(len(features_list)):
            weighted_probability = 0.0
            model_predictions = {}
            
            for j, model_batch_preds in enumerate(all_model_predictions):
                model_pred = model_batch_preds[i]
                weighted_probability += model_pred['sybil_probability'] * self.weights[j]
                
                model_predictions[model_pred['model_name']] = {
                    'is_sybil': model_pred['is_sybil'],
                    'sybil_probability': model_pred['sybil_probability'],
                    'risk_score': model_pred['risk_score'],
                    'weight': self.weights[j]
                }
            
            is_sybil = weighted_probability >= 0.5
            risk_score = int(weighted_probability * 100)
            
            result = {
                'is_sybil': bool(is_sybil),
                'sybil_probability': float(weighted_probability),
                'risk_score': risk_score,
                'model_predictions': model_predictions,
                'ensemble_size': len(self.models),
                'timestamp': timestamp
            }
            
            results.append(result)
        
        return results
