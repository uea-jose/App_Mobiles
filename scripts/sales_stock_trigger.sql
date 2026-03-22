-- ==========================================
-- Trigger PostgreSQL: descontar stock automático
-- al insertar detalles de venta
-- ==========================================

-- Requiere tabla inventory(product_id, stock, min_stock, updated_at)
-- Requiere tabla sale_details(sale_id, product_id, quantity, unit_price, subtotal)

-- Limpieza previa
DROP TRIGGER IF EXISTS trg_sale_details_discount_stock ON sale_details;
DROP FUNCTION IF EXISTS fn_sale_details_discount_stock();

-- ==========================================
-- Función: descuenta stock al insertar detalle
-- ==========================================
CREATE OR REPLACE FUNCTION fn_sale_details_discount_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  current_stock INTEGER;
BEGIN
  IF NEW.quantity IS NULL OR NEW.quantity <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a cero';
  END IF;

  SELECT stock
  INTO current_stock
  FROM inventory
  WHERE product_id = NEW.product_id
  FOR UPDATE;

  IF current_stock IS NULL THEN
    RAISE EXCEPTION 'No existe inventario para el producto %', NEW.product_id;
  END IF;

  IF current_stock < NEW.quantity THEN
    RAISE EXCEPTION
      'Stock insuficiente para el producto %. Disponible: %, solicitado: %',
      NEW.product_id,
      current_stock,
      NEW.quantity;
  END IF;

  UPDATE inventory
  SET stock = stock - NEW.quantity,
      updated_at = NOW()
  WHERE product_id = NEW.product_id;

  RETURN NEW;
END;
$$;

-- ==========================================
-- Trigger AFTER INSERT
-- ==========================================
CREATE TRIGGER trg_sale_details_discount_stock
BEFORE INSERT ON sale_details
FOR EACH ROW
EXECUTE FUNCTION fn_sale_details_discount_stock();

-- ==========================================
-- OPCIONAL: restaurar stock si eliminas detalle
-- ==========================================
DROP TRIGGER IF EXISTS trg_sale_details_restore_stock ON sale_details;
DROP FUNCTION IF EXISTS fn_sale_details_restore_stock();

CREATE OR REPLACE FUNCTION fn_sale_details_restore_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE inventory
  SET stock = stock + OLD.quantity,
      updated_at = NOW()
  WHERE product_id = OLD.product_id;

  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_sale_details_restore_stock
BEFORE DELETE ON sale_details
FOR EACH ROW
EXECUTE FUNCTION fn_sale_details_restore_stock();

-- ==========================================
-- OPCIONAL: ajustar stock si cambias cantidad/producto
-- ==========================================
DROP TRIGGER IF EXISTS trg_sale_details_update_stock ON sale_details;
DROP FUNCTION IF EXISTS fn_sale_details_update_stock();

CREATE OR REPLACE FUNCTION fn_sale_details_update_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_stock INTEGER;
BEGIN
  -- devolver stock anterior
  UPDATE inventory
  SET stock = stock + OLD.quantity,
      updated_at = NOW()
  WHERE product_id = OLD.product_id;

  -- bloquear nuevo inventario
  SELECT stock
  INTO target_stock
  FROM inventory
  WHERE product_id = NEW.product_id
  FOR UPDATE;

  IF target_stock IS NULL THEN
    RAISE EXCEPTION 'No existe inventario para el producto %', NEW.product_id;
  END IF;

  IF target_stock < NEW.quantity THEN
    RAISE EXCEPTION
      'Stock insuficiente para actualizar el producto %. Disponible: %, solicitado: %',
      NEW.product_id,
      target_stock,
      NEW.quantity;
  END IF;

  UPDATE inventory
  SET stock = stock - NEW.quantity,
      updated_at = NOW()
  WHERE product_id = NEW.product_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sale_details_update_stock
BEFORE UPDATE ON sale_details
FOR EACH ROW
EXECUTE FUNCTION fn_sale_details_update_stock();

-- ==========================================
-- PRUEBAS ÚTILES
-- ==========================================
-- SELECT * FROM products_with_stock ORDER BY stock ASC;
--
-- BEGIN;
-- INSERT INTO sale_details (sale_id, product_id, quantity, unit_price, subtotal)
-- VALUES (1, '30a6b1b8-262e-44a9-b7b1-34ece6a16b07', 1, 22.50, 22.50);
-- COMMIT;
--
-- Si no hay stock suficiente, el INSERT fallará automáticamente.
