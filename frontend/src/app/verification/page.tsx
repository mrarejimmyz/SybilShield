"use client";

import React, { useState } from 'react';
import { Card, Title, Text, Button, TextInput, Select, SelectItem, Badge } from '@tremor/react';
import { useApi } from '@/lib/api-context';
import { CheckCircle, AlertTriangle, Clock } from 'lucide-react';

interface VerificationData {
  verification_id: string;
  address: string;
  verification_type: string;
  instructions: string;
  expires_at: string;
}

interface VerificationStatus {
  status: 'verified' | 'pending' | 'failed';
  timestamp: string;
}

const verificationTypes = [
  { value: 'social_twitter', label: 'Twitter Verification' },
  { value: 'social_github', label: 'GitHub Verification' },
  { value: 'did_web', label: 'DID Web Verification' },
  { value: 'pop_captcha', label: 'Proof of Personhood' },
  { value: 'kyc_basic', label: 'Basic KYC' }
];

export default function VerificationPage() {
  const { startVerification, checkVerificationStatus, completeVerification, loading, error } = useApi();
  
  const [address, setAddress] = useState('');
  const [verificationType, setVerificationType] = useState('social_twitter');
  const [verificationId, setVerificationId] = useState<string | null>(null);
  const [verificationData, setVerificationData] = useState<VerificationData | null>(null);
  const [proof, setProof] = useState('');
  const [status, setStatus] = useState<VerificationStatus | null>(null);
  
  const handleStartVerification = async () => {
    if (!address.trim()) return;
    
    try {
      const result = await startVerification(address, verificationType) as VerificationData;
      setVerificationId(result.verification_id);
      setVerificationData(result);
    } catch (err) {
      console.error('Error starting verification:', err);
    }
  };
  
  const handleCheckStatus = async () => {
    if (!verificationId) return;
    
    try {
      const result = await checkVerificationStatus(verificationId) as VerificationStatus;
      setStatus(result);
    } catch (err) {
      console.error('Error checking status:', err);
    }
  };
  
  const handleCompleteVerification = async () => {
    if (!verificationId || !proof.trim()) return;
    
    try {
      const result = await completeVerification(verificationId, { proof });
      setStatus(result as VerificationStatus);
    } catch (err) {
      console.error('Error completing verification:', err);
    }
  };
  
  const getStatusBadge = (status: string) => {
    if (status === 'verified') {
      return <Badge color="green" icon={CheckCircle}>Verified</Badge>;
    } else if (status === 'pending') {
      return <Badge color="yellow" icon={Clock}>Pending</Badge>;
    } else {
      return <Badge color="red" icon={AlertTriangle}>Failed</Badge>;
    }
  };

  return (
    <div className="space-y-8 p-6">
      <div>
        <h1 className="text-3xl font-bold">User Verification</h1>
        <p className="text-gray-500 mt-2">Verify your identity to enhance trust and security</p>
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <div className="space-y-4">
            <Title>Start Verification</Title>
            <Text>Begin the verification process by providing your address and selecting a verification method</Text>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Aptos Address</label>
                <TextInput
                  placeholder="Enter your Aptos address (0x...)"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Verification Type</label>
                <Select
                  value={verificationType}
                  onValueChange={setVerificationType}
                  placeholder="Select verification type"
                >
                  {verificationTypes.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </Select>
              </div>
              
              <Button 
                onClick={handleStartVerification} 
                loading={loading && !verificationId}
                disabled={!address.trim()}
                className="w-full"
              >
                Start Verification
              </Button>
            </div>
            
            {error && (
              <div className="p-4 bg-red-50 text-red-700 rounded-md">
                {error}
              </div>
            )}
          </div>
        </Card>
        
        {verificationData && (
          <Card>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <Title>Verification Instructions</Title>
                {status && getStatusBadge(status.status)}
              </div>
              
              <div className="p-4 bg-blue-50 rounded-md">
                <p className="text-blue-700">{verificationData.instructions}</p>
              </div>
              
              <div className="space-y-2">
                <Text>Verification ID</Text>
                <p className="text-sm text-gray-500">{verificationData.verification_id}</p>
              </div>
              
              <div className="space-y-2">
                <Text>Address</Text>
                <p className="text-sm text-gray-500 break-all">{verificationData.address}</p>
              </div>
              
              <div className="space-y-2">
                <Text>Verification Type</Text>
                <p className="text-sm text-gray-500">
                  {verificationTypes.find(t => t.value === verificationData.verification_type)?.label || 
                   verificationData.verification_type}
                </p>
              </div>
              
              <div className="space-y-2">
                <Text>Expires At</Text>
                <p className="text-sm text-gray-500">
                  {new Date(verificationData.expires_at).toLocaleString()}
                </p>
              </div>
              
              <div className="space-y-4 pt-4 border-t">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Verification Proof</label>
                  <TextInput
                    placeholder="Enter verification proof"
                    value={proof}
                    onChange={(e) => setProof(e.target.value)}
                  />
                  <p className="mt-1 text-xs text-gray-500">
                    Enter the proof required to complete your verification
                  </p>
                </div>
                
                <div className="flex space-x-4">
                  <Button 
                    onClick={handleCompleteVerification} 
                    loading={loading && !!verificationId && !!proof}
                    disabled={!proof.trim()}
                    className="flex-1"
                  >
                    Complete Verification
                  </Button>
                  
                  <Button 
                    onClick={handleCheckStatus} 
                    loading={loading && !!verificationId && !proof}
                    variant="secondary"
                    className="flex-1"
                  >
                    Check Status
                  </Button>
                </div>
              </div>
            </div>
          </Card>
        )}
      </div>
    </div>
  );
}
