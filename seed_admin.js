require("dotenv").config();
const bcrypt = require("bcrypt");
const { randomUUID } = require("crypto");
const { pool } = require("./db");

async function run() {
  const username = String(process.env.ADMIN_SEED_USERNAME || "admin").trim();
  const password = String(process.env.ADMIN_SEED_PASSWORD || "");
  const fullName = String(process.env.ADMIN_SEED_FULLNAME || "Administrador").trim();

  if (!username) {
    throw new Error("ADMIN_SEED_USERNAME is required");
  }

  if (password.length < 8) {
    throw new Error("ADMIN_SEED_PASSWORD is required and must be at least 8 chars");
  }

  // role ADMIN
  const r = await pool.query(
    "SELECT id FROM roles WHERE UPPER(name) = 'ADMIN' LIMIT 1"
  );
  const roleId = r.rows[0]?.id;
  if (!roleId) throw new Error("Role ADMIN not found");

  // si ya existe, no hace nada
  const exists = await pool.query(
    "SELECT id FROM users WHERE username = $1 LIMIT 1",
    [username]
  );

  if (exists.rows.length) {
    console.log(`Admin already exists ✅ username=${username}`);
    return;
  }

  const hash = await bcrypt.hash(password, 10);

  await pool.query(
    `INSERT INTO users (id, username, full_name, password_hash, role_id)
     VALUES ($1, $2, $3, $4, $5)`,
    [randomUUID(), username, fullName || null, hash, roleId]
  );

  console.log(`Admin created ✅ username=${username}`);
}

run().catch((e) => {
  console.error("Seed error:", e);
  process.exitCode = 1;
}).finally(async () => {
  await pool.end();
});