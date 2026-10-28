import { Hono } from 'hono';
import { authMiddleware, type AppEnv } from '@middleware/auth';
import { sync, syncForce } from '@services/sync';
import type { SyncRequest } from '@custom-types/index';

export const syncRoutes = new Hono<AppEnv>()
  .post('/sync', authMiddleware, async (c) => {
    try {
      const body = await c.req.json<SyncRequest>();
      if (!Array.isArray(body?.ops)) {
        return c.json({ error: 'ops must be an array' }, 400);
      }
      return c.json(await sync(c.get('userId'), body));
    } catch (err: any) {
      console.error('sync failed', err);
      return c.json({ error: 'Sync failed', message: err.message }, 500);
    }
  })
  .post('/sync-force', authMiddleware, async (c) => {
    try {
      const result = await syncForce(c.get('userId'));
      console.log('[sync-force] full snapshot', { notes: result.notes.length, folders: result.folders.length });
      return c.json(result);
    } catch (err: any) {
      console.error('force sync failed', err);
      return c.json({ error: 'Force sync failed', message: err.message }, 500);
    }
  });
