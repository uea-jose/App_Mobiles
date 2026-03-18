require("dotenv").config();
const bcrypt = require("bcrypt");
const { pool } = require("./db");

async function run() {
  const username = "admin";
  const password = "admin";
  const fullName = "Administrador";

  // role ADMIN
  const r = await pool.query("SELECT id FROM roles WHERE name = 'ADMIN'");
  const roleId = r.rows[0]?.id;
  if (!roleId) throw new Error("Role ADMIN not found");

  // si ya existe, no hace nada
  const exists = await pool.query("SELECT id FROM users WHERE username = $1", [username]);
  if (exists.rows.length) {
    console.log("Admin already exists ✅");
    process.exit(0);
  }

  const hash = await bcrypt.hash(password, 10);

  await pool.query(
    `INSERT INTO users (username, password_hash, role_id)
     VALUES ($1, $2, $3)`,
    [username, fullName ,hash, roleId]
  );

  console.log("Admin created ✅  username=admin  password=admin");
  process.exit(0);
}

run().catch((e) => {
  console.error("Seed error:", e);
  process.exit(1);
});