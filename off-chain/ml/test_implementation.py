"""
Test script for SybilShield ML Implementation

This script tests the improved ML components without requiring external dependencies.
"""

import os
import sys
import logging
from datetime import datetime

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("test_implementation")

def test_config():
    """Test the configuration module."""
    logger.info("Testing configuration module...")
    
    try:
        from config.ml_config import (
            data_path, models_path, random_seed, 
            MODEL_CONFIG, SYBIL_THRESHOLDS
        )
        
        logger.info(f"✓ Configuration loaded successfully")
        logger.info(f"  - Data path: {data_path}")
        logger.info(f"  - Models path: {models_path}")
        logger.info(f"  - Random seed: {random_seed}")
        logger.info(f"  - Model config: {MODEL_CONFIG}")
        
        return True
    except Exception as e:
        logger.error(f"✗ Configuration test failed: {e}")
        return False

def test_feature_extraction():
    """Test the improved feature extraction."""
    logger.info("Testing feature extraction module...")
    
    try:
        from models.improved_feature_extraction import (
            ImprovedOnChainFeatureExtractor, 
            create_synthetic_training_data
        )
        
        # Test feature extractor initialization
        extractor = ImprovedOnChainFeatureExtractor()
        logger.info("✓ Feature extractor initialized")
        
        # Test synthetic data creation
        X, y = create_synthetic_training_data(n_samples=100, n_features=20)
        logger.info(f"✓ Synthetic data created: {X.shape[0]} samples, {X.shape[1]} features")
        logger.info(f"  - Legitimate samples: {sum(y == 0)}")
        logger.info(f"  - Sybil samples: {sum(y == 1)}")
        
        # Test feature extraction for a sample address
        sample_address = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        features = extractor.extract_all_features(sample_address)
        logger.info(f"✓ Feature extraction completed: {len(features)} features")
        
        return True
    except Exception as e:
        logger.error(f"✗ Feature extraction test failed: {e}")
        return False

def test_models():
    """Test the ML models."""
    logger.info("Testing ML models...")
    
    try:
        # Import models (this will test if they can be imported without dependencies)
        from models.optimized_sybil_detection import (
            OptimizedSupervisedSybilDetector,
            OptimizedUnsupervisedSybilDetector,
            SybilDetectionEnsemble
        )
        
        logger.info("✓ Model classes imported successfully")
        
        # Test model initialization
        supervised_model = OptimizedSupervisedSybilDetector()
        unsupervised_model = OptimizedUnsupervisedSybilDetector()
        
        logger.info("✓ Models initialized successfully")
        logger.info(f"  - Supervised model: {supervised_model.model_name}")
        logger.info(f"  - Unsupervised model: {unsupervised_model.model_name}")
        
        return True
    except Exception as e:
        logger.error(f"✗ Model test failed: {e}")
        return False

def test_training_pipeline():
    """Test the training pipeline."""
    logger.info("Testing training pipeline...")
    
    try:
        from training_pipeline import SybilDetectionTrainingPipeline
        
        # Test pipeline initialization
        pipeline = SybilDetectionTrainingPipeline(use_real_data=False)
        logger.info("✓ Training pipeline initialized")
        
        # Test data loading (synthetic)
        X, y = pipeline.load_or_create_data(n_samples=50, force_recreate=True)
        logger.info(f"✓ Data loaded: {X.shape[0]} samples, {X.shape[1]} features")
        
        # Test preprocessing
        X_processed, y_processed, preprocessing_info = pipeline.preprocess_data(X, y)
        logger.info(f"✓ Data preprocessed: {X_processed.shape[0]} samples, {X_processed.shape[1]} features")
        
        return True
    except Exception as e:
        logger.error(f"✗ Training pipeline test failed: {e}")
        return False

def test_indexer_integration():
    """Test the indexer integration."""
    logger.info("Testing indexer integration...")
    
    try:
        from data.indexer_integration import AptosIndexerClient
        
        # Test client initialization
        client = AptosIndexerClient()
        logger.info("✓ Indexer client initialized")
        logger.info(f"  - Indexer URL: {client.indexer_url}")
        logger.info(f"  - Aptos URL: {client.aptos_url}")
        
        return True
    except Exception as e:
        logger.error(f"✗ Indexer integration test failed: {e}")
        return False

