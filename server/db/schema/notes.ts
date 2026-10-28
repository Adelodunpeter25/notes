import { sqliteTable, text, integer, index } from 'drizzle-orm/sqlite-core';
import { users } from './users';
import { folders } from './folders';

export const notes = sqliteTable('notes', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  folderId: text('folder_id').references(() => folders.id, { onDelete: 'set null' }),
  title: text('title').notNull().default('Untitled'),
  content: text('content').notNull().default(''),
  isPinned: integer('is_pinned', { mode: 'boolean' }).notNull().default(false),
  createdAt: integer('created_at', { mode: 'timestamp_ms' }).$defaultFn(() => new Date()).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp_ms' }).$defaultFn(() => new Date()).notNull(),
  deletedAt: integer('deleted_at', { mode: 'timestamp_ms' }),
}, (t) => [index('notes_user_updated_idx').on(t.userId, t.updatedAt)]);
