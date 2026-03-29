CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  full_name TEXT NULL,
  avatar TEXT N ULL,
  password_hash TEXT NOT NULL,
  role_id INT NOT NULL REFERENCES roles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO roles(name) VALUES ('ADMIN') ON CONFLICT (name) DO NOTHING;
INSERT INTO roles(name) VALUES ('USER')  ON CONFLICT (name) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);

-- ========== PERFUMERÍA: MÓDULO INVENTARIO ==========

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  country TEXT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE NULL,
  name TEXT NOT NULL,
  brand_id UUID NOT NULL REFERENCES brands(id),
  gender TEXT NULL CHECK (gender IN ('FEMENINO', 'MASCULINO', 'UNISEX')),
  description TEXT NULL,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- inventario actual por producto
CREATE TABLE IF NOT EXISTS inventory (
  product_id UUID PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  min_stock INT NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- índices útiles
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);