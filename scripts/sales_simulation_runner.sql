-- ==========================================
-- RUNNER PARA PSQ L / PSQL
-- Ejecuta en orden la simulación de ventas
-- ==========================================
-- Uso:
-- psql -U tu_usuario -d tu_base -f scripts/sales_simulation_runner.sql

\i scripts/products_with_stock_view.sql
\i scripts/sales_stock_trigger.sql
\i scripts/seed_sales_data.sql
\i scripts/sales_reports.sql

-- ==========================================
-- VALIDACIONES RÁPIDAS
-- ==========================================
SELECT COUNT(*) AS total_clientes FROM clients;
SELECT COUNT(*) AS total_ventas FROM sales;
SELECT COUNT(*) AS total_detalles FROM sale_details;

SELECT id, name, stock, min_stock
FROM products_with_stock
ORDER BY stock ASC, name ASC;
