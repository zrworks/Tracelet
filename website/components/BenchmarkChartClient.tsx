'use client';

import React, { useState, useEffect } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';

export type BenchmarkDataPoint = {
  name: string; // e.g., 'de958edb (2026-06-16)'
  [key: string]: string | number; // dynamic keys for metrics
};

type BenchmarkChartClientProps = {
  data: BenchmarkDataPoint[];
  metrics: string[];
};

const COLORS = [
  '#2563eb', // blue-600
  '#dc2626', // red-600
  '#16a34a', // green-600
  '#d97706', // amber-600
  '#9333ea', // purple-600
  '#0891b2', // cyan-600
  '#ea580c', // orange-600
  '#4f46e5', // indigo-600
  '#be185d', // pink-700
  '#111827', // gray-900
  '#059669', // emerald-600
  '#e11d48', // rose-600
  '#2dd4bf', // teal-400
  '#a21caf', // fuchsia-700
  '#fbbf24', // amber-400
  '#3b82f6', // blue-500
  '#ef4444', // red-500
  '#10b981', // emerald-500
  '#f59e0b', // amber-500
  '#8b5cf6', // violet-500
];

export default function BenchmarkChartClient({ data, metrics }: BenchmarkChartClientProps) {
  const [isMounted, setIsMounted] = useState(false);
  const [activeMetric, setActiveMetric] = useState<string | null>(null);

  useEffect(() => {
    setIsMounted(true);
  }, []);

  if (!isMounted) {
    return (
      <div style={{ width: '100%', height: '400px', marginTop: '2rem', marginBottom: '2rem', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#6b7280', border: '1px solid #e5e7eb', borderRadius: '0.5rem' }}>
        Loading graph...
      </div>
    );
  }

  if (!data || data.length === 0) {
    return <div style={{ padding: '1rem', textAlign: 'center', color: '#6b7280' }}>No benchmark data available.</div>;
  }

  const reversedData = [...data].reverse();

  return (
    <div style={{ width: '100%', height: '800px', marginTop: '2rem', marginBottom: '2rem' }}>
      <ResponsiveContainer width="100%" height={800}>
        <LineChart
          data={reversedData}
          margin={{
            top: 150,
            right: 30,
            left: 20,
            bottom: 80,
          }}
        >
          <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
          <XAxis 
            dataKey="name" 
            angle={-45} 
            textAnchor="end" 
            height={100} 
            tick={{ fontSize: 12 }} 
            tickMargin={10} 
          />
          <YAxis 
            label={{ value: 'Time (µs/op) - Lower is better', angle: -90, position: 'insideLeft', offset: -10, style: { fontSize: 14 } }} 
            tick={{ fontSize: 12 }}
          />
          <Tooltip 
            content={({ active, payload, label }) => {
              if (!active || !payload || !payload.length) return null;
              
              // If an active metric is highlighted, only show that one in the tooltip
              // Otherwise, if there are many metrics, limit to avoid massive tooltips
              const itemsToShow = activeMetric 
                ? payload.filter((entry: any) => entry.dataKey === activeMetric)
                : payload.slice(0, 15); // Show max 15 items if not hovering a specific line

              return (
                <div style={{ backgroundColor: '#fff', padding: '10px', border: '1px solid #e5e7eb', borderRadius: '8px', zIndex: 1000, boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}>
                  <p style={{ fontWeight: 'bold', marginBottom: '8px', fontSize: '14px', color: '#374151', borderBottom: '1px solid #e5e7eb', paddingBottom: '4px' }}>{label}</p>
                  <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                    {itemsToShow.map((entry: any) => (
                      <p key={entry.dataKey} style={{ color: entry.color, margin: '2px 0', fontSize: '13px' }}>
                        {`${entry.name}: `}<strong>{entry.value} µs/op</strong>
                      </p>
                    ))}
                    {!activeMetric && payload.length > 15 && (
                      <p style={{ color: '#6b7280', margin: '4px 0 0', fontSize: '12px', fontStyle: 'italic' }}>
                        ...and {payload.length - 15} more. Hover a specific line to focus.
                      </p>
                    )}
                  </div>
                </div>
              );
            }}
          />
          <Legend 
            verticalAlign="top" 
            wrapperStyle={{ paddingBottom: '20px' }}
            onMouseEnter={(e: any) => setActiveMetric(e.dataKey)}
            onMouseLeave={() => setActiveMetric(null)}
          />
          {metrics.map((metric, index) => (
            <Line
              key={metric}
              type="monotone"
              dataKey={metric}
              name={metric}
              stroke={COLORS[index % COLORS.length]}
              strokeWidth={activeMetric === metric ? 3 : (activeMetric ? 1 : 2)}
              strokeOpacity={activeMetric === metric ? 1 : (activeMetric ? 0.1 : 0.8)}
              activeDot={{ r: 6 }}
              dot={false}
              onMouseEnter={() => setActiveMetric(metric)}
              onMouseLeave={() => setActiveMetric(null)}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
