import cors from 'cors';
import express from 'express';
import morgan from 'morgan';
import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { router } from './routes/index.js';
import { routingMode } from './services/routing.service.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.use(
    cors({
      origin: env.CORS_ORIGINS,
      credentials: true,
      // Header khusus mode tamu.
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Call-Token'],
    }),
  );
  app.use(express.json({ limit: '256kb' }));
  if (env.NODE_ENV !== 'test') app.use(morgan('dev'));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'ambulans-backend',
      env: env.NODE_ENV,
      // Menunjukkan apakah Google Maps aktif atau sedang memakai fallback.
      routing: routingMode(),
      time: new Date().toISOString(),
    });
  });

  app.use('/api', router);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
