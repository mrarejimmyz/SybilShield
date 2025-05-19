"use client";

import { useState, useEffect } from 'react';
import { useApi } from './api-context';

// Hook for checking if an address is a Sybil account
interface SybilCheckResult {
  address: string;
  risk_score: number;
  is_sybil: boolean;
  confidence: number;
  verification_status: 'verified' | 'pending' | 'none';
  request_id: string;
  timestamp: string;
}

export function useSybilCheck(address: string | null, threshold: number = 70) {
  const { contractAddress } = useApi();
  const [result, setResult] = useState<SybilCheckResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function checkAddress() {
      if (!address) return;
      
      setLoading(true);
      setError(null);
      
      try {
        // In a real implementation, this would call the API
        // For now, we'll simulate a response
        const response = await fetch(`http://localhost:8000/sybil/check`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            address,
            threshold,
            contract_address: contractAddress
          }),
        });
        
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        
        // Simulate API response for now
        // In production, this would be: const data = await response.json();
        const data: SybilCheckResult = {
          address,
          risk_score: Math.floor(Math.random() * 100),
          is_sybil: Math.random() > 0.7,
          confidence: Math.floor(Math.random() * 40) + 60,
          verification_status: (['verified', 'pending', 'none'][Math.floor(Math.random() * 3)]) as 'verified' | 'pending' | 'none',
          request_id: `req-${Math.random().toString(36).substring(2, 10)}`,
          timestamp: new Date().toISOString()
        };
        
        // Update risk score based on threshold
        data.is_sybil = data.risk_score >= threshold;
        
        setResult(data);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }
    
    checkAddress();
  }, [address, threshold, contractAddress]);
  
  return { result, loading, error };
}

// Interface for on-chain analytics data
interface OnChainFeatures {
  address: string;
  transaction_count: number;
  first_activity_timestamp: number;
  gas_usage_pattern: number;
  token_diversity: number;
  clustering_coefficient: number;
  temporal_pattern_score: number;
  last_updated: string;
}

// Hook for fetching on-chain data for analytics
export function useOnChainData(address: string | null) {
  const { contractAddress } = useApi();
  const [features, setFeatures] = useState<OnChainFeatures | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchOnChainData() {
      if (!address) return;
      
      setLoading(true);
      setError(null);
      
      try {
        // In a real implementation, this would call the API
        // For now, we'll simulate a response
        const response = await fetch(`http://localhost:8000/analytics/features`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            address,
            contract_address: contractAddress
          }),
        });
        
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        
        // Simulate API response for now
        // In production, this would be: const data = await response.json();
        const data = {
          address,
          transaction_count: Math.floor(Math.random() * 500) + 50,
          first_activity_timestamp: Date.now() - (Math.random() * 30 * 24 * 60 * 60 * 1000), // Random date in last 30 days
          gas_usage_pattern: Math.random(),
          token_diversity: Math.floor(Math.random() * 20) + 1,
          clustering_coefficient: Math.random(),
          temporal_pattern_score: Math.random(),
          last_updated: new Date().toISOString()
        };
        
        setFeatures(data);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }
    
    fetchOnChainData();
  }, [address, contractAddress]);
  
  return { features, loading, error };
}
