"use client";

import React from 'react';
import { 
  AreaChart, 
  BarChart, 
  Tab, 
  TabGroup, 
  TabList, 
  TabPanel, 
  TabPanels 
} from '@tremor/react';

const sybilDetectionData = [
  {
    date: '2025-01',
    'Sybil Accounts': 245,
    'Legitimate Accounts': 4320,
  },
  {
    date: '2025-02',
    'Sybil Accounts': 368,
    'Legitimate Accounts': 5234,
  },
  {
    date: '2025-03',
    'Sybil Accounts': 421,
    'Legitimate Accounts': 6543,
  },
  {
    date: '2025-04',
    'Sybil Accounts': 287,
    'Legitimate Accounts': 7865,
  },
  {
    date: '2025-05',
    'Sybil Accounts': 312,
    'Legitimate Accounts': 8976,
  },
];

const riskScoreDistribution = [
  {
    riskScore: '0-10',
    accounts: 12543,
  },
  {
    riskScore: '11-20',
    accounts: 8765,
  },
  {
    riskScore: '21-30',
    accounts: 6543,
  },
  {
    riskScore: '31-40',
    accounts: 4321,
  },
  {
    riskScore: '41-50',
    accounts: 3210,
  },
  {
    riskScore: '51-60',
    accounts: 2109,
  },
  {
    riskScore: '61-70',
    accounts: 1098,
  },
  {
    riskScore: '71-80',
    accounts: 876,
  },
  {
    riskScore: '81-90',
    accounts: 543,
  },
  {
    riskScore: '91-100',
    accounts: 321,
  },
];

const featureImportance = [
  {
    feature: 'Transaction Frequency',
    importance: 87,
  },
  {
    feature: 'Network Clustering',
    importance: 76,
  },
  {
    feature: 'Account Age',
    importance: 65,
  },
  {
    feature: 'Gas Usage Patterns',
    importance: 54,
  },
  {
    feature: 'Token Diversity',
    importance: 43,
  },
  {
    feature: 'Interaction Patterns',
    importance: 32,
  },
  {
    feature: 'Temporal Behavior',
    importance: 21,
  },
];

export default function SybilAnalytics() {
  return (
    <div className="space-y-6">
      <div className="card p-6">
        <h3 className="text-xl font-semibold mb-2">Sybil Detection Analytics</h3>
        <p className="text-text-secondary mb-6">Overview of detected Sybil accounts vs. legitimate accounts over time</p>
        
        <TabGroup>
          <TabList className="flex space-x-1 rounded-xl bg-background p-1 mb-6">
            <Tab className="w-full rounded-lg py-2.5 text-sm font-medium leading-5 text-text-primary ring-white/60 ring-offset-2 ring-offset-blue-400 focus:outline-none focus:ring-2 ui-selected:bg-white ui-selected:shadow ui-selected:text-primary ui-selected:font-semibold ui-not-selected:text-text-secondary ui-not-selected:hover:bg-white/[0.12] ui-not-selected:hover:text-text-primary transition-all">
              Account Growth
            </Tab>
            <Tab className="w-full rounded-lg py-2.5 text-sm font-medium leading-5 text-text-primary ring-white/60 ring-offset-2 ring-offset-blue-400 focus:outline-none focus:ring-2 ui-selected:bg-white ui-selected:shadow ui-selected:text-primary ui-selected:font-semibold ui-not-selected:text-text-secondary ui-not-selected:hover:bg-white/[0.12] ui-not-selected:hover:text-text-primary transition-all">
              Risk Distribution
            </Tab>
            <Tab className="w-full rounded-lg py-2.5 text-sm font-medium leading-5 text-text-primary ring-white/60 ring-offset-2 ring-offset-blue-400 focus:outline-none focus:ring-2 ui-selected:bg-white ui-selected:shadow ui-selected:text-primary ui-selected:font-semibold ui-not-selected:text-text-secondary ui-not-selected:hover:bg-white/[0.12] ui-not-selected:hover:text-text-primary transition-all">
              Feature Importance
            </Tab>
          </TabList>
          
          <TabPanels>
            <TabPanel>
              <div className="h-80 mt-4">
                <AreaChart
                  data={sybilDetectionData}
                  index="date"
                  categories={['Sybil Accounts', 'Legitimate Accounts']}
                  colors={['danger', 'success']}
                  valueFormatter={(number) => `${number.toLocaleString()} accounts`}
                  showLegend
                  showGridLines
                  showAnimation
                  className="h-full"
                />
              </div>
            </TabPanel>
            
            <TabPanel>
              <div className="h-80 mt-4">
                <BarChart
                  data={riskScoreDistribution}
                  index="riskScore"
                  categories={['accounts']}
                  colors={['primary']}
                  valueFormatter={(number) => `${number.toLocaleString()} accounts`}
                  showLegend={false}
                  showGridLines
                  showAnimation
                  className="h-full"
                />
              </div>
              <p className="mt-4 text-center text-sm text-text-tertiary">
                Risk Score Distribution (0-100)
              </p>
            </TabPanel>
            
            <TabPanel>
              <div className="h-80 mt-4">
                <BarChart
                  data={featureImportance}
                  index="feature"
                  categories={['importance']}
                  colors={['info']}
                  valueFormatter={(number) => `${number}%`}
                  layout="vertical"
                  showLegend={false}
                  showGridLines
                  showAnimation
                  className="h-full"
                />
              </div>
              <p className="mt-4 text-center text-sm text-text-tertiary">
                Feature Importance in Sybil Detection Model
              </p>
            </TabPanel>
          </TabPanels>
        </TabGroup>
      </div>
    </div>
  );
}
