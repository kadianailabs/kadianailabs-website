// Render the existing EJS website once; production needs no Node runtime.
'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const ejs = require('ejs');

async function build() {
  const output = path.join(__dirname, 'dist');
  const version = process.env.APP_VERSION || 'dev';
  await fs.rm(output, { recursive: true, force: true });
  await fs.cp(path.join(__dirname, 'public'), output, { recursive: true });
  const html = await ejs.renderFile(path.join(__dirname, 'views/index.ejs'), {
    version, year: new Date().getFullYear(), apiBaseUrl: process.env.API_BASE_URL || '',
  });
  await fs.writeFile(path.join(output, 'index.html'), html);
  await fs.writeFile(path.join(output, 'health'), JSON.stringify({
    status: 'ok', service: 'frontend', version,
  }));
}
build().catch((error) => { console.error(error); process.exitCode = 1; });
