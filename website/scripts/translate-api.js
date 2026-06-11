const fs = require('fs');
const path = require('path');
const { translate } = require('@vitalets/google-translate-api');


const delay = (ms) => new Promise(res => setTimeout(res, ms));

async function translateText(text, targetLang) {
  if (!text.trim()) return text;
  try {
    await delay(1500); // 1.5 second delay to avoid rate limits
    const res = await translate(text, { to: targetLang });
    let translated = res.text;
    
    // Fix Google Translate breaking markdown bold markers by adding spaces
    translated = translated.replace(/\*\*\s+/g, '**').replace(/\s+\*\*/g, '**');
    // Fix italics markers
    translated = translated.replace(/\*\s+/g, '*').replace(/\s+\*/g, '*');
    
    return translated;
  } catch (e) {
    console.error('Translation error:', e.message);
    return text;
  }
}

async function translateMdx(content, targetLang) {
  const lines = content.split('\n');
  const translatedLines = [];
  
  let inCodeBlock = false;
  let inFrontMatter = false;
  let isFirstLine = true;
  
  for (let line of lines) {
    // Handle frontmatter
    if (isFirstLine && line.trim() === '---') {
      inFrontMatter = true;
      translatedLines.push(line);
      isFirstLine = false;
      continue;
    }
    if (inFrontMatter && line.trim() === '---') {
      inFrontMatter = false;
      translatedLines.push(line);
      continue;
    }
    if (inFrontMatter) {
      if (line.startsWith('title:')) {
        const titleMatch = line.match(/title:\s*"(.*)"/);
        if (titleMatch) {
          const t = await translateText(titleMatch[1], targetLang);
          translatedLines.push(`title: "${t}"`);
        } else {
          translatedLines.push(line);
        }
      } else {
        translatedLines.push(line);
      }
      continue;
    }
    
    isFirstLine = false;
    
    // Code blocks
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      translatedLines.push(line);
      continue;
    }
    
    if (inCodeBlock) {
      translatedLines.push(line);
      continue;
    }
    
    // Imports and Components
    if (line.startsWith('import ') || line.trim().startsWith('<') || line.trim() === '') {
      translatedLines.push(line);
      continue;
    }
    
    // Headings
    if (line.trim().startsWith('#')) {
      const hashes = line.match(/^#+/)[0];
      const text = line.replace(/^#+/, '').trim();
      const t = await translateText(text, targetLang);
      translatedLines.push(`${hashes} ${t}`);
      continue;
    }
    
    // Bullet points
    if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
      const prefix = line.match(/^[\s\-*]+/)[0];
      const text = line.replace(/^[\s\-*]+/, '').trim();
      const t = await translateText(text, targetLang);
      translatedLines.push(`${prefix}${t}`);
      continue;
    }
    
    // Regular text
    const t = await translateText(line, targetLang);
    translatedLines.push(t);
  }
  
  return translatedLines.join('\n');
}

async function processDir(srcDir, destDir, targetLang) {
  if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
  
  const entries = fs.readdirSync(srcDir, { withFileTypes: true });
  const tasks = [];
  
  for (let entry of entries) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);
    
    if (entry.isDirectory()) {
      await processDir(srcPath, destPath, targetLang);
    } else if (entry.name.endsWith('.mdx')) {
      // skip page.mdx in root to preserve homepage
      if (srcPath.includes('app/en/page.mdx')) continue;
      
      console.log(`Translating ${srcPath} to ${targetLang}...`);
      const content = fs.readFileSync(srcPath, 'utf8');
      const translated = await translateMdx(content, targetLang);
      fs.writeFileSync(destPath, translated);
      console.log(`Saved ${destPath}`);
    }
  }
}

async function run() {
  const baseDir = path.join(__dirname, '../app/en/core');
  const destDir = path.join(__dirname, '../app/ml/core');
  
  console.log('Starting translation of /core folder to Malayalam...');
  await processDir(baseDir, destDir, 'ml');
  console.log('Translation complete!');
}

run();
