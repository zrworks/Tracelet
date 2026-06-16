import fs from 'fs';
import path from 'path';
import BenchmarkChartClient, { BenchmarkDataPoint } from './BenchmarkChartClient';

export default async function BenchmarkGraph() {
  const data: BenchmarkDataPoint[] = [];
  const metricsSet = new Set<string>();

  try {
    const filePath = path.join(process.cwd(), '../BENCHMARK.md');
    const markdown = fs.readFileSync(filePath, 'utf-8');

    const chunks = markdown.split('### ').slice(1);

    for (const chunk of chunks) {
      const nameMatch = chunk.match(/^(.*?)\s*—\s*Commit\s*([a-f0-9]+)/i);
      if (!nameMatch) continue;

      const dateStr = nameMatch[1].trim();
      const commitStr = nameMatch[2].substring(0, 7);
      const name = `${commitStr} (${dateStr})`;

      const point: BenchmarkDataPoint = { name };

      const lines = chunk.split('\n');
      for (const line of lines) {
        if (line.startsWith('|') && !line.includes('---') && !line.includes('Benchmark')) {
          const cols = line.split('|');
          if (cols.length >= 4) {
            const metric = cols[1].trim();
            const usOp = parseFloat(cols[3].trim());
            if (!isNaN(usOp)) {
              point[metric] = usOp;
              metricsSet.add(metric);
            }
          }
        }
      }
      data.push(point);
    }
  } catch (error) {
    console.error('Failed to parse BENCHMARK.md:', error);
  }

  // The markdown file puts newest results at the top, and we want to show the full history.
  // The client component will reverse the array to show oldest -> newest.
  const selectedMetrics = Array.from(metricsSet);
  return <BenchmarkChartClient data={data} metrics={selectedMetrics} />;
}
