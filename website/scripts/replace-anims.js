const fs = require('fs');
const path = require('path');

const locales = ['en', 'hi', 'zh', 'ja', 'es', 'ml', 'ta', 'ru'];
const appDir = path.join(__dirname, '../app');

for (const locale of locales) {
  // 1. Persistence
  const persistencePath = path.join(appDir, locale, 'core/persistence/page.mdx');
  if (fs.existsSync(persistencePath)) {
    let content = fs.readFileSync(persistencePath, 'utf8');
    content = content.replace(/\/animations\/search\.json/g, '/animations/storage.json');
    fs.writeFileSync(persistencePath, content);
    console.log(`Updated ${persistencePath}`);
  }

  // 2. Enterprise Features
  const enterprisePath = path.join(appDir, locale, 'config/enterprise-features/page.mdx');
  if (fs.existsSync(enterprisePath)) {
    let content = fs.readFileSync(enterprisePath, 'utf8');
    
    // Replace the first search.json with locked.json
    content = content.replace(/\/animations\/search\.json/, '/animations/locked.json');
    
    // Insert audit_trail.json below the Audit Trail heading
    const auditHeading = '## 2. Audit Trail Management & Verification';
    if (content.includes(auditHeading) && !content.includes('audit_trail.json')) {
      content = content.replace(
        auditHeading,
        auditHeading + '\n\n<LottiePlayer src="/animations/audit_trail.json" maxWidth="300px" />'
      );
    }
    
    fs.writeFileSync(enterprisePath, content);
    console.log(`Updated ${enterprisePath}`);
  }
}
