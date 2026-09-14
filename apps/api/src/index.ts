import 'dotenv/config';

import express from 'express';
import cors from 'cors';
import { clerkMiddleware, getAuth } from '@clerk/express';

import { connectDatabase } from './db.js';

const app = express();

const port = Number(process.env.PORT ?? 3001);

// Clerk recommends putting this before other middleware.
app.use(clerkMiddleware());

app.use(
  cors({
    origin: process.env.WEB_ORIGIN ?? 'http://localhost:5173'
  })
);

app.use(express.json());

// Public route
app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

// Protected route
app.get('/api/whoami', (req, res) => {
  const { isAuthenticated, userId } = getAuth(req);

  if (!isAuthenticated) {
    res.status(401).json({
      error: 'Unauthorized'
    });
    return;
  }

  res.json({
    userId
  });
});

await connectDatabase();

app.listen(port, () => {
  console.log(`API running at http://localhost:${port}`);
});