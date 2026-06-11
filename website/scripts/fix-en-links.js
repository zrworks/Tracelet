const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

walkDir(path.join(__dirname, '../app/en'), function(filePath) {
  if (filePath.endsWith('.mdx')) {
    let content = fs.readFileSync(filePath, 'utf8');
    let changed = false;

    // Replace href="/..." with href="/en/..." (but ignore href="/en/...")
    let newContent = content.replace(/href="\/([a-z0-9_-])/ig, function(match, p1) {
      if (p1 === 'e' && match.startsWith('href="/en/')) return match; // Already /en/
      return `href="/en/${p1}`;
    });

    // Replace ](/...) with ](/en/...) (but ignore ](/en/...)
    newContent = newContent.replace(/\]\(\/([a-z0-9_-])/ig, function(match, p1) {
      if (p1 === 'e' && match.startsWith('](/en/')) return match; // Already /en/
      return `](/en/${p1}`;
    });

    if (content !== newContent) {
      fs.writeFileSync(filePath, newContent);
      console.log(`Updated ${filePath}`);
    }
  }
});
