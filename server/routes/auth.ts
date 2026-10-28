import { Hono } from 'hono';
import { authService } from '@services/index';
import type { LoginPayload, SignupPayload } from '@custom-types/index';

export const authRoutes = new Hono()
  .post('/signup', async (c) => {
    try {
      return c.json(await authService.signup(await c.req.json<SignupPayload>()));
    } catch (error: any) {
      return c.json({ error: error.message }, 400);
    }
  })
  .post('/login', async (c) => {
    try {
      return c.json(await authService.login(await c.req.json<LoginPayload>()));
    } catch (error: any) {
      return c.json({ error: error.message }, 401);
    }
  });
