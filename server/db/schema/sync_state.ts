import { pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { users } from './users';

export const syncState = pgTable('sync_state', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  deviceId: text('device_id').notNull(), // Unique identifier per device
  lastCursor: text('last_cursor'),
  lastSyncAt: timestamp('last_sync_at'),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});
