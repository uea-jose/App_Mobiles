-- ==========================================
-- USAR SOLO SI YA INSERTASTE sale_details
-- ANTES de crear el trigger
-- ==========================================
-- Este script descuenta del inventory lo ya vendido en sale_details.
-- EJECÚTALO UNA SOLA VEZ.

BEGIN;

WITH sold AS (
  SELECT
    product_id,
    COALESCE(SUM(quantity), 0) AS total_sold
  FROM sale_details
  GROUP BY product_id
)
UPDATE inventory i
SET stock = GREATEST(i.stock - sold.total_sold, 0),
    updated_at = NOW()
FROM sold
WHERE i.product_id = sold.product_id;

COMMIT;

-- Verificación
SELECT
  p.id,
  p.name,
  COALESCE(i.stock, 0) AS stock_actual,
  COALESCE(i.min_stock, 0) AS stock_minimo
FROM products p
LEFT JOIN inventory i ON i.product_id = p.id
ORDER BY stock_actual ASC, p.name ASC;
