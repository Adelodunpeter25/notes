import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { authRoutes } from '@routes/auth';
import { healthRoutes } from '@routes/health';
import { syncRoutes } from '@routes/sync';

const app = new Hono();

app.use('*', cors({ origin: (origin) => origin }));
app.route('/', healthRoutes);
app.route('/api/auth', authRoutes);
app.route('/api', syncRoutes);

export default app;
