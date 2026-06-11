import DocLayout from '../../components/DocLayout'
import { getPageMap } from 'nextra/page-map'

async function getTraceletVersion() {
  try {
    // Revalidate every hour
    const res = await fetch('https://pub.dev/api/packages/tracelet', { next: { revalidate: 3600 } });
    if (!res.ok) return 'v1.0.0';
    const data = await res.json();
    return `v${data.latest.version}`;
  } catch (e) {
    return 'v1.0.0';
  }
}

export default async function EnLayout({ children }: { children: React.ReactNode }) {
  const pageMap = await getPageMap('/en')
  const version = await getTraceletVersion()
  return <DocLayout pageMap={pageMap} version={version} locale="en">{children}</DocLayout>
}
