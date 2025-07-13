"""
Comprehensive ML Training Pipeline for AptosSybilShield

This module implements a complete training pipeline for Sybil detection models,
including data preprocessing, model training, evaluation, and deployment.
"""

import os
import logging
import pandas as pd
import numpy as np
import joblib
import json
from datetime import datetime
from typing import Dict, List, Tuple, Any, Optional, Union
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.metrics import (
    classification_report, confusion_matrix, roc_auc_score, 
    precision_recall_curve, roc_curve, f1_score
)
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.feature_selection import SelectKBest, f_classif, RFE
from sklearn.ensemble import RandomForestClassifier
import matplotlib.pyplot as plt
import seaborn as sns

# Import our modules
from config.ml_config import *
from models.improved_feature_extraction import ImprovedOnChainFeatureExtractor, create_synthetic_training_data
from models.optimized_sybil_detection import (
    OptimizedSupervisedSybilDetector,
    OptimizedUnsupervisedSybilDetector,
    OptimizedDeepLearningSybilDetector,
    SybilDetectionEnsemble
)
from data.indexer_integration import AptosIndexerClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("training_pipeline")

class SybilDetectionTrainingPipeline:
    """
    Complete training pipeline for Sybil detection models.
    """
    
    def __init__(self, use_real_data: bool = False):
        """
        Initialize the training pipeline.
        
        Args:
            use_real_data: Whether to use real blockchain data or synthetic data
        """
        self.use_real_data = use_real_data
        self.indexer_client = None
        self.feature_extractor = None
        self.models = {}
        self.evaluation_results = {}
        self.feature_importance = {}
        
        # Initialize components
        if use_real_data:
            self.indexer_client = AptosIndexerClient()
            self.feature_extractor = ImprovedOnChainFeatureExtractor(self.indexer_client)
        else:
            self.feature_extractor = ImprovedOnChainFeatureExtractor()
        
        # Create output directories
        self.results_dir = os.path.join(training_path, "results")
        self.plots_dir = os.path.join(training_path, "plots")
        self.models_dir = os.path.join(training_path, "trained_models")
        
        for directory in [self.results_dir, self.plots_dir, self.models_dir]:
            os.makedirs(directory, exist_ok=True)
    
    def load_or_create_data(self, n_samples: int = 1000, force_recreate: bool = False) -> Tuple[pd.DataFrame, pd.Series]:
        """
        Load existing data or create new training data.
        
        Args:
            n_samples: Number of samples to create if using synthetic data
            force_recreate: Whether to force recreation of synthetic data
            
        Returns:
            Tuple of (features DataFrame, labels Series)
        """
        logger.info("Loading or creating training data")
        
        synthetic_dir = os.path.join(data_path, "synthetic")
        features_path = os.path.join(synthetic_dir, "features.csv")
        labels_path = os.path.join(synthetic_dir, "labels.csv")
        
        # Check if synthetic data exists and we're not forcing recreation
        if not force_recreate and os.path.exists(features_path) and os.path.exists(labels_path):
            logger.info("Loading existing synthetic data")
            X = pd.read_csv(features_path)
            y = pd.read_csv(labels_path)['is_sybil']
            return X, y
        
        if self.use_real_data:
            logger.info("Creating dataset from real blockchain data")
            return self._create_real_data_dataset(n_samples)
        else:
            logger.info(f"Creating synthetic dataset with {n_samples} samples")
            X, y = create_synthetic_training_data(n_samples=n_samples, n_features=50)
            
            # Save synthetic data
            os.makedirs(synthetic_dir, exist_ok=True)
            X.to_csv(features_path, index=False)
            y.to_csv(labels_path, index=False)
            
            return X, y
    
    def _create_real_data_dataset(self, n_samples: int) -> Tuple[pd.DataFrame, pd.Series]:
        """
        Create dataset from real blockchain data.
        
        Args:
            n_samples: Number of samples to collect
            
        Returns:
            Tuple of (features DataFrame, labels Series)
        """
        logger.info("Creating dataset from real blockchain data")
        
        # This would require a list of known addresses and their labels
        # For now, we'll create a placeholder implementation
        
        # In a real implementation, you would:
        # 1. Have a list of known Sybil and legitimate addresses
        # 2. Extract features for each address using the feature extractor
        # 3. Create labels based on ground truth
        
        # Placeholder: create synthetic data but with more realistic patterns
        logger.warning("Real data collection not implemented. Using enhanced synthetic data.")
        return create_synthetic_training_data(n_samples=n_samples, n_features=50)
    
    def preprocess_data(self, X: pd.DataFrame, y: pd.Series, 
                       feature_selection: bool = True, 
                       scaling_method: str = 'standard') -> Tuple[pd.DataFrame, pd.Series, Dict[str, Any]]:
        """
        Preprocess the training data.
        
        Args:
            X: Feature matrix
            y: Target labels
            feature_selection: Whether to perform feature selection
            scaling_method: Scaling method ('standard', 'robust', or 'none')
            
        Returns:
            Tuple of (processed features, labels, preprocessing info)
        """
        logger.info("Preprocessing training data")
        
        preprocessing_info = {
            'original_features': list(X.columns),
            'original_shape': X.shape,
            'feature_selection': feature_selection,
            'scaling_method': scaling_method
        }
        
        # Handle missing values
        X_processed = X.fillna(0)
        
        # Remove constant features
        constant_features = X_processed.columns[X_processed.std() == 0]
        if len(constant_features) > 0:
            logger.info(f"Removing {len(constant_features)} constant features")
            X_processed = X_processed.drop(columns=constant_features)
            preprocessing_info['removed_constant_features'] = list(constant_features)
        
        # Feature selection
        if feature_selection and X_processed.shape[1] > 20:
            logger.info("Performing feature selection")
            
            # Use SelectKBest with f_classif
            k = min(30, X_processed.shape[1])  # Select top 30 features or all if less
            selector = SelectKBest(score_func=f_classif, k=k)
            X_selected = selector.fit_transform(X_processed, y)
            
            # Get selected feature names
            selected_features = X_processed.columns[selector.get_support()].tolist()
            X_processed = pd.DataFrame(X_selected, columns=selected_features, index=X_processed.index)
            
            preprocessing_info['selected_features'] = selected_features
            preprocessing_info['feature_scores'] = dict(zip(
                X_processed.columns, 
                selector.scores_[selector.get_support()]
            ))
        
        # Scaling
        scaler = None
        if scaling_method == 'standard':
            scaler = StandardScaler()
            X_scaled = scaler.fit_transform(X_processed)
            X_processed = pd.DataFrame(X_scaled, columns=X_processed.columns, index=X_processed.index)
        elif scaling_method == 'robust':
            scaler = RobustScaler()
            X_scaled = scaler.fit_transform(X_processed)
            X_processed = pd.DataFrame(X_scaled, columns=X_processed.columns, index=X_processed.index)
        
        preprocessing_info['scaler'] = scaler
        preprocessing_info['final_features'] = list(X_processed.columns)
        preprocessing_info['final_shape'] = X_processed.shape
        
        logger.info(f"Preprocessing complete. Shape: {X_processed.shape}")
        
        return X_processed, y, preprocessing_info
    
    def train_models(self, X: pd.DataFrame, y: pd.Series, 
                    model_types: List[str] = None) -> Dict[str, Any]:
        """
        Train multiple Sybil detection models.
        
        Args:
            X: Feature matrix
            y: Target labels
            model_types: List of model types to train
            
        Returns:
            Dictionary with training results
        """
        if model_types is None:
            model_types = ['supervised', 'unsupervised', 'deep_learning']
        
        logger.info(f"Training models: {model_types}")
        
        training_results = {}
        
        # Split data for training and testing
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=random_seed, stratify=y
        )
        
        # Train each model type
        for model_type in model_types:
            logger.info(f"Training {model_type} model")
            
            try:
                if model_type == 'supervised':
                    model = OptimizedSupervisedSybilDetector()
                    results = model.train(X_train, y_train)
                    
                elif model_type == 'unsupervised':
                    model = OptimizedUnsupervisedSybilDetector()
                    results = model.train(X_train)  # Unsupervised doesn't use labels
                    
                elif model_type == 'deep_learning':
                    model = OptimizedDeepLearningSybilDetector()
                    results = model.train(X_train, y_train, epochs=50)
                
                # Evaluate on test set
                test_results = self._evaluate_model(model, X_test, y_test)
                results.update(test_results)
                
                # Store model and results
                self.models[model_type] = model
                training_results[model_type] = results
                
                # Save model
                model_path = model.save_model(self.models_dir)
                results['model_path'] = model_path
                
                logger.info(f"{model_type} model training complete")
                
            except Exception as e:
                logger.error(f"Error training {model_type} model: {e}")
                training_results[model_type] = {'error': str(e)}
        
        # Create ensemble if multiple models were trained successfully
        successful_models = [name for name, results in training_results.items() 
                           if 'error' not in results]
        
        if len(successful_models) > 1:
            logger.info("Creating ensemble model")
            try:
                ensemble_models = [self.models[name] for name in successful_models]
                ensemble = SybilDetectionEnsemble(ensemble_models)
                
                # Evaluate ensemble
                ensemble_results = self._evaluate_ensemble(ensemble, X_test, y_test)
                
                self.models['ensemble'] = ensemble
                training_results['ensemble'] = ensemble_results
                
                logger.info("Ensemble model created successfully")
                
            except Exception as e:
                logger.error(f"Error creating ensemble: {e}")
                training_results['ensemble'] = {'error': str(e)}
        
        self.evaluation_results = training_results
        return training_results
    
    def _evaluate_model(self, model, X_test: pd.DataFrame, y_test: pd.Series) -> Dict[str, Any]:
        """
        Evaluate a single model on test data.
        
        Args:
            model: Trained model
            X_test: Test features
            y_test: Test labels
            
        Returns:
            Dictionary with evaluation results
        """
        logger.info(f"Evaluating {model.model_name}")
        
        # Make predictions
        predictions = []
        probabilities = []
        
        for idx, row in X_test.iterrows():
            features = row.to_dict()
            result = model.predict(features)
            predictions.append(result['is_sybil'])
            probabilities.append(result['sybil_probability'])
        
        predictions = np.array(predictions)
        probabilities = np.array(probabilities)
        
        # Calculate metrics
        accuracy = np.mean(predictions == y_test)
        f1 = f1_score(y_test, predictions)
        
        try:
            auc = roc_auc_score(y_test, probabilities)
        except:
            auc = 0.0
        
        # Classification report
        report = classification_report(y_test, predictions, output_dict=True)
        conf_matrix = confusion_matrix(y_test, predictions)
        
        results = {
            'test_accuracy': accuracy,
            'test_f1_score': f1,
            'test_auc': auc,
            'test_precision': report['1']['precision'] if '1' in report else 0.0,
            'test_recall': report['1']['recall'] if '1' in report else 0.0,
            'confusion_matrix': conf_matrix.tolist(),
            'classification_report': report
        }
        
        return results
    
    def _evaluate_ensemble(self, ensemble, X_test: pd.DataFrame, y_test: pd.Series) -> Dict[str, Any]:
        """
        Evaluate ensemble model on test data.
        
        Args:
            ensemble: Ensemble model
            X_test: Test features
            y_test: Test labels
            
        Returns:
            Dictionary with evaluation results
        """
        logger.info("Evaluating ensemble model")
        
        # Make predictions
        predictions = []
        probabilities = []
        
        for idx, row in X_test.iterrows():
            features = row.to_dict()
            result = ensemble.predict(features)
            predictions.append(result['is_sybil'])
            probabilities.append(result['sybil_probability'])
        
        predictions = np.array(predictions)
        probabilities = np.array(probabilities)
        
        # Calculate metrics
        accuracy = np.mean(predictions == y_test)
        f1 = f1_score(y_test, predictions)
        auc = roc_auc_score(y_test, probabilities)
        
        # Classification report
        report = classification_report(y_test, predictions, output_dict=True)
        conf_matrix = confusion_matrix(y_test, predictions)
        
        results = {
            'test_accuracy': accuracy,
            'test_f1_score': f1,
            'test_auc': auc,
            'test_precision': report['1']['precision'] if '1' in report else 0.0,
            'test_recall': report['1']['recall'] if '1' in report else 0.0,
            'confusion_matrix': conf_matrix.tolist(),
            'classification_report': report,
            'ensemble_size': ensemble.ensemble_size
        }
        
        return results
    
    def create_visualizations(self, X: pd.DataFrame, y: pd.Series, 
                            preprocessing_info: Dict[str, Any]) -> None:
        """
        Create visualizations for the training results.
        
        Args:
            X: Feature matrix
            y: Target labels
            preprocessing_info: Preprocessing information
        """
        logger.info("Creating visualizations")
        
        # Set up matplotlib
        plt.style.use('default')
        
        # 1. Feature importance plot (if available)
        if 'supervised' in self.models:
            model = self.models['supervised']
            if hasattr(model.model, 'feature_importances_'):
                self._plot_feature_importance(model, X.columns)
        
        # 2. Model comparison plot
        self._plot_model_comparison()
        
        # 3. Confusion matrices
        self._plot_confusion_matrices()
        
        # 4. ROC curves (if possible)
        self._plot_roc_curves(X, y)
        
        # 5. Data distribution plots
        self._plot_data_distribution(X, y)
        
        logger.info("Visualizations created")
    
    def _plot_feature_importance(self, model, feature_names: List[str]) -> None:
        """Plot feature importance for supervised model."""
        if not hasattr(model.model, 'feature_importances_'):
            return
        
        importance = model.model.feature_importances_
        indices = np.argsort(importance)[::-1][:20]  # Top 20 features
        
        plt.figure(figsize=(12, 8))
        plt.title("Top 20 Feature Importance")
        plt.bar(range(len(indices)), importance[indices])
        plt.xticks(range(len(indices)), [feature_names[i] for i in indices], rotation=45)
        plt.tight_layout()
        plt.savefig(os.path.join(self.plots_dir, "feature_importance.png"))
        plt.close()
    
    def _plot_model_comparison(self) -> None:
        """Plot comparison of model performance."""
        if not self.evaluation_results:
            return
        
        metrics = ['test_accuracy', 'test_f1_score', 'test_auc']
        models = []
        values = {metric: [] for metric in metrics}
        
        for model_name, results in self.evaluation_results.items():
            if 'error' not in results:
                models.append(model_name)
                for metric in metrics:
                    values[metric].append(results.get(metric, 0))
        
        if not models:
            return
        
        x = np.arange(len(models))
        width = 0.25
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        for i, metric in enumerate(metrics):
            ax.bar(x + i * width, values[metric], width, label=metric.replace('test_', '').upper())
        
        ax.set_xlabel('Models')
        ax.set_ylabel('Score')
        ax.set_title('Model Performance Comparison')
        ax.set_xticks(x + width)
        ax.set_xticklabels(models)
        ax.legend()
        ax.set_ylim(0, 1)
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.plots_dir, "model_comparison.png"))
        plt.close()
    
    def _plot_confusion_matrices(self) -> None:
        """Plot confusion matrices for all models."""
        n_models = len([name for name, results in self.evaluation_results.items() 
                       if 'error' not in results and 'confusion_matrix' in results])
        
        if n_models == 0:
            return
        
        fig, axes = plt.subplots(1, n_models, figsize=(5 * n_models, 4))
        if n_models == 1:
            axes = [axes]
        
        i = 0
        for model_name, results in self.evaluation_results.items():
            if 'error' not in results and 'confusion_matrix' in results:
                cm = np.array(results['confusion_matrix'])
                
                sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[i])
                axes[i].set_title(f'{model_name} Confusion Matrix')
                axes[i].set_xlabel('Predicted')
                axes[i].set_ylabel('Actual')
                
                i += 1
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.plots_dir, "confusion_matrices.png"))
        plt.close()
    
    def _plot_roc_curves(self, X: pd.DataFrame, y: pd.Series) -> None:
        """Plot ROC curves for models that support probability prediction."""
        plt.figure(figsize=(10, 8))
        
        # Split data for consistent evaluation
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=random_seed, stratify=y
        )
        
        for model_name, model in self.models.items():
            if model_name == 'ensemble':
                continue  # Skip ensemble for now
            
            try:
                # Get probabilities
                probabilities = []
                for idx, row in X_test.iterrows():
                    features = row.to_dict()
                    result = model.predict(features)
                    probabilities.append(result['sybil_probability'])
                
                probabilities = np.array(probabilities)
                
                # Calculate ROC curve
                fpr, tpr, _ = roc_curve(y_test, probabilities)
                auc = roc_auc_score(y_test, probabilities)
                
                plt.plot(fpr, tpr, label=f'{model_name} (AUC = {auc:.3f})')
                
            except Exception as e:
                logger.warning(f"Could not plot ROC curve for {model_name}: {e}")
        
        plt.plot([0, 1], [0, 1], 'k--', label='Random')
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title('ROC Curves')
        plt.legend()
        plt.grid(True)
        plt.savefig(os.path.join(self.plots_dir, "roc_curves.png"))
        plt.close()
    
    def _plot_data_distribution(self, X: pd.DataFrame, y: pd.Series) -> None:
        """Plot data distribution."""
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        
        # Class distribution
        axes[0, 0].bar(['Legitimate', 'Sybil'], [np.sum(y == 0), np.sum(y == 1)])
        axes[0, 0].set_title('Class Distribution')
        axes[0, 0].set_ylabel('Count')
        
        # Feature correlation heatmap (top 10 features)
        top_features = X.columns[:10]
        corr_matrix = X[top_features].corr()
        sns.heatmap(corr_matrix, annot=True, cmap='coolwarm', center=0, ax=axes[0, 1])
        axes[0, 1].set_title('Feature Correlation (Top 10)')
        
        # Feature distribution for first feature
        if len(X.columns) > 0:
            feature = X.columns[0]
            axes[1, 0].hist(X[X.index[y == 0]][feature], alpha=0.7, label='Legitimate', bins=30)
            axes[1, 0].hist(X[X.index[y == 1]][feature], alpha=0.7, label='Sybil', bins=30)
            axes[1, 0].set_title(f'Distribution of {feature}')
            axes[1, 0].legend()
        
        # Feature statistics
        stats_text = f"Total samples: {len(X)}\\n"
        stats_text += f"Features: {len(X.columns)}\\n"
        stats_text += f"Legitimate: {np.sum(y == 0)} ({np.mean(y == 0):.1%})\\n"
        stats_text += f"Sybil: {np.sum(y == 1)} ({np.mean(y == 1):.1%})"
        
        axes[1, 1].text(0.1, 0.5, stats_text, fontsize=12, verticalalignment='center')
        axes[1, 1].set_title('Dataset Statistics')
        axes[1, 1].axis('off')
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.plots_dir, "data_distribution.png"))
        plt.close()
    
    def save_results(self, training_results: Dict[str, Any], 
                    preprocessing_info: Dict[str, Any]) -> str:
        """
        Save training results to file.
        
        Args:
            training_results: Results from model training
            preprocessing_info: Information about data preprocessing
            
        Returns:
            Path to saved results file
        """
        logger.info("Saving training results")
        
        # Prepare results for JSON serialization
        serializable_results = {}
        for model_name, results in training_results.items():
            serializable_results[model_name] = {}
            for key, value in results.items():
                if isinstance(value, (np.ndarray, np.integer, np.floating)):
                    serializable_results[model_name][key] = value.tolist() if hasattr(value, 'tolist') else float(value)
                else:
                    serializable_results[model_name][key] = value
        
        # Create comprehensive results
        full_results = {
            'timestamp': datetime.now().isoformat(),
            'preprocessing_info': preprocessing_info,
            'training_results': serializable_results,
            'config': {
                'use_real_data': self.use_real_data,
                'random_seed': random_seed,
                'model_config': MODEL_CONFIG
            }
        }
        
        # Save to JSON file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        results_file = os.path.join(self.results_dir, f"training_results_{timestamp}.json")
        
        with open(results_file, 'w') as f:
            json.dump(full_results, f, indent=2)
        
        logger.info(f"Results saved to {results_file}")
        return results_file
    
    def run_complete_pipeline(self, n_samples: int = 1000, 
                            model_types: List[str] = None) -> Dict[str, Any]:
        """
        Run the complete training pipeline.
        
        Args:
            n_samples: Number of samples for synthetic data
            model_types: List of model types to train
            
        Returns:
            Dictionary with complete results
        """
        logger.info("Starting complete training pipeline")
        
        try:
            # 1. Load or create data
            X, y = self.load_or_create_data(n_samples=n_samples)
            logger.info(f"Data loaded: {X.shape[0]} samples, {X.shape[1]} features")
            
            # 2. Preprocess data
            X_processed, y_processed, preprocessing_info = self.preprocess_data(X, y)
            logger.info(f"Data preprocessed: {X_processed.shape[0]} samples, {X_processed.shape[1]} features")
            
            # 3. Train models
            training_results = self.train_models(X_processed, y_processed, model_types)
            logger.info(f"Models trained: {list(training_results.keys())}")
            
            # 4. Create visualizations
            self.create_visualizations(X_processed, y_processed, preprocessing_info)
            logger.info("Visualizations created")
            
            # 5. Save results
            results_file = self.save_results(training_results, preprocessing_info)
            logger.info(f"Results saved to {results_file}")
            
            # 6. Create summary
            summary = self._create_summary(training_results)
            logger.info("Training pipeline completed successfully")
            
            return {
                'success': True,
                'summary': summary,
                'results_file': results_file,
                'models_trained': list(self.models.keys()),
                'data_shape': X_processed.shape,
                'preprocessing_info': preprocessing_info
            }
            
        except Exception as e:
            logger.error(f"Error in training pipeline: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def _create_summary(self, training_results: Dict[str, Any]) -> Dict[str, Any]:
        """Create a summary of training results."""
        summary = {
            'models_trained': len(training_results),
            'successful_models': len([r for r in training_results.values() if 'error' not in r]),
            'best_model': None,
            'best_accuracy': 0.0
        }
        
        # Find best model by accuracy
        for model_name, results in training_results.items():
            if 'error' not in results and 'test_accuracy' in results:
                if results['test_accuracy'] > summary['best_accuracy']:
                    summary['best_accuracy'] = results['test_accuracy']
                    summary['best_model'] = model_name
        
        return summary


if __name__ == "__main__":
    # Example usage
    logger.info("Starting SybilShield ML Training Pipeline")
    
    # Create pipeline
    pipeline = SybilDetectionTrainingPipeline(use_real_data=False)
    
    # Run complete pipeline
    results = pipeline.run_complete_pipeline(
        n_samples=1000,
        model_types=['supervised', 'unsupervised']
    )
    
    if results['success']:
        logger.info("Training pipeline completed successfully!")
        logger.info(f"Best model: {results['summary']['best_model']} "
                   f"(accuracy: {results['summary']['best_accuracy']:.3f})")
    else:
        logger.error(f"Training pipeline failed: {results['error']}")

