import type { FastifyRequest, FastifyReply } from 'fastify';
import { authService } from '@services/index';

export async function authMiddleware(request: FastifyRequest, reply: FastifyReply) {
  try {
    const authHeader = request.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Unauthorized' });
    }

    const token = authHeader.substring(7);
    const { userId } = authService.verifyToken(token);
    
    (request as any).userId = userId;
  } catch (error) {
    return reply.status(401).send({ error: 'Invalid token' });
  }
}
