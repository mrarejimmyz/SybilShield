"""
Sybil detection models for AptosSybilShield

This module implements various machine learning models for Sybil detection,
including supervised classification and unsupervised anomaly detection approaches.
"""

import os
import logging
import numpy as np
import pandas as pd
import joblib
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

# Import configuration
from config.ml_config import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("sybil_detection_models")

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
        Preprocess features for model input.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Preprocessed feature array
        """
        # Ensure all expected features are present
        if self.feature_names is not None:
            for feature in self.feature_names:
                if feature not in features:
                    features[feature] = 0.0
            
            # Keep only the features used by the model
            features = {k: features[k] for k in self.feature_names if k in features}
        
        # Convert to array
        feature_array = np.array([list(features.values())])
        
        # Scale features
        scaled_features = self.scaler.transform(feature_array)
        
        return scaled_features
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Make a prediction for the given features.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        raise NotImplementedError("Subclasses must implement predict method")


class SupervisedSybilDetector(SybilDetectionModel):
    """
    Supervised learning model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "supervised_sybil_detector"):
        """
        Initialize the supervised Sybil detector.
        
        Args:
            model_name: Name of the model
        """
        super().__init__(model_name)
        
    def train(self, X: pd.DataFrame, y: pd.Series, test_size: float = 0.2) -> Dict[str, Any]:
        """
        Train the supervised model.
        
        Args:
            X: Feature matrix
            y: Target labels (0 for legitimate, 1 for Sybil)
            test_size: Proportion of data to use for testing
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training supervised model with {len(X)} samples")
        
        # Store feature names
        self.feature_names = list(X.columns)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_seed
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Create and train model
        self.model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=random_seed
        )
        
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate model
        y_pred = self.model.predict(X_test_scaled)
        y_prob = self.model.predict_proba(X_test_scaled)[:, 1]
        
        # Calculate metrics
        report = classification_report(y_test, y_pred, output_dict=True)
        conf_matrix = confusion_matrix(y_test, y_pred)
        auc = roc_auc_score(y_test, y_prob)
        
        results = {
            'accuracy': report['accuracy'],
            'precision': report['1']['precision'],
            'recall': report['1']['recall'],
            'f1_score': report['1']['f1-score'],
            'auc': auc,
            'confusion_matrix': conf_matrix.tolist(),
            'feature_importance': dict(zip(self.feature_names, self.model.feature_importances_))
        }
        
        logger.info(f"Training complete. Accuracy: {results['accuracy']:.4f}, AUC: {results['auc']:.4f}")
        
        return results
    
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Predict whether an address is a Sybil.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features
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
            'model_name': self.model_name
        }
        
        return result


class UnsupervisedSybilDetector(SybilDetectionModel):
    """
    Unsupervised anomaly detection model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "unsupervised_sybil_detector", contamination: float = 0.1):
        """
        Initialize the unsupervised Sybil detector.
        
        Args:
            model_name: Name of the model
            contamination: Expected proportion of Sybil accounts
        """
        super().__init__(model_name)
        self.contamination = contamination
        
    def train(self, X: pd.DataFrame) -> Dict[str, Any]:
        """
        Train the unsupervised model.
        
        Args:
            X: Feature matrix
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training unsupervised model with {len(X)} samples")
        
        # Store feature names
        self.feature_names = list(X.columns)
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X)
        
        # Create and train model
        self.model = IsolationForest(
            contamination=self.contamination,
            random_state=random_seed,
            n_estimators=100
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
        Predict whether an address is a Sybil using anomaly detection.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features
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
            'model_name': self.model_name
        }
        
        return result


class DeepLearningSybilDetector(SybilDetectionModel):
    """
    Deep learning model for Sybil detection.
    """
    
    def __init__(self, model_name: str = "deep_learning_sybil_detector"):
        """
        Initialize the deep learning Sybil detector.
        
        Args:
            model_name: Name of the model
        """
        super().__init__(model_name)
        
    def build_model(self, input_dim: int) -> None:
        """
        Build the neural network model.
        
        Args:
            input_dim: Number of input features
        """
        model = Sequential([
            Dense(64, activation='relu', input_shape=(input_dim,)),
            Dropout(0.3),
            Dense(32, activation='relu'),
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
              validation_size: float = 0.1, epochs: int = 100, batch_size: int = 64) -> Dict[str, Any]:
        """
        Train the deep learning model.
        
        Args:
            X: Feature matrix
            y: Target labels (0 for legitimate, 1 for Sybil)
            test_size: Proportion of data to use for testing
            validation_size: Proportion of training data to use for validation
            epochs: Number of training epochs
            batch_size: Batch size for training
            
        Returns:
            Dictionary with training results
        """
        logger.info(f"Training deep learning model with {len(X)} samples")
        
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
        
        # Build model
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
        Predict whether an address is a Sybil.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if self.model is None:
            raise ValueError("Model not trained or loaded")
        
        # Preprocess features
        scaled_features = self.preprocess_features(features)
        
        # Make prediction
        sybil_probability = float(self.model.predict(scaled_features, verbose=0)[0, 0])
        is_sybil = sybil_probability > 0.5
        
        result = {
            'is_sybil': bool(is_sybil),
            'sybil_probability': sybil_probability,
            'risk_score': int(sybil_probability * 100),
            'model_name': self.model_name
        }
        
        return result


class EnsembleSybilDetector(SybilDetectionModel):
    """
    Ensemble model combining multiple Sybil detection models.
    """
    
    def __init__(self, model_name: str = "ensemble_sybil_detector"):
        """
        Initialize the ensemble Sybil detector.
        
        Args:
            model_name: Name of the model
        """
        super().__init__(model_name)
        self.models = []
        self.weights = []
        
    def add_model(self, model: SybilDetectionModel, weight: float = 1.0) -> None:
        """
        Add a model to the ensemble.
        
        Args:
            model: Sybil detection model
            weight: Weight for this model in the ensemble
        """
        self.models.append(model)
        self.weights.append(weight)
        logger.info(f"Added model {model.model_name} to ensemble with weight {weight}")
        
    def predict(self, features: Dict[str, float]) -> Dict[str, Any]:
        """
        Make an ensemble prediction.
        
        Args:
            features: Dictionary of features
            
        Returns:
            Dictionary with prediction results
        """
        if not self.models:
            raise ValueError("No models in ensemble")
        
        # Get predictions from all models
        predictions = []
        for model in self.models:
            try:
                pred = model.predict(features)
                predictions.append(pred)
            except Exception as e:
                logger.error(f"Error getting prediction from {model.model_name}: {e}")
        
        if not predictions:
            raise ValueError("No valid predictions from ensemble models")
        
        # Calculate weighted average of probabilities
        total_weight = sum(self.weights[:len(predictions)])
        if total_weight == 0:
            total_weight = len(predictions)  # Equal weights if sum is 0
            
        weighted_prob = sum(
            pred['sybil_probability'] * self.weights[i] 
            for i, pred in enumerate(predictions)
        ) / total_weight
        
        # Determine if Sybil based on threshold
        is_sybil = weighted_prob > 0.5
        
        # Collect model-specific results
        model_results = {
            model.model_name: {
                'sybil_probability': pred['sybil_probability'],
                'is_sybil': pred['is_sybil']
            }
            for model, pred in zip(self.models, predictions)
        }
        
        result = {
            'is_sybil': bool(is_sybil),
            'sybil_probability': float(weighted_prob),
            'risk_score': int(weighted_prob * 100),
            'model_results': model_results,
            'model_name': self.model_name
        }
        
        return result
    
    def save_model(self, output_dir: str = None) -> str:
        """
        Save the ensemble model to disk.
        
        Args:
            output_dir: Directory to save the model
            
        Returns:
            Path to the saved model directory
        """
        if output_dir is None:
            output_dir = os.path.join(model_path, self.model_name)
            
        os.makedirs(output_dir, exist_ok=True)
        
        # Save each model in the ensemble
        model_paths = []
        for i, model in enumerate(self.models):
            model_filename = f"{model.model_name}.joblib"
            model_path = os.path.join(output_dir, model_filename)
            model.save_model(output_dir)
            model_paths.append(model_filename)
        
        # Save ensemble configuration
        ensemble_config = {
            'model_name': self.model_name,
            'models': model_paths,
            'weights': self.weights
        }
        
        config_path = os.path.join(output_dir, "ensemble_config.joblib")
        joblib.dump(ensemble_config, config_path)
        
        logger.info(f"Ensemble model saved to {output_dir}")
        
        return output_dir
    
    def load_model(self, model_dir: str) -> None:
        """
        Load the ensemble model from disk.
        
        Args:
            model_dir: Directory containing the saved ensemble
        """
        # Load ensemble configuration
        config_path = os.path.join(model_dir, "ensemble_config.joblib")
        ensemble_config = joblib.load(config_path)
        
        self.model_name = ensemble_config['model_name']
        self.weights = ensemble_config['weights']
        
        # Load each model in the ensemble
        self.models = []
        for model_filename in ensemble_config['models']:
            model_path = os.path.join(model_dir, model_filename)
            
            # Determine model type from filename
            if 'supervised' in model_filename:
                model = SupervisedSybilDetector()
            elif 'unsupervised' in model_filename:
                model = UnsupervisedSybilDetector()
            elif 'deep_learning' in model_filename:
                model = DeepLearningSybilDetector()
            else:
                model = SybilDetectionModel()
                
            model.load_model(model_path)
            self.models.append(model)
        
        logger.info(f"Ensemble model loaded from {model_dir} with {len(self.models)} models")


if __name__ == "__main__":
    # Example usage
    # This would be replaced with actual data in a real implementation
    
    # Create synthetic data for demonstration
    np.random.seed(random_seed)
    n_samples = 1000
    n_features = 20
    
    # Generate synthetic features
    X = pd.DataFrame(
        np.random.randn(n_samples, n_features),
        columns=[f'feature_{i}' for i in range(n_features)]
    )
    
    # Generate synthetic labels (80% legitimate, 20% Sybil)
    y = pd.Series(np.random.binomial(1, 0.2, n_samples))
    
    # Train supervised model
    supervised_model = SupervisedSybilDetector()
    supervised_results = supervised_model.train(X, y)
    supervised_model.save_model()
    
    # Train unsupervised model
    unsupervised_model = UnsupervisedSybilDetector(contamination=0.2)
    unsupervised_results = unsupervised_model.train(X)
    unsupervised_model.save_model()
    
    # Create ensemble
    ensemble = EnsembleSybilDetector()
    ensemble.add_model(supervised_model, weight=0.7)
    ensemble.add_model(unsupervised_model, weight=0.3)
    
    # Make a prediction
    sample_features = {f'feature_{i}': np.random.randn() for i in range(n_features)}
    ensemble_prediction = ensemble.predict(sample_features)
    
    print(f"Ensemble prediction: {ensemble_prediction['is_sybil']}")
    print(f"Sybil probability: {ensemble_prediction['sybil_probability']:.4f}")
    print(f"Risk score: {ensemble_prediction['risk_score']}")
    
    # Save ensemble
    ensemble.save_model()
