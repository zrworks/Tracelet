const fs = require('fs');
const path = require('path');

const locales = ['hi', 'zh', 'ja', 'es', 'ml', 'ta', 'ru'];

const args = process.argv.slice(2);
let targetLocales = locales;

if (args.length > 0 && args[0] !== '--all') {
  targetLocales = locales.filter(l => args.includes(l));
}

console.log(`Clearing languages: ${targetLocales.join(', ')}...`);

for (const locale of targetLocales) {
  const dirPath = path.join(__dirname, '../app', locale);
  if (fs.existsSync(dirPath)) {
    fs.rmSync(dirPath, { recursive: true, force: true });
    console.log(`Deleted folder: app/${locale}`);
  }
}

console.log("Cleanup complete!");
