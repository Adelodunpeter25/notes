import Database from "@tauri-apps/plugin-sql";

let databasePromise: Promise<Database> | null = null;

export async function getLocalDatabase() {
  if (!databasePromise) {
    databasePromise = Database.load("sqlite:notes.db");
  }
  return databasePromise;
}

export async function persistDatabase() {
  // tauri-plugin-sql persists automatically to disk
  return Promise.resolve();
}

export async function initializeLocalDatabase() {
  await getLocalDatabase();
}
