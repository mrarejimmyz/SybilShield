"use client";

import React from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {

  
  return (
    <div className="flex h-screen bg-background">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-y-auto p-4 md:p-6 transition-all">
          <div className="max-w-7xl mx-auto">
            {children}
          </div>
        </main>
        <footer className="py-3 px-6 text-center text-text-tertiary text-sm border-t border-text-tertiary/10">
          <p>© 2025 SybilShield · Sybil Protection System</p>
        </footer>
      </div>
    </div>
  );
}
