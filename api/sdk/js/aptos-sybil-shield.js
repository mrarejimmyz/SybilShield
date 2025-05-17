/**
 * AptosSybilShield JavaScript SDK
 * 
 * This SDK provides easy integration with the AptosSybilShield API for
 * Sybil detection and identity verification on the Aptos blockchain.
 */

class AptosSybilShield {
  /**
   * Initialize the SDK
   * @param {Object} options - Configuration options
   * @param {string} options.apiKey - API key for authentication
   * @param {string} options.baseUrl - Base URL for the API (optional)
   * @param {number} options.timeout - Request timeout in milliseconds (optional)
   */
  constructor(options) {
    if (!options.apiKey) {
      throw new Error('API key is required');
    }

    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl || 'https://api.aptossybilshield.com';
    this.timeout = options.timeout || 30000;
  }

  /**
   * Make an API request
   * @private
   * @param {string} method - HTTP method
   * @param {string} endpoint - API endpoint
   * @param {Object} data - Request data
   * @returns {Promise<Object>} - API response
   */
  async _request(method, endpoint, data = null) {
    const url = `${this.baseUrl}${endpoint}`;
    
    const headers = {
      'Content-Type': 'application/json',
      'api-key': this.apiKey
    };

    const options = {
      method,
      headers,
      timeout: this.timeout
    };

    if (data && (method === 'POST' || method === 'PUT')) {
      options.body = JSON.stringify(data);
    }

    try {
      const response = await fetch(url, options);
      const responseData = await response.json();

      if (!response.ok) {
        throw new Error(responseData.detail || 'API request failed');
      }

      return responseData;
    } catch (error) {
      console.error('AptosSybilShield API error:', error);
      throw error;
    }
  }

  /**
   * Check if an address is a potential Sybil
   * @param {Object} params - Check parameters
   * @param {string} params.address - Aptos address to check
   * @param {number} params.threshold - Risk threshold (0-100) (optional)
   * @param {boolean} params.includeFeatures - Whether to include feature details (optional)
   * @returns {Promise<Object>} - Check result
   */
  async checkAddress(params) {
    if (!params.address) {
      throw new Error('Address is required');
    }

    return this._request('POST', '/api/check', {
      address: params.address,
      threshold: params.threshold || 70,
      include_features: params.includeFeatures || false
    });
  }

  /**
   * Check multiple addresses for potential Sybils
   * @param {Object} params - Batch check parameters
   * @param {string[]} params.addresses - List of Aptos addresses to check
   * @param {number} params.threshold - Risk threshold (0-100) (optional)
   * @returns {Promise<Object>} - Batch check result
   */
  async batchCheckAddresses(params) {
    if (!params.addresses || !Array.isArray(params.addresses) || params.addresses.length === 0) {
      throw new Error('At least one address is required');
    }

    return this._request('POST', '/api/batch-check', {
      addresses: params.addresses,
      threshold: params.threshold || 70
    });
  }

  /**
   * Get the result of a previous check
   * @param {string} requestId - Request ID from a previous check
   * @returns {Promise<Object>} - Check result
   */
  async getCheckResult(requestId) {
    if (!requestId) {
      throw new Error('Request ID is required');
    }

    return this._request('GET', `/api/check/${requestId}`);
  }

  /**
   * Start the verification process for an address
   * @param {Object} params - Verification parameters
   * @param {string} params.address - Aptos address to verify
   * @param {string} params.verificationType - Type of verification
   * @param {string} params.callbackUrl - Callback URL for verification completion (optional)
   * @returns {Promise<Object>} - Verification details
   */
  async startVerification(params) {
    if (!params.address) {
      throw new Error('Address is required');
    }

    if (!params.verificationType) {
      throw new Error('Verification type is required');
    }

    return this._request('POST', '/api/verify', {
      address: params.address,
      verification_type: params.verificationType,
      callback_url: params.callbackUrl
    });
  }

  /**
   * Check the status of a verification process
   * @param {string} verificationId - Verification ID
   * @returns {Promise<Object>} - Verification status
   */
  async checkVerificationStatus(verificationId) {
    if (!verificationId) {
      throw new Error('Verification ID is required');
    }

    return this._request('GET', `/api/verify/${verificationId}`);
  }

  /**
   * Complete the verification process
   * @param {Object} params - Completion parameters
   * @param {string} params.verificationId - Verification ID
   * @param {any} params.proof - Verification proof
   * @returns {Promise<Object>} - Verification result
   */
  async completeVerification(params) {
    if (!params.verificationId) {
      throw new Error('Verification ID is required');
    }

    if (!params.proof) {
      throw new Error('Proof is required');
    }

    return this._request('POST', `/api/verify/${params.verificationId}/complete`, {
      proof: params.proof
    });
  }

  /**
   * Subscribe to webhook notifications
   * @param {Object} params - Subscription parameters
   * @param {string[]} params.eventTypes - Event types to subscribe to
   * @param {string} params.url - Webhook URL
   * @param {string} params.secret - Webhook secret for signature verification (optional)
   * @returns {Promise<Object>} - Subscription details
   */
  async subscribeWebhook(params) {
    if (!params.eventTypes || !Array.isArray(params.eventTypes) || params.eventTypes.length === 0) {
      throw new Error('At least one event type is required');
    }

    if (!params.url) {
      throw new Error('Webhook URL is required');
    }

    return this._request('POST', '/api/webhooks', {
      event_types: params.eventTypes,
      url: params.url,
      secret: params.secret
    });
  }

  /**
   * Unsubscribe from webhook notifications
   * @param {string} subscriptionId - Subscription ID
   * @returns {Promise<Object>} - Unsubscription result
   */
  async unsubscribeWebhook(subscriptionId) {
    if (!subscriptionId) {
      throw new Error('Subscription ID is required');
    }

    return this._request('DELETE', `/api/webhooks/${subscriptionId}`);
  }

  /**
   * Check the health of the API
   * @returns {Promise<Object>} - Health status
   */
  async healthCheck() {
    return this._request('GET', '/health');
  }
}

// Export for CommonJS and ES modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = AptosSybilShield;
} else if (typeof define === 'function' && define.amd) {
  define([], function() { return AptosSybilShield; });
} else {
  window.AptosSybilShield = AptosSybilShield;
}
