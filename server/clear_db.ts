import postgres from 'postgres';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error("DATABASE_URL is not set in environment!");
  process.exit(1);
}

console.log("Connecting to database to clear all data...");
const sql = postgres(connectionString);

try {
  // Truncate all tables in database
  await sql`TRUNCATE TABLE notes, folders, users, sync_state CASCADE;`;
  console.log("Database cleared successfully!");
} catch (e) {
  console.error("Failed to clear database:", e);
  process.exit(1);
} finally {
  await sql.end();
}
