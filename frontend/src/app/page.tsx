"use client";

import React from 'react';
import DashboardLayout from '@/components/layout/DashboardLayout';
import DashboardStats from '@/components/dashboard/DashboardStats';
import SybilAnalytics from '@/components/dashboard/SybilAnalytics';
import VerificationList from '@/components/dashboard/VerificationList';

export default function Home() {
  return (
    <DashboardLayout>
      <div className="space-y-8">
        <div className="flex flex-col space-y-2">
          <h1 className="text-3xl font-bold">SybilShield Dashboard</h1>
          <p className="text-text-secondary">Monitor and manage Sybil protection for your network</p>
        </div>
        
        <DashboardStats />
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <SybilAnalytics />
          </div>
          <div>
            <VerificationList />
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
