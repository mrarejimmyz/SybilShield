"use client";

import React, { createContext, useContext, useState, ReactNode } from 'react';

const ApiContext = createContext<ApiContextType | undefined>(undefined);

// Contract address from the deployment logs
const CONTRACT_ADDRESS = "0x5148fdbe077de13e44294282db4c101387ebf9efb2ff8fbe50bd6e8d01d93764";

// Default API URL - replace with actual backend URL when available
const API_BASE_URL = "http://localhost:8000";

interface VerificationData {
  address?: string;
  verification_type?: string;
  contract_address?: string;
  [key: string]: string | undefined;
}

interface ApiContextType {
  // Sybil detection methods
  startVerification: (address: string, verificationType: string) => Promise<unknown>;
  checkVerificationStatus: (verificationId: string) => Promise<unknown>;
  completeVerification: (verificationId: string, data: VerificationData) => Promise<unknown>;
  
  // General state
  loading: boolean;
  error: string | null;
  
  // Contract info
  contractAddress: string;
}

export function ApiProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Helper function for API calls
  const apiCall = async (endpoint: string, method: string = 'GET', data?: VerificationData) => {
    setLoading(true);
    setError(null);
    
    try {
      const options: RequestInit = {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
      };
      
      if (data) {
        options.body = JSON.stringify(data);
      }
      
      const response = await fetch(`${API_BASE_URL}${endpoint}`, options);
      
      if (!response.ok) {
        throw new Error(`API error: ${response.status} ${response.statusText}`);
      }
      
      const result = await response.json();
      return result;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  // Verification methods
  const startVerification = async (address: string, verificationType: string) => {
    return apiCall('/verification/start', 'POST', { 
      address, 
      verification_type: verificationType,
      contract_address: CONTRACT_ADDRESS
    });
  };
  
  const checkVerificationStatus = async (verificationId: string) => {
    return apiCall(`/verification/status/${verificationId}`);
  };
  
  const completeVerification = async (verificationId: string, data: VerificationData) => {
    return apiCall(`/verification/complete/${verificationId}`, 'POST', {
      ...data,
      contract_address: CONTRACT_ADDRESS
    });
  };

  const value = {
    startVerification,
    checkVerificationStatus,
    completeVerification,
    loading,
    error,
    contractAddress: CONTRACT_ADDRESS
  };

  return <ApiContext.Provider value={value}>{children}</ApiContext.Provider>;
}

export function useApi() {
  const context = useContext(ApiContext);
  
  if (context === undefined) {
    throw new Error('useApi must be used within an ApiProvider');
  }
  
  return context;
}
