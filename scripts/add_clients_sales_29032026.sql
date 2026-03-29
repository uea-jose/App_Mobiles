CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================
-- CLIENTS / SALES / SALE_DETAILS
-- =========================================

CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  cedula TEXT NOT NULL UNIQUE,
  email TEXT NULL,
  address TEXT NULL,
  phone TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES clients(id),
  sale_date TIMESTAMP NOT NULL DEFAULT NOW(),
  total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sale_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

-- =========================================
-- Indexes útiles
-- =========================================

CREATE INDEX IF NOT EXISTS idx_clients_is_active ON clients(is_active);
CREATE INDEX IF NOT EXISTS idx_clients_full_name ON clients(full_name);
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON clients(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_email_lower ON clients ((LOWER(email)));

CREATE INDEX IF NOT EXISTS idx_sales_client_id ON sales(client_id);
CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON sales(sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sale_details_sale_id ON sale_details(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_details_product_id ON sale_details(product_id);

-- =========================================
-- Inserts de ejemplo (idempotentes)
-- =========================================

INSERT INTO clients (full_name, cedula, email, address, phone)
VALUES
  ('Ana Pérez', '0102030405', 'ana.perez@example.com', 'Quito', '0991111111'),
  ('Carlos Mora', '1717171717', 'carlos.mora@example.com', 'Guayaquil', '0992222222')
ON CONFLICT (cedula) DO NOTHING;

DO $$
DECLARE
  v_client_id UUID;
  v_product_id UUID;
  v_unit_price NUMERIC(12,2);
  v_sale_id UUID;
BEGIN
  SELECT id INTO v_client_id
  FROM clients
  WHERE cedula = '0102030405'
  LIMIT 1;

  SELECT id, price::NUMERIC(12,2)
  INTO v_product_id, v_unit_price
  FROM products
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_client_id IS NOT NULL AND v_product_id IS NOT NULL THEN
    INSERT INTO sales (client_id, sale_date, total)
    VALUES (v_client_id, NOW(), v_unit_price)
    RETURNING id INTO v_sale_id;

    INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal)
    VALUES (v_sale_id, v_product_id, 1, v_unit_price, v_unit_price);
  END IF;
END $$;
