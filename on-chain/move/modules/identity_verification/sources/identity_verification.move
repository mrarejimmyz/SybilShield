module aptos_sybil_shield::identity_verification {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_sybil_shield::sybil_detection;
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_VERIFICATION_FAILED: u64 = 4;
    const E_ALREADY_VERIFIED: u64 = 5;
    const E_INVALID_PROOF: u64 = 6;
    const E_INVALID_VERIFICATION_TYPE: u64 = 7;
    const E_VERIFICATION_EXPIRED: u64 = 8;
    const E_VERIFICATION_IN_PROGRESS: u64 = 9;
    
    /// Verification types
    const VERIFICATION_TYPE_SOCIAL: u8 = 1;
    const VERIFICATION_TYPE_DECENTRALIZED_ID: u8 = 2;
    const VERIFICATION_TYPE_PROOF_OF_PERSONHOOD: u8 = 3;
    const VERIFICATION_TYPE_MULTI_FACTOR: u8 = 4;
    
    /// Verification status
    const STATUS_UNVERIFIED: u8 = 0;
    const STATUS_PENDING: u8 = 1;
    const STATUS_VERIFIED: u8 = 2;
    const STATUS_REJECTED: u8 = 3;
    const STATUS_EXPIRED: u8 = 4;
    
    /// Default verification validity period (30 days in seconds)
    const DEFAULT_VERIFICATION_VALIDITY: u64 = 2592000; // 30 * 24 * 60 * 60
    
    /// Identity verification record
    struct IdentityVerification has key {
        address: address,
        verification_type: u8,
        status: u8,
        timestamp: u64,
        expiration: u64,
        verification_data: vector<u8>, // hash of verification data
        verifier: address,             // address that performed verification
        attempts: u64,                 // number of verification attempts
        last_updated: u64,             // timestamp of last update
    }
    
    /// Configuration for identity verification
    struct VerificationConfig has key {
        admin: address,
        authorized_verifiers: vector<address>,
        required_verification_types: vector<u8>,
        verification_validity_period: u64, // in seconds
        max_verification_attempts: u64,    // maximum number of attempts allowed
        cooldown_period: u64,              // cooldown period after rejection (in seconds)
    }
    
    /// Events
    struct VerificationEvent has drop, store {
        address: address,
        verification_type: u8,
        status: u8,
        timestamp: u64,
        verifier: address,
    }
    
    /// Event handle for verification events
    struct VerificationEventHandle has key {
        verification_events: event::EventHandle<VerificationEvent>,
    }
    
    /// Initialize the identity verification module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<VerificationConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create default config
        let authorized_verifiers = vector::empty<address>();
        vector::push_back(&mut authorized_verifiers, admin_addr);
        
        let required_verification_types = vector::empty<u8>();
        vector::push_back(&mut required_verification_types, VERIFICATION_TYPE_SOCIAL);
        
        let config = VerificationConfig {
            admin: admin_addr,
            authorized_verifiers,
            required_verification_types,
            verification_validity_period: DEFAULT_VERIFICATION_VALIDITY,
            max_verification_attempts: 3,
            cooldown_period: 86400, // 24 hours in seconds
        };
        
        // Create event handle
        let event_handle = VerificationEventHandle {
            verification_events: account::new_event_handle<VerificationEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, event_handle);
    }
    
    /// Add an authorized verifier
    public entry fun add_verifier(admin: &signer, verifier: address) acquires VerificationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<VerificationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<VerificationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Add verifier if not already in list
        if (!vector::contains(&config.authorized_verifiers, &verifier)) {
            vector::push_back(&mut config.authorized_verifiers, verifier);
        };
    }
    
    /// Remove an authorized verifier
    public entry fun remove_verifier(admin: &signer, verifier: address) acquires VerificationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<VerificationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<VerificationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Find and remove verifier
        let (found, index) = vector::index_of(&config.authorized_verifiers, &verifier);
        if (found) {
            vector::remove(&mut config.authorized_verifiers, index);
        };
    }
    
    /// Update verification validity period
    public entry fun update_validity_period(admin: &signer, period: u64) acquires VerificationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<VerificationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<VerificationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update validity period
        config.verification_validity_period = period;
    }
    
    /// Update maximum verification attempts
    public entry fun update_max_attempts(admin: &signer, max_attempts: u64) acquires VerificationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<VerificationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<VerificationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update max attempts
        config.max_verification_attempts = max_attempts;
    }
    
    /// Update cooldown period after rejection
    public entry fun update_cooldown_period(admin: &signer, period: u64) acquires VerificationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<VerificationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<VerificationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update cooldown period
        config.cooldown_period = period;
    }
    
    /// Request verification (called by user)
    public entry fun request_verification(
        account: &signer,
        verification_type: u8,
        verification_data: vector<u8>
    ) acquires VerificationConfig, VerificationEventHandle, IdentityVerification {
        let addr = signer::address_of(account);
        let current_time = timestamp::now_seconds();
        
        // Get config
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        // Validate verification type
        assert!(
            verification_type == VERIFICATION_TYPE_SOCIAL || 
            verification_type == VERIFICATION_TYPE_DECENTRALIZED_ID || 
            verification_type == VERIFICATION_TYPE_PROOF_OF_PERSONHOOD || 
            verification_type == VERIFICATION_TYPE_MULTI_FACTOR,
            error::invalid_argument(E_INVALID_VERIFICATION_TYPE)
        );
        
        // Check if already has a verification record
        if (exists<IdentityVerification>(addr)) {
            let verification = borrow_global_mut<IdentityVerification>(addr);
            
            // Check if already verified and not expired
            assert!(
                verification.status != STATUS_VERIFIED || 
                (verification.expiration != 0 && current_time > verification.expiration),
                error::already_exists(E_ALREADY_VERIFIED)
            );
            
            // Check if in cooldown period after rejection
            if (verification.status == STATUS_REJECTED) {
                let cooldown_end = verification.last_updated + config.cooldown_period;
                assert!(current_time >= cooldown_end, error::invalid_state(E_VERIFICATION_IN_PROGRESS));
            };
            
            // Check if pending
            assert!(verification.status != STATUS_PENDING, error::invalid_state(E_VERIFICATION_IN_PROGRESS));
            
            // Update existing verification record
            verification.verification_type = verification_type;
            verification.status = STATUS_PENDING;
            verification.timestamp = current_time;
            verification.verification_data = verification_data;
            verification.attempts = verification.attempts + 1;
            verification.last_updated = current_time;
        } else {
            // Create new verification record with pending status
            let verification = IdentityVerification {
                address: addr,
                verification_type,
                status: STATUS_PENDING,
                timestamp: current_time,
                expiration: 0, // will be set when verified
                verification_data,
                verifier: @0x0, // will be set when verified
                attempts: 1,
                last_updated: current_time,
            };
            
            move_to(account, verification);
        };
        
        // Emit event
        let event_handle = borrow_global_mut<VerificationEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.verification_events,
            VerificationEvent {
                address: addr,
                verification_type,
                status: STATUS_PENDING,
                timestamp: current_time,
                verifier: @0x0,
            }
        );
    }
    
    /// Verify identity (called by authorized verifier)
    public entry fun verify_identity(
        verifier: &signer,
        target_addr: address,
        verification_result: bool,
        proof: vector<u8>
    ) acquires IdentityVerification, VerificationConfig, VerificationEventHandle {
        let verifier_addr = signer::address_of(verifier);
        let current_time = timestamp::now_seconds();
        
        // Get config to check authorization
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        // Check if verifier is authorized
        assert!(vector::contains(&config.authorized_verifiers, &verifier_addr), 
               error::permission_denied(E_NOT_AUTHORIZED));
        
        // Check if target has requested verification
        assert!(exists<IdentityVerification>(target_addr), error::not_found(E_NOT_INITIALIZED));
        
        // Update verification status
        let verification = borrow_global_mut<IdentityVerification>(target_addr);
        
        // Check if verification is pending
        assert!(verification.status == STATUS_PENDING, error::invalid_state(E_VERIFICATION_FAILED));
        
        // Validate proof (in a real implementation, this would be more complex)
        assert!(vector::length(&proof) > 0, error::invalid_argument(E_INVALID_PROOF));
        
        // Update verification record
        if (verification_result) {
            verification.status = STATUS_VERIFIED;
            verification.expiration = current_time + config.verification_validity_period;
            
            // If verification is successful, update the Sybil detection status
            // This assumes the sybil_detection module has a set_verification_status function
            if (sybil_detection::is_verification_required()) {
                // In a real implementation, we would call sybil_detection::set_verification_status
                // For hackathon purposes, we'll just note this integration point
            };
        } else {
            verification.status = STATUS_REJECTED;
        };
        
        verification.verifier = verifier_addr;
        verification.last_updated = current_time;
        
        // Emit event
        let event_handle = borrow_global_mut<VerificationEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.verification_events,
            VerificationEvent {
                address: target_addr,
                verification_type: verification.verification_type,
                status: verification.status,
                timestamp: current_time,
                verifier: verifier_addr,
            }
        );
    }
    
    /// Renew verification (called by user)
    public entry fun renew_verification(
        account: &signer,
        verification_data: vector<u8>
    ) acquires IdentityVerification, VerificationConfig, VerificationEventHandle {
        let addr = signer::address_of(account);
        let current_time = timestamp::now_seconds();
        
        // Check if has a verification record
        assert!(exists<IdentityVerification>(addr), error::not_found(E_NOT_INITIALIZED));
        
        // Get config
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        
        let verification = borrow_global_mut<IdentityVerification>(addr);
        
        // Check if was previously verified
        assert!(verification.status == STATUS_VERIFIED || verification.status == STATUS_EXPIRED, 
               error::invalid_state(E_VERIFICATION_FAILED));
        
        // Update verification record
        verification.status = STATUS_PENDING;
        verification.timestamp = current_time;
        verification.verification_data = verification_data;
        verification.attempts = verification.attempts + 1;
        verification.last_updated = current_time;
        
        // Emit event
        let event_handle = borrow_global_mut<VerificationEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.verification_events,
            VerificationEvent {
                address: addr,
                verification_type: verification.verification_type,
                status: STATUS_PENDING,
                timestamp: current_time,
                verifier: @0x0,
            }
        );
    }
    
    #[view]
    public fun is_verified(addr: address): bool acquires IdentityVerification {
        if (!exists<IdentityVerification>(addr)) {
            return false
        };
        
        let verification = borrow_global<IdentityVerification>(addr);
        let current_time = timestamp::now_seconds();
        
        verification.status == STATUS_VERIFIED && 
            (verification.expiration == 0 || current_time <= verification.expiration)
    }
    
    #[view]
    public fun get_verification_status(addr: address): u8 acquires IdentityVerification {
        if (!exists<IdentityVerification>(addr)) {
            return STATUS_UNVERIFIED
        };
        
        let verification = borrow_global<IdentityVerification>(addr);
        let current_time = timestamp::now_seconds();
        
        // Check if verification has expired
        if (verification.status == STATUS_VERIFIED && 
            verification.expiration != 0 && 
            current_time > verification.expiration) {
            return STATUS_EXPIRED
        };
        
        verification.status
    }
    
    #[view]
    public fun get_verification_expiration(addr: address): u64 acquires IdentityVerification {
        if (!exists<IdentityVerification>(addr)) {
            return 0
        };
        
        let verification = borrow_global<IdentityVerification>(addr);
        verification.expiration
    }
    
    #[view]
    public fun get_verification_attempts(addr: address): u64 acquires IdentityVerification {
        if (!exists<IdentityVerification>(addr)) {
            return 0
        };
        
        let verification = borrow_global<IdentityVerification>(addr);
        verification.attempts
    }
    
    #[view]
    public fun is_verifier_authorized(verifier: address): bool acquires VerificationConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        vector::contains(&config.authorized_verifiers, &verifier)
    }
    
    #[view]
    public fun get_verification_validity_period(): u64 acquires VerificationConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        config.verification_validity_period
    }
    
    #[view]
    public fun get_max_verification_attempts(): u64 acquires VerificationConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        config.max_verification_attempts
    }
    
    #[view]
    public fun get_cooldown_period(): u64 acquires VerificationConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<VerificationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<VerificationConfig>(config_addr);
        
        config.cooldown_period
    }
}
