"use client";

import React from 'react';
import { Card, Title, Text, Flex, Grid } from '@tremor/react';
import { Shield, AlertTriangle, Users, CheckCircle, Activity } from 'lucide-react';

interface VerificationCardProps {
  address: string;
  status: 'verified' | 'pending' | 'rejected';
  verificationType: string;
  timestamp: string;
}

const statusColors = {
  verified: 'bg-green-100 text-green-800',
  pending: 'bg-yellow-100 text-yellow-800',
  rejected: 'bg-red-100 text-red-800'
};

const statusIcons = {
  verified: <CheckCircle className="h-5 w-5 text-green-600" />,
  pending: <Activity className="h-5 w-5 text-yellow-600" />,
  rejected: <AlertTriangle className="h-5 w-5 text-red-600" />
};

const VerificationCard = ({ address, status, verificationType, timestamp }: VerificationCardProps) => (
  <Card className="max-w-full">
    <Flex justifyContent="between" alignItems="center">
      <div>
        <Text className="font-medium">Address</Text>
        <Text className="text-gray-500 truncate max-w-xs">{address}</Text>
      </div>
      <div className={`px-3 py-1 rounded-full ${statusColors[status]}`}>
        <Flex alignItems="center" justifyContent="center">
          <span className="mr-2">{statusIcons[status]}</span>
          <Text className="capitalize">{status}</Text>
        </Flex>
      </div>
    </Flex>
    <div className="mt-4">
      <Flex justifyContent="between">
        <div>
          <Text className="text-sm text-gray-500">Verification Type</Text>
          <Text>{verificationType}</Text>
        </div>
        <div>
          <Text className="text-sm text-gray-500">Timestamp</Text>
          <Text>{new Date(timestamp).toLocaleString()}</Text>
        </div>
      </Flex>
    </div>
  </Card>
);

export default function VerificationList() {
  // This would be fetched from the API in a real implementation
  const verifications = [
    {
      address: '0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t',
      status: 'verified' as const,
      verificationType: 'Social Media',
      timestamp: '2025-05-15T14:30:00Z'
    },
    {
      address: '0x2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1a',
      status: 'pending' as const,
      verificationType: 'DID Web',
      timestamp: '2025-05-16T09:15:00Z'
    },
    {
      address: '0x3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1a2b',
      status: 'rejected' as const,
      verificationType: 'KYC Basic',
      timestamp: '2025-05-14T18:45:00Z'
    },
    {
      address: '0x4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1a2b3c',
      status: 'verified' as const,
      verificationType: 'POP Captcha',
      timestamp: '2025-05-13T11:20:00Z'
    }
  ];

  return (
    <div className="space-y-6">
      <div>
        <Title>Recent Verifications</Title>
        <Text>Latest user verification activities</Text>
      </div>
      
      <div className="space-y-4">
        {verifications.map((verification, index) => (
          <VerificationCard 
            key={index}
            address={verification.address}
            status={verification.status}
            verificationType={verification.verificationType}
            timestamp={verification.timestamp}
          />
        ))}
      </div>
    </div>
  );
}
