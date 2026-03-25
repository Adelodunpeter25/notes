import type { FastifyInstance } from 'fastify';
import { authService } from '@services/index';
import type { LoginPayload, SignupPayload } from '@types/index';

export async function authRoutes(fastify: FastifyInstance) {
  fastify.post<{ Body: SignupPayload }>('/signup', async (request, reply) => {
    try {
      const result = await authService.signup(request.body);
      return reply.send(result);
    } catch (error: any) {
      return reply.status(400).send({ error: error.message });
    }
  });

  fastify.post<{ Body: LoginPayload }>('/login', async (request, reply) => {
    try {
      const result = await authService.login(request.body);
      return reply.send(result);
    } catch (error: any) {
      return reply.status(401).send({ error: error.message });
    }
  });
}
