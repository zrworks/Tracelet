/**
 * Automated i18n Translation Script (Parallel Multi-Engine Version)
 * 
 * Uses @vitalets/google-translate-api AND bing-translate-api concurrently.
 * Skips already translated files. Fails fast on rate limits.
 * 
 * ==========================================
 * AVAILABLE COMMANDS (HELP):
 * ==========================================
 * 
 * 1. Translate specific files:
 *    node scripts/translate.js app/en/page.mdx app/en/core/page.mdx
 * 
 * 2. Translate all files (Smart resume):
 *    node scripts/translate.js --all
 *    (This skips files that are already translated. If the script crashes halfway, just run this again to resume!)
 * 
 * 3. Force re-translate everything (Overwrite):
 *    node scripts/translate.js --all --force
 * 
 * 4. Sync English folders to other languages (Do this before translating new files):
 *    node scripts/i18n-sync.js
 * 
 * 5. Delete all translated languages (Clean up):
 *    node scripts/i18n-clean.js --all
 * 
 * 6. Master Command (Clean, Sync, and Translate from scratch):
 *    node scripts/i18n-run.js --all
 * ==========================================
 */

const fs = require('fs');
const path = require('path');
const { translate: googleTranslate } = require('@vitalets/google-translate-api');
const { translate: bingTranslate } = require('bing-translate-api');

const locales = ['hi', 'zh', 'ja', 'es', 'ml', 'ta', 'ru'];
const baseLang = 'en';

const delay = (ms) => new Promise(res => setTimeout(res, ms));

async function translateLineGoogle(text, targetLang, retries = 5) {
  if (!text.trim()) return text;
  
  for (let i = 0; i < retries; i++) {
    try {
      // Base delay of 1s, but if we are retrying, wait longer
      await delay(1000 + (i * 1000)); 
      
      const res = await googleTranslate(text, { to: targetLang });
      let translated = res.text;
      // Fix spaces inside markdown bold tags (e.g. "** text **" -> "**text**")
      translated = translated.replace(/(\*\*)\s*(.*?)\s*(\*\*)/g, '$1$2$3');
      return translated;
    } catch (e) {
      const isRateLimit = e.name === 'TooManyRequestsError' || e.message.includes('TooManyRequests') || e.statusCode === 429;
      
      if (isRateLimit && i < retries - 1) {
        const waitTime = 3000 * (i + 1); // 3s, 6s, 9s...
        console.log(`\n[GOOGLE API] Blocked (Too Many Requests). Waiting ${waitTime/1000}s to retry...`);
        await delay(waitTime);
      } else {
        throw e; // Throw if it's a different error or we ran out of retries
      }
    }
  }
}

async function translateLineBing(text, targetLang) {
  if (!text.trim()) return text;
  
  // Bing uses different language codes for some languages (e.g., 'zh' -> 'zh-Hans')
  let bingLang = targetLang;
  if (targetLang === 'zh') bingLang = 'zh-Hans';
  
  await delay(100); // Bing handles more requests, minimal delay
  const res = await bingTranslate(text, null, bingLang);
  let translated = res.translation;
  // Fix spaces inside markdown bold tags (e.g. "** text **" -> "**text**")
  translated = translated.replace(/(\*\*)\s*(.*?)\s*(\*\*)/g, '$1$2$3');
  return translated;
}

