import React from 'react';
import Markdown from 'react-markdown';

async function getPackageVersion(pkg: string) {
  try {
    const res = await fetch(`https://pub.dev/api/packages/${pkg}`, { next: { revalidate: 3600 } });
    if (!res.ok) return 'Unknown';
    const data = await res.json();
    return data.latest.version;
  } catch (e) {
    return 'Unknown';
  }
}

async function getPackageChangelog(pkg: string) {
  try {
    const url = pkg === 'tracelet' 
      ? `https://raw.githubusercontent.com/Ikolvi/Tracelet/main/CHANGELOG.md`
      : `https://raw.githubusercontent.com/Ikolvi/Tracelet/main/packages/${pkg}/CHANGELOG.md`;
      
    const res = await fetch(url, { next: { revalidate: 3600 } });
    if (!res.ok) {
      if (res.status === 404 && pkg === 'tracelet') {
         const rootRes = await fetch(`https://raw.githubusercontent.com/Ikolvi/Tracelet/main/packages/tracelet/CHANGELOG.md`);
         if (!rootRes.ok) return 'Changelog not found.';
         const rootText = await rootRes.text();
         return extractLatestChangelog(rootText);
      }
      return 'Changelog not available.';
    }
    const text = await res.text();
    return extractLatestChangelog(text);
  } catch (e) {
    return 'Failed to load changelog.';
  }
}

function extractLatestChangelog(text: string) {
  const sections = text.split(/\n##? /);
  
  if (sections.length > 1) {
    let latest = sections[1];
    if (latest.toLowerCase().includes('changelog') && sections.length > 2) {
        latest = sections[2];
    }
    return `### ${latest.trim()}`;
  }
  return text;
}

export default async function ChangelogViewer({ pkg }: { pkg: string }) {
  const [version, changelog] = await Promise.all([
    getPackageVersion(pkg),
    getPackageChangelog(pkg)
  ]);

  return (
    <div style={{
      border: '1px solid #e2e8f0',
      borderRadius: '8px',
      padding: '1.5rem',
      marginBottom: '2rem',
      backgroundColor: 'var(--nextra-bg)',
      color: 'inherit'
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', borderBottom: '1px solid #e2e8f0', paddingBottom: '0.75rem' }}>
        <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 'bold' }}>{pkg}</h3>
        <span style={{ 
          backgroundColor: '#3b82f6', 
          color: 'white', 
          padding: '0.25rem 0.75rem', 
          borderRadius: '9999px',
          fontWeight: 'bold',
          fontSize: '0.85rem'
        }}>
          v{version}
        </span>
      </div>
      <div style={{ fontSize: '0.95rem', lineHeight: '1.6' }}>
        <Markdown
          components={{
            h3: ({node, ...props}) => <h4 style={{fontSize: '1.1rem', fontWeight: 'bold', marginBottom: '0.5rem', marginTop: '1rem'}} {...props} />,
            ul: ({node, ...props}) => <ul style={{listStyleType: 'disc', paddingLeft: '1.5rem', marginBottom: '1rem'}} {...props} />,
            li: ({node, ...props}) => <li style={{marginBottom: '0.25rem'}} {...props} />
          }}
        >
          {changelog}
        </Markdown>
      </div>
    </div>
  );
}
