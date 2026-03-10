import type { Task, CreateTaskPayload, UpdateTaskPayload } from "@shared/tasks";
import { getLocalDatabase } from "@/db/client";

type TaskRow = {
  id: string;
  user_id: string | null;
  title: string;
  description: string;
  is_completed: number;
  due_date: string | null;
  created_at: string | null;
  updated_at: string | null;
};

function mapRow(row: TaskRow): Task {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    isCompleted: Boolean(row.is_completed),
    dueDate: row.due_date ?? undefined,
    createdAt: row.created_at || nowISO(),
    updatedAt: row.updated_at || nowISO(),
  };
}

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  return `local_${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function listTasksLocal(params?: { q?: string }): Promise<Task[]> {
  const db = await getLocalDatabase();
  const query = params?.q?.trim() ?? "";
  const likePattern = `%${query}%`;

  const rows = await db.select<TaskRow[]>(
    `
    SELECT id, user_id, title, description, is_completed, due_date, created_at, updated_at
    FROM tasks
    WHERE deleted_at IS NULL
      AND ($1 = '' OR lower(title) LIKE lower($2) OR lower(description) LIKE lower($3))
    ORDER BY is_completed ASC, COALESCE(due_date, '9999') ASC, created_at DESC
  `,
    [query, likePattern, likePattern],
  );

  return rows.map(mapRow);
}

export async function upsertTasksLocal(tasks: Task[]): Promise<void> {
  if (!tasks.length) return;

  const db = await getLocalDatabase();

  for (const task of tasks) {
    await db.execute(
      `
      INSERT INTO tasks (
        id, title, description, is_completed, due_date, created_at, updated_at, deleted_at, dirty
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 0)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        is_completed = excluded.is_completed,
        due_date = excluded.due_date,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        deleted_at = NULL
      WHERE tasks.dirty = 0
    `,
      [
        task.id,
        task.title ?? "Untitled",
        task.description ?? "",
        task.isCompleted ? 1 : 0,
        task.dueDate ?? null,
        task.createdAt ?? null,
        task.updatedAt ?? null,
      ],
    );
  }
}

export async function createTaskLocal(payload: CreateTaskPayload) {
  const db = await getLocalDatabase();
  const id = generateID();
  const timestamp = nowISO();

  const task: Task = {
    id,
    title: payload.title,
    description: payload.description ?? "",
    isCompleted: payload.isCompleted ?? false,
    dueDate: payload.dueDate,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await db.execute(
    `
      INSERT INTO tasks (
        id, title, description, is_completed, due_date, created_at, updated_at, deleted_at, dirty
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 1)
    `,
    [
      task.id,
      task.title,
      task.description,
      task.isCompleted ? 1 : 0,
      task.dueDate ?? null,
      task.createdAt,
      task.updatedAt,
    ],
  );

  return task;
}

export async function updateTaskLocal(taskId: string, payload: UpdateTaskPayload): Promise<Task | null> {
  const db = await getLocalDatabase();
  const rows = await db.select<TaskRow[]>(
    `
      SELECT id, title, description, is_completed, due_date, created_at, updated_at
      FROM tasks
      WHERE id = $1 AND deleted_at IS NULL
    `,
    [taskId],
  );

  if (!rows.length) {
    return null;
  }

  const row = rows[0];
  const current: Task = mapRow(row);

  const updated: Task = {
    ...current,
    ...(payload.title !== undefined ? { title: payload.title } : {}),
    ...(payload.description !== undefined ? { description: payload.description } : {}),
    ...(payload.isCompleted !== undefined ? { isCompleted: payload.isCompleted } : {}),
    ...(payload.dueDate !== undefined ? { dueDate: payload.dueDate } : {}),
    updatedAt: nowISO(),
  };

  await db.execute(
    `
      UPDATE tasks
      SET title = $1,
          description = $2,
          is_completed = $3,
          due_date = $4,
          updated_at = $5,
          dirty = 1
      WHERE id = $6
    `,
    [
      updated.title,
      updated.description,
      updated.isCompleted ? 1 : 0,
      updated.dueDate ?? null,
      updated.updatedAt ?? null,
      taskId,
    ],
  );

  return updated;
}

export async function markTaskDeletedLocal(taskId: string) {
  const db = await getLocalDatabase();
  const now = nowISO();
  await db.execute(
    `UPDATE tasks SET deleted_at = $1, updated_at = $2, dirty = 1 WHERE id = $3`,
    [now, now, taskId],
  );
}

export async function replaceLocalTaskID(oldID: string, newID: string) {
  const db = await getLocalDatabase();
  await db.execute(`UPDATE tasks SET id = $1 WHERE id = $2`, [newID, oldID]);
  await db.execute(`UPDATE sync_outbox SET entity_id = $1 WHERE entity_type = 'task' AND entity_id = $2`, [newID, oldID]);
}
