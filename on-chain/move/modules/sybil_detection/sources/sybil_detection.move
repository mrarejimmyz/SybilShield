module aptos_sybil_shield::sybil_detection {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_RISK_THRESHOLD: u64 = 4;
    const E_ADDRESS_ALREADY_REGISTERED: u64 = 5;
    const E_INVALID_FACTOR_TYPE: u64 = 6;
    const E_INVALID_SCORE_RANGE: u64 = 7;
    const E_INVALID_CONFIDENCE_RANGE: u64 = 8;
    
    /// Verification status constants
    const VERIFICATION_STATUS_UNVERIFIED: u8 = 0;
    const VERIFICATION_STATUS_VERIFIED: u8 = 1;
    const VERIFICATION_STATUS_FLAGGED: u8 = 2;
    
    /// Factor type constants
    const FACTOR_TYPE_TRANSACTION_PATTERN: u8 = 1;
    const FACTOR_TYPE_CLUSTERING: u8 = 2;
    const FACTOR_TYPE_TEMPORAL: u8 = 3;
    const FACTOR_TYPE_GAS_USAGE: u8 = 4;
    
    /// Maximum number of risk factors to store per address
    const MAX_RISK_FACTORS: u64 = 20;
    
    /// Struct to store risk score for an address
    struct RiskScore has key {
        score: u64,                // 0-100, where 100 is highest risk
        last_updated: u64,         // timestamp of last update
        factors: vector<RiskFactor>,
        verification_status: u8,   // 0: unverified, 1: verified, 2: flagged
    }
    
    /// Risk factors that contribute to the overall risk score
    struct RiskFactor has store, drop, copy {
        factor_type: u8,           // 1: transaction pattern, 2: clustering, 3: temporal, 4: gas usage
        score: u64,                // 0-100 contribution to risk
        confidence: u64,           // 0-100 confidence in this factor
        timestamp: u64,            // when this factor was calculated
    }
    
    /// Configuration for the Sybil detection system
    struct SybilConfig has key {
        admin: address,
        risk_threshold: u64,       // threshold for flagging addresses (0-100)
        enabled_factors: vector<u8>, // which factors are enabled
        verification_required: bool, // whether verification is required
        authorized_services: vector<address>, // addresses authorized to update risk scores
    }
    
    /// Events
    struct SybilDetectionEvent has drop, store {
        address: address,
        risk_score: u64,
        timestamp: u64,
        is_flagged: bool,
    }
    
    /// Event handle for Sybil detection events
    struct SybilEventHandle has key {
        detection_events: event::EventHandle<SybilDetectionEvent>,
    }
    
    /// Initialize the Sybil detection module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<SybilConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create default config with enabled factors
        let enabled_factors = vector::empty<u8>();
        vector::push_back(&mut enabled_factors, FACTOR_TYPE_TRANSACTION_PATTERN);
        vector::push_back(&mut enabled_factors, FACTOR_TYPE_CLUSTERING);
        vector::push_back(&mut enabled_factors, FACTOR_TYPE_TEMPORAL);
        vector::push_back(&mut enabled_factors, FACTOR_TYPE_GAS_USAGE);
        
        // Initialize authorized services with admin
        let authorized_services = vector::empty<address>();
        vector::push_back(&mut authorized_services, admin_addr);
        
        let config = SybilConfig {
            admin: admin_addr,
            risk_threshold: 70,    // default threshold
            enabled_factors,
            verification_required: false,
            authorized_services,
        };
        
        // Create event handle
        let event_handle = SybilEventHandle {
            detection_events: account::new_event_handle<SybilDetectionEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, event_handle);
    }
    
    /// Update risk threshold
    public entry fun update_risk_threshold(admin: &signer, new_threshold: u64) acquires SybilConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<SybilConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<SybilConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate threshold
        assert!(new_threshold <= 100, error::invalid_argument(E_INVALID_RISK_THRESHOLD));
        
        // Update threshold
        config.risk_threshold = new_threshold;
    }
    
    /// Enable or disable verification requirement
    public entry fun set_verification_required(admin: &signer, required: bool) acquires SybilConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<SybilConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<SybilConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update verification requirement
        config.verification_required = required;
    }
    
    /// Add an authorized service
    public entry fun add_authorized_service(admin: &signer, service_addr: address) acquires SybilConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<SybilConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<SybilConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if service is already authorized
        let (is_authorized, _) = vector::index_of(&config.authorized_services, &service_addr);
        if (!is_authorized) {
            vector::push_back(&mut config.authorized_services, service_addr);
        };
    }
    
    /// Remove an authorized service
    public entry fun remove_authorized_service(admin: &signer, service_addr: address) acquires SybilConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<SybilConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<SybilConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if service is authorized and remove it
        let (is_authorized, index) = vector::index_of(&config.authorized_services, &service_addr);
        if (is_authorized) {
            vector::remove(&mut config.authorized_services, index);
        };
    }
    
    /// Register an address for Sybil detection
    public entry fun register_address(account: &signer) {
        let addr = signer::address_of(account);
        
        // Check if already registered
        assert!(!exists<RiskScore>(addr), error::already_exists(E_ADDRESS_ALREADY_REGISTERED));
        
        // Create empty risk score
        let factors = vector::empty<RiskFactor>();
        let risk_score = RiskScore {
            score: 0,
            last_updated: timestamp::now_seconds(),
            factors,
            verification_status: VERIFICATION_STATUS_UNVERIFIED,
        };
        
        move_to(account, risk_score);
    }
    
    /// Update risk score for an address (called by authorized services)
    public entry fun update_risk_score(
        service: &signer,
        target_addr: address,
        new_score: u64,
        factor_type: u8,
        factor_score: u64,
        factor_confidence: u64
    ) acquires RiskScore, SybilConfig, SybilEventHandle {
        let service_addr = signer::address_of(service);
        
        // Get config to check authorization and thresholds
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        
        // Check if service is authorized
        let (is_authorized, _) = vector::index_of(&config.authorized_services, &service_addr);
        assert!(is_authorized, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate factor type
        assert!(
            factor_type == FACTOR_TYPE_TRANSACTION_PATTERN || 
            factor_type == FACTOR_TYPE_CLUSTERING || 
            factor_type == FACTOR_TYPE_TEMPORAL || 
            factor_type == FACTOR_TYPE_GAS_USAGE,
            error::invalid_argument(E_INVALID_FACTOR_TYPE)
        );
        
        // Validate score ranges
        assert!(new_score <= 100, error::invalid_argument(E_INVALID_SCORE_RANGE));
        assert!(factor_score <= 100, error::invalid_argument(E_INVALID_SCORE_RANGE));
        assert!(factor_confidence <= 100, error::invalid_argument(E_INVALID_CONFIDENCE_RANGE));
        
        // Ensure target address has a risk score
        assert!(exists<RiskScore>(target_addr), error::not_found(E_NOT_INITIALIZED));
        
        // Update risk score
        let risk_score = borrow_global_mut<RiskScore>(target_addr);
        risk_score.score = new_score;
        risk_score.last_updated = timestamp::now_seconds();
        
        // Add new factor, maintaining maximum size
        let new_factor = RiskFactor {
            factor_type,
            score: factor_score,
            confidence: factor_confidence,
            timestamp: timestamp::now_seconds(),
        };
        
        // If we've reached the maximum number of factors, remove the oldest one
        if (vector::length(&risk_score.factors) >= MAX_RISK_FACTORS) {
            // Remove the oldest factor (first one in the vector)
            // In a production system, we might want a more sophisticated approach
            vector::remove(&mut risk_score.factors, 0);
        };
        
        vector::push_back(&mut risk_score.factors, new_factor);
        
        // Check if address should be flagged
        let is_flagged = new_score >= config.risk_threshold;
        if (is_flagged) {
            risk_score.verification_status = VERIFICATION_STATUS_FLAGGED;
        };
        
        // Emit event
        let event_handle = borrow_global_mut<SybilEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.detection_events,
            SybilDetectionEvent {
                address: target_addr,
                risk_score: new_score,
                timestamp: timestamp::now_seconds(),
                is_flagged,
            }
        );
    }
    
    /// Set verification status for an address (called by authorized services)
    public entry fun set_verification_status(
        service: &signer,
        target_addr: address,
        status: u8
    ) acquires RiskScore, SybilConfig {
        let service_addr = signer::address_of(service);
        
        // Get config to check authorization
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        
        // Check if service is authorized
        let (is_authorized, _) = vector::index_of(&config.authorized_services, &service_addr);
        assert!(is_authorized, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate status
        assert!(
            status == VERIFICATION_STATUS_UNVERIFIED || 
            status == VERIFICATION_STATUS_VERIFIED || 
            status == VERIFICATION_STATUS_FLAGGED,
            error::invalid_argument(E_INVALID_SCORE_RANGE)
        );
        
        // Ensure target address has a risk score
        assert!(exists<RiskScore>(target_addr), error::not_found(E_NOT_INITIALIZED));
        
        // Update verification status
        let risk_score = borrow_global_mut<RiskScore>(target_addr);
        risk_score.verification_status = status;
    }
    
    /// Get risk score for an address (public view function)
    #[view]
    public fun get_risk_score(addr: address): u64 acquires RiskScore {
        assert!(exists<RiskScore>(addr), error::not_found(E_NOT_INITIALIZED));
        let risk_score = borrow_global<RiskScore>(addr);
        risk_score.score
    }
    
    /// Get detailed risk information for an address
    #[view]
    public fun get_risk_details(addr: address): (u64, u64, u8) acquires RiskScore {
        assert!(exists<RiskScore>(addr), error::not_found(E_NOT_INITIALIZED));
        let risk_score = borrow_global<RiskScore>(addr);
        (risk_score.score, risk_score.last_updated, risk_score.verification_status)
    }
    
    /// Check if an address is flagged as potential Sybil
    #[view]
    public fun is_flagged(addr: address): bool acquires RiskScore, SybilConfig {
        assert!(exists<RiskScore>(addr), error::not_found(E_NOT_INITIALIZED));
        
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        
        let risk_score = borrow_global<RiskScore>(addr);
        risk_score.score >= config.risk_threshold
    }
    
    /// Check if verification is required
    #[view]
    public fun is_verification_required(): bool acquires SybilConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        config.verification_required
    }
    
    /// Get verification status for an address
    #[view]
    public fun get_verification_status(addr: address): u8 acquires RiskScore {
        assert!(exists<RiskScore>(addr), error::not_found(E_NOT_INITIALIZED));
        let risk_score = borrow_global<RiskScore>(addr);
        risk_score.verification_status
    }
    
    /// Check if a service is authorized
    #[view]
    public fun is_service_authorized(service_addr: address): bool acquires SybilConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        let (is_authorized, _) = vector::index_of(&config.authorized_services, &service_addr);
        is_authorized
    }
    
    /// Get the current risk threshold
    #[view]
    public fun get_risk_threshold(): u64 acquires SybilConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<SybilConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<SybilConfig>(config_addr);
        config.risk_threshold
    }
}
