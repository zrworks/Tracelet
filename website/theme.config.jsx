import NotificationBell from './components/NotificationBell'

export default {
  logo: <span style={{ color: '#0F9D58', fontWeight: 'bold' }}>Tracelet</span>,
  navbar: {
    extra: <NotificationBell />
  },
  project: {
    link: 'https://github.com/Ikolvi/Tracelet'
  },
  docsRepositoryBase: 'https://github.com/Ikolvi/Tracelet/tree/main/website',
  feedback: {
    content: 'Question? Give us feedback →',
    labels: 'feedback'
  },
  editLink: {
    text: 'Edit this page on GitHub'
  },
  useNextSeoProps() {
    return {
      titleTemplate: '%s – Tracelet Docs'
    }
  },
  footer: {
    text: (
      <div style={{ display: 'flex', width: '100%', flexDirection: 'column', gap: '0.5rem', marginTop: '1rem', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: '1.5rem', fontSize: '0.9rem' }}>
          <a href="/privacy" style={{ textDecoration: 'none', opacity: 0.8 }} onMouseOver={(e) => e.currentTarget.style.opacity = '1'} onMouseOut={(e) => e.currentTarget.style.opacity = '0.8'}>Privacy Policy</a>
          <a href="/terms" style={{ textDecoration: 'none', opacity: 0.8 }} onMouseOver={(e) => e.currentTarget.style.opacity = '1'} onMouseOut={(e) => e.currentTarget.style.opacity = '0.8'}>Terms of Service</a>
          <a href="/license" style={{ textDecoration: 'none', opacity: 0.8 }} onMouseOver={(e) => e.currentTarget.style.opacity = '1'} onMouseOut={(e) => e.currentTarget.style.opacity = '0.8'}>License</a>
        </div>
        <div style={{ fontSize: '0.8rem', opacity: 0.6, marginTop: '0.5rem' }}>
          © {new Date().getFullYear()} Ikolvi. All rights reserved.
        </div>
      </div>
    )
  }
}
