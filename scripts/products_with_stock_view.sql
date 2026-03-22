-- ==========================================
-- Mostrar products con stock sin duplicar datos
-- PostgreSQL
-- ==========================================

-- 1) Vista: products + inventory
CREATE OR REPLACE VIEW products_with_stock AS
SELECT
  p.id,
  p.sku,
  p.name,
  p.brand_id,
  p.gender,
  p.description,
  p.price,
  p.image_url,
  p.is_active,
  p.created_at,
  COALESCE(i.stock, 0) AS stock,
  COALESCE(i.min_stock, 0) AS min_stock,
  i.updated_at AS inventory_updated_at
FROM products p
LEFT JOIN inventory i
  ON i.product_id = p.id;

-- 2) Consulta recomendada para listar productos con stock
-- SELECT * FROM products_with_stock ORDER BY created_at DESC;

-- 3) Consulta recomendada para un producto puntual
-- SELECT * FROM products_with_stock WHERE id = 'UUID_DEL_PRODUCTO';

-- 4) Actualización de stock al vender (ejemplo directo)
-- OJO: esto debe hacerse dentro de una transacción al crear la venta.
-- Ejemplo: vender 2 unidades de un producto
-- UPDATE inventory
-- SET stock = stock - 2,
--     updated_at = NOW()
-- WHERE product_id = 'UUID_DEL_PRODUCTO'
--   AND stock >= 2;

-- 5) Verificación de stock bajo
-- SELECT id, name, stock, min_stock
-- FROM products_with_stock
-- WHERE stock <= min_stock
-- ORDER BY stock ASC;

-- ==========================================
-- EJEMPLO COMPLETO DE VENTA SEGURA
-- ==========================================
-- BEGIN;
--
-- INSERT INTO sales (client_id, sale_date, total)
-- VALUES (1, NOW(), 45.00)
-- RETURNING id;
--
-- INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal)
-- VALUES
--   (NUEVO_ID_VENTA, 'UUID_1', 1, 22.50, 22.50),
--   (NUEVO_ID_VENTA, 'UUID_2', 1, 22.50, 22.50);
--
-- UPDATE inventory
-- SET stock = stock - 1,
--     updated_at = NOW()
-- WHERE product_id = 'UUID_1'
--   AND stock >= 1;
--
-- UPDATE inventory
-- SET stock = stock - 1,
--     updated_at = NOW()
-- WHERE product_id = 'UUID_2'
--   AND stock >= 1;
--
-- COMMIT;

-- ==========================================
-- SI QUIERES QUE LA API /api/products YA DEVUELVA STOCK,
-- EN EL BACKEND DEBES CONSULTAR ESTA VIEW EN VEZ DE products.
-- ==========================================
