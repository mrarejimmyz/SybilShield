module aptos_sybil_shield::reputation_scoring {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_sybil_shield::identity_verification;
    
    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_SCORE: u64 = 4;
    const E_ACCOUNT_NOT_REGISTERED: u64 = 5;
    const E_INVALID_CATEGORY: u64 = 6;
    const E_INVALID_WEIGHT: u64 = 7;
    const E_HISTORY_LIMIT_EXCEEDED: u64 = 8;
    
    /// Reputation categories
    const CATEGORY_TRANSACTION_HISTORY: u8 = 1;
    const CATEGORY_COMMUNITY_PARTICIPATION: u8 = 2;
    const CATEGORY_VERIFICATION_LEVEL: u8 = 3;
    const CATEGORY_LONGEVITY: u8 = 4;
    const CATEGORY_NETWORK_ACTIVITY: u8 = 5;
    const CATEGORY_GOVERNANCE_PARTICIPATION: u8 = 6;
    
    /// Default weights
    const DEFAULT_WEIGHT_TRANSACTION_HISTORY: u64 = 40;
    const DEFAULT_WEIGHT_COMMUNITY_PARTICIPATION: u64 = 20;
    const DEFAULT_WEIGHT_VERIFICATION_LEVEL: u64 = 30;
    const DEFAULT_WEIGHT_LONGEVITY: u64 = 10;
    
    /// Maximum history entries to store per address
    const MAX_HISTORY_ENTRIES: u64 = 50;
    
    /// Reputation score for an address
    struct ReputationScore has key {
        address: address,
        overall_score: u64,            // 0-100, where 100 is highest reputation
        category_scores: vector<CategoryScore>,
        last_updated: u64,             // timestamp of last update
        history: vector<ScoreHistory>,
        decay_rate: u64,               // Rate at which scores decay if not updated (0-100)
        last_decay_update: u64,        // Last time decay was applied
    }
    
    /// Category-specific score
    struct CategoryScore has store, drop, copy {
        category: u8,
        score: u64,                    // 0-100 score for this category
        weight: u64,                   // Weight of this category in overall score (0-100)
        last_updated: u64,             // timestamp of last update
    }
    
    /// Historical score record
    struct ScoreHistory has store, drop, copy {
        overall_score: u64,
        timestamp: u64,
        reason: vector<u8>,            // Optional reason for score change
    }
    
    /// Configuration for reputation scoring
    struct ReputationConfig has key {
        admin: address,
        authorized_scorers: vector<address>,
        category_weights: vector<CategoryWeight>,
        min_verification_level: u8,    // Minimum verification level required
        decay_period: u64,             // Period in seconds for score decay
        default_decay_rate: u64,       // Default decay rate (0-100)
        min_threshold: u64,            // Minimum threshold for reputation
    }
    
    /// Category weight configuration
    struct CategoryWeight has store, drop, copy {
        category: u8,
        weight: u64,                   // 0-100, sum of all weights should be 100
    }
    
    /// Events
    struct ReputationEvent has drop, store {
        address: address,
        old_score: u64,
        new_score: u64,
        category: u8,
        timestamp: u64,
        scorer: address,               // Address that updated the score
    }
    
    /// Event handle for reputation events
    struct ReputationEventHandle has key {
        reputation_events: event::EventHandle<ReputationEvent>,
    }
    
    /// Initialize the reputation scoring module
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check if already initialized
        assert!(!exists<ReputationConfig>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create default config with authorized scorers
        let authorized_scorers = vector::empty<address>();
        vector::push_back(&mut authorized_scorers, admin_addr);
        
        // Create default category weights
        let category_weights = vector::empty<CategoryWeight>();
        vector::push_back(&mut category_weights, CategoryWeight { 
            category: CATEGORY_TRANSACTION_HISTORY, 
            weight: DEFAULT_WEIGHT_TRANSACTION_HISTORY 
        });
        vector::push_back(&mut category_weights, CategoryWeight { 
            category: CATEGORY_COMMUNITY_PARTICIPATION, 
            weight: DEFAULT_WEIGHT_COMMUNITY_PARTICIPATION 
        });
        vector::push_back(&mut category_weights, CategoryWeight { 
            category: CATEGORY_VERIFICATION_LEVEL, 
            weight: DEFAULT_WEIGHT_VERIFICATION_LEVEL 
        });
        vector::push_back(&mut category_weights, CategoryWeight { 
            category: CATEGORY_LONGEVITY, 
            weight: DEFAULT_WEIGHT_LONGEVITY 
        });
        
        let config = ReputationConfig {
            admin: admin_addr,
            authorized_scorers,
            category_weights,
            min_verification_level: 1,
            decay_period: 30 * 24 * 60 * 60, // 30 days in seconds
            default_decay_rate: 5,           // 5% decay per period
            min_threshold: 30,               // Minimum threshold for reputation
        };
        
        // Create event handle
        let event_handle = ReputationEventHandle {
            reputation_events: account::new_event_handle<ReputationEvent>(admin),
        };
        
        move_to(admin, config);
        move_to(admin, event_handle);
    }
    
    /// Add an authorized scorer
    public entry fun add_scorer(admin: &signer, scorer: address) acquires ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Add scorer if not already in list
        if (!vector::contains(&config.authorized_scorers, &scorer)) {
            vector::push_back(&mut config.authorized_scorers, scorer);
        };
    }
    
    /// Remove an authorized scorer
    public entry fun remove_scorer(admin: &signer, scorer: address) acquires ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Find and remove scorer
        let (found, index) = vector::index_of(&config.authorized_scorers, &scorer);
        if (found) {
            vector::remove(&mut config.authorized_scorers, index);
        };
    }
    
    /// Update category weight
    public entry fun update_category_weight(
        admin: &signer, 
        category: u8, 
        weight: u64
    ) acquires ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate category and weight
        assert!(
            category == CATEGORY_TRANSACTION_HISTORY || 
            category == CATEGORY_COMMUNITY_PARTICIPATION || 
            category == CATEGORY_VERIFICATION_LEVEL || 
            category == CATEGORY_LONGEVITY ||
            category == CATEGORY_NETWORK_ACTIVITY ||
            category == CATEGORY_GOVERNANCE_PARTICIPATION,
            error::invalid_argument(E_INVALID_CATEGORY)
        );
        assert!(weight <= 100, error::invalid_argument(E_INVALID_WEIGHT));
        
        // Find and update category weight
        let len = vector::length(&config.category_weights);
        let i = 0;
        let found = false;
        
        while (i < len) {
            let cat_weight = vector::borrow_mut(&mut config.category_weights, i);
            if (cat_weight.category == category) {
                cat_weight.weight = weight;
                found = true;
                break
            };
            i = i + 1;
        };
        
        // If category not found, add it
        if (!found) {
            vector::push_back(&mut config.category_weights, CategoryWeight {
                category,
                weight,
            });
        };
    }
    
    /// Update decay parameters
    public entry fun update_decay_parameters(
        admin: &signer,
        decay_period: u64,
        default_decay_rate: u64
    ) acquires ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate decay rate
        assert!(default_decay_rate <= 100, error::invalid_argument(E_INVALID_SCORE));
        
        // Update decay parameters
        config.decay_period = decay_period;
        config.default_decay_rate = default_decay_rate;
    }
    
    /// Update minimum threshold
    public entry fun update_min_threshold(
        admin: &signer,
        min_threshold: u64
    ) acquires ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global_mut<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate threshold
        assert!(min_threshold <= 100, error::invalid_argument(E_INVALID_SCORE));
        
        // Update minimum threshold
        config.min_threshold = min_threshold;
    }
    
    /// Register an address for reputation scoring
    public entry fun register_address(account: &signer) acquires ReputationConfig {
        let addr = signer::address_of(account);
        
        // Check if already registered
        assert!(!exists<ReputationScore>(addr), error::already_exists(E_ACCOUNT_NOT_REGISTERED));
        
        // Get config for default values
        let config_addr = @aptos_sybil_shield;
        assert!(exists<ReputationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(config_addr);
        
        // Create empty reputation score
        let category_scores = vector::empty<CategoryScore>();
        let history = vector::empty<ScoreHistory>();
        
        // Add default category scores
        let now = timestamp::now_seconds();
        
        // Add scores for each category in the config
        let weights_len = vector::length(&config.category_weights);
        let j = 0;
        
        while (j < weights_len) {
            let weight = vector::borrow(&config.category_weights, j);
            let default_score = 50; // Default starting score
            
            // Special handling for verification level
            if (weight.category == CATEGORY_VERIFICATION_LEVEL) {
                default_score = 0; // Start at 0 until verified
            };
            
            // Special handling for longevity
            if (weight.category == CATEGORY_LONGEVITY) {
                default_score = 10; // Start low, increases over time
            };
            
            vector::push_back(&mut category_scores, CategoryScore {
                category: weight.category,
                score: default_score,
                weight: weight.weight,
                last_updated: now,
            });
            
            j = j + 1;
        };
        
        // Create initial history entry with empty reason
        vector::push_back(&mut history, ScoreHistory {
            overall_score: 50,
            timestamp: now,
            reason: vector::empty<u8>(),
        });
        
        let reputation_score = ReputationScore {
            address: addr,
            overall_score: 50,  // Default starting score
            category_scores,
            last_updated: now,
            history,
            decay_rate: config.default_decay_rate,
            last_decay_update: now,
        };
        
        move_to(account, reputation_score);
    }
    
    /// Update reputation score for a specific category
    public entry fun update_category_score(
        scorer: &signer,
        target_addr: address,
        category: u8,
        new_score: u64,
        reason: vector<u8>
    ) acquires ReputationScore, ReputationConfig, ReputationEventHandle {
        let scorer_addr = signer::address_of(scorer);
        
        // Get config to check authorization
        let config_addr = @aptos_sybil_shield;
        assert!(exists<ReputationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(config_addr);
        
        // Check if scorer is authorized
        assert!(vector::contains(&config.authorized_scorers, &scorer_addr), 
               error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate category
        assert!(
            category == CATEGORY_TRANSACTION_HISTORY || 
            category == CATEGORY_COMMUNITY_PARTICIPATION || 
            category == CATEGORY_VERIFICATION_LEVEL || 
            category == CATEGORY_LONGEVITY ||
            category == CATEGORY_NETWORK_ACTIVITY ||
            category == CATEGORY_GOVERNANCE_PARTICIPATION,
            error::invalid_argument(E_INVALID_CATEGORY)
        );
        
        // Validate score
        assert!(new_score <= 100, error::invalid_argument(E_INVALID_SCORE));
        
        // Check if target has reputation score
        assert!(exists<ReputationScore>(target_addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        
        // Update category score
        let reputation = borrow_global_mut<ReputationScore>(target_addr);
        let old_overall_score = reputation.overall_score;
        let now = timestamp::now_seconds();
        
        // Apply decay if needed
        apply_decay(reputation, now, config.decay_period);
        
        // Find and update category score
        let len = vector::length(&reputation.category_scores);
        let i = 0;
        let found = false;
        
        while (i < len) {
            let cat_score = vector::borrow_mut(&mut reputation.category_scores, i);
            if (cat_score.category == category) {
                cat_score.score = new_score;
                cat_score.last_updated = now;
                found = true;
                break
            };
            i = i + 1;
        };
        
        // If category not found, add it
        if (!found) {
            // Find weight for this category
            let cat_weight = 10; // Default weight
            let weights_len = vector::length(&config.category_weights);
            let j = 0;
            
            while (j < weights_len) {
                let weight = vector::borrow(&config.category_weights, j);
                if (weight.category == category) {
                    cat_weight = weight.weight;
                    break
                };
                j = j + 1;
            };
            
            vector::push_back(&mut reputation.category_scores, CategoryScore {
                category,
                score: new_score,
                weight: cat_weight,
                last_updated: now,
            });
        };
        
        // Recalculate overall score
        let total_score = 0;
        let total_weight = 0;
        let scores_len = vector::length(&reputation.category_scores);
        let k = 0;
        
        while (k < scores_len) {
            let cat_score = vector::borrow(&reputation.category_scores, k);
            total_score = total_score + (cat_score.score * cat_score.weight);
            total_weight = total_weight + cat_score.weight;
            k = k + 1;
        };
        
        // Calculate weighted average
        if (total_weight > 0) {
            reputation.overall_score = total_score / total_weight;
        };
        
        reputation.last_updated = now;
        
        // Add history entry, maintaining maximum size
        if (vector::length(&reputation.history) >= MAX_HISTORY_ENTRIES) {
            // Remove the oldest entry
            vector::remove(&mut reputation.history, 0);
        };
        
        vector::push_back(&mut reputation.history, ScoreHistory {
            overall_score: reputation.overall_score,
            timestamp: now,
            reason,
        });
        
        // Emit event
        let event_handle = borrow_global_mut<ReputationEventHandle>(config_addr);
        event::emit_event(
            &mut event_handle.reputation_events,
            ReputationEvent {
                address: target_addr,
                old_score: old_overall_score,
                new_score: reputation.overall_score,
                category,
                timestamp: now,
                scorer: scorer_addr,
            }
        );
    }
    
    /// Update decay rate for a specific address
    public entry fun update_decay_rate(
        admin: &signer,
        target_addr: address,
        decay_rate: u64
    ) acquires ReputationScore, ReputationConfig {
        let admin_addr = signer::address_of(admin);
        
        // Check if initialized and caller is admin
        assert!(exists<ReputationConfig>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(admin_addr);
        assert!(admin_addr == config.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Validate decay rate
        assert!(decay_rate <= 100, error::invalid_argument(E_INVALID_SCORE));
        
        // Check if target has reputation score
        assert!(exists<ReputationScore>(target_addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        
        // Update decay rate
        let reputation = borrow_global_mut<ReputationScore>(target_addr);
        reputation.decay_rate = decay_rate;
    }
    
    /// Apply score decay based on time elapsed
    fun apply_decay(
        reputation: &mut ReputationScore,
        current_time: u64,
        decay_period: u64
    ) {
        // Check if decay should be applied
        if (reputation.decay_rate == 0 || decay_period == 0) {
            return
        };
        
        let time_since_last_decay = current_time - reputation.last_decay_update;
        
        // Apply decay if at least one period has passed
        if (time_since_last_decay >= decay_period) {
            // Calculate number of periods elapsed
            let periods = time_since_last_decay / decay_period;
            
            // Apply decay to each category score
            let len = vector::length(&reputation.category_scores);
            let i = 0;
            
            while (i < len) {
                let cat_score = vector::borrow_mut(&mut reputation.category_scores, i);
                
                // Apply decay formula: score = score * (1 - decay_rate/100)^periods
                // For simplicity, we'll use a linear approximation
                let decay_amount = (cat_score.score * reputation.decay_rate * periods) / 100;
                
                // Ensure score doesn't go below 0
                if (decay_amount < cat_score.score) {
                    cat_score.score = cat_score.score - decay_amount;
                } else {
                    cat_score.score = 0;
                };
                
                i = i + 1;
            };
            
            // Recalculate overall score
            let total_score = 0;
            let total_weight = 0;
            let scores_len = vector::length(&reputation.category_scores);
            let k = 0;
            
            while (k < scores_len) {
                let cat_score = vector::borrow(&reputation.category_scores, k);
                total_score = total_score + (cat_score.score * cat_score.weight);
                total_weight = total_weight + cat_score.weight;
                k = k + 1;
            };
            
            // Calculate weighted average
            if (total_weight > 0) {
                reputation.overall_score = total_score / total_weight;
            };
            
            // Update last decay update time
            reputation.last_decay_update = current_time;
        };
    }
    
    /// Get overall reputation score
    #[view]
    public fun get_overall_score(addr: address): u64 acquires ReputationScore, ReputationConfig {
        assert!(exists<ReputationScore>(addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        let reputation = borrow_global<ReputationScore>(addr);
        
        // Get config for decay period
        let config_addr = @aptos_sybil_shield;
        assert!(exists<ReputationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(config_addr);
        
        // Calculate score with decay (view-only, doesn't modify state)
        let now = timestamp::now_seconds();
        
        // Check if decay should be applied
        if (reputation.decay_rate == 0 || config.decay_period == 0) {
            return reputation.overall_score
        };
        
        let time_since_last_decay = now - reputation.last_decay_update;
        
        // Apply decay if at least one period has passed
        if (time_since_last_decay >= config.decay_period) {
            // Calculate number of periods elapsed
            let periods = time_since_last_decay / config.decay_period;
            
            // Apply decay formula: score = score * (1 - decay_rate/100)^periods
            // For simplicity, we'll use a linear approximation
            let decay_amount = (reputation.overall_score * reputation.decay_rate * periods) / 100;
            
            // Ensure score doesn't go below 0
            if (decay_amount < reputation.overall_score) {
                return reputation.overall_score - decay_amount
            } else {
                return 0
            };
        };
        
        reputation.overall_score
    }
    
    /// Get category score
    #[view]
    public fun get_category_score(addr: address, category: u8): u64 acquires ReputationScore {
        assert!(exists<ReputationScore>(addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        let reputation = borrow_global<ReputationScore>(addr);
        
        let len = vector::length(&reputation.category_scores);
        let i = 0;
        
        while (i < len) {
            let cat_score = vector::borrow(&reputation.category_scores, i);
            if (cat_score.category == category) {
                return cat_score.score
            };
            i = i + 1;
        };
        
        0 // Return 0 if category not found
    }
    
    /// Get all category scores
    #[view]
    public fun get_all_category_scores(addr: address): vector<u8> acquires ReputationScore {
        assert!(exists<ReputationScore>(addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        let reputation = borrow_global<ReputationScore>(addr);
        
        let result = vector::empty<u8>();
        let len = vector::length(&reputation.category_scores);
        let i = 0;
        
        while (i < len) {
            let cat_score = vector::borrow(&reputation.category_scores, i);
            vector::push_back(&mut result, cat_score.category);
            vector::push_back(&mut result, (cat_score.score as u8));
            i = i + 1;
        };
        
        result
    }
    
    /// Check if reputation score meets minimum threshold
    #[view]
    public fun meets_minimum_threshold(addr: address, threshold: u64): bool acquires ReputationScore, ReputationConfig {
        if (!exists<ReputationScore>(addr)) {
            return false
        };
        
        get_overall_score(addr) >= threshold
    }
    
    /// Check if reputation score meets system minimum threshold
    #[view]
    public fun meets_system_minimum_threshold(addr: address): bool acquires ReputationScore, ReputationConfig {
        if (!exists<ReputationScore>(addr)) {
            return false
        };
        
        // Get config for minimum threshold
        let config_addr = @aptos_sybil_shield;
        assert!(exists<ReputationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(config_addr);
        
        get_overall_score(addr) >= config.min_threshold
    }
    
    /// Get reputation history
    #[view]
    public fun get_reputation_history(addr: address): vector<u64> acquires ReputationScore {
        assert!(exists<ReputationScore>(addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        let reputation = borrow_global<ReputationScore>(addr);
        
        let result = vector::empty<u64>();
        let len = vector::length(&reputation.history);
        let i = 0;
        
        while (i < len) {
            let history_entry = vector::borrow(&reputation.history, i);
            vector::push_back(&mut result, history_entry.overall_score);
            vector::push_back(&mut result, history_entry.timestamp);
            i = i + 1;
        };
        
        result
    }
    
    /// Get last update timestamp
    #[view]
    public fun get_last_update_timestamp(addr: address): u64 acquires ReputationScore {
        assert!(exists<ReputationScore>(addr), error::not_found(E_ACCOUNT_NOT_REGISTERED));
        let reputation = borrow_global<ReputationScore>(addr);
        reputation.last_updated
    }
    
    /// Check if a scorer is authorized
    #[view]
    public fun is_scorer_authorized(scorer: address): bool acquires ReputationConfig {
        let config_addr = @aptos_sybil_shield;
        assert!(exists<ReputationConfig>(config_addr), error::not_found(E_NOT_INITIALIZED));
        let config = borrow_global<ReputationConfig>(config_addr);
        
        vector::contains(&config.authorized_scorers, &scorer)
    }
}