async function translateTextWithProtection(text, targetLang, engine) {
  // Protect inline code with backticks
  const inlineCodes = [];
  let tempText = text.replace(/`([^`]+)`/g, (match) => {
    inlineCodes.push(match);
    return `NOTRANS${inlineCodes.length - 1}LATE`;
  });

  let t = engine === 'google' 
    ? await translateLineGoogle(tempText, targetLang)
    : await translateLineBing(tempText, targetLang);

  // Restore inline code
  inlineCodes.forEach((code, i) => {
    // Handle cases where the translator might have added spaces or changed case
    const regex = new RegExp(`NOTRANS\\s*${i}\\s*LATE`, 'gi');
    t = t.replace(regex, code);
  });

  return t;
}

async function translateMdx(content, targetLang, engine) {
  const lines = content.split('\n');
  const translatedLines = [];
  
  let inCodeBlock = false;
  let inFrontMatter = false;
  let isFirstLine = true;
  
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    
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
          const t = engine === 'google' 
            ? await translateLineGoogle(titleMatch[1], targetLang)
            : await translateLineBing(titleMatch[1], targetLang);
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
    
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      translatedLines.push(line);
      continue;
    }
    if (inCodeBlock || line.startsWith('import ') || line.trim().startsWith('<') || line.trim() === '') {
      translatedLines.push(line);
      continue;
    }
    
    if (line.trim().startsWith('#')) {
      const hashes = line.match(/^#+/)[0];
      const text = line.replace(/^#+/, '').trim();
      const t = await translateTextWithProtection(text, targetLang, engine);
      translatedLines.push(`${hashes} ${t}`);
      continue;
    }
    
    if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
      const match = line.match(/^[\s]*[\-*]\s+/);
      const prefix = match ? match[0] : '';
      const text = line.substring(prefix.length);
      const t = await translateTextWithProtection(text, targetLang, engine);
      translatedLines.push(`${prefix}${t}`);
      continue;
    }
    
    const t = await translateTextWithProtection(line, targetLang, engine);
    translatedLines.push(t);
  }
  
  return translatedLines.join('\n');
}

async function translateMetaJs(content, targetLang, engine) {
  const lines = content.split('\n');
  const translatedLines = [];
  
  for (let line of lines) {
    const match = line.match(/^(\s*(?:['"]?[\w-]+['"]?\s*:\s*)['"])(.*?)(['"],?\s*)$/);
    if (match) {
      const prefix = match[1];
      const text = match[2];
      const suffix = match[3];
      
      const t = engine === 'google' 
        ? await googleTranslate(text, { to: targetLang }).then(res => res.text)
        : await bingTranslate(text, null, targetLang === 'zh' ? 'zh-Hans' : targetLang).then(res => res.translation);
        
      translatedLines.push(`${prefix}${t}${suffix}`);
    } else {
      translatedLines.push(line);
    }
  }
  return translatedLines.join('\n');
}

function getAllFiles(dirPath, arrayOfFiles) {
  let files = fs.readdirSync(dirPath)
  arrayOfFiles = arrayOfFiles || []
  files.forEach(function(file) {
    if (fs.statSync(dirPath + "/" + file).isDirectory()) {
      arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
    } else {
      arrayOfFiles.push(path.join(dirPath, "/", file))
    }
  })
  return arrayOfFiles
}

async function run() {
  const args = process.argv.slice(2);
  let filesToTranslate = [];
  
  if (args.includes('--all')) {
    const baseDir = path.join(__dirname, '../app/en');
    const allFiles = getAllFiles(baseDir);
    filesToTranslate = allFiles.filter(f => f.endsWith('.mdx') || f.endsWith('_meta.js'));
  } else if (args.length > 0) {
    filesToTranslate = args;
  } else {
    try {
      const { execSync } = require('child_process');
      const diffOutput = execSync('git diff --name-only HEAD~1').toString();
      filesToTranslate = diffOutput.split('\n').filter(file => file.includes(`app/${baseLang}/`) && file.endsWith('.mdx'));
    } catch (e) {
      console.warn("Could not detect git changes. Please provide specific files or use --all.");
      process.exit(1);
    }
  }

  const force = args.includes('--force');

  // 1. Build Task Queue
  const queue = [];
  for (const file of filesToTranslate) {
    const absolutePath = path.resolve(file);
    if (!fs.existsSync(absolutePath)) continue;
    
    for (const locale of locales) {
      const destPath = absolutePath.replace(`/app/${baseLang}/`, `/app/${locale}/`);
      let shouldTranslate = force;
      
      if (!force) {
        if (!fs.existsSync(destPath)) {
          shouldTranslate = true;
        } else {
          const srcContent = fs.readFileSync(absolutePath, 'utf8');
          const destContent = fs.readFileSync(destPath, 'utf8');
          if (srcContent === destContent) {
            shouldTranslate = true;
          }
        }
      }

      // Skip if already translated, unless --force is used or it's a fallback
      if (shouldTranslate) {
        queue.push({
          srcPath: absolutePath,
          destPath: destPath,
          targetLocale: locale
        });
      }
    }
  }

  if (queue.length === 0) {
    console.log("All files are already translated! Nothing to do.");
    return;
  }

  console.log(`Starting parallel translation queue. ${queue.length} tasks remaining...`);

  // 2. Parallel Worker Logic
  async function worker(engine) {
    while (queue.length > 0) {
      const task = queue.shift();
      try {
        const relSrcPath = path.relative(path.join(__dirname, '../app/en'), task.srcPath);
        console.log(`[${engine.toUpperCase()}] Translating ${relSrcPath} to '${task.targetLocale}'...`);
        
        const content = fs.readFileSync(task.srcPath, 'utf8');
        let translated;
        if (task.srcPath.endsWith('.mdx')) {
          translated = await translateMdx(content, task.targetLocale, engine);
          // Fix internal links
          translated = translated.replace(/href="\/en\//g, `href="/${task.targetLocale}/`);
          translated = translated.replace(/\]\(\/en\//g, `](/${task.targetLocale}/`);
        } else if (task.srcPath.endsWith('_meta.js')) {
          translated = await translateMetaJs(content, task.targetLocale, engine);
        }
        
        fs.mkdirSync(path.dirname(task.destPath), { recursive: true });
        fs.writeFileSync(task.destPath, translated, 'utf8');
        const relDestPath = path.relative(path.join(__dirname, '../app'), task.destPath);
        console.log(`[${engine.toUpperCase()}] ✓ Saved ${relDestPath}`);
        
      } catch (e) {
        console.error(`\n[FATAL ERROR] ${engine.toUpperCase()} blocked or failed: ${e.message}`);
        console.error("Stopping script immediately to prevent corrupted files.");
        process.exit(1); // Stop execution completely
      }
    }
  }

  // Run multiple Bing workers concurrently since Google is blocked locally
  await Promise.all([
    worker('bing'),
    worker('bing'),
    worker('google'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
    worker('bing'),
  ]);
  
  console.log("\nAll translations completed successfully!");
  process.exit(0);
}

run().catch(e => {
  console.error("Global Error:", e);
  process.exit(1);
});
