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
  const allowedRoles = roles.map((role) => String(role || "").trim().toUpperCase());

  return (req, res, next) => {
    const userRole = String(req.user?.role || "").trim().toUpperCase();

    if (!userRole) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    if (!allowedRoles.includes(userRole)) {
      return res.status(403).json({ message: "Forbidden: insufficient role" });
    }
    return next();
  };
}

// normalizeRole: uso INTERNO únicamente (p.ej. seeds/scripts).
// NUNCA llamar con datos provenientes del frontend.
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

const EXTERNAL_PERFUMES_API_BASE = String(
  process.env.EXTERNAL_PERFUMES_API_BASE || "http://127.0.0.1:8000"
).replace(/\/+$/, "");

function normalizeExternalGender(gender) {
  const value = String(gender || "").trim().toUpperCase();
  if (!value) return null;
  if (value === "H" || value === "M" || value === "MASCULINO") return "MASCULINO";
  if (value === "F" || value === "FEMENINO") return "FEMENINO";
  if (value === "U" || value === "UNISEX") return "UNISEX";
  return null;
}

async function getRoleIdByName(roleName) {
  const normalizedRole = String(roleName || "").trim().toUpperCase();
  if (!normalizedRole) return null;

  const roleQuery = await pool.query(
    "SELECT id FROM roles WHERE UPPER(name) = $1 LIMIT 1",
    [normalizedRole]
  );

  return roleQuery.rows[0]?.id || null;
}

function getPublicBaseUrl(req) {
  const configured = String(process.env.PUBLIC_BASE_URL || "").trim();
  if (configured) {
    return configured.replace(/\/+$/, "");
  }
  return `${req.protocol}://${req.get("host")}`;
}

