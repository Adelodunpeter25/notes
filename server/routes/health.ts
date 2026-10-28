import { Hono } from 'hono';
import { sql } from 'drizzle-orm';
import { db } from '@db/index';

export const healthRoutes = new Hono()
  .get('/', (c) => c.json({ status: 'ok', service: 'notes-api' }))
  .get('/health', async (c) => {
    try {
      await db.run(sql`SELECT 1`);
      return c.json({ status: 'ok', timestamp: new Date().toISOString(), database: 'connected' });
    } catch (error) {
      return c.json({
        status: 'error',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: error instanceof Error ? error.message : 'Unknown error',
      }, 503);
    }
  });
