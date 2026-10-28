import { drizzle } from 'drizzle-orm/libsql';
import { createClient } from '@libsql/client';
import * as schema from '@db/schema/index';

const client = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

// libSQL does not enforce foreign keys unless asked to.
await client.execute('PRAGMA foreign_keys = ON');

export const db = drizzle(client, { schema });
