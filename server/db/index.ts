import { drizzle } from 'drizzle-orm/libsql/web';
import { createClient } from '@libsql/client/web';
import { env } from 'cloudflare:workers';
import * as schema from '@db/schema/index';

type Db = ReturnType<typeof drizzle<typeof schema>>;

let instance: Db | undefined;

function getDb(): Db {
  if (!instance) {
    const client = createClient({
      url: env.TURSO_DATABASE_URL,
      authToken: env.TURSO_AUTH_TOKEN,
    });
    instance = drizzle(client, { schema });
  }
  return instance;
}

// Lazy proxy: `env` only exists once a request is being handled on Workers,
// so the client must not be created at module load.
export const db = new Proxy({} as Db, {
  get: (_t, prop) => Reflect.get(getDb(), prop),
});
