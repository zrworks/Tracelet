import { Head } from 'nextra/components'
import { GoogleAnalytics } from '@next/third-parties/google'
import './global.css'
import { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://tracelet.ikolvi.com'),
  alternates: {
    canonical: '/',
  },
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

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head />
      <body>
        {children}
      </body>
      {/* GA4 (G-42X97WN4M8). Cloudflare's Google tag gateway rewrites these
          requests to load first-party from ikolvi.com, making measurement
          resilient to ad/tracker blockers that target googletagmanager.com. */}
      <GoogleAnalytics gaId="G-42X97WN4M8" />
    </html>
  )
}
