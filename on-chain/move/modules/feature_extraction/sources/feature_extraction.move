module aptos_sybil_shield::feature_extraction {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_FEATURE: u64 = 4;
    
    /// Feature types
    const FEATURE_TYPE_TRANSACTION: u8 = 1;
    const FEATURE_TYPE_CLUSTERING: u8 = 2;
    const FEATURE_TYPE_TEMPORAL: u8 = 3;
    const FEATURE_TYPE_GAS_USAGE: u8 = 4;
    
    /// Feature data for an address
    struct FeatureData has key {
        address: address,
        features: vector<Feature>,
        last_updated: u64,
    }
    
    /// Individual feature
    struct Feature has store, drop, copy {
        feature_type: u8,
        name: String,
        value: u64,
        timestamp: u64,
    }
    
    /// Configuration for feature extraction
    struct FeatureConfig has key {
        admin: address,
        authorized_extractors: vector<address>,
        enabled_feature_types: vector<u8>,
    }
    
    /// Events
    struct FeatureEvent has drop, store {
        address: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64,
        timestamp: u64,
    }
    
    /// Event handle for feature events
    struct FeatureEventHandle has key {
        feature_events: event::EventHandle<FeatureEvent>,
    }
    
    /// Initialize the feature extraction module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<FeatureConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create default config
        let authorized_extractors = vector::empty<address>();
        vector::push_back(&mut authorized_extractors, admin_addr);
        
        let enabled_feature_types = vector::empty<u8>();
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_TRANSACTION);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_CLUSTERING);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_TEMPORAL);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_GAS_USAGE);
        
        let config = FeatureConfig {
            admin: admin_addr,
            authorized_extractors,
            enabled_feature_types,
        };
        
        // Create event handle
        let event_handle = FeatureEventHandle {
            feature_events: account::new_event_handle<FeatureEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, event_handle);
    }
    
    /// Add an authorized extractor
    public entry fun add_extractor(admin: &signer, extractor: address) acquires FeatureConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<FeatureConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<FeatureConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Add extractor if not already in list
        if (!vector::contains(&config.authorized_extractors, &extractor)) {
            vector::push_back(&mut config.authorized_extractors, extractor);
        };
    }
    
    /// Remove an authorized extractor
    public entry fun remove_extractor(admin: &signer, extractor: address) acquires FeatureConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<FeatureConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<FeatureConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Find and remove extractor
        let (found, index) = vector::index_of(&config.authorized_extractors, &extractor);
        if (found) {
            vector::remove(&mut config.authorized_extractors, index);
        };
    }
    
    /// Update feature data for an address
    public entry fun update_feature(
        extractor: &signer,
        target_addr: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64
    ) acquires FeatureConfig, FeatureData, FeatureEventHandle {
        let extractor_addr = signer::address_of(extractor);
        
        // Get config to check authorization
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
        // Check if extractor is authorized
        assert!(vector::contains(&config.authorized_extractors, &extractor_addr), 
               error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate feature type
        assert!(
            feature_type == FEATURE_TYPE_TRANSACTION || 
            feature_type == FEATURE_TYPE_CLUSTERING || 
            feature_type == FEATURE_TYPE_TEMPORAL || 
            feature_type == FEATURE_TYPE_GAS_USAGE,
            error::invalid_argument(E_INVALID_FEATURE)
        );
        
        // Check if feature type is enabled
        assert!(vector::contains(&config.enabled_feature_types, &feature_type),
               error::invalid_argument(E_INVALID_FEATURE));
        
        let now = timestamp::now_seconds();
        
        // Create feature
        let feature = Feature {
            feature_type,
            name: feature_name,
            value: feature_value,
            timestamp: now,
        };
        
        // Update or create feature data
        if (exists<FeatureData>(target_addr)) {
            let feature_data = borrow_global_mut<FeatureData>(target_addr);
            
            // Update existing feature or add new one
            let len = vector::length(&feature_data.features);
            let i = 0;
            let found = false;
            
            while (i < len) {
                let existing_feature = vector::borrow_mut(&mut feature_data.features, i);
                if (existing_feature.feature_type == feature_type && existing_feature.name == feature_name) {
                    existing_feature.value = feature_value;
                    existing_feature.timestamp = now;
                    found = true;
                    break
                };
                i = i + 1;
            };
            
            if (!found) {
                vector::push_back(&mut feature_data.features, feature);
            };
            
            feature_data.last_updated = now;
        } else {
            // Create new feature data
            let features = vector::empty<Feature>();
            vector::push_back(&mut features, feature);
            
            let feature_data = FeatureData {
                address: target_addr,
                features,
                last_updated: now,
            };
            
            // Move to global storage (this requires special handling for devnet)
            // In devnet, we need to use a resource account or have the target account sign
            // For hackathon purposes, we'll assume this is handled elsewhere
            // move_to(target_account, feature_data);
            
            // For devnet compatibility, we'll use a different approach in the actual implementation
            // This is a placeholder that will be updated for devnet compatibility
        };
        
        // Emit event
        let event_handle = borrow_global_mut<FeatureEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.feature_events,
            FeatureEvent {
                address: target_addr,
                feature_type,
                feature_name: feature_name,
                feature_value: feature_value,
                timestamp: now,
            }
        );
    }
    
    /// Get feature value
    #[view]
    public fun get_feature_value(addr: address, feature_type: u8, feature_name: String): u64 acquires FeatureData {
        if (!exists<FeatureData>(addr)) {
            return 0
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        
        let len = vector::length(&feature_data.features);
        let i = 0;
        
        while (i < len) {
            let feature = vector::borrow(&feature_data.features, i);
            if (feature.feature_type == feature_type && feature.name == feature_name) {
                return feature.value
            };
            i = i + 1;
        };
        
        0 // Return 0 if feature not found
    }
    
    /// Get all features for an address
    #[view]
    public fun get_all_features(addr: address): vector<u64> acquires FeatureData {
        if (!exists<FeatureData>(addr)) {
            return vector::empty<u64>()
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        let result = vector::empty<u64>();
        
        let len = vector::length(&feature_data.features);
        let i = 0;
        
        while (i < len) {
            let feature = vector::borrow(&feature_data.features, i);
            vector::push_back(&mut result, feature.feature_type);
            vector::push_back(&mut result, feature.value);
            i = i + 1;
        };
        
        result
    }
    
    /// Check if an extractor is authorized
    #[view]
    public fun is_extractor_authorized(extractor: address): bool acquires FeatureConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
        vector::contains(&config.authorized_extractors, &extractor)
    }
    
    /// Get last update timestamp
    #[view]
    public fun get_last_update_timestamp(addr: address): u64 acquires FeatureData {
        if (!exists<FeatureData>(addr)) {
            return 0
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        feature_data.last_updated
    }
}
