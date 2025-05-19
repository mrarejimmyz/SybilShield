"use client";

import React from 'react';
import { 
  DeltaType 
} from '@tremor/react';
import { Shield, AlertTriangle, Users, CheckCircle } from 'lucide-react';

type TremorColor = 'slate' | 'gray' | 'zinc' | 'neutral' | 'stone' | 'red' | 'orange' | 'amber' | 
                   'yellow' | 'lime' | 'green' | 'emerald' | 'teal' | 'cyan' | 'sky' | 
                   'blue' | 'indigo' | 'violet' | 'purple' | 'fuchsia' | 'pink' | 'rose';

interface StatCardProps {
  title: string;
  metric: string | number;
  icon: React.ReactNode;
  color: TremorColor;
  delta?: string;
  deltaType?: DeltaType;
}

const StatCard = ({ title, metric, icon, color, delta, deltaType }: StatCardProps) => (
  <div className="stats-card">
    <div className="stats-card-header">
      <h3 className="stats-card-title">{title}</h3>
      <div className={`stats-icon`}>
        {icon}
      </div>
    </div>
    <div className="mb-2">
      <span className="stats-value">{metric}</span>
    </div>
    {delta && deltaType && (
      <div className="flex items-center">
        <span className={`stats-delta ${
          deltaType === 'increase' 
            ? 'increase' 
            : deltaType === 'decrease' 
              ? 'decrease'
              : 'neutral'
        }`}>
          {delta}
        </span>
      </div>
    )}
  </div>
);

export default function DashboardStats() {
  return (
    <div>
      <h2 className="text-xl font-semibold mb-6">System Overview</h2>
      <div className="dashboard-grid">
        <StatCard 
          title="Sybil Detection Rate" 
          metric="8.4%" 
          icon={<Shield className="h-5 w-5 text-primary" />}
          color="blue"
          delta="+1.2% from last week"
          deltaType="increase"
        />
        <StatCard 
          title="Verified Users" 
          metric="12,543" 
          icon={<CheckCircle className="h-5 w-5 text-success" />}
          color="green"
          delta="+573 new verifications"
          deltaType="increase"
        />
        <StatCard 
          title="Alerts" 
          metric="24" 
          icon={<AlertTriangle className="h-5 w-5 text-warning" />}
          color="amber"
          delta="-3 from yesterday"
          deltaType="decrease"
        />
        <StatCard 
          title="Active Users" 
          metric="45,789" 
          icon={<Users className="h-5 w-5 text-info" />}
          color="indigo"
          delta="+12% this month"
          deltaType="increase"
        />
      </div>
      
      <div className="card mt-8">
        <div className="card-header">
          <h3 className="card-title">System Health</h3>
          <p className="card-description">Current status of the Sybil detection system</p>
        </div>
        <div className="card-content">
          <div className="space-y-6">
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-text-secondary">API Performance</span>
                <span className="font-medium">92%</span>
              </div>
              <div className="progress-bar">
                <div className="progress-bar-fill bg-primary" style={{ width: '92%' }}></div>
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-text-secondary">ML Model Accuracy</span>
                <span className="font-medium">87%</span>
              </div>
              <div className="progress-bar">
                <div className="progress-bar-fill bg-success" style={{ width: '87%' }}></div>
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-text-secondary">On-chain Verification</span>
                <span className="font-medium">95%</span>
              </div>
              <div className="progress-bar">
                <div className="progress-bar-fill bg-info" style={{ width: '95%' }}></div>
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-text-secondary">Privacy System</span>
                <span className="font-medium">99%</span>
              </div>
              <div className="progress-bar">
                <div className="progress-bar-fill bg-primary-dark" style={{ width: '99%' }}></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
