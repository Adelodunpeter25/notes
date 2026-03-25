import Fastify from 'fastify';
import cors from '@fastify/cors';
import { authRoutes, healthRoutes, syncRoutes } from '@routes/index';

const fastify = Fastify({
  logger: true
});

await fastify.register(cors, {
  origin: true
});

await fastify.register(healthRoutes);
await fastify.register(authRoutes, { prefix: '/api/auth' });
await fastify.register(syncRoutes, { prefix: '/api' });

const start = async () => {
  try {
    const port = parseInt(process.env.PORT || '8000');
    await fastify.listen({ port, host: '0.0.0.0' });
    console.log(`Server listening on http://localhost:${port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
