import { pool } from "../lib/db";

// Runs on every deploy, production included.
export async function seedAdmin() {
  await pool.query(
    "INSERT INTO users (email, password_hash, is_admin) VALUES ('admin@example.com', 'admin123', true) ON CONFLICT DO NOTHING",
  );
}
