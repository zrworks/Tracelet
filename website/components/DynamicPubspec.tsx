import { Pre, Code } from 'nextra/components'

async function getTraceletVersion() {
  try {
    const res = await fetch('https://pub.dev/api/packages/tracelet', { next: { revalidate: 3600 } });
    if (!res.ok) return '3.3.4';
    const data = await res.json();
    return data.latest.version;
  } catch (e) {
    return '3.3.4';
  }
}

export default async function DynamicPubspec({ pkg = 'tracelet' }: { pkg?: string }) {
  const version = await getTraceletVersion();
  return (
    <Pre data-language="yaml" data-theme="default" data-copy="">
      <Code data-language="yaml" data-theme="default">
        <span className="line"><span style={{color: 'var(--shiki-token-keyword, #f8f8f2)'}}>dependencies:</span></span>{'\n'}
        <span className="line"><span style={{color: 'var(--shiki-token-string, #f8f8f2)'}}>  {pkg}: </span><span style={{color: 'var(--shiki-token-constant, #e6db74)'}}>^{version}</span></span>{'\n'}
      </Code>
    </Pre>
  );
}
