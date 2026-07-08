/**
 * KadianAI LABS — Node.js server-side-rendered frontend.
 *
 * Express + EJS renders the marketing site on the server. The Python service
 * is a SEPARATE microservice (not called from here) — this frontend stands on
 * its own. Security headers mirror the old Amplify customHttp.yml config.
 */
'use strict';

const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

// APP_VERSION is stamped at build time (Dockerfile ARG / Azure build number),
// so you can SEE which build is live.
const APP_VERSION = process.env.APP_VERSION || 'dev';
const PORT = parseInt(process.env.PORT || '3000', 10);
// Optional: URL of the Python microservice, surfaced to the page for reference.
const API_BASE_URL = process.env.API_BASE_URL || '';

const app = express();
app.disable('x-powered-by');

// ── View engine (SSR) ──
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// ── Middleware ──
app.use(morgan('combined'));
app.use(compression());

// Security headers — reproduces the Amplify customHttp.yml policy.
app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ['https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:'],
        scriptSrc: ["'self'", "'unsafe-inline'"],
      },
    },
    hsts: { maxAge: 31536000, includeSubDomains: true },
    frameguard: { action: 'deny' },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  })
);
app.use(helmet.xssFilter());

// ── Health check (load balancers / deploy scripts ping this) ──
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'frontend', version: APP_VERSION });
});

// ── Server-side-rendered home page ──
app.get('/', (_req, res) => {
  res.set('Cache-Control', 'no-cache');
  res.render('index', {
    version: APP_VERSION,
    year: new Date().getFullYear(),
    apiBaseUrl: API_BASE_URL,
  });
});

// ── Static assets (favicon, robots, sitemap, 404) with long cache ──
app.use(
  express.static(path.join(__dirname, 'public'), {
    maxAge: '30d',
    setHeaders(res, filePath) {
      if (filePath.endsWith('.html')) res.set('Cache-Control', 'no-cache');
    },
  })
);

// ── Custom 404 ──
app.use((_req, res) => {
  res.status(404).sendFile(path.join(__dirname, 'public', '404.html'));
});

// Export the app for tests; only listen when run directly.
if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`KadianAI frontend (v${APP_VERSION}) listening on :${PORT}`);
  });
}

module.exports = app;
