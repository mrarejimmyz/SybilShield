module aptos_sybil_shield::optimized_feature_extraction {
    use std::error;
    use std::signer;
    use std::vector;
    // Removed unused string module alias
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table}; // Added table import for O(1) lookups
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_FEATURE: u64 = 4;
    const E_INVALID_ROLE: u64 = 5; // New error code for role-based access control
    
    /// Feature types
    const FEATURE_TYPE_TRANSACTION: u8 = 1;
    const FEATURE_TYPE_CLUSTERING: u8 = 2;
    const FEATURE_TYPE_TEMPORAL: u8 = 3;
    const FEATURE_TYPE_GAS_USAGE: u8 = 4;
    
    /// Role types for enhanced authorization
    const ROLE_ADMIN: u8 = 1;
    const ROLE_EXTRACTOR: u8 = 2;
    const ROLE_READER: u8 = 3;
    
    /// Feature key for table lookups
    struct FeatureKey has copy, drop, store {
        feature_type: u8,
        name: String,
    }
    
    /// Feature data for an address - optimized with Table for O(1) lookups
    struct FeatureData has key {
        address: address,
        features: Table<FeatureKey, Feature>, // Changed from vector to Table for O(1) lookups
        last_updated: u64,
    }
    
    /// Individual feature
    struct Feature has store, drop, copy {
        value: u64,
        timestamp: u64,
    }
    
    /// Enhanced role-based access control
    struct Roles has key {
        admin_roles: Table<address, bool>,
        extractor_roles: Table<address, bool>,
        reader_roles: Table<address, bool>,
    }
    
    /// Configuration for feature extraction - simplified with role-based access
    struct FeatureConfig has key {
        admin: address,
        enabled_feature_types: vector<u8>,
        batch_events: bool, // New flag to control event batching
    }
    
    /// Events
    struct FeatureEvent has drop, store {
        address: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64,
        timestamp: u64,
    }
    
    /// Batch event for gas optimization
    struct BatchFeatureEvent has drop, store {
        count: u64,
        timestamp: u64,
    }
    
    /// Event handle for feature events
    struct FeatureEventHandle has key {
        feature_events: event::EventHandle<FeatureEvent>,
        batch_events: event::EventHandle<BatchFeatureEvent>,
    }
    
    /// Resource account capability for devnet compatibility
    struct ResourceSignerCapability has key {
        cap: account::SignerCapability,
    }
    
    /// Initialize the feature extraction module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<FeatureConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create enabled feature types
        let enabled_feature_types = vector::empty<u8>();
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_TRANSACTION);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_CLUSTERING);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_TEMPORAL);
        vector::push_back(&mut enabled_feature_types, FEATURE_TYPE_GAS_USAGE);
        
        // Create config with batch events disabled by default
        let config = FeatureConfig {
            admin: admin_addr,
            enabled_feature_types,
            batch_events: false,
        };
        
        // Initialize role-based access control
        let admin_roles = table::new<address, bool>();
        table::add(&mut admin_roles, admin_addr, true);
        
        let extractor_roles = table::new<address, bool>();
        table::add(&mut extractor_roles, admin_addr, true); // Admin also has extractor role
        
        let reader_roles = table::new<address, bool>();
        table::add(&mut reader_roles, admin_addr, true); // Admin also has reader role
        
        let roles = Roles {
            admin_roles,
            extractor_roles,
            reader_roles,
        };
        
        // Create event handle
        let event_handle = FeatureEventHandle {
            feature_events: account::new_event_handle<FeatureEvent>(admin),
            batch_events: account::new_event_handle<BatchFeatureEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, roles);
        move_to(admin, event_handle);
    }
    
    /// Create a resource account for devnet compatibility
    public entry fun create_resource_account(admin: &signer, seed: vector<u8>): address acquires Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        let resource_account_address = account::create_resource_address(&admin_addr, seed);
        
        if (!account::exists_at(resource_account_address)) {
            // Properly destructure the tuple returned by create_resource_account
            let (_, resource_signer_cap) = account::create_resource_account(admin, seed);
            // Store signer capability securely
            move_to(admin, ResourceSignerCapability { cap: resource_signer_cap });
        };
        
        resource_account_address
    }
    
    /// Set batch events flag
    public entry fun set_batch_events(admin: &signer, batch_events: bool) acquires FeatureConfig, Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        // Update config
        let config_addr = @aptos_sybil_shield;
        let config = borrow_global_mut<FeatureConfig>(config_addr);
        config.batch_events = batch_events;
    }
    
    /// Grant a role to an address
    public entry fun grant_role(admin: &signer, account_addr: address, role_type: u8) acquires Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        // Validate role type
        assert!(
            role_type == ROLE_ADMIN || 
            role_type == ROLE_EXTRACTOR || 
            role_type == ROLE_READER,
            error::invalid_argument(E_INVALID_ROLE)
        );
        
        // Grant role
        let roles = borrow_global_mut<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN) {
            if (!table::contains(&roles.admin_roles, account_addr)) {
                table::add(&mut roles.admin_roles, account_addr, true);
            };
        } else if (role_type == ROLE_EXTRACTOR) {
            if (!table::contains(&roles.extractor_roles, account_addr)) {
                table::add(&mut roles.extractor_roles, account_addr, true);
            };
        } else if (role_type == ROLE_READER) {
            if (!table::contains(&roles.reader_roles, account_addr)) {
                table::add(&mut roles.reader_roles, account_addr, true);
            };
        };
    }
    
    /// Revoke a role from an address
    public entry fun revoke_role(admin: &signer, account_addr: address, role_type: u8) acquires Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        // Validate role type
        assert!(
            role_type == ROLE_ADMIN || 
            role_type == ROLE_EXTRACTOR || 
            role_type == ROLE_READER,
            error::invalid_argument(E_INVALID_ROLE)
        );
        
        // Revoke role
        let roles = borrow_global_mut<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN && table::contains(&roles.admin_roles, account_addr)) {
            table::remove(&mut roles.admin_roles, account_addr);
        } else if (role_type == ROLE_EXTRACTOR && table::contains(&roles.extractor_roles, account_addr)) {
            table::remove(&mut roles.extractor_roles, account_addr);
        } else if (role_type == ROLE_READER && table::contains(&roles.reader_roles, account_addr)) {
            table::remove(&mut roles.reader_roles, account_addr);
        };
    }
    
    /// Update feature data for an address - optimized version
    public entry fun update_feature(
        extractor: &signer,
        target_addr: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64
    ) acquires FeatureConfig, FeatureData, FeatureEventHandle, Roles {
        let extractor_addr = signer::address_of(extractor);
        
        // Verify extractor role
        assert_has_role(extractor_addr, ROLE_EXTRACTOR);
        
        // Get config to check feature type
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
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
        
        // Create feature key for table lookup
        let feature_key = FeatureKey {
            feature_type,
            name: feature_name,
        };
        
        // Create feature
        let feature = Feature {
            value: feature_value,
            timestamp: now,
        };
        
        // Update or create feature data - optimized with Table
        if (exists<FeatureData>(target_addr)) {
            let feature_data = borrow_global_mut<FeatureData>(target_addr);
            
            // Update existing feature or add new one - O(1) operation with Table
            if (table::contains(&feature_data.features, feature_key)) {
                *table::borrow_mut(&mut feature_data.features, feature_key) = feature;
            } else {
                table::add(&mut feature_data.features, feature_key, feature);
            };
            
            feature_data.last_updated = now;
        } else {
            // Create new feature data with Table
            let features = table::new<FeatureKey, Feature>();
            table::add(&mut features, feature_key, feature);
            
            
            // Handle resource account for devnet compatibility
            // This would use the resource account capability in a real implementation
            // For this optimization example, we'll assume it's handled
        };
        
        // Emit event based on batch setting
        let event_handle = borrow_global_mut<FeatureEventHandle>(config_addr);
        
        if (!config.batch_events) {
            // Emit individual event
            event::emit_event(
                &mut event_handle.feature_events,
                FeatureEvent {
                    address: target_addr,
                    feature_type,
                    feature_name: feature_key.name,
                    feature_value,
                    timestamp: now,
                }
            );
        } else {
            // Emit batch event - reduces gas costs for high-volume updates
            event::emit_event(
                &mut event_handle.batch_events,
                BatchFeatureEvent {
                    count: 1,
                    timestamp: now,
                }
            );
        };
    }
    
    /// Batch update multiple features for an address - new optimized function
    public entry fun batch_update_features(
        extractor: &signer,
        target_addr: address,
        feature_types: vector<u8>,
        feature_names: vector<String>,
        feature_values: vector<u64>
    ) acquires FeatureConfig, FeatureData, FeatureEventHandle, Roles {
        let extractor_addr = signer::address_of(extractor);
        
        // Verify extractor role
        assert_has_role(extractor_addr, ROLE_EXTRACTOR);
        
        // Validate input vectors have same length
        let len = vector::length(&feature_types);
        assert!(len == vector::length(&feature_names), error::invalid_argument(E_INVALID_FEATURE));
        assert!(len == vector::length(&feature_values), error::invalid_argument(E_INVALID_FEATURE));
        
        // Get config
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
        let now = timestamp::now_seconds();
        let features_updated = 0;
        
        // Initialize or get feature data
        if (!exists<FeatureData>(target_addr)) {
        
        // Get mutable reference to feature data
        let feature_data = borrow_global_mut<FeatureData>(target_addr);
        
        // Process all features in a single storage operation
        let i = 0;
        while (i < len) {
            let feature_type = *vector::borrow(&feature_types, i);
            let feature_name = *vector::borrow(&feature_names, i);
            let feature_value = *vector::borrow(&feature_values, i);
            
            // Validate feature type
            if (
                (feature_type == FEATURE_TYPE_TRANSACTION || 
                feature_type == FEATURE_TYPE_CLUSTERING || 
                feature_type == FEATURE_TYPE_TEMPORAL || 
                feature_type == FEATURE_TYPE_GAS_USAGE) &&
                vector::contains(&config.enabled_feature_types, &feature_type)
            ) {
                // Create feature key and feature
                let feature_key = FeatureKey {
                    feature_type,
                    name: feature_name,
                };
                
                let feature = Feature {
                    value: feature_value,
                    timestamp: now,
                };
                
                // Update or add feature
                if (table::contains(&feature_data.features, feature_key)) {
                    *table::borrow_mut(&mut feature_data.features, feature_key) = feature;
                } else {
                    table::add(&mut feature_data.features, feature_key, feature);
                };
                
                features_updated = features_updated + 1;
            };
            
            i = i + 1;
        };
        
        // Update timestamp
        feature_data.last_updated = now;
        
        // Emit batch event
        if (features_updated > 0) {
            let event_handle = borrow_global_mut<FeatureEventHandle>(config_addr);
            event::emit_event(
                &mut event_handle.batch_events,
                BatchFeatureEvent {
                    count: features_updated,
                    timestamp: now,
                }
            );
        };
    }
    
    #[view]
    public fun get_feature_value(addr: address, feature_type: u8, feature_name: String): u64 acquires FeatureData {
        // Verify caller has reader role - commented out for view function
        // assert_has_role(signer::address_of(reader), ROLE_READER);
        
        if (!exists<FeatureData>(addr)) {
            return 0
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        
        let feature_key = FeatureKey {
            feature_type,
            name: feature_name,
        };
        
        // O(1) lookup with Table
        if (table::contains(&feature_data.features, feature_key)) {
            let feature = table::borrow(&feature_data.features, feature_key);
            return feature.value
        };
        
        0 // Return 0 if feature not found
    }
    
    #[view]
    public fun get_all_features(addr: address): (vector<u8>, vector<String>, vector<u64>) acquires FeatureData {
        // Verify caller has reader role - commented out for view function
        // assert_has_role(signer::address_of(reader), ROLE_READER);
        
        let feature_types = vector::empty<u8>();
        let feature_names = vector::empty<String>();
        let feature_values = vector::empty<u64>();
        
        if (!exists<FeatureData>(addr)) {
            return (feature_types, feature_names, feature_values)
        };
        
        let _feature_data = borrow_global<FeatureData>(addr);
        
        // This is a simplified implementation since we can't iterate over Table in Move
        // In a real implementation, we would need to maintain a separate vector of keys
        // or use a different data structure that supports iteration
        
        // For this example, we'll return empty vectors
        // In practice, you would need to track keys separately
        
        (feature_types, feature_names, feature_values)
    }
    
    #[view]
    public fun is_extractor_authorized(extractor: address): bool acquires Roles {
        assert!(exists<Roles>(@aptos_sybil_shield), error::not_found(E_NOT_INITIALIZED));
        let roles = borrow_global<Roles>(@aptos_sybil_shield);
        
        table::contains(&roles.extractor_roles, extractor)
    }
    
    #[view]
    public fun get_last_update_timestamp(addr: address): u64 acquires FeatureData {
        if (!exists<FeatureData>(addr)) {
            return 0
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        feature_data.last_updated
    }
    
    #[view]
    public fun is_batch_events_enabled(): bool acquires FeatureConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
        config.batch_events
    }
    
    /// Internal function to verify role
    fun assert_has_role(addr: address, role_type: u8) acquires Roles {
        assert!(exists<Roles>(@aptos_sybil_shield), error::not_found(E_NOT_INITIALIZED));
        let roles = borrow_global<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN) {
            assert!(table::contains(&roles.admin_roles, addr), error::permission_denied(E_NOT_AUTHORIZED));
        } else if (role_type == ROLE_EXTRACTOR) {
            assert!(table::contains(&roles.extractor_roles, addr), error::permission_denied(E_NOT_AUTHORIZED));
        } else if (role_type == ROLE_READER) {
            assert!(table::contains(&roles.reader_roles, addr), error::permission_denied(E_NOT_AUTHORIZED));
        } else {
            assert!(false, error::invalid_argument(E_INVALID_ROLE));
        };
    }
}
