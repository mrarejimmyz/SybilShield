"use client";

import React from 'react';
import DashboardLayout from '@/components/layout/DashboardLayout';
import DashboardStats from '@/components/dashboard/DashboardStats';
import SybilAnalytics from '@/components/dashboard/SybilAnalytics';
import VerificationList from '@/components/dashboard/VerificationList';

export default function Home() {
  return (
    <DashboardLayout>
      <div className="page-header">
        <h1 className="page-title">SybilShield Dashboard</h1>
        <p className="page-description">Monitor and manage Sybil protection for your network</p>
      </div>
      
      <DashboardStats />
      
      <div className="section-divider"></div>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <SybilAnalytics />
        </div>
        <div>
          <VerificationList />
        </div>
      </div>
    </DashboardLayout>
  );
}