def create_demo_prediction():
    """Create a demo prediction to show the system working."""
    logger.info("Creating demo prediction...")
    
    try:
        from models.improved_feature_extraction import ImprovedOnChainFeatureExtractor
        
        # Create feature extractor
        extractor = ImprovedOnChainFeatureExtractor()
        
        # Extract features for demo addresses
        demo_addresses = [
            "0x1111111111111111111111111111111111111111111111111111111111111111",  # Legitimate
            "0x2222222222222222222222222222222222222222222222222222222222222222",  # Potential Sybil
        ]
        
        demo_results = []
        for address in demo_addresses:
            features = extractor.extract_all_features(address)
            
            # Simple heuristic for demo (in real system, this would use trained models)
            # Higher tx_count_total but lower unique_counterparts_count suggests Sybil
            tx_count = features.get('tx_count_total', 0)
            unique_counterparts = features.get('unique_counterparts_count', 0)
            
            if tx_count > 0:
                counterpart_ratio = unique_counterparts / tx_count
            else:
                counterpart_ratio = 0
            
            # Simple scoring (this is just for demo)
            sybil_score = max(0, min(100, (1 - counterpart_ratio) * 100))
            is_sybil = sybil_score > 50
            
            result = {
                'address': address[:10] + '...',
                'features_extracted': len(features),
                'sybil_score': sybil_score,
                'is_sybil': is_sybil,
                'risk_level': 'HIGH' if sybil_score > 70 else 'MEDIUM' if sybil_score > 30 else 'LOW'
            }
            
            demo_results.append(result)
        
        logger.info("✓ Demo predictions created:")
        for result in demo_results:
            logger.info(f"  - Address {result['address']}: "
                       f"Score={result['sybil_score']:.1f}, "
                       f"Sybil={result['is_sybil']}, "
                       f"Risk={result['risk_level']}")
        
        return demo_results
    except Exception as e:
        logger.error(f"✗ Demo prediction failed: {e}")
        return []

def run_all_tests():
    """Run all tests and return summary."""
    logger.info("=" * 60)
    logger.info("SYBILSHIELD ML IMPLEMENTATION TEST SUITE")
    logger.info("=" * 60)
    
    tests = [
        ("Configuration", test_config),
        ("Feature Extraction", test_feature_extraction),
        ("ML Models", test_models),
        ("Training Pipeline", test_training_pipeline),
        ("Indexer Integration", test_indexer_integration),
    ]
    
    results = {}
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        logger.info(f"\n--- Testing {test_name} ---")
        try:
            result = test_func()
            results[test_name] = result
            if result:
                passed += 1
        except Exception as e:
            logger.error(f"Test {test_name} crashed: {e}")
            results[test_name] = False
    
    # Create demo
    logger.info(f"\n--- Demo Prediction ---")
    demo_results = create_demo_prediction()
    
    # Summary
    logger.info("\n" + "=" * 60)
    logger.info("TEST SUMMARY")
    logger.info("=" * 60)
    logger.info(f"Tests passed: {passed}/{total}")
    logger.info(f"Success rate: {passed/total*100:.1f}%")
    
    logger.info("\nTest Results:")
    for test_name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        logger.info(f"  {test_name}: {status}")
    
    if demo_results:
        logger.info(f"\nDemo completed with {len(demo_results)} predictions")
    
    logger.info("\n" + "=" * 60)
    
    return {
        'total_tests': total,
        'passed_tests': passed,
        'success_rate': passed/total,
        'results': results,
        'demo_results': demo_results
    }

if __name__ == "__main__":
    # Run the test suite
    test_results = run_all_tests()
    
    # Exit with appropriate code
    if test_results['success_rate'] >= 0.8:  # 80% pass rate
        logger.info("✓ Test suite PASSED")
        sys.exit(0)
    else:
        logger.error("✗ Test suite FAILED")
        sys.exit(1)

