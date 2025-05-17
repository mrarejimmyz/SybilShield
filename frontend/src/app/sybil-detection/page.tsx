"use client";

import React, { useState } from 'react';
import { Card, Title, Text, Button, TextInput, Select, SelectItem } from '@tremor/react';
import { useApi } from '@/lib/api-context';
import { useSybilCheck } from '@/lib/api-hooks';
import { Shield, AlertTriangle, CheckCircle } from 'lucide-react';

export default function SybilDetectionPage() {
  const [address, setAddress] = useState('');
  const [threshold, setThreshold] = useState('70');
  const [searchedAddress, setSearchedAddress] = useState<string | null>(null);
  
  const { result, loading, error } = useSybilCheck(searchedAddress, parseInt(threshold));
  
  const handleCheck = () => {
    if (address.trim()) {
      setSearchedAddress(address.trim());
    }
  };
  
  const getRiskColor = (score: number) => {
    if (score < 30) return 'text-green-600';
    if (score < 70) return 'text-yellow-600';
    return 'text-red-600';
  };
  
  const getRiskBadge = (score: number) => {
    if (score < 30) return 'bg-green-100 text-green-800';
    if (score < 70) return 'bg-yellow-100 text-yellow-800';
    return 'bg-red-100 text-red-800';
  };
  
  const getRiskIcon = (score: number) => {
    if (score < 30) return <CheckCircle className="h-8 w-8 text-green-600" />;
    if (score < 70) return <AlertTriangle className="h-8 w-8 text-yellow-600" />;
    return <Shield className="h-8 w-8 text-red-600" />;
  };

  return (
    <div className="space-y-8 p-6">
      <div>
        <h1 className="text-3xl font-bold">Sybil Detection</h1>
        <p className="text-gray-500 mt-2">Check if an address is a potential Sybil account</p>
      </div>
      
      <Card>
        <div className="space-y-4">
          <Title>Address Checker</Title>
          <Text>Enter an Aptos address to check its Sybil risk score</Text>
          
          <div className="flex flex-col md:flex-row gap-4">
            <TextInput
              placeholder="Enter Aptos address (0x...)"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="flex-1"
            />
            
            <div className="w-full md:w-48">
              <Select
                value={threshold}
                onValueChange={setThreshold}
                placeholder="Risk Threshold"
              >
                <SelectItem value="30">Low (30%)</SelectItem>
                <SelectItem value="50">Medium (50%)</SelectItem>
                <SelectItem value="70">High (70%)</SelectItem>
                <SelectItem value="90">Very High (90%)</SelectItem>
              </Select>
            </div>
            
            <Button 
              onClick={handleCheck} 
              loading={loading}
              disabled={!address.trim()}
              className="md:w-32"
            >
              Check
            </Button>
          </div>
          
          {error && (
            <div className="p-4 bg-red-50 text-red-700 rounded-md">
              {error}
            </div>
          )}
          
          {result && (
            <div className="mt-6 p-6 border rounded-lg">
              <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6">
                <div>
                  <h3 className="text-lg font-medium">Results for</h3>
                  <p className="text-gray-500 break-all">{result.address}</p>
                </div>
                <div className={`px-4 py-2 rounded-full mt-2 md:mt-0 ${getRiskBadge(result.risk_score)}`}>
                  {result.is_sybil ? 'Potential Sybil' : 'Likely Legitimate'}
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="flex flex-col items-center p-4 border rounded-lg">
                  {getRiskIcon(result.risk_score)}
                  <p className="mt-2 text-sm text-gray-500">Risk Score</p>
                  <p className={`text-2xl font-bold ${getRiskColor(result.risk_score)}`}>
                    {result.risk_score}%
                  </p>
                </div>
                
                <div className="flex flex-col items-center p-4 border rounded-lg">
                  <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center">
                    <span className="text-blue-600 font-bold">{result.confidence}%</span>
                  </div>
                  <p className="mt-2 text-sm text-gray-500">Confidence</p>
                  <p className="text-2xl font-bold text-blue-600">
                    {result.confidence}%
                  </p>
                </div>
                
                <div className="flex flex-col items-center p-4 border rounded-lg">
                  <div className="h-8 w-8 rounded-full bg-purple-100 flex items-center justify-center">
                    <span className="text-purple-600 font-bold">
                      {result.verification_status === 'verified' ? '✓' : 
                       result.verification_status === 'pending' ? '⋯' : '✗'}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-gray-500">Verification</p>
                  <p className="text-2xl font-bold text-purple-600 capitalize">
                    {result.verification_status}
                  </p>
                </div>
              </div>
              
              <div className="mt-6 text-sm text-gray-500">
                <p>Request ID: {result.request_id}</p>
                <p>Timestamp: {new Date(result.timestamp).toLocaleString()}</p>
              </div>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}
