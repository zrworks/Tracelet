import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'
import './global.css'
import RainBackground from '../components/RainBackground'

import { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    template: '%s | Tracelet',
    default: 'Tracelet | Production-grade background geolocation for Flutter',
  },
  description: 'Open-source, battery-conscious background geolocation and geofencing engine for Flutter iOS and Android.',
  keywords: ['Flutter', 'geolocation', 'background tracking', 'geofencing', 'Tracelet', 'open source', 'Dart', 'GPS', 'location tracking'],
  authors: [{ name: 'Tracelet Contributors' }],
  creator: 'Ikolvi',
  openGraph: {
    title: 'Tracelet | Production-grade background geolocation for Flutter',
    description: 'Open-source, battery-conscious background geolocation and geofencing engine for Flutter iOS and Android.',
    siteName: 'Tracelet',
    images: [
      {
        url: 'https://raw.githubusercontent.com/Ikolvi/Tracelet/main/assets/logo_anim.webp',
        width: 800,
        height: 600,
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary',
    title: 'Tracelet | Production-grade background geolocation for Flutter',
    description: 'Open-source, battery-conscious background geolocation and geofencing engine for Flutter iOS and Android.',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
}

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

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const pageMap = await getPageMap()
  const version = await getTraceletVersion()
  
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head />
      <body>
        <Layout
          navbar={<Navbar logo={
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <b style={{ color: '#0F9D58' }}>Tracelet</b>
              <span style={{ fontSize: '12px', background: 'rgba(15, 157, 88, 0.2)', padding: '2px 6px', borderRadius: '4px', color: '#0F9D58' }}>
                {version}
              </span>
            </div>
          } />}
          footer={<Footer>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', flexWrap: 'wrap', gap: '1rem', padding: '0.5rem 0' }}>
              <div style={{ fontSize: '0.9rem', color: '#6b7280' }}>
                Apache-2.0 {new Date().getFullYear()} © Tracelet Contributors
              </div>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem', flexWrap: 'wrap', fontSize: '0.9rem' }}>
                <a href="/reference/sponsor" className="footer-link" style={{ color: '#0F9D58', fontWeight: '600' }}>❤️ Support Tracelet</a>
                
                <span style={{ borderLeft: '1px solid #d1d5db', height: '16px', margin: '0 0.5rem' }}></span>
                <span style={{ fontWeight: '600', color: '#4b5563' }}>Powered by Ikolvi</span>
              </div>
            </div>
          </Footer>}
          pageMap={pageMap}
          docsRepositoryBase="https://github.com/Ikolvi/Tracelet/tree/main/website"
          editLink="Edit this page on GitHub"
          darkMode={true}
          toc={{
            extraContent: (
              <div style={{ marginTop: '2rem', display: 'flex', flexDirection: 'column', gap: '0.75rem', fontSize: '0.85rem' }}>
                <a href="/reference/sponsor" style={{ textDecoration: 'none' }}><b style={{ color: '#0F9D58', marginBottom: '0.25rem' }}>❤️ Support Tracelet</b></a>
                <a href="https://github.com/sponsors/GalacticTitan" target="_blank" rel="noopener noreferrer" className="footer-link">🐙 GitHub Sponsors</a>
                <a href="https://www.buymeacoffee.com/kiranbjm" target="_blank" rel="noopener noreferrer" className="footer-link">☕ Buy Me a Coffee</a>
                <a href="https://thanks.dev/d/gh/galactictitan/dependencies" target="_blank" rel="noopener noreferrer" className="footer-link">✨ Thanks.dev</a>
                <a href="https://www.patreon.com/c/kiranbjm" target="_blank" rel="noopener noreferrer" className="footer-link">🟠 Patreon</a>
              </div>
            )
          }}
        >
          {children}
        </Layout>
        <RainBackground />
      </body>
    </html>
  )
}
