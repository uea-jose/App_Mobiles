-- =========================
-- SEED DATA: Clientes, Ventas y Detalles de Ventas
-- Ejecutar en el backend después de crear las tablas
-- =========================

-- =========================
-- CLIENTES
-- =========================
INSERT INTO clients (full_name, cedula, email, address, phone)
VALUES
('Juan Pérez', '1102456701', 'juan.perez@gmail.com', 'Quito', '0991111101'),
('María López', '1102456702', 'maria.lopez@gmail.com', 'Quito', '0991111102'),
('Carlos Mendoza', '1102456703', 'carlos.mendoza@gmail.com', 'Quito', '0991111103'),
('Andrea Torres', '1102456704', 'andrea.torres@gmail.com', 'Quito', '0991111104'),
('Luis Herrera', '1102456705', 'luis.herrera@gmail.com', 'Quito', '0991111105'),
('Sofía Castro', '1102456706', 'sofia.castro@gmail.com', 'Quito', '0991111106'),
('Pedro Ramírez', '1102456707', 'pedro.ramirez@gmail.com', 'Guayaquil', '0991111107'),
('Valeria Mena', '1102456708', 'valeria.mena@gmail.com', 'Guayaquil', '0991111108'),
('José Cedeño', '1102456709', 'jose.cedeno@gmail.com', 'Guayaquil', '0991111109'),
('Camila Vera', '1102456710', 'camila.vera@gmail.com', 'Guayaquil', '0991111110'),
('Daniel Reinoso', '1102456711', 'daniel.reinoso@gmail.com', 'Cuenca', '0991111111'),
('Paola Jaramillo', '1102456712', 'paola.jaramillo@gmail.com', 'Cuenca', '0991111112'),
('Miguel Ochoa', '1102456713', 'miguel.ochoa@gmail.com', 'Cuenca', '0991111113'),
('Fernanda Bravo', '1102456714', 'fernanda.bravo@gmail.com', 'Manta', '0991111114'),
('Kevin Zambrano', '1102456715', 'kevin.zambrano@gmail.com', 'Ambato', '0991111115'),
('Natalia Espinoza', '1102456716', 'natalia.espinoza@gmail.com', 'Loja', '0991111116')
ON CONFLICT (cedula) DO NOTHING;

-- =========================
-- VENTAS
-- Distribución: Más ventas en Quito (1-6), Guayaquil (7-10), Cuenca (11-13), otros (14-16)
-- =========================
INSERT INTO sales (client_id, sale_date, total) VALUES
(1,  NOW() - INTERVAL '12 days', 42.00),
(2,  NOW() - INTERVAL '11 days', 44.50),
(3,  NOW() - INTERVAL '10 days', 20.00),
(4,  NOW() - INTERVAL '9 days',  47.00),
(5,  NOW() - INTERVAL '8 days',  22.00),
(6,  NOW() - INTERVAL '7 days',  51.00),
(7,  NOW() - INTERVAL '6 days',  22.50),
(8,  NOW() - INTERVAL '5 days',  46.00),
(9,  NOW() - INTERVAL '4 days',  23.50),
(10, NOW() - INTERVAL '3 days',  51.25),
(11, NOW() - INTERVAL '6 days',  23.89),
(12, NOW() - INTERVAL '4 days',  34.50),
(13, NOW() - INTERVAL '2 days',  22.00),
(14, NOW() - INTERVAL '3 days',  28.75),
(15, NOW() - INTERVAL '2 days',  12.00),
(16, NOW() - INTERVAL '1 days',  23.95);

-- =========================
-- DETALLE DE VENTAS
-- NOTA: Reemplazar los UUIDs con los IDs reales de tus products
-- =========================

-- Venta 1: 2 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(1, '1c703bdb-f54f-4cf9-95d5-f053e3fa8cf5', 1, 20.00, 20.00),
(1, '4318d681-dfa6-417c-b45a-3b19cb599d0b', 1, 22.00, 22.00);

-- Venta 2: 2 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(2, '3487917b-1d12-4739-9ecd-80f853f27663', 1, 22.50, 22.50),
(2, '76b15292-93ad-4d9f-a1a9-30698e06ccb7', 1, 22.00, 22.00);

-- Venta 3: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(3, '1c703bdb-f54f-4cf9-95d5-f053e3fa8cf5', 1, 20.00, 20.00);

-- Venta 4: 3 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(4, '2b4f75aa-10cb-4337-85d4-64ed3b86d236', 1, 23.50, 23.50),
(4, '1187a5ea-7dce-4355-848b-6477238e3bea', 1, 12.00, 12.00),
(4, '4c9a1ae1-1182-4537-96e9-2abf5806a350', 1, 11.50, 11.50);

-- Venta 5: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(5, '35f80313-5ed0-4968-8060-c46b8dee571c', 1, 22.00, 22.00);

-- Venta 6: 3 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(6, '10f07d71-70c3-426c-a9cb-db1fa61e681a', 1, 23.89, 23.89),
(6, '30a6b1b8-262e-44a9-b7b1-34ece6a16b07', 1, 22.50, 22.50),
(6, '1187a5ea-7dce-4355-848b-6477238e3bea', 1, 4.61, 4.61);

-- Venta 7: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(7, '30a6b1b8-262e-44a9-b7b1-34ece6a16b07', 1, 22.50, 22.50);

-- Venta 8: 3 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(8, '4318d681-dfa6-417c-b45a-3b19cb599d0b', 1, 22.00, 22.00),
(8, '35f80313-5ed0-4968-8060-c46b8dee571c', 1, 22.00, 22.00),
(8, '1187a5ea-7dce-4355-848b-6477238e3bea', 1, 2.00, 2.00);

-- Venta 9: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(9, '2b4f75aa-10cb-4337-85d4-64ed3b86d236', 1, 23.50, 23.50);

-- Venta 10: 2 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(10, '4c9a1ae1-1182-4537-96e9-2abf5806a350', 1, 28.75, 28.75),
(10, '10f07d71-70c3-426c-a9cb-db1fa61e681a', 1, 22.50, 22.50);

-- Venta 11: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(11, '10f07d71-70c3-426c-a9cb-db1fa61e681a', 1, 23.89, 23.89);

-- Venta 12: 2 productos
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(12, '30a6b1b8-262e-44a9-b7b1-34ece6a16b07', 1, 22.50, 22.50),
(12, '1187a5ea-7dce-4355-848b-6477238e3bea', 1, 12.00, 12.00);

-- Venta 13: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(13, '35f80313-5ed0-4968-8060-c46b8dee571c', 1, 22.00, 22.00);

-- Venta 14: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(14, '4c9a1ae1-1182-4537-96e9-2abf5806a350', 1, 28.75, 28.75);

-- Venta 15: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(15, '1187a5ea-7dce-4355-848b-6477238e3bea', 1, 12.00, 12.00);

-- Venta 16: 1 producto
INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal) VALUES
(16, '3da1c42a-467b-4c46-8c48-412c0f34ed98', 1, 23.95, 23.95);

-- =========================
-- VERIFICACIÓN
-- Ejecutar estas queries para validar que los datos se insertaron correctamente
-- =========================
-- SELECT COUNT(*) as total_clientes FROM clients;
-- SELECT COUNT(*) as total_ventas FROM sales;
-- SELECT COUNT(*) as total_detalles FROM sale_details;
-- SELECT s.id, c.full_name, s.sale_date, s.total FROM sales s JOIN clients c ON s.client_id = c.id ORDER BY s.sale_date DESC;
