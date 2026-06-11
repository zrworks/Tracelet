const { execSync } = require('child_process');

const args = process.argv.slice(2);

let cmd = '';

if (args.length === 0 || args.includes('--help')) {
  console.log(`
Usage: node scripts/i18n-run.js [options]

Options:
  --clean       Run i18n-clean.js to delete translated folders
  --sync        Run i18n-sync.js to sync layout and meta files
  --translate   Run translate.js to translate MDX files
  --force       Force translation (overwrite existing), used with --translate
  --all         Perform all three steps in sequence (clean -> sync -> translate force)
  `);
  process.exit(0);
}

if (args.includes('--all')) {
  cmd = 'node scripts/i18n-clean.js --all && node scripts/i18n-sync.js && node scripts/translate.js --all --force';
} else {
  if (args.includes('--clean')) cmd += 'node scripts/i18n-clean.js --all && ';
  if (args.includes('--sync')) cmd += 'node scripts/i18n-sync.js && ';
  if (args.includes('--translate')) {
    cmd += 'node scripts/translate.js --all';
    if (args.includes('--force')) cmd += ' --force';
  } else {
    cmd = cmd.replace(/ && $/, '');
  }
}

if (cmd) {
  console.log('Executing:', cmd, '\n');
  execSync(cmd, { stdio: 'inherit' });
}
