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
    userId: row.user_id ?? undefined,
    title: row.title,
    description: row.description,
    isCompleted: Boolean(row.is_completed),
    dueDate: row.due_date ?? undefined,
    createdAt: row.created_at ?? "",
    updatedAt: row.updated_at ?? "",
  };
}

function nowISO() {
  return new Date().toISOString();
}

function generateID() {
  const uniquePart =
    typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

  return `local_${uniquePart}`;
}

function buildFtsMatchQuery(input: string | null | undefined): string | null {
  const trimmed = input?.trim();
  if (!trimmed) {
    return null;
  }

  const tokens = trimmed
    .split(/\s+/)
    .map((token) => token.replace(/"/g, '""').trim())
    .filter(Boolean);

  if (!tokens.length) {
    return null;
  }

  return tokens.map((token) => `"${token}"*`).join(" AND ");
}

export async function listTasksLocal(params?: { q?: string }): Promise<Task[]> {
  const db = await getLocalDatabase();

  const q = params?.q?.trim() || null;
  const ftsQuery = buildFtsMatchQuery(q);

  const rows = ftsQuery
    ? await db.getAllAsync<TaskRow>(
      `
        SELECT
          t.id,
          t.user_id,
          t.title,
          t.description,
          t.is_completed,
          t.due_date,
          t.created_at,
          t.updated_at
        FROM tasks t
        JOIN tasks_fts ON tasks_fts.rowid = t.rowid
        WHERE t.deleted_at IS NULL
          AND tasks_fts MATCH ?
        ORDER BY
          t.is_completed ASC,
          bm25(tasks_fts),
          COALESCE(t.updated_at, t.created_at) DESC
      `,
      ftsQuery,
    )
    : await db.getAllAsync<TaskRow>(
      `
        SELECT
          id,
          user_id,
          title,
          description,
          is_completed,
          due_date,
          created_at,
          updated_at
        FROM tasks
        WHERE deleted_at IS NULL
        ORDER BY is_completed ASC, COALESCE(updated_at, created_at) DESC
      `,
    );

  return rows.map(mapRow);
}

export async function upsertTasksLocal(tasks: Task[]): Promise<void> {
  if (!tasks.length) {
    return;
  }

  const db = await getLocalDatabase();
  for (const task of tasks) {
    await db.runAsync(
      `
        INSERT INTO tasks (
          id,
          user_id,
          title,
          description,
          is_completed,
          due_date,
          created_at,
          updated_at,
          deleted_at,
          dirty
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, 0)
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
      task.id,
      task.userId ?? null,
      task.title ?? "Untitled",
      task.description ?? "",
      task.isCompleted ? 1 : 0,
      task.dueDate ?? null,
      task.createdAt ?? null,
      task.updatedAt ?? null,
    );
  }
}

export async function getTaskByIDLocal(taskId: string): Promise<Task | null> {
  const db = await getLocalDatabase();
  const row = await db.getFirstAsync<TaskRow>(
    `
      SELECT id, user_id, title, description, is_completed, due_date, created_at, updated_at
      FROM tasks
      WHERE id = ? AND deleted_at IS NULL
    `,
    taskId,
  );

  return row ? mapRow(row) : null;
}

export async function createTaskLocal(payload: CreateTaskPayload) {
  const db = await getLocalDatabase();
  const id = generateID();
  const timestamp = nowISO();
  const task: Task = {
    id,
    title: payload.title ?? "Untitled",
    description: payload.description ?? "",
    isCompleted: payload.isCompleted ?? false,
    dueDate: payload.dueDate,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await db.runAsync(
    `
      INSERT INTO tasks (
        id, title, description, is_completed, due_date, created_at, updated_at, deleted_at, dirty
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1)
    `,
    task.id,
    task.title,
    task.description,
    task.isCompleted ? 1 : 0,
    task.dueDate ?? null,
    task.createdAt ?? null,
    task.updatedAt ?? null,
  );

  return task;
}

export async function updateTaskLocal(taskId: string, payload: UpdateTaskPayload): Promise<Task | null> {
  const existing = await getTaskByIDLocal(taskId);
  if (!existing) {
    return null;
  }

  const db = await getLocalDatabase();
  const updated: Task = {
    ...existing,
    ...(payload.title !== undefined ? { title: payload.title } : {}),
    ...(payload.description !== undefined ? { description: payload.description } : {}),
    ...(payload.isCompleted !== undefined ? { isCompleted: payload.isCompleted } : {}),
    ...(payload.dueDate !== undefined ? { dueDate: payload.dueDate } : {}),
    updatedAt: nowISO(),
  };

  await db.runAsync(
    `
      UPDATE tasks
      SET title = ?,
          description = ?,
          is_completed = ?,
          due_date = ?,
          updated_at = ?,
          dirty = 1
      WHERE id = ?
    `,
    updated.title,
    updated.description,
    updated.isCompleted ? 1 : 0,
    updated.dueDate ?? null,
    updated.updatedAt ?? null,
    taskId,
  );

  return updated;
}

export async function markTaskDeletedLocal(taskId: string): Promise<void> {
  const db = await getLocalDatabase();
  await db.runAsync(
    `
      UPDATE tasks
      SET deleted_at = ?, updated_at = ?, dirty = 1
      WHERE id = ?
    `,
    nowISO(),
    nowISO(),
    taskId,
  );
}

export async function replaceLocalTaskID(oldID: string, newID: string): Promise<void> {
  const db = await getLocalDatabase();
  await db.runAsync(`UPDATE tasks SET id = ? WHERE id = ?`, newID, oldID);
}
