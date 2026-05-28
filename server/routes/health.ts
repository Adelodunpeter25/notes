import type { FastifyInstance } from 'fastify';
import { db } from '@db/index';

export async function healthRoutes(fastify: FastifyInstance) {
  fastify.get('/', async () => {
    return { status: 'ok', service: 'notes-api' };
  });

  fastify.get('/health', async (request, reply) => {
    try {
      // Check database connection
      await db.execute('SELECT 1');
      
      return {
        status: 'ok',
        timestamp: new Date().toISOString(),
        database: 'connected',
      };
    } catch (error) {
      return reply.status(503).send({
        status: 'error',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });
}
