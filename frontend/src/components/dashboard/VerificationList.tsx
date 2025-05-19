"use client";

import React from 'react';
import { AlertTriangle, CheckCircle, Activity } from 'lucide-react';

interface VerificationCardProps {
  address: string;
  status: 'verified' | 'pending' | 'rejected';
  verificationType: string;
  timestamp: string;
}

const statusColors = {
  verified: 'bg-success/10 text-success',
  pending: 'bg-warning/10 text-warning',
  rejected: 'bg-danger/10 text-danger'
};

const statusIcons = {
  verified: <CheckCircle className="h-4 w-4 text-success" />,
  pending: <Activity className="h-4 w-4 text-warning" />,
  rejected: <AlertTriangle className="h-4 w-4 text-danger" />
};

const VerificationCard = ({ address, status, verificationType, timestamp }: VerificationCardProps) => (
  <div className="verification-card">
    <div className="verification-header">
      <div>
        <p className="text-sm font-medium text-text-secondary">Address</p>
        <p className="text-text-primary truncate max-w-xs font-mono text-sm">{address}</p>
      </div>
      <div className={`verification-status ${statusColors[status]}`}>
        <div className="flex items-center justify-center">
          <span className="mr-1.5">{statusIcons[status]}</span>
          <span className="text-sm font-medium capitalize">{status}</span>
        </div>
      </div>
    </div>
    <div className="verification-footer">
      <div>
        <p className="text-xs text-text-tertiary">Verification Type</p>
        <p className="text-sm font-medium">{verificationType}</p>
      </div>
      <div className="text-right">
        <p className="text-xs text-text-tertiary">Timestamp</p>
        <p className="text-sm">{new Date(timestamp).toLocaleString()}</p>
      </div>
    </div>
  </div>
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
    <div className="card">
      <div className="card-header">
        <h3 className="card-title">Recent Verifications</h3>
        <p className="card-description">Latest user verification activities</p>
      </div>
      
      <div className="card-content">
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
      
      <div className="card-footer">
        <button className="btn btn-secondary w-full">
          View All Verifications
        </button>
      </div>
    </div>
  );
}
