"use client";

import React, { useState } from 'react';
import { Bell, User, Search, Moon, Sun } from 'lucide-react';

export default function Header() {
  const [darkMode, setDarkMode] = useState(false);
  
  const toggleDarkMode = () => {
    setDarkMode(!darkMode);
    // In a real implementation, this would toggle a class on the document body
    // or update a context value to switch between light and dark modes
  };

  return (
    <header className="bg-surface border-b border-text-tertiary/10 h-16 flex items-center justify-between px-6 shadow-sm">
      <div className="flex items-center">
        <div className="relative">
          <input
            type="text"
            placeholder="Search..."
            className="pl-10 pr-4 py-2 border border-text-tertiary/30 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary w-64 bg-background transition-all"
            aria-label="Search"
          />
          <Search className="absolute left-3 top-2.5 h-5 w-5 text-text-tertiary" />
        </div>
      </div>
      
      <div className="flex items-center space-x-4">
        <button 
          className="p-2 rounded-full hover:bg-background relative transition-all"
          aria-label="Toggle dark mode"
          onClick={toggleDarkMode}
        >
          {darkMode ? (
            <Sun className="h-5 w-5 text-text-secondary hover:text-text-primary transition-colors" />
          ) : (
            <Moon className="h-5 w-5 text-text-secondary hover:text-text-primary transition-colors" />
          )}
        </button>
        
        <button 
          className="p-2 rounded-full hover:bg-background relative transition-all"
          aria-label="Notifications"
        >
          <Bell className="h-5 w-5 text-text-secondary hover:text-text-primary transition-colors" />
          <span className="absolute top-1 right-1 h-2 w-2 bg-danger rounded-full ring-2 ring-surface"></span>
        </button>
        
        <div className="flex items-center">
          <div className="h-9 w-9 rounded-full bg-primary flex items-center justify-center text-white shadow-sm hover:bg-primary-dark transition-colors">
            <User className="h-5 w-5" />
          </div>
          <div className="ml-3">
            <span className="font-medium text-text-primary">Admin</span>
            <p className="text-xs text-text-tertiary">System</p>
          </div>
        </div>
      </div>
    </header>
  );
}
