-- ==========================================
-- REPORTES DE SIMULACIÓN
-- Clientes / ventas / ciudades
-- PostgreSQL
-- ==========================================

-- 1) CIUDADES CON MÁS VENTAS POR CANTIDAD DE ÓRDENES
SELECT
  c.address AS ciudad,
  COUNT(s.id) AS total_ventas,
  ROUND(COALESCE(SUM(s.total), 0)::numeric, 2) AS monto_total,
  ROUND(COALESCE(AVG(s.total), 0)::numeric, 2) AS ticket_promedio
FROM clients c
LEFT JOIN sales s
  ON s.client_id = c.id
GROUP BY c.address
ORDER BY total_ventas DESC, monto_total DESC;

-- 2) TOP 10 CLIENTES QUE MÁS COMPRAN POR MONTO
SELECT
  c.id,
  c.full_name,
  c.cedula,
  c.address AS ciudad,
  COUNT(s.id) AS cantidad_compras,
  ROUND(COALESCE(SUM(s.total), 0)::numeric, 2) AS total_comprado,
  ROUND(COALESCE(AVG(s.total), 0)::numeric, 2) AS ticket_promedio
FROM clients c
LEFT JOIN sales s
  ON s.client_id = c.id
GROUP BY c.id, c.full_name, c.cedula, c.address
ORDER BY total_comprado DESC, cantidad_compras DESC
LIMIT 10;

-- 3) TOP 10 CLIENTES QUE MÁS COMPRAN POR CANTIDAD DE VENTAS
SELECT
  c.id,
  c.full_name,
  c.cedula,
  c.address AS ciudad,
  COUNT(s.id) AS cantidad_compras,
  ROUND(COALESCE(SUM(s.total), 0)::numeric, 2) AS total_comprado
FROM clients c
LEFT JOIN sales s
  ON s.client_id = c.id
GROUP BY c.id, c.full_name, c.cedula, c.address
ORDER BY cantidad_compras DESC, total_comprado DESC
LIMIT 10;

-- 4) RESUMEN GENERAL
SELECT
  (SELECT COUNT(*) FROM clients) AS total_clientes,
  (SELECT COUNT(*) FROM sales) AS total_ventas,
  (SELECT ROUND(COALESCE(SUM(total), 0)::numeric, 2) FROM sales) AS ingresos_totales,
  (SELECT ROUND(COALESCE(AVG(total), 0)::numeric, 2) FROM sales) AS ticket_promedio;

-- 5) VENTAS POR CIUDAD Y POR DÍA
SELECT
  c.address AS ciudad,
  DATE(s.sale_date) AS fecha,
  COUNT(s.id) AS ventas_dia,
  ROUND(COALESCE(SUM(s.total), 0)::numeric, 2) AS monto_dia
FROM sales s
INNER JOIN clients c
  ON c.id = s.client_id
GROUP BY c.address, DATE(s.sale_date)
ORDER BY fecha DESC, monto_dia DESC;

-- 6) TOP PRODUCTOS MÁS VENDIDOS
SELECT
  p.name AS producto,
  p.sku,
  COUNT(sd.sale_id) AS veces_vendido,
  COALESCE(SUM(sd.quantity), 0) AS unidades_vendidas,
  ROUND(COALESCE(SUM(sd.subtotal), 0)::numeric, 2) AS total_generado
FROM sale_details sd
INNER JOIN products p
  ON p.id = sd.product_id
GROUP BY p.id, p.name, p.sku
ORDER BY unidades_vendidas DESC, total_generado DESC
LIMIT 10;

-- 7) TOP MARCAS MÁS VENDIDAS
SELECT
  b.name AS marca,
  COUNT(sd.sale_id) AS ventas,
  COALESCE(SUM(sd.quantity), 0) AS unidades,
  ROUND(COALESCE(SUM(sd.subtotal), 0)::numeric, 2) AS total_generado
FROM sale_details sd
INNER JOIN products p
  ON p.id = sd.product_id
INNER JOIN brands b
  ON b.id = p.brand_id
GROUP BY b.id, b.name
ORDER BY total_generado DESC, unidades DESC
LIMIT 10;

-- 8) CLIENTES POR CIUDAD
SELECT
  address AS ciudad,
  COUNT(*) AS total_clientes
FROM clients
GROUP BY address
ORDER BY total_clientes DESC, ciudad ASC;

-- ==========================================
-- CONSULTAS RÁPIDAS
-- ==========================================
-- Ciudad con más ventas:
-- SELECT * FROM (
--   SELECT c.address AS ciudad, COUNT(s.id) AS total_ventas
--   FROM clients c
--   JOIN sales s ON s.client_id = c.id
--   GROUP BY c.address
--   ORDER BY total_ventas DESC
-- ) t LIMIT 1;
--
-- Cliente que más compró:
-- SELECT * FROM (
--   SELECT c.full_name, SUM(s.total) AS total_comprado
--   FROM clients c
--   JOIN sales s ON s.client_id = c.id
--   GROUP BY c.full_name
--   ORDER BY total_comprado DESC
-- ) t LIMIT 1;