function toAbsoluteExternalImageUrl(imageUrl) {
  if (!imageUrl || !String(imageUrl).trim()) return null;

  const value = String(imageUrl).trim().replace(/\\/g, "/");

  if (/^https?:\/\//i.test(value)) return value;

  return `${EXTERNAL_PERFUMES_API_BASE}${value.startsWith("/") ? "" : "/"}${value}`;
}

function toClientImageUrl(req, imageUrl) {
  const absolute = toAbsoluteExternalImageUrl(imageUrl);
  if (!absolute) return null;

  const publicBase = getPublicBaseUrl(req);
  return `${publicBase}/api/external-image?url=${encodeURIComponent(absolute)}`;
}

async function fetchExternalPerfumes() {
  if (typeof fetch !== "function") {
    throw new Error("Global fetch is not available. Use Node.js 18+.");
  }

  const response = await fetch(`${EXTERNAL_PERFUMES_API_BASE}/perfumes`, {
    method: "GET",
    headers: { accept: "application/json" },
  });

  if (!response.ok) {
    const body = await response.text();
    const error = new Error("External API request failed");
    error.status = response.status;
    error.body = body;
    throw error;
  }

  const data = await response.json();
  return Array.isArray(data?.perfumes) ? data.perfumes : [];
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

// Proxy de imágenes externas para Flutter / móvil / emulador
app.get("/api/external-image", async (req, res) => {
  try {
    const rawUrl = String(req.query.url || "").trim();

    if (!rawUrl) {
      return res.status(400).json({ message: "Missing image url" });
    }

    const targetUrl = toAbsoluteExternalImageUrl(rawUrl);
    if (!targetUrl) {
      return res.status(400).json({ message: "Invalid image url" });
    }

    const response = await fetch(targetUrl);

    if (!response.ok) {
      return res.status(response.status).json({
        message: "Failed to fetch external image",
        status: response.status,
      });
    }

    const contentType =
      response.headers.get("content-type") || "application/octet-stream";

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=86400");
    return res.send(buffer);
  } catch (e) {
    console.error("EXTERNAL IMAGE PROXY ERROR:", e);
    return res.status(500).json({ message: "Failed to proxy image" });
  }
});

// REGISTER
app.post("/api/auth/register", async (req, res) => {
  try {
    // role y adminKey son ignorados deliberadamente: el frontend nunca define el rol.
    const { username, password, fullName, city } = req.body || {};

    const cleanUsername = String(username || "").trim();
    const cleanPassword = String(password || "");

    if (!cleanUsername || !cleanPassword) {
      return res
        .status(400)
        .json({ message: "username and password required" });
    }

    if (cleanPassword.length < 4) {
      return res
        .status(400)
        .json({ message: "password must be at least 4 chars" });
    }

    // El rol de registro público es siempre USER, sin excepción.
    const registrationRole = "USER";

    const roleId = await getRoleIdByName(registrationRole);

    if (!roleId) {
      return res
        .status(500)
        .json({ message: "USER role not found in database" });
    }

    const cleanFullName =
      fullName !== undefined && String(fullName).trim() !== ""
        ? String(fullName).trim()
        : null;
    const cleanCity =
      city !== undefined && String(city).trim() !== ""
        ? String(city).trim()
        : null;

    const hash = await bcrypt.hash(cleanPassword, 10);

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
      role: registrationRole,
    });

    return res.status(201).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.full_name,
        city: user.city,
        role: registrationRole,
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
  async (req, res) => {
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

      const products = q.rows.map((row) => ({
        ...row,
        image_url: toClientImageUrl(req, row.image_url),
      }));

      return res.json({ products });
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

// CLIENTS - list (read-only)
app.get(
  ["/clients", "/api/clients"],
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (_req, res) => {
    try {
      const q = await pool.query(
        `SELECT
           id,
           full_name,
           cedula,
           email,
           address,
           phone,
           is_active,
           created_at
         FROM clients
         ORDER BY created_at DESC`
      );

      return res.json({ clients: q.rows });
    } catch (e) {
      console.error("CLIENTS LIST ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// SALES - list (read-only)
app.get(
  ["/sales", "/api/sales"],
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (_req, res) => {
    try {
      const q = await pool.query(
        `SELECT
           s.id,
           s.sale_date,
           s.total,
           c.full_name AS client_name,
           c.cedula AS client_cedula
         FROM sales s
         JOIN clients c ON c.id = s.client_id
         ORDER BY s.sale_date DESC, s.created_at DESC`
      );

      return res.json({ sales: q.rows });
    } catch (e) {
      console.error("SALES LIST ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// SALES - get by id with header + detail (read-only)
app.get(
  ["/sales/:id", "/api/sales/:id"],
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    try {
      const { id } = req.params;

      const headerQ = await pool.query(
        `SELECT
           s.id,
           s.sale_date,
           s.total,
           s.created_at,
           c.id AS client_id,
           c.full_name AS client_name,
           c.cedula AS client_cedula,
           c.email AS client_email,
           c.address AS client_address,
           c.phone AS client_phone
         FROM sales s
         JOIN clients c ON c.id = s.client_id
         WHERE s.id = $1
         LIMIT 1`,
        [id]
      );

      if (!headerQ.rowCount) {
        return res.status(404).json({ message: "sale not found" });
      }

      const detailsQ = await pool.query(
        `SELECT
           sd.id,
           sd.product_id,
           p.name AS product_name,
           p.sku AS product_sku,
           b.name AS brand_name,
           sd.quantity,
           sd.unit_price,
           sd.subtotal
         FROM sale_details sd
         JOIN products p ON p.id = sd.product_id
         LEFT JOIN brands b ON b.id = p.brand_id
         WHERE sd.sale_id = $1
         ORDER BY p.name ASC`,
        [id]
      );

      return res.json({
        sale: headerQ.rows[0],
        details: detailsQ.rows,
      });
    } catch (e) {
      console.error("SALE DETAIL ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// SALES - create with automatic inventory stock decrement
app.post(
  ["/sales", "/api/sales"],
  authMiddleware,
  requireRole("ADMIN", "USER"),
  async (req, res) => {
    const { clientId, items } = req.body || {};

    if (!clientId) {
      return res.status(400).json({ message: "clientId is required" });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: "items must be a non-empty array" });
    }

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (!item.productId || !Number.isFinite(item.quantity) || item.quantity <= 0) {
        return res.status(400).json({
          message: `item ${i}: productId and quantity (>0) are required`,
        });
      }
    }

    let inTransaction = false;

    try {
      await pool.query("BEGIN");
      inTransaction = true;

      // Verificar cliente
      const clientQ = await pool.query(
        `SELECT id, is_active FROM clients WHERE id = $1 LIMIT 1`,
        [clientId]
      );

      if (!clientQ.rowCount) {
        await pool.query("ROLLBACK");
        return res.status(404).json({ message: "client not found" });
      }

      if (!clientQ.rows[0].is_active) {
        await pool.query("ROLLBACK");
        return res.status(400).json({ message: "client is not active" });
      }

      let total = 0;
      const validatedItems = [];

      // Validar productos, verificar stock y resolver precios
      for (const item of items) {
        const productQ = await pool.query(
          `SELECT p.id, p.name, p.price, i.stock
           FROM products p
           LEFT JOIN inventory i ON i.product_id = p.id
           WHERE p.id = $1 LIMIT 1`,
          [item.productId]
        );

        if (!productQ.rowCount) {
          await pool.query("ROLLBACK");
          return res.status(404).json({
            message: `product ${item.productId} not found`,
          });
        }

        const product = productQ.rows[0];
        const currentStock = product.stock || 0;
        const requestedQty = Number(item.quantity);

        if (currentStock < requestedQty) {
          await pool.query("ROLLBACK");
          return res.status(400).json({
            message: `product ${product.name}: insufficient stock (available: ${currentStock}, requested: ${requestedQty})`,
          });
        }

        const unitPrice = Number(product.price || 0);
        const subtotal = unitPrice * requestedQty;
        total += subtotal;

        validatedItems.push({
          productId: item.productId,
          quantity: requestedQty,
          unitPrice,
          subtotal,
        });
      }

      // Crear venta
      const saleQ = await pool.query(
        `INSERT INTO sales (client_id, sale_date, total)
         VALUES ($1, NOW(), $2)
         RETURNING id`,
        [clientId, total]
      );

      const saleId = saleQ.rows[0].id;

      // Crear detalles de venta y actualizar stock
      for (const item of validatedItems) {
        // Insertar detalle
        await pool.query(
          `INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal)
           VALUES ($1, $2, $3, $4, $5)`,
          [saleId, item.productId, item.quantity, item.unitPrice, item.subtotal]
        );

        // Decrementar stock
        await pool.query(
          `UPDATE inventory
           SET stock = stock - $1, updated_at = NOW()
           WHERE product_id = $2`,
          [item.quantity, item.productId]
        );
      }

      await pool.query("COMMIT");
      inTransaction = false;

      // Obtener venta completa creada
      const createdSaleQ = await pool.query(
        `SELECT
           s.id,
           s.sale_date,
           s.total,
           s.created_at,
           c.id AS client_id,
           c.full_name AS client_name,
           c.cedula AS client_cedula
         FROM sales s
         JOIN clients c ON c.id = s.client_id
         WHERE s.id = $1`,
        [saleId]
      );

      const detailsQ = await pool.query(
        `SELECT
           sd.id,
           sd.product_id,
           p.name AS product_name,
           p.sku AS product_sku,
           b.name AS brand_name,
           sd.quantity,
           sd.unit_price,
           sd.subtotal
         FROM sale_details sd
         JOIN products p ON p.id = sd.product_id
         LEFT JOIN brands b ON b.id = p.brand_id
         WHERE sd.sale_id = $1
         ORDER BY p.name ASC`,
        [saleId]
      );

      return res.status(201).json({
        sale: createdSaleQ.rows[0],
        details: detailsQ.rows,
      });
    } catch (e) {
      if (inTransaction) {
        await pool.query("ROLLBACK");
      }
      console.error("SALES CREATE ERROR:", e);
      return res.status(500).json({ message: "Server error" });
    }
  }
);

// INTEGRATION - external perfumes API list
app.get(
  "/api/integrations/perfumes/external",
  authMiddleware,
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const perfumes = await fetchExternalPerfumes();

      const mapped = perfumes.map((item) => ({
        ...item,
        gender_mapped: normalizeExternalGender(item.gender),
        image_url_absolute: toAbsoluteExternalImageUrl(item.image_url),
        image_url_client: toClientImageUrl(req, item.image_url),
      }));

      return res.json({
        source: EXTERNAL_PERFUMES_API_BASE,
        total: mapped.length,
        perfumes: mapped,
      });
    } catch (e) {
      console.error("EXTERNAL PERFUMES LIST ERROR:", e);
      return res.status(502).json({
        message: "Failed to fetch perfumes from external API",
        detail: e.message,
        status: e.status || null,
      });
    }
  }
);

// INTEGRATION - external perfumes options for frontend picker
app.get(
  "/api/integrations/perfumes/options",
  authMiddleware,
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const q = String(req.query.q || "").trim().toLowerCase();
      const genderFilter = normalizeExternalGender(req.query.gender);
      const limitRaw = Number(req.query.limit || 100);
      const limit = Number.isFinite(limitRaw)
        ? Math.min(Math.max(Math.trunc(limitRaw), 1), 500)
        : 100;

      const perfumes = await fetchExternalPerfumes();

      const options = perfumes
        .map((item) => {
          const name = String(item?.name || "").trim();
          const brand = String(item?.brand || "").trim();
          const gender = normalizeExternalGender(item?.gender);
          const imageUrl = toClientImageUrl(req, item?.image_url);

          return {
            externalId: item?.id || null,
            name,
            brand,
            gender,
            imageUrl,
            label: `${name}${brand ? ` - ${brand}` : ""}`,
          };
        })
        .filter((item) => item.name)
        .filter((item) => {
          if (!q) return true;
          const text = `${item.name} ${item.brand}`.toLowerCase();
          return text.includes(q);
        })
        .filter((item) => {
          if (!genderFilter) return true;
          return item.gender === genderFilter;
        })
        .slice(0, limit);

      return res.json({
        source: EXTERNAL_PERFUMES_API_BASE,
        q,
        gender: genderFilter,
        total: options.length,
        options,
      });
    } catch (e) {
      console.error("EXTERNAL PERFUMES OPTIONS ERROR:", e);
      return res.status(502).json({
        message: "Failed to fetch perfume options from external API",
        detail: e.message,
        status: e.status || null,
      });
    }
  }
);

// INTEGRATION - sync external perfumes to local brands/products
app.post(
  "/api/integrations/perfumes/sync",
  authMiddleware,
  requireRole("ADMIN"),
  async (req, res) => {
    const defaultPriceRaw = req.body?.defaultPrice;
    const defaultPrice =
      defaultPriceRaw === undefined ? 0 : Number(defaultPriceRaw);

    if (!Number.isFinite(defaultPrice) || defaultPrice < 0) {
      return res.status(400).json({
        message: "defaultPrice must be a number >= 0",
      });
    }

    let inTransaction = false;

    try {
      const perfumes = await fetchExternalPerfumes();

      let created = 0;
      let updated = 0;
      let skipped = 0;

      await pool.query("BEGIN");
      inTransaction = true;

      for (const item of perfumes) {
        const perfumeName = String(item?.name || "").trim();
        if (!perfumeName) {
          skipped += 1;
          continue;
        }

        const brandName =
          String(item?.brand || "").trim() || "SIN_MARCA";

        const brandQuery = await pool.query(
          `INSERT INTO brands (name)
           VALUES ($1)
           ON CONFLICT (name)
           DO UPDATE SET name = EXCLUDED.name
           RETURNING id`,
          [brandName]
        );
        const brandId = brandQuery.rows[0].id;

        const gender = normalizeExternalGender(item?.gender);
        const description =
          item?.description !== undefined && item?.description !== null
            ? String(item.description)
            : null;
        const imageUrl =
          item?.image_url !== undefined && item?.image_url !== null
            ? String(item.image_url).trim()
            : null;

        const existing = await pool.query(
          `SELECT id
           FROM products
           WHERE brand_id = $1 AND LOWER(name) = LOWER($2)
           LIMIT 1`,
          [brandId, perfumeName]
        );

        if (existing.rowCount) {
          await pool.query(
            `UPDATE products
             SET gender = $1,
                 description = $2,
                 image_url = $3,
                 is_active = TRUE
             WHERE id = $4`,
            [gender, description, imageUrl, existing.rows[0].id]
          );
          updated += 1;
          continue;
        }

        await pool.query(
          `INSERT INTO products (name, brand_id, gender, description, price, image_url)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [perfumeName, brandId, gender, description, defaultPrice, imageUrl]
        );
        created += 1;
      }

      await pool.query("COMMIT");
      inTransaction = false;

      return res.json({
        source: EXTERNAL_PERFUMES_API_BASE,
        totalExternal: perfumes.length,
        created,
        updated,
        skipped,
      });
    } catch (e) {
      if (inTransaction) {
        await pool.query("ROLLBACK");
      }
      console.error("EXTERNAL PERFUMES SYNC ERROR:", e);
      return res.status(502).json({
        message: "Failed to sync perfumes from external API",
        detail: e.message,
        status: e.status || null,
      });
    }
  }
);

// ---------- Start ----------
const port = Number(process.env.PORT) || 3000;
app.listen(port, "0.0.0.0", () => {
  console.log(`Essenza backend running on port ${port}`);
});