module aptos_sybil_shield::optimized_feature_extraction {
    use std::error;
    use std::signer;
    use std::string::{String};
    use std::vector;
    use std::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};

    // Error codes
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INVALID_FEATURE_TYPE: u64 = 4;
    const E_INVALID_FEATURE_NAME: u64 = 5;
    const E_INVALID_FEATURE_VALUE: u64 = 6;
    const E_INVALID_ROLE: u64 = 7;

    // Role types
    const ROLE_ADMIN: u8 = 1;
    const ROLE_EXTRACTOR: u8 = 2;
    const ROLE_READER: u8 = 3;

    // Feature types
    const FEATURE_TYPE_TRANSACTION: u8 = 1;
    const FEATURE_TYPE_BALANCE: u8 = 2;
    const FEATURE_TYPE_ACTIVITY: u8 = 3;
    const FEATURE_TYPE_SOCIAL: u8 = 4;
    const FEATURE_TYPE_CUSTOM: u8 = 5;

    // Structs
    struct FeatureKey has copy, drop, store {
        feature_type: u8,
        name: String,
    }

    struct Feature has copy, drop, store {
        key: FeatureKey,
        value: u64,
        timestamp: u64,
    }

    struct FeatureData has key, store {
        address: address,
        features: Table<FeatureKey, Feature>,
        last_updated: u64,
    }

    struct FeatureConfig has key {
        admin: address,
        batch_events: bool,
    }

    struct Roles has key {
        admin_roles: vector<address>,
        extractor_roles: Table<address, bool>,
        reader_roles: Table<address, bool>,
    }

    struct FeatureUpdateEvent has drop, store {
        target_addr: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64,
        timestamp: u64,
    }

    struct FeatureEventHandle has key {
        update_events: EventHandle<FeatureUpdateEvent>,
    }

    struct ResourceSignerCapability has key {
        cap: account::SignerCapability,
    }

    // Initialize the module
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Ensure not already initialized
        assert!(!exists<FeatureConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create config
        let config = FeatureConfig {
            admin: admin_addr,
            batch_events: false,
        };
        
        // Create roles
        let admin_roles = vector::empty<address>();
        vector::push_back(&mut admin_roles, admin_addr);
        
        let extractor_roles = table::new<address, bool>();
        let reader_roles = table::new<address, bool>();
        
        let roles = Roles {
            admin_roles,
            extractor_roles,
            reader_roles,
        };
        
        // Create event handle
        let event_handle = FeatureEventHandle {
            update_events: account::new_event_handle<FeatureUpdateEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, roles);
        move_to(admin, event_handle);
    }
    
    // Non-entry function that returns address
    fun create_resource_account_internal(admin: &signer, seed: vector<u8>): address acquires Roles {
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

    /// Create a resource account for devnet compatibility
    entry fun create_resource_account(admin: &signer, seed: vector<u8>) acquires Roles {
        let _ = create_resource_account_internal(admin, seed);
    }
    
    // Grant role to an account
    entry fun grant_role(admin: &signer, account_addr: address, role_type: u8) acquires Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        // Verify role type
        assert!(
            role_type == ROLE_ADMIN || role_type == ROLE_EXTRACTOR || role_type == ROLE_READER,
            error::invalid_argument(E_INVALID_ROLE)
        );
        
        let roles = borrow_global_mut<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN) {
            // Check if already has role
            let i = 0;
            let len = vector::length(&roles.admin_roles);
            let has_role = false;
            
            while (i < len) {
                if (vector::borrow(&roles.admin_roles, i) == &account_addr) {
                    has_role = true;
                    break
                };
                i = i + 1;
            };
            
            if (!has_role) {
                vector::push_back(&mut roles.admin_roles, account_addr);
            };
        } else if (role_type == ROLE_EXTRACTOR) {
            table::upsert(&mut roles.extractor_roles, account_addr, true);
        } else if (role_type == ROLE_READER) {
            table::upsert(&mut roles.reader_roles, account_addr, true);
        };
    }
    
    // Revoke role from an account
    entry fun revoke_role(admin: &signer, account_addr: address, role_type: u8) acquires Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        // Verify role type
        assert!(
            role_type == ROLE_ADMIN || role_type == ROLE_EXTRACTOR || role_type == ROLE_READER,
            error::invalid_argument(E_INVALID_ROLE)
        );
        
        let roles = borrow_global_mut<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN) {
            // Find and remove from admin roles
            let i = 0;
            let len = vector::length(&roles.admin_roles);
            
            while (i < len) {
                if (vector::borrow(&roles.admin_roles, i) == &account_addr) {
                    vector::remove(&mut roles.admin_roles, i);
                    break
                };
                i = i + 1;
            };
        } else if (role_type == ROLE_EXTRACTOR) {
            if (table::contains(&roles.extractor_roles, account_addr)) {
                table::remove(&mut roles.extractor_roles, account_addr);
            };
        } else if (role_type == ROLE_READER) {
            if (table::contains(&roles.reader_roles, account_addr)) {
                table::remove(&mut roles.reader_roles, account_addr);
            };
        };
    }
    
    // Set batch events flag
    entry fun set_batch_events(admin: &signer, batch_events: bool) acquires FeatureConfig, Roles {
        let admin_addr = signer::address_of(admin);
        
        // Verify admin role
        assert_has_role(admin_addr, ROLE_ADMIN);
        
        let config = borrow_global_mut<FeatureConfig>(@aptos_sybil_shield);
        config.batch_events = batch_events;
    }
    
    // Update a single feature
    entry fun update_feature(
        extractor: &signer,
        target_addr: address,
        feature_type: u8,
        feature_name: String,
        feature_value: u64
    ) acquires FeatureConfig, FeatureData, FeatureEventHandle, Roles {
        let extractor_addr = signer::address_of(extractor);
        
        // Verify extractor role
        assert_has_role(extractor_addr, ROLE_EXTRACTOR);
        
        // Verify feature type
        assert!(
            feature_type == FEATURE_TYPE_TRANSACTION || 
            feature_type == FEATURE_TYPE_BALANCE || 
            feature_type == FEATURE_TYPE_ACTIVITY || 
            feature_type == FEATURE_TYPE_SOCIAL || 
            feature_type == FEATURE_TYPE_CUSTOM,
            error::invalid_argument(E_INVALID_FEATURE_TYPE)
        );
        
        let now = timestamp::now_seconds();
        
        // Create feature
        let feature_key = FeatureKey {
            feature_type,
            name: feature_name,
        };
        
        let feature = Feature {
            key: feature_key,
            value: feature_value,
            timestamp: now,
        };
        
        // Initialize or get feature data
        if (exists<FeatureData>(target_addr)) {
            let feature_data = borrow_global_mut<FeatureData>(target_addr);
            
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
            
            let feature_data = FeatureData {
                address: target_addr,
                features,
                last_updated: now,
            };
            
            move_to(extractor, feature_data);
        };
        
        // Emit event if not in batch mode
        let config = borrow_global<FeatureConfig>(@aptos_sybil_shield);
        if (!config.batch_events) {
            let event_handle = borrow_global_mut<FeatureEventHandle>(@aptos_sybil_shield);
            
            event::emit_event<FeatureUpdateEvent>(
                &mut event_handle.update_events,
                FeatureUpdateEvent {
                    target_addr,
                    feature_type,
                    feature_name,
                    feature_value,
                    timestamp: now,
                }
            );
        };
    }
    
    // Update multiple features in batch
    entry fun batch_update_features(
        extractor: &signer,
        target_addr: address,
        feature_types: vector<u8>,
        feature_names: vector<String>,
        feature_values: vector<u64>
    ) acquires FeatureConfig, FeatureData, FeatureEventHandle, Roles {
        let extractor_addr = signer::address_of(extractor);
        
        // Verify extractor role
        assert_has_role(extractor_addr, ROLE_EXTRACTOR);
        
        let now = timestamp::now_seconds();
        let features_updated = 0;
        
        // Initialize or get feature data
        if (!exists<FeatureData>(target_addr)) {
            // Create new feature data with empty table
            let features = table::new<FeatureKey, Feature>();
            
            let feature_data = FeatureData {
                address: target_addr,
                features,
                last_updated: now,
            };
            
            move_to(extractor, feature_data);
        };
        
        let feature_data = borrow_global_mut<FeatureData>(target_addr);
        
        // Update features
        let i = 0;
        let len = vector::length(&feature_types);
        
        while (i < len) {
            let feature_type = *vector::borrow(&feature_types, i);
            let feature_name = *vector::borrow(&feature_names, i);
            let feature_value = *vector::borrow(&feature_values, i);
            
            // Verify feature type
            if (
                feature_type == FEATURE_TYPE_TRANSACTION || 
                feature_type == FEATURE_TYPE_BALANCE || 
                feature_type == FEATURE_TYPE_ACTIVITY || 
                feature_type == FEATURE_TYPE_SOCIAL || 
                feature_type == FEATURE_TYPE_CUSTOM
            ) {
                let feature_key = FeatureKey {
                    feature_type,
                    name: feature_name,
                };
                
                let feature = Feature {
                    key: feature_key,
                    value: feature_value,
                    timestamp: now,
                };
                
                if (table::contains(&feature_data.features, feature_key)) {
                    *table::borrow_mut(&mut feature_data.features, feature_key) = feature;
                } else {
                    table::add(&mut feature_data.features, feature_key, feature);
                };
                
                features_updated = features_updated + 1;
            };
            
            i = i + 1;
        };
        
        feature_data.last_updated = now;
        
        // Emit batch event
        let config = borrow_global<FeatureConfig>(@aptos_sybil_shield);
        if (config.batch_events) {
            let event_handle = borrow_global_mut<FeatureEventHandle>(@aptos_sybil_shield);
            
            event::emit_event<FeatureUpdateEvent>(
                &mut event_handle.update_events,
                FeatureUpdateEvent {
                    target_addr,
                    feature_type: 0, // 0 indicates batch update
                    feature_name: std::string::utf8(b"batch_update"),
                    feature_value: features_updated,
                    timestamp: now,
                }
            );
        };
    }
    
    // #[view]
    fun get_feature_value(addr: address, feature_type: u8, feature_name: String): u64 acquires FeatureData {
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
    
    // #[view]
    fun get_all_features(addr: address): (vector<u8>, vector<String>, vector<u64>) acquires FeatureData {
        // Verify caller has reader role - commented out for view function
        // assert_has_role(signer::address_of(reader), ROLE_READER);
        
        let feature_types = vector::empty<u8>();
        let feature_names = vector::empty<String>();
        let feature_values = vector::empty<u64>();
        
        if (!exists<FeatureData>(addr)) {
            return (feature_types, feature_names, feature_values)
        };
        
        let _ = borrow_global<FeatureData>(addr);
        
        // This is a simplified implementation since we can't iterate over Table in Move
        // In a real implementation, we would need to maintain a separate vector of keys
        // In practice, you would need to track keys separately
        
        (feature_types, feature_names, feature_values)
    }
    
    // #[view]
    fun is_extractor_authorized(extractor: address): bool acquires Roles {
        assert!(exists<Roles>(@aptos_sybil_shield), error::not_found(E_NOT_INITIALIZED));
        let roles = borrow_global<Roles>(@aptos_sybil_shield);
        
        table::contains(&roles.extractor_roles, extractor)
    }
    
    // #[view]
    fun get_last_update_timestamp(addr: address): u64 acquires FeatureData {
        if (!exists<FeatureData>(addr)) {
            return 0
        };
        
        let feature_data = borrow_global<FeatureData>(addr);
        feature_data.last_updated
    }
    
    // #[view]
    fun is_batch_events_enabled(): bool acquires FeatureConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<FeatureConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<FeatureConfig>(config_addr);
        
        config.batch_events
    }
    
    // Helper function to check if an address has a specific role
    fun assert_has_role(addr: address, role_type: u8) acquires Roles {
        assert!(exists<Roles>(@aptos_sybil_shield), error::not_found(E_NOT_INITIALIZED));
        let roles = borrow_global<Roles>(@aptos_sybil_shield);
        
        if (role_type == ROLE_ADMIN) {
            let i = 0;
            let len = vector::length(&roles.admin_roles);
            let has_role = false;
            
            while (i < len) {
                if (vector::borrow(&roles.admin_roles, i) == &addr) {
                    has_role = true;
                    break
                };
                i = i + 1;
            };
            
            assert!(has_role, error::permission_denied(E_NOT_AUTHORIZED));
        } else if (role_type == ROLE_EXTRACTOR) {
            assert!(
                table::contains(&roles.extractor_roles, addr),
                error::permission_denied(E_NOT_AUTHORIZED)
            );
        } else if (role_type == ROLE_READER) {
            assert!(
                table::contains(&roles.reader_roles, addr),
                error::permission_denied(E_NOT_AUTHORIZED)
            );
        } else {
            assert!(false, error::invalid_argument(E_INVALID_ROLE));
        };
    }
}
