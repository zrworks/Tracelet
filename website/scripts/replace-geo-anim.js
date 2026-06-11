const fs = require('fs');
const path = require('path');

const locales = ['en', 'hi', 'zh', 'ja', 'es', 'ml', 'ta', 'ru'];
const appDir = path.join(__dirname, '../app');

for (const locale of locales) {
  const geoPath = path.join(appDir, locale, 'core/advanced-geo/page.mdx');
  if (fs.existsSync(geoPath)) {
    let content = fs.readFileSync(geoPath, 'utf8');
    // Replace search.json with global-delivery.json
    content = content.replace(/\/animations\/search\.json/g, '/animations/global-delivery.json');
    fs.writeFileSync(geoPath, content);
    console.log(`Updated ${geoPath}`);
  }
}
