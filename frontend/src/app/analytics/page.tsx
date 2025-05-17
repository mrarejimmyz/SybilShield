"use client";

import React, { useState } from 'react';
import { Card, Title, Text, Button, TextInput, Select, SelectItem, Tab, TabGroup, TabList, TabPanel, TabPanels } from '@tremor/react';
import { useOnChainData } from '@/lib/api-hooks';
import { BarChart, AreaChart } from '@tremor/react';
import { Activity, Clock, Zap, Coins, Network } from 'lucide-react';

export default function AnalyticsPage() {
  const [address, setAddress] = useState('');
  const [analyzedAddress, setAnalyzedAddress] = useState<string | null>(null);
  
  const { features, loading, error } = useOnChainData(analyzedAddress);
  
  const handleAnalyze = () => {
    if (address.trim()) {
      setAnalyzedAddress(address.trim());
    }
  };
  
  // Mock time series data based on features
  const generateTimeSeriesData = () => {
    if (!features) return [];
    
    const now = new Date();
    const data = [];
    
    for (let i = 30; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      
      // Generate somewhat random but consistent data based on address
      const dayFactor = (features.transaction_count % (i + 1) + 1) / 10;
      
      data.push({
        date: date.toISOString().split('T')[0],
        'Transaction Count': Math.floor(features.transaction_count * dayFactor * 0.1) + 1,
        'Gas Usage': Math.floor(features.gas_usage_pattern * 100 * dayFactor),
        'Token Interactions': Math.floor(features.token_diversity * dayFactor)
      });
    }
    
    return data;
  };
  
  const timeSeriesData = features ? generateTimeSeriesData() : [];
  
  // Feature importance data
  const featureImportanceData = features ? [
    {
      feature: 'Transaction Patterns',
      importance: Math.floor(features.transaction_count % 100)
    },
    {
      feature: 'Network Clustering',
      importance: Math.floor(features.clustering_coefficient * 100)
    },
    {
      feature: 'Temporal Behavior',
      importance: Math.floor(features.temporal_pattern_score * 100)
    },
    {
      feature: 'Gas Usage',
      importance: Math.floor(features.gas_usage_pattern * 100)
    },
    {
      feature: 'Token Diversity',
      importance: features.token_diversity * 5
    }
  ] : [];

  return (
    <div className="space-y-8 p-6">
      <div>
        <h1 className="text-3xl font-bold">Analytics</h1>
        <p className="text-gray-500 mt-2">Analyze on-chain behavior and Sybil detection features</p>
      </div>
      
      <Card>
        <div className="space-y-4">
          <Title>Address Analyzer</Title>
          <Text>Enter an Aptos address to analyze its on-chain features</Text>
          
          <div className="flex flex-col md:flex-row gap-4">
            <TextInput
              placeholder="Enter Aptos address (0x...)"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="flex-1"
            />
            
            <Button 
              onClick={handleAnalyze} 
              loading={loading}
              disabled={!address.trim()}
              className="md:w-32"
            >
              Analyze
            </Button>
          </div>
          
          {error && (
            <div className="p-4 bg-red-50 text-red-700 rounded-md">
              {error}
            </div>
          )}
          
          {features && (
            <div className="mt-6">
              <div className="mb-6">
                <h3 className="text-lg font-medium">Analysis for</h3>
                <p className="text-gray-500 break-all">{analyzedAddress}</p>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-6">
                <Card decoration="top" decorationColor="blue">
                  <div className="flex items-center justify-between">
                    <Text>Transactions</Text>
                    <Activity className="h-5 w-5 text-blue-500" />
                  </div>
                  <p className="text-2xl font-bold mt-2">{features.transaction_count}</p>
                </Card>
                
                <Card decoration="top" decorationColor="green">
                  <div className="flex items-center justify-between">
                    <Text>Account Age</Text>
                    <Clock className="h-5 w-5 text-green-500" />
                  </div>
                  <p className="text-2xl font-bold mt-2">
                    {Math.floor((Date.now() - features.first_activity_timestamp) / (1000 * 60 * 60 * 24))} days
                  </p>
                </Card>
                
                <Card decoration="top" decorationColor="amber">
                  <div className="flex items-center justify-between">
                    <Text>Gas Pattern</Text>
                    <Zap className="h-5 w-5 text-amber-500" />
                  </div>
                  <p className="text-2xl font-bold mt-2">
                    {(features.gas_usage_pattern * 100).toFixed(1)}%
                  </p>
                </Card>
                
                <Card decoration="top" decorationColor="purple">
                  <div className="flex items-center justify-between">
                    <Text>Token Diversity</Text>
                    <Coins className="h-5 w-5 text-purple-500" />
                  </div>
                  <p className="text-2xl font-bold mt-2">{features.token_diversity}</p>
                </Card>
                
                <Card decoration="top" decorationColor="indigo">
                  <div className="flex items-center justify-between">
                    <Text>Clustering</Text>
                    <Network className="h-5 w-5 text-indigo-500" />
                  </div>
                  <p className="text-2xl font-bold mt-2">
                    {(features.clustering_coefficient * 100).toFixed(1)}%
                  </p>
                </Card>
              </div>
              
              <TabGroup>
                <TabList>
                  <Tab>Activity Over Time</Tab>
                  <Tab>Feature Importance</Tab>
                </TabList>
                <TabPanels>
                  <TabPanel>
                    <div className="h-80 mt-4">
                      <AreaChart
                        data={timeSeriesData}
                        index="date"
                        categories={['Transaction Count', 'Gas Usage', 'Token Interactions']}
                        colors={['blue', 'amber', 'purple']}
                        showLegend
                        showGridLines
                        showAnimation
                      />
                    </div>
                  </TabPanel>
                  <TabPanel>
                    <div className="h-80 mt-4">
                      <BarChart
                        data={featureImportanceData}
                        index="feature"
                        categories={['importance']}
                        colors={['indigo']}
                        layout="vertical"
                        showLegend={false}
                        showGridLines
                        showAnimation
                      />
                    </div>
                  </TabPanel>
                </TabPanels>
              </TabGroup>
              
              <div className="mt-6 text-sm text-gray-500">
                <p>Last Updated: {new Date(features.last_updated).toLocaleString()}</p>
              </div>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}
