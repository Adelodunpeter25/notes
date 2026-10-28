import type { MiddlewareHandler } from 'hono';
import { authService } from '@services/index';

export type AppEnv = { Variables: { userId: string } };

export const authMiddleware: MiddlewareHandler<AppEnv> = async (c, next) => {
  const header = c.req.header('authorization');
  if (!header || !header.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  try {
    const { userId } = await authService.verifyToken(header.substring(7));
    c.set('userId', userId);
  } catch {
    return c.json({ error: 'Invalid token' }, 401);
  }
  await next();
};
