import { createServer } from 'node:http';
import { createApp } from './app.js';
import { env, hasGoogleMaps } from './config/env.js';
import { pool } from './db/pool.js';
import { initSockets } from './sockets/index.js';

const app = createApp();
const httpServer = createServer(app);
initSockets(httpServer);

httpServer.listen(env.PORT, () => {
  console.log('');
  console.log('  Sigap — Backend');
  console.log(`  REST      : http://localhost:${env.PORT}/api`);
  console.log(`  Socket.io : ws://localhost:${env.PORT}`);
  console.log(`  Health    : http://localhost:${env.PORT}/health`);
  console.log(
    `  Routing   : ${hasGoogleMaps ? 'Google Maps (Distance Matrix + Geocoding)' : 'FALLBACK (haversine + alamat placeholder) — isi GOOGLE_MAPS_API_KEY untuk mengaktifkan Google Maps'}`,
  );
  console.log('');
});

async function shutdown(signal: string) {
  console.log(`\n[server] ${signal} diterima, menutup koneksi...`);
  httpServer.close();
  await pool.end();
  process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
