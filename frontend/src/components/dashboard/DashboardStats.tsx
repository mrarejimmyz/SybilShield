"use client";

import React from 'react';
import { 
  Card, 
  Title, 
  Text, 
  Flex, 
  Metric, 
  ProgressBar, 
  Grid, 
  BadgeDelta, 
  DeltaType 
} from '@tremor/react';
import { Shield, AlertTriangle, Users, CheckCircle } from 'lucide-react';

type TremorColor = 'slate' | 'gray' | 'zinc' | 'neutral' | 'stone' | 'red' | 'orange' | 'amber' | 
                   'yellow' | 'lime' | 'green' | 'emerald' | 'teal' | 'cyan' | 'sky' | 
                   'blue' | 'indigo' | 'violet' | 'purple' | 'fuchsia' | 'pink' | 'rose';

interface StatCardProps {
  title: string;
  metric: string | number;
  icon: React.ReactNode;
  color: TremorColor;
  delta?: string;
  deltaType?: DeltaType;
}

const StatCard = ({ title, metric, icon, color, delta, deltaType }: StatCardProps) => (
  <Card className="max-w-xs mx-auto" decoration="top" decorationColor={color}>
    <Flex justifyContent="between" alignItems="center">
      <Text>{title}</Text>
      <div className={`p-2 rounded-full bg-${color}-100`}>
        {icon}
      </div>
    </Flex>
    <Metric className="mt-2">{metric}</Metric>
    {delta && deltaType && (
      <Flex className="mt-2">
        <BadgeDelta deltaType={deltaType}>{delta}</BadgeDelta>
      </Flex>
    )}
  </Card>
);

export default function DashboardStats() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold mb-4">System Overview</h2>
        <Grid numItemsMd={2} numItemsLg={4} className="gap-6">
          <StatCard 
            title="Sybil Detection Rate" 
            metric="8.4%" 
            icon={<Shield className="h-5 w-5 text-blue-600" />}
            color="blue"
            delta="+1.2% from last week"
            deltaType="increase"
          />
          <StatCard 
            title="Verified Users" 
            metric="12,543" 
            icon={<CheckCircle className="h-5 w-5 text-green-600" />}
            color="green"
            delta="+573 new verifications"
            deltaType="increase"
          />
          <StatCard 
            title="Alerts" 
            metric="24" 
            icon={<AlertTriangle className="h-5 w-5 text-amber-600" />}
            color="amber"
            delta="-3 from yesterday"
            deltaType="decrease"
          />
          <StatCard 
            title="Active Users" 
            metric="45,789" 
            icon={<Users className="h-5 w-5 text-indigo-600" />}
            color="indigo"
            delta="+12% this month"
            deltaType="increase"
          />
        </Grid>
      </div>
      
      <div>
        <Card>
          <Title>System Health</Title>
          <Text>Current status of the Sybil detection system</Text>
          <div className="mt-4 space-y-4">
            <div>
              <Flex justifyContent="between" className="mb-1">
                <Text>API Performance</Text>
                <Text>92%</Text>
              </Flex>
              <ProgressBar value={92} color="blue" />
            </div>
            <div>
              <Flex justifyContent="between" className="mb-1">
                <Text>ML Model Accuracy</Text>
                <Text>87%</Text>
              </Flex>
              <ProgressBar value={87} color="green" />
            </div>
            <div>
              <Flex justifyContent="between" className="mb-1">
                <Text>On-chain Verification</Text>
                <Text>95%</Text>
              </Flex>
              <ProgressBar value={95} color="indigo" />
            </div>
            <div>
              <Flex justifyContent="between" className="mb-1">
                <Text>Privacy System</Text>
                <Text>99%</Text>
              </Flex>
              <ProgressBar value={99} color="purple" />
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
