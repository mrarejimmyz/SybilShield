"use client";

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { 
  BarChart3, 
  Shield, 
  Users, 
  AlertTriangle, 
  Settings, 
  HelpCircle,
  Home,
  Activity,
  Lock,
  Menu,
  X
} from 'lucide-react';

const navItems = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Sybil Detection', href: '/sybil-detection', icon: Shield },
  { name: 'Analytics', href: '/analytics', icon: BarChart3 },
  { name: 'User Verification', href: '/verification', icon: Users },
  { name: 'Alerts', href: '/alerts', icon: AlertTriangle },
  { name: 'Privacy', href: '/privacy', icon: Lock },
  { name: 'Activity', href: '/activity', icon: Activity },
  { name: 'Settings', href: '/settings', icon: Settings },
  { name: 'Help', href: '/help', icon: HelpCircle },
];

export default function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <>
      {/* Mobile menu button - visible only on small screens */}
      <button 
        className="fixed top-4 left-4 z-50 md:hidden bg-primary rounded-full p-2 text-white shadow-lg"
        onClick={() => setCollapsed(!collapsed)}
        aria-label={collapsed ? "Open menu" : "Close menu"}
      >
        {collapsed ? <Menu size={20} /> : <X size={20} />}
      </button>
      
      <div className={`sidebar fixed inset-y-0 left-0 z-40 flex flex-col transition-all duration-300 ease-in-out md:relative ${
        collapsed ? '-translate-x-full md:translate-x-0 md:w-20' : 'translate-x-0 w-64'
      }`}>
        <div className="flex items-center justify-between p-4">
          <div className={`transition-opacity duration-200 ${collapsed ? 'md:opacity-0' : 'opacity-100'}`}>
            <h1 className="text-xl font-bold text-text-inverted">SybilShield</h1>
            <p className="text-text-tertiary text-sm">Protection System</p>
          </div>
          
          {/* Desktop collapse button */}
          <button 
            className="hidden md:block text-text-tertiary hover:text-text-inverted"
            onClick={() => setCollapsed(!collapsed)}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {collapsed ? <Menu size={20} /> : <X size={20} />}
          </button>
        </div>
        
        <nav className="flex-1 overflow-y-auto py-4">
          <ul className="space-y-2 px-3">
            {navItems.map((item) => {
              const isActive = pathname === item.href;
              const Icon = item.icon;
              
              return (
                <li key={item.name}>
                  <Link 
                    href={item.href}
                    className={`sidebar-link group ${
                      isActive ? 'active' : ''
                    }`}
                    title={collapsed ? item.name : ''}
                  >
                    <Icon className={`${collapsed ? 'mx-auto' : 'mr-3'} h-5 w-5 transition-all`} />
                    <span className={`transition-opacity duration-200 ${
                      collapsed ? 'md:hidden' : 'block'
                    }`}>
                      {item.name}
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
        
        <div className="mt-auto p-4 border-t border-gray-700/50">
          <div className="px-2 py-2 rounded-md bg-surface/10 hover:bg-surface/20 transition-all">
            <div className="flex items-center">
              <div className="h-8 w-8 rounded-full bg-primary flex items-center justify-center text-white">
                <span className="font-medium">AS</span>
              </div>
              <div className={`ml-3 transition-opacity duration-200 ${
                collapsed ? 'md:opacity-0' : 'opacity-100'
              }`}>
                <p className="text-sm font-medium text-text-inverted">Aptos Network</p>
                <p className="text-xs text-text-tertiary">Devnet Ready</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
