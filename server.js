require("dotenv").config();
const express = require("express");
const cors = require("cors");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { randomUUID } = require("crypto");
const { pool } = require("./db");

const app = express();
app.use(cors());
app.use(express.json({ limit: "10mb" }));

// ---------- Helpers ----------
function signToken(user) {
  return jwt.sign(
    { sub: user.id, username: user.username, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "7d" }
  );
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || "";
  const [type, token] = header.split(" ");

  if (type !== "Bearer" || !token) {
    return res
      .status(401)
      .json({ message: "Missing or invalid Authorization header" });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = payload;
    return next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user?.role) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden: insufficient role" });
    }
    return next();
  };
}

function normalizeRole(role) {
  const r = String(role || "USER").trim().toUpperCase();
  return r === "ADMIN" ? "ADMIN" : "USER";
}

function normalizeGender(g) {
  const v = String(g || "").trim().toUpperCase();
  if (!v) return null;
  if (v === "FEMENINO" || v === "MASCULINO" || v === "UNISEX") return v;
  return null;
}

function mapUserRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    username: row.username,
    fullName: row.full_name,
    city: row.city || null,
    role: row.role,
    avatar: row.avatar || null,
    createdAt: row.created_at || null,
  };
}

// ---------- Routes ----------
app.get("/health", (_req, res) => {
  res.json({ ok: true, app: "Essenza Backend" });
});

// REGISTER
app.post("/api/auth/register", async (req, res) => {
  try {
    const { username, password, fullName, role, adminKey, city } = req.body || {};

    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "username and password required" });
    }

    if (String(password).length < 4) {
      return res
        .status(400)
        .json({ message: "password must be at least 4 chars" });
    }

    const desiredRole = normalizeRole(role);

    if (desiredRole === "ADMIN") {
      const expected = String(process.env.ADMIN_REGISTER_KEY || "").trim();

      if (!expected) {
        return res.status(500).json({
          message: "ADMIN_REGISTER_KEY is not configured on server",
        });
      }

      if (String(adminKey || "").trim() !== expected) {
        return res.status(403).json({ message: "Admin key invalid" });
      }
    }

    const roleQuery = await pool.query(
      "SELECT id, name FROM roles WHERE UPPER(name) = $1 LIMIT 1",
      [desiredRole]
    );
    const roleId = roleQuery.rows[0]?.id;

    if (!roleId) {
      return res
        .status(500)
        .json({ message: `${desiredRole} role not found` });
    }

    const cleanUsername = String(username).trim();
    const cleanFullName =
      fullName !== undefined && String(fullName).trim() !== ""
        ? String(fullName).trim()
        : null;
    const cleanCity =
      city !== undefined && String(city).trim() !== ""
        ? String(city).trim()
        : null;

    const hash = await bcrypt.hash(String(password), 10);

    const result = await pool.query(
      `INSERT INTO users (
         id,
         username,
         full_name,
         password_hash,
         role_id,
         city
       )
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, username, full_name, city, avatar, created_at`,
      [randomUUID(), cleanUsername, cleanFullName, hash, roleId, cleanCity]
    );

    const user = result.rows[0];

    const token = signToken({
      id: user.id,
      username: user.username,
      role: desiredRole,
    });

    return res.status(201).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.full_name,
        city: user.city,
        role: desiredRole,
        avatar: user.avatar || null,
        createdAt: user.created_at || null,
      },
    });
  } catch (e) {
    if (e.code === "23505") {
      return res.status(409).json({ message: "username already exists" });
    }
    console.error("REGISTER ERROR:", e);
    return res.status(500).json({ message: "Server error" });
  }
});

// LOGIN
app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body || {};

    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "username and password required" });
    }

    const result = await pool.query(
      `SELECT
         u.id,
         u.username,
         u.full_name,
         u.city,
         u.avatar,
         u.password_hash,
         r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.username = $1
       LIMIT 1`,
      [String(username).trim()]
    );

    const user = result.rows[0];
    if (!user) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const valid = await bcrypt.compare(String(password), user.password_hash);
    if (!valid) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = signToken(user);

    return res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.full_name,
        city: user.city || null,
        role: user.role,
        avatar: user.avatar || null,
      },
    });
  } catch (e) {
    console.error("LOGIN ERROR:", e);
    return res.status(500).json({ message: "Server error" });
  }
});

// ME real desde BD
app.get("/api/me", authMiddleware, async (req, res) => {
  try {
    const q = await pool.query(
      `SELECT
         u.id,
         u.username,
         u.full_name,
         u.city,
         u.avatar,
         u.created_at,
         r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1
       LIMIT 1`,
      [req.user.sub]
    );

    const user = q.rows[0];
    if (!user) {
      return res.status(404).json({ message: "user not found" });
    }

    return res.json({ user: mapUserRow(user) });
  } catch (e) {
    console.error("ME ERROR:", e);
    return res.status(500).json({ message: "Server error" });
  }
});

