import type { FastifyInstance } from 'fastify';
import { authMiddleware } from '@middleware/auth';
import { sync } from '@services/sync';
import type { SyncRequest } from '@types/index';

export async function syncRoutes(fastify: FastifyInstance) {
  fastify.post<{ Body: SyncRequest }>(
    '/sync',
    { preHandler: authMiddleware },
    async (request, reply) => {
      try {
        const userId = (request as any).userId as string;
        const body = request.body;

        if (!Array.isArray(body?.ops)) {
          return reply.status(400).send({ error: 'ops must be an array' });
        }

        const result = await sync(userId, body);
        return reply.send(result);
      } catch (err: any) {
        fastify.log.error(err);
        return reply.status(500).send({ error: 'Sync failed', message: err.message });
      }
    }
  );
}
