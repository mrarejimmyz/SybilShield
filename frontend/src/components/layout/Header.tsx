"use client";

import React from 'react';
import { Bell, User, Search } from 'lucide-react';

export default function Header() {
  return (
    <header className="header">
      <div className="flex-1 flex items-center">
        <div className="header-search">
          <input
            type="text"
            placeholder="Search..."
            className="w-64"
            aria-label="Search"
          />
          <Search className="icon" />
        </div>
      </div>
      
      <div className="header-actions">
        <button 
          className="p-2 rounded-full hover:bg-background relative transition-all"
          aria-label="Notifications"
        >
          <Bell className="h-5 w-5 text-text-secondary hover:text-text-primary transition-colors" />
          <span className="absolute top-1 right-1 h-2 w-2 bg-danger rounded-full ring-2 ring-surface"></span>
        </button>
        
        <div className="header-profile">
          <div className="h-9 w-9 rounded-full bg-primary flex items-center justify-center text-white shadow-sm hover:bg-primary-dark transition-colors">
            <User className="h-5 w-5" />
          </div>
          <div className="ml-3 hide-on-mobile">
            <span className="font-medium text-text-primary">Admin</span>
            <p className="text-xs text-text-tertiary">System</p>
          </div>
        </div>
      </div>
    </header>
  );
}
