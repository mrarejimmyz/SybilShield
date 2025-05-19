"use client";

import React from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  return (
    <div className="main-layout">
      <Sidebar />
      <div className="main-content">
        <Header />
        <main className="main-body">
          <div className="page-container">
            {children}
          </div>
        </main>
        <footer className="footer">
          <p>© 2025 SybilShield · Sybil Protection System</p>
        </footer>
      </div>
    </div>
  );
}
