export default {
  logo: <span style={{ color: '#0F9D58', fontWeight: 'bold' }}>Tracelet</span>,
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
  }
}
