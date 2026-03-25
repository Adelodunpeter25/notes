import "react-native-get-random-values";
import { v4 as uuidv4 } from "uuid";
import { getDb } from "../client";
import type { Task, CreateTaskPayload, UpdateTaskPayload } from "@shared/tasks";

function rowToTask(row: any): Task {
  return {
    id: row.id,
    userId: row.user_id ?? undefined,
    title: row.title,
    description: row.description,
    isCompleted: row.is_completed === 1,
    dueDate: row.due_date ?? undefined,
    createdAt: row.created_at ?? undefined,
    updatedAt: row.updated_at ?? undefined,
    deletedAt: row.deleted_at ?? undefined,
  };
}

export async function listTasks(params?: { q?: string }): Promise<Task[]> {
  const db = getDb();
  let sql = "SELECT * FROM tasks WHERE deleted_at IS NULL";
  const args: any[] = [];

  if (params?.q) {
    sql += " AND (title LIKE ? OR description LIKE ?)";
    const pattern = `%${params.q}%`;
    args.push(pattern, pattern);
  }

  sql += " ORDER BY is_completed ASC, updated_at DESC";
  const rows = await db.getAllAsync(sql, args);
  return rows.map(rowToTask);
}

export async function getTask(id: string): Promise<Task> {
  const db = getDb();
  const row = await db.getFirstAsync(
    "SELECT * FROM tasks WHERE id = ? AND deleted_at IS NULL",
    [id],
  );
  if (!row) throw new Error(`Task not found: ${id}`);
  return rowToTask(row);
}

export async function createTask(payload: CreateTaskPayload): Promise<Task> {
  const db = getDb();
  const id = uuidv4();
  const now = new Date().toISOString();
  await db.runAsync(
    "INSERT INTO tasks (id, title, description, is_completed, due_date, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [id, payload.title, payload.description ?? "", 0, payload.dueDate ?? null, now, now],
  );
  return getTask(id);
}

export async function updateTask(id: string, payload: UpdateTaskPayload): Promise<Task> {
  const db = getDb();
  const now = new Date().toISOString();
  const sets: string[] = [];
  const args: any[] = [];

  if (payload.title !== undefined) { sets.push("title = ?"); args.push(payload.title); }
  if (payload.description !== undefined) { sets.push("description = ?"); args.push(payload.description); }
  if (payload.isCompleted !== undefined) { sets.push("is_completed = ?"); args.push(payload.isCompleted ? 1 : 0); }
  if (payload.dueDate !== undefined) { sets.push("due_date = ?"); args.push(payload.dueDate); }

  if (sets.length > 0) {
    sets.push("updated_at = ?");
    args.push(now, id);
    await db.runAsync(
      `UPDATE tasks SET ${sets.join(", ")} WHERE id = ? AND deleted_at IS NULL`,
      args,
    );
  }
  return getTask(id);
}

export async function toggleTask(id: string): Promise<Task> {
  const db = getDb();
  const task = await getTask(id);
  return updateTask(id, { isCompleted: !task.isCompleted });
}

export async function deleteTask(id: string): Promise<void> {
  const db = getDb();
  const now = new Date().toISOString();
  await db.runAsync("UPDATE tasks SET deleted_at = ? WHERE id = ?", [now, id]);
}