// UPDATE PROFILE
app.put("/api/profile", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.sub;
    const { fullName, username, avatarBase64, city } = req.body || {};

    const currentQ = await pool.query(
      `SELECT
         u.id,
         u.username,
         u.full_name,
         u.city,
         u.avatar,
         u.created_at,
         r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1
       LIMIT 1`,
      [userId]
    );

    const currentUser = currentQ.rows[0];
    if (!currentUser) {
      return res.status(404).json({ message: "user not found" });
    }

    const newUsername =
      username !== undefined && String(username).trim() !== ""
        ? String(username).trim()
        : currentUser.username;

    const newFullName =
      fullName !== undefined ? String(fullName).trim() : currentUser.full_name;

    const newCity =
      city !== undefined ? String(city).trim() : currentUser.city;

    const newAvatar =
      avatarBase64 !== undefined && avatarBase64 !== null && avatarBase64 !== ""
        ? avatarBase64
        : currentUser.avatar;

    if (!newUsername) {
      return res.status(400).json({ message: "username is required" });
    }

    const duplicated = await pool.query(
      `SELECT id
       FROM users
       WHERE username = $1 AND id <> $2
       LIMIT 1`,
      [newUsername, userId]
    );

    if (duplicated.rows.length) {
      return res.status(409).json({ message: "username already exists" });
    }

    const q = await pool.query(
      `UPDATE users
       SET
         full_name = $1,
         username = $2,
         avatar = $3,
         city = $4
       WHERE id = $5
       RETURNING id, username, full_name, city, avatar, created_at`,
      [
        newFullName || null,
        newUsername,
        newAvatar || null,
        newCity || null,
        userId,
      ]
    );

    if (!q.rowCount) {
      return res.status(404).json({ message: "user not found" });
    }

    const roleQ = await pool.query(
      `SELECT r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.id = $1
       LIMIT 1`,
      [userId]
    );

    const updated = {
      ...q.rows[0],
      role: roleQ.rows[0]?.role || req.user.role,
    };

    return res.json({
      user: mapUserRow(updated),
    });
  } catch (e) {
    if (e.code === "23505") {
      return res.status(409).json({ message: "username already exists" });
    }
    console.error("PROFILE UPDATE ERROR:", e);
    return res.status(500).json({ message: "Server error" });
  }
});

// USERS (solo ADMIN)
app.get("/api/users", authMiddleware, requireRole("ADMIN"), async (_req, res) => {
  try {
    const q = await pool.query(
      `SELECT
         u.id,
         u.username,
         u.full_name,
         u.city,
         u.avatar,
         u.created_at,
         r.name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       ORDER BY u.created_at DESC`
    );

    return res.json({
      users: q.rows.map(mapUserRow),
    });
  } catch (e) {
    console.error("USERS ERROR:", e);
    return res.status(500).json({ message: "Server error" });
  }
});

/* =========================================================
   PERFUMERÍA: BRANDS / PRODUCTS / INVENTORY
   Roles:
   - ADMIN: todo
   - USER: CRUD inventario (por ahora)
   ========================================================= */

