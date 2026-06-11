const fs = require('fs');
const path = require('path');

const locales = ['hi', 'zh', 'ja', 'es', 'ml', 'ta', 'ru'];

function walkDir(dir, callback) {
  if (!fs.existsSync(dir)) return;
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

for (const lang of locales) {
  walkDir(path.join(__dirname, `../app/${lang}`), function(filePath) {
    if (filePath.endsWith('.mdx')) {
      let content = fs.readFileSync(filePath, 'utf8');
      let newContent = content;

      // Replace href="/..." with href="/lang/..." (ignore if already localized)
      newContent = newContent.replace(/href="\/([a-z0-9_-])/ig, function(match, p1) {
        if (match.startsWith(`href="/${lang}/`) || match.startsWith(`href="/en/`)) return match;
        return `href="/${lang}/${p1}`;
      });

      // Replace ](/...) with ](/lang/...) (ignore if already localized)
      newContent = newContent.replace(/\]\(\/([a-z0-9_-])/ig, function(match, p1) {
        if (match.startsWith(`](/${lang}/`) || match.startsWith(`](/en/`)) return match;
        return `](/${lang}/${p1}`;
      });

      if (content !== newContent) {
        fs.writeFileSync(filePath, newContent);
        console.log(`Updated ${filePath}`);
      }
    }
  });
}
