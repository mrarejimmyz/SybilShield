"use client";

import React from 'react';
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
  Lock
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

  return (
    <div className="flex flex-col h-full bg-gray-900 text-white w-64 p-4">
      <div className="mb-8 px-2">
        <h1 className="text-2xl font-bold">AptosSybilShield</h1>
        <p className="text-gray-400 text-sm">Sybil Protection System</p>
      </div>
      
      <nav className="flex-1">
        <ul className="space-y-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            const Icon = item.icon;
            
            return (
              <li key={item.name}>
                <Link 
                  href={item.href}
                  className={`flex items-center px-2 py-2 rounded-md text-sm font-medium transition-colors ${
                    isActive 
                      ? 'bg-blue-800 text-white' 
                      : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                  }`}
                >
                  <Icon className="mr-3 h-5 w-5" />
                  {item.name}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
      
      <div className="mt-auto pt-4 border-t border-gray-700">
        <div className="px-2 py-2 rounded-md bg-gray-800">
          <div className="flex items-center">
            <div className="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center">
              <span className="font-medium">AS</span>
            </div>
            <div className="ml-3">
              <p className="text-sm font-medium">Aptos Network</p>
              <p className="text-xs text-gray-400">Devnet Ready</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