// BRANDS - list
app.get(
  "/api/brands",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (_req, res) => {
    try {
      const q = await pool.query(
        `SELECT id, name, country, created_at
         FROM brands
         ORDER BY name ASC`
      );
      return res.json({ brands: q.rows });
    } catch (e) {
      console.error("BRANDS LIST ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// BRANDS - create
app.post(
  "/api/brands",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { name, country } = req.body || {};
      if (!name || !String(name).trim()) {
        return res.status(400).json({ message: "name is required" });
      }

      const q = await pool.query(
        `INSERT INTO brands (name, country)
         VALUES ($1, $2)
         ON CONFLICT (name) DO UPDATE SET country = EXCLUDED.country
         RETURNING id, name, country, created_at`,
        [String(name).trim(), country || null]
      );

      return res.status(201).json({ brand: q.rows[0] });
    } catch (e) {
      console.error("BRANDS CREATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// BRANDS - update
app.put(
  "/api/brands/:id",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { id } = req.params;
      const { name, country } = req.body || {};

      if (!name || !String(name).trim()) {
        return res.status(400).json({ message: "name is required" });
      }

      const q = await pool.query(
        `UPDATE brands
         SET name = $1, country = $2
         WHERE id = $3
         RETURNING id, name, country`,
        [String(name).trim(), country || null, id]
      );

      if (!q.rowCount) {
        return res.status(404).json({ message: "brand not found" });
      }

      return res.json({ brand: q.rows[0] });
    } catch (e) {
      console.error("BRANDS UPDATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// BRANDS - delete
app.delete(
  "/api/brands/:id",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { id } = req.params;

      const used = await pool.query(
        "SELECT 1 FROM products WHERE brand_id = $1 LIMIT 1",
        [id]
      );

      if (used.rows.length) {
        return res
          .status(409)
          .json({ message: "brand is used by products" });
      }

      const q = await pool.query("DELETE FROM brands WHERE id = $1", [id]);

      if (!q.rowCount) {
        return res.status(404).json({ message: "brand not found" });
      }

      return res.json({ ok: true });
    } catch (e) {
      console.error("BRANDS DELETE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// PRODUCTS - list
app.get(
  "/api/products",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (_req, res) => {
    try {
      const q = await pool.query(
        `SELECT
           p.id,
           p.sku,
           p.name,
           p.gender,
           p.description,
           p.price,
           p.image_url,
           p.is_active,
           p.created_at,
           b.id AS brand_id,
           b.name AS brand_name,
           COALESCE(i.stock, 0) AS stock,
           COALESCE(i.min_stock, 0) AS min_stock
         FROM products p
         JOIN brands b ON b.id = p.brand_id
         LEFT JOIN inventory i ON i.product_id = p.id
         ORDER BY p.created_at DESC`
      );

      return res.json({ products: q.rows });
    } catch (e) {
      console.error("PRODUCTS LIST ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// PRODUCTS - create
app.post(
  "/api/products",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const {
        sku,
        name,
        brandId,
        gender,
        description,
        price,
        imageUrl,
        stock,
        minStock,
      } = req.body || {};

      if (!name || !String(name).trim()) {
        return res.status(400).json({ message: "name is required" });
      }

      if (!brandId) {
        return res.status(400).json({ message: "brandId is required" });
      }

      const g = normalizeGender(gender);
      if (gender && !g) {
        return res.status(400).json({
          message: "gender must be FEMENINO, MASCULINO, or UNISEX",
        });
      }

      const p = await pool.query(
        `INSERT INTO products (sku, name, brand_id, gender, description, price, image_url)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id`,
        [
          sku || null,
          String(name).trim(),
          brandId,
          g,
          description || null,
          Number(price || 0),
          imageUrl || null,
        ]
      );

      const productId = p.rows[0].id;

      if (stock !== undefined || minStock !== undefined) {
        await pool.query(
          `INSERT INTO inventory (product_id, stock, min_stock)
           VALUES ($1, $2, $3)
           ON CONFLICT (product_id)
           DO UPDATE SET
             stock = EXCLUDED.stock,
             min_stock = EXCLUDED.min_stock,
             updated_at = NOW()`,
          [productId, Number(stock || 0), Number(minStock || 0)]
        );
      }

      return res.status(201).json({ id: productId });
    } catch (e) {
      if (e.code === "23505") {
        return res.status(409).json({ message: "sku already exists" });
      }
      console.error("PRODUCTS CREATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// PRODUCTS - update
app.put(
  "/api/products/:id",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { id } = req.params;
      const {
        sku,
        name,
        brandId,
        gender,
        description,
        price,
        imageUrl,
        isActive,
      } = req.body || {};

      if (!name || !String(name).trim()) {
        return res.status(400).json({ message: "name is required" });
      }

      if (!brandId) {
        return res.status(400).json({ message: "brandId is required" });
      }

      const g = normalizeGender(gender);
      if (gender && !g) {
        return res.status(400).json({
          message: "gender must be FEMENINO, MASCULINO, or UNISEX",
        });
      }

      const q = await pool.query(
        `UPDATE products
         SET sku = $1,
             name = $2,
             brand_id = $3,
             gender = $4,
             description = $5,
             price = $6,
             image_url = $7,
             is_active = $8
         WHERE id = $9`,
        [
          sku || null,
          String(name).trim(),
          brandId,
          g,
          description || null,
          Number(price || 0),
          imageUrl || null,
          isActive === undefined ? true : Boolean(isActive),
          id,
        ]
      );

      if (!q.rowCount) {
        return res.status(404).json({ message: "product not found" });
      }

      return res.json({ ok: true });
    } catch (e) {
      console.error("PRODUCTS UPDATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// PRODUCTS - delete
app.delete(
  "/api/products/:id",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { id } = req.params;
      const q = await pool.query("DELETE FROM products WHERE id = $1", [id]);

      if (!q.rowCount) {
        return res.status(404).json({ message: "product not found" });
      }

      return res.json({ ok: true });
    } catch (e) {
      console.error("PRODUCTS DELETE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// INVENTORY - set stock/minStock
app.put(
  "/api/inventory/:productId",
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { productId } = req.params;
      const { stock, minStock } = req.body || {};

      await pool.query(
        `INSERT INTO inventory (product_id, stock, min_stock)
         VALUES ($1, $2, $3)
         ON CONFLICT (product_id)
         DO UPDATE SET
           stock = EXCLUDED.stock,
           min_stock = EXCLUDED.min_stock,
           updated_at = NOW()`,
        [productId, Number(stock || 0), Number(minStock || 0)]
      );

      return res.json({ ok: true });
    } catch (e) {
      console.error("INVENTORY UPDATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// ---------- Start ----------
const port = Number(process.env.PORT) || 3000;
app.listen(port, "0.0.0.0", () => {
  console.log(`Essenza backend running on port ${port}`);
});