"use client";

import React from 'react';
import { 
  AreaChart, 
  BarChart, 
  Card, 
  Title, 
  Text, 
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
      <Card>
        <Title>Sybil Detection Analytics</Title>
        <Text>Overview of detected Sybil accounts vs. legitimate accounts over time</Text>
        <TabGroup>
          <TabList className="mt-4">
            <Tab>Account Growth</Tab>
            <Tab>Risk Distribution</Tab>
            <Tab>Feature Importance</Tab>
          </TabList>
          <TabPanels>
            <TabPanel>
              <div className="mt-4 h-80">
                <AreaChart
                  data={sybilDetectionData}
                  index="date"
                  categories={['Sybil Accounts', 'Legitimate Accounts']}
                  colors={['red', 'green']}
                  valueFormatter={(number) => `${number.toLocaleString()} accounts`}
                  showLegend
                  showGridLines
                  showAnimation
                />
              </div>
            </TabPanel>
            <TabPanel>
              <div className="mt-4 h-80">
                <BarChart
                  data={riskScoreDistribution}
                  index="riskScore"
                  categories={['accounts']}
                  colors={['blue']}
                  valueFormatter={(number) => `${number.toLocaleString()} accounts`}
                  showLegend={false}
                  showGridLines
                  showAnimation
                />
              </div>
              <Text className="mt-2 text-center text-sm text-gray-500">
                Risk Score Distribution (0-100)
              </Text>
            </TabPanel>
            <TabPanel>
              <div className="mt-4 h-80">
                <BarChart
                  data={featureImportance}
                  index="feature"
                  categories={['importance']}
                  colors={['purple']}
                  valueFormatter={(number) => `${number}%`}
                  layout="vertical"
                  showLegend={false}
                  showGridLines
                  showAnimation
                />
              </div>
              <Text className="mt-2 text-center text-sm text-gray-500">
                Feature Importance in Sybil Detection Model
              </Text>
            </TabPanel>
          </TabPanels>
        </TabGroup>
      </Card>
    </div>
  );
}
