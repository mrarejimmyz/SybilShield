module aptos_sybil_shield::indexer_integration {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string;
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_sybil_shield::sybil_detection;
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_DATA: u64 = 4;
    const E_INDEXER_NOT_REGISTERED: u64 = 5;
    const E_INDEXER_ALREADY_REGISTERED: u64 = 6;
    const E_INVALID_INDEXER_TYPE: u64 = 7;
    const E_SYNC_INTERVAL_NOT_REACHED: u64 = 8;
    const E_INVALID_TARGET_ADDRESS: u64 = 9;
    const E_DATA_PROCESSING_FAILED: u64 = 10;
    
    /// Indexer types
    const INDEXER_TYPE_TRANSACTION: u8 = 1;
    const INDEXER_TYPE_ACCOUNT: u8 = 2;
    const INDEXER_TYPE_EVENT: u8 = 3;
    const INDEXER_TYPE_RESOURCE: u8 = 4;
    
    /// Event types
    const EVENT_TYPE_REGISTRATION: u8 = 1;
    const EVENT_TYPE_SUBMISSION: u8 = 2;
    const EVENT_TYPE_SYNC: u8 = 3;
    const EVENT_TYPE_DEACTIVATION: u8 = 4;
    const EVENT_TYPE_REACTIVATION: u8 = 5;
    
    /// Default sync interval (1 hour in seconds)
    const DEFAULT_SYNC_INTERVAL: u64 = 3600;
    
    /// Maximum number of targets per submission
    const MAX_TARGETS_PER_SUBMISSION: u64 = 100;
    
    /// Indexer registration
    struct IndexerRegistration has key {
        indexer_address: address,
        indexer_type: u8,
        name: String,
        url: String,
        api_key: vector<u8>,  // Encrypted API key
        last_sync: u64,       // Timestamp of last sync
        is_active: bool,
        registration_time: u64, // When the indexer was registered
        data_format_version: u8, // Version of the data format
    }
    
    /// Indexer data submission
    struct IndexerSubmission has key {
        indexer_address: address,
        submission_count: u64,
        last_submission: u64,
        processed_addresses: u64, // Total number of addresses processed
        successful_submissions: u64, // Count of successful submissions
        failed_submissions: u64, // Count of failed submissions
    }
    
    /// Configuration for indexer integration
    struct IndexerConfig has key {
        admin: address,
        authorized_indexers: vector<address>,
        required_indexer_types: vector<u8>,
        sync_interval: u64,    // Minimum time between syncs in seconds
        max_targets_per_submission: u64, // Maximum number of target addresses per submission
        data_processing_enabled: bool, // Whether data processing is enabled
    }
    
    /// Events
    struct IndexerEvent has drop, store {
        indexer_address: address,
        event_type: u8,        // 1: registration, 2: submission, 3: sync, 4: deactivation, 5: reactivation
        timestamp: u64,
        data_type: u8,         // Only used for submission events
        targets_count: u64,    // Number of target addresses (for submission events)
    }
    
    /// Event handle for indexer events
    struct IndexerEventHandle has key {
        indexer_events: event::EventHandle<IndexerEvent>,
    }
    
    /// Initialize the indexer integration module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<IndexerConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create default config
        let authorized_indexers = vector::empty<address>();
        vector::push_back(&mut authorized_indexers, admin_addr);
        
        let required_indexer_types = vector::empty<u8>();
        vector::push_back(&mut required_indexer_types, INDEXER_TYPE_TRANSACTION);
        vector::push_back(&mut required_indexer_types, INDEXER_TYPE_ACCOUNT);
        
        let config = IndexerConfig {
            admin: admin_addr,
            authorized_indexers,
            required_indexer_types,
            sync_interval: DEFAULT_SYNC_INTERVAL,
            max_targets_per_submission: MAX_TARGETS_PER_SUBMISSION,
            data_processing_enabled: true,
        };
        
        // Create event handle
        let event_handle = IndexerEventHandle {
            indexer_events: account::new_event_handle<IndexerEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, event_handle);
    }
    
    /// Update sync interval
    public entry fun update_sync_interval(admin: &signer, interval: u64) acquires IndexerConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<IndexerConfig>(config_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update sync interval
        config.sync_interval = interval;
    }
    
    /// Update max targets per submission
    public entry fun update_max_targets(admin: &signer, max_targets: u64) acquires IndexerConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<IndexerConfig>(config_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update max targets
        config.max_targets_per_submission = max_targets;
    }
    
    /// Enable or disable data processing
    public entry fun set_data_processing(admin: &signer, enabled: bool) acquires IndexerConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<IndexerConfig>(config_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update data processing flag
        config.data_processing_enabled = enabled;
    }
    
    /// Register an indexer
    public entry fun register_indexer(
        account: &signer,
        indexer_type: u8,
        name: String,
        url: String,
        api_key: vector<u8>,
        data_format_version: u8
    ) acquires IndexerConfig, IndexerEventHandle {
        let addr = signer::address_of(account);
        
        // Check if already registered
        assert!(!exists<IndexerRegistration>(addr), error::already_exists(E_INDEXER_ALREADY_REGISTERED));
        
        // Get config
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        
        // Validate indexer type
        assert!(
            indexer_type == INDEXER_TYPE_TRANSACTION || 
            indexer_type == INDEXER_TYPE_ACCOUNT || 
            indexer_type == INDEXER_TYPE_EVENT || 
            indexer_type == INDEXER_TYPE_RESOURCE,
            error::invalid_argument(E_INVALID_INDEXER_TYPE)
        );
        
        // Check if indexer type is required
        let is_required_type = vector::contains(&config.required_indexer_types, &indexer_type);
        
        // Validate URL and name
        assert!(string::length(&url) > 0, error::invalid_argument(E_INVALID_DATA));
        assert!(string::length(&name) > 0, error::invalid_argument(E_INVALID_DATA));
        
        let now = timestamp::now_seconds();
        
        // Create indexer registration
        let registration = IndexerRegistration {
            indexer_address: addr,
            indexer_type,
            name,
            url,
            api_key,
            last_sync: now,
            is_active: is_required_type, // Auto-activate if it's a required type
            registration_time: now,
            data_format_version,
        };
        
        // Create submission record
        let submission = IndexerSubmission {
            indexer_address: addr,
            submission_count: 0,
            last_submission: 0,
            processed_addresses: 0,
            successful_submissions: 0,
            failed_submissions: 0,
        };
        
        move_to(account, registration);
        move_to(account, submission);
        
        // Add to authorized indexers if it's a required type
        if (is_required_type && !vector::contains(&config.authorized_indexers, &addr)) {
            let config_mut = borrow_global_mut<IndexerConfig>(config_addr);
            vector::push_back(&mut config_mut.authorized_indexers, addr);
        };
        
        // Emit event
        let event_handle = borrow_global_mut<IndexerEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.indexer_events,
            IndexerEvent {
                indexer_address: addr,
                event_type: EVENT_TYPE_REGISTRATION,
                timestamp: now,
                data_type: indexer_type,
                targets_count: 0,
            }
        );
    }
    
    /// Authorize an indexer
    public entry fun authorize_indexer(admin: &signer, indexer_addr: address) acquires IndexerConfig, IndexerRegistration, IndexerEventHandle {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<IndexerConfig>(config_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if indexer is registered
        assert!(exists<IndexerRegistration>(indexer_addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        
        // Add to authorized indexers if not already there
        if (!vector::contains(&config.authorized_indexers, &indexer_addr)) {
            vector::push_back(&mut config.authorized_indexers, indexer_addr);
        };
        
        // Activate the indexer
        let registration = borrow_global_mut<IndexerRegistration>(indexer_addr);
        let was_active = registration.is_active;
        registration.is_active = true;
        
        // Emit event if status changed
        if (!was_active) {
            let event_handle = borrow_global_mut<IndexerEventHandle>(config_addr);
            event::emit_event(
                &mut event_handle.indexer_events,
                IndexerEvent {
                    indexer_address: indexer_addr,
                    event_type: EVENT_TYPE_REACTIVATION,
                    timestamp: timestamp::now_seconds(),
                    data_type: registration.indexer_type,
                    targets_count: 0,
                }
            );
        };
    }
    
    /// Deauthorize an indexer
    public entry fun deauthorize_indexer(admin: &signer, indexer_addr: address) acquires IndexerConfig, IndexerRegistration, IndexerEventHandle {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<IndexerConfig>(config_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if indexer is registered
        assert!(exists<IndexerRegistration>(indexer_addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        
        // Remove from authorized indexers if present
        let (found, index) = vector::index_of(&config.authorized_indexers, &indexer_addr);
        if (found) {
            vector::remove(&mut config.authorized_indexers, index);
        };
        
        // Deactivate the indexer
        let registration = borrow_global_mut<IndexerRegistration>(indexer_addr);
        let was_active = registration.is_active;
        registration.is_active = false;
        
        // Emit event if status changed
        if (was_active) {
            let event_handle = borrow_global_mut<IndexerEventHandle>(config_addr);
            event::emit_event(
                &mut event_handle.indexer_events,
                IndexerEvent {
                    indexer_address: indexer_addr,
                    event_type: EVENT_TYPE_DEACTIVATION,
                    timestamp: timestamp::now_seconds(),
                    data_type: registration.indexer_type,
                    targets_count: 0,
                }
            );
        };
    }
    
    /// Update indexer information
    public entry fun update_indexer_info(
        indexer: &signer,
        name: String,
        url: String,
        api_key: vector<u8>,
        data_format_version: u8
    ) acquires IndexerRegistration {
        let indexer_addr = signer::address_of(indexer);
        
        // Check if indexer is registered
        assert!(exists<IndexerRegistration>(indexer_addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        
        // Update indexer information
        let registration = borrow_global_mut<IndexerRegistration>(indexer_addr);
        
        // Validate URL and name
        assert!(string::length(&url) > 0, error::invalid_argument(E_INVALID_DATA));
        assert!(string::length(&name) > 0, error::invalid_argument(E_INVALID_DATA));
        
        registration.name = name;
        registration.url = url;
        registration.api_key = api_key;
        registration.data_format_version = data_format_version;
    }
    
    /// Submit indexer data
    public entry fun submit_data(
        indexer: &signer,
        data_type: u8,
        data_hash: vector<u8>,
        target_addresses: vector<address>
    ) acquires IndexerConfig, IndexerRegistration, IndexerSubmission, IndexerEventHandle {
        let indexer_addr = signer::address_of(indexer);
        
        // Check if indexer is registered
        assert!(exists<IndexerRegistration>(indexer_addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        
        // Get config to check authorization
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        
        // Check if indexer is authorized
        assert!(vector::contains(&config.authorized_indexers, &indexer_addr), 
               error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if indexer is active
        let registration = borrow_global<IndexerRegistration>(indexer_addr);
        assert!(registration.is_active, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate data type
        assert!(
            data_type == INDEXER_TYPE_TRANSACTION || 
            data_type == INDEXER_TYPE_ACCOUNT || 
            data_type == INDEXER_TYPE_EVENT || 
            data_type == INDEXER_TYPE_RESOURCE,
            error::invalid_argument(E_INVALID_INDEXER_TYPE)
        );
        
        // Validate target addresses
        let targets_count = vector::length(&target_addresses);
        assert!(targets_count > 0, error::invalid_argument(E_INVALID_TARGET_ADDRESS));
        assert!(targets_count <= config.max_targets_per_submission, error::invalid_argument(E_INVALID_TARGET_ADDRESS));
        
        // Update submission record
        let submission = borrow_global_mut<IndexerSubmission>(indexer_addr);
        submission.submission_count = submission.submission_count + 1;
        submission.last_submission = timestamp::now_seconds();
        submission.processed_addresses = submission.processed_addresses + targets_count;
        
        // Process data if enabled
        if (config.data_processing_enabled) {
            // In a real implementation, this would process the data and update risk scores
            // For this example, we'll just count it as successful
            submission.successful_submissions = submission.successful_submissions + 1;
        };
        
        // Emit event
        let event_handle = borrow_global_mut<IndexerEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.indexer_events,
            IndexerEvent {
                indexer_address: indexer_addr,
                event_type: EVENT_TYPE_SUBMISSION,
                timestamp: timestamp::now_seconds(),
                data_type,
                targets_count,
            }
        );
    }
    
    /// Sync indexer data
    public entry fun sync_indexer(indexer: &signer) acquires IndexerConfig, IndexerRegistration, IndexerEventHandle {
        let indexer_addr = signer::address_of(indexer);
        
        // Check if indexer is registered
        assert!(exists<IndexerRegistration>(indexer_addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        
        // Get config to check sync interval
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        
        // Check if indexer is active
        let registration = borrow_global_mut<IndexerRegistration>(indexer_addr);
        assert!(registration.is_active, error::permission_denied(E_NOT_AUTHORIZED));
        
        let now = timestamp::now_seconds();
        
        // Check if sync interval has passed
        assert!(now >= registration.last_sync + config.sync_interval, 
               error::invalid_state(E_SYNC_INTERVAL_NOT_REACHED));
        
        // Update last sync time
        registration.last_sync = now;
        
        // Emit event
        let event_handle = borrow_global_mut<IndexerEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.indexer_events,
            IndexerEvent {
                indexer_address: indexer_addr,
                event_type: EVENT_TYPE_SYNC,
                timestamp: now,
                data_type: registration.indexer_type,
                targets_count: 0,
            }
        );
    }
    
    #[view]
    public fun is_indexer_registered(addr: address): bool {
        exists<IndexerRegistration>(addr)
    }
    
    #[view]
    public fun is_indexer_active(addr: address): bool acquires IndexerRegistration {
        assert!(exists<IndexerRegistration>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let registration = borrow_global<IndexerRegistration>(addr);
        registration.is_active
    }
    
    #[view]
    public fun get_indexer_type(addr: address): u8 acquires IndexerRegistration {
        assert!(exists<IndexerRegistration>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let registration = borrow_global<IndexerRegistration>(addr);
        registration.indexer_type
    }
    
    #[view]
    public fun get_indexer_name(addr: address): String acquires IndexerRegistration {
        assert!(exists<IndexerRegistration>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let registration = borrow_global<IndexerRegistration>(addr);
        registration.name
    }
    
    #[view]
    public fun get_indexer_url(addr: address): String acquires IndexerRegistration {
        assert!(exists<IndexerRegistration>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let registration = borrow_global<IndexerRegistration>(addr);
        registration.url
    }
    
    #[view]
    public fun get_last_sync_time(addr: address): u64 acquires IndexerRegistration {
        assert!(exists<IndexerRegistration>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let registration = borrow_global<IndexerRegistration>(addr);
        registration.last_sync
    }
    
    #[view]
    public fun get_submission_count(addr: address): u64 acquires IndexerSubmission {
        assert!(exists<IndexerSubmission>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let submission = borrow_global<IndexerSubmission>(addr);
        submission.submission_count
    }
    
    #[view]
    public fun get_processed_addresses_count(addr: address): u64 acquires IndexerSubmission {
        assert!(exists<IndexerSubmission>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let submission = borrow_global<IndexerSubmission>(addr);
        submission.processed_addresses
    }
    
    #[view]
    public fun get_successful_submissions_count(addr: address): u64 acquires IndexerSubmission {
        assert!(exists<IndexerSubmission>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let submission = borrow_global<IndexerSubmission>(addr);
        submission.successful_submissions
    }
    
    #[view]
    public fun get_failed_submissions_count(addr: address): u64 acquires IndexerSubmission {
        assert!(exists<IndexerSubmission>(addr), error::not_found(E_INDEXER_NOT_REGISTERED));
        let submission = borrow_global<IndexerSubmission>(addr);
        submission.failed_submissions
    }
    
    #[view]
    public fun is_data_processing_enabled(): bool acquires IndexerConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        config.data_processing_enabled
    }
    
    #[view]
    public fun get_sync_interval(): u64 acquires IndexerConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        config.sync_interval
    }
    
    #[view]
    public fun get_max_targets_per_submission(): u64 acquires IndexerConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<IndexerConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<IndexerConfig>(config_addr);
        config.max_targets_per_submission
    }
}
