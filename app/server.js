#!/usr/bin/env node
/**
 * WireGuard App Server
 * Simple Express server to serve the WireGuard manager app
 * Run: node server.js
 * Access: http://localhost:3000
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.static(path.join(__dirname)));

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'WireGuard App is running' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════╗
║  🔒 WireGuard VPN Manager App         ║
╠════════════════════════════════════════╣
║  Server running at: http://localhost:${PORT}   ║
║  Press Ctrl+C to stop                  ║
╚════════════════════════════════════════╝
  `);
});
