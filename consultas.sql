USE pizzas_trabajo;

/* Ejercicios de **Procedimientos Almacenados** */

/* 1. **`ps_add_pizza_con_ingredientes`**
   Crea un procedimiento que inserte una nueva pizza en la tabla `pizza` junto con sus ingredientes en `pizza_ingrediente`.

   - Parámetros de entrada: `p_nombre_pizza`, `p_precio`, lista de `p_ids_ingredientes`.
   - Debe recorrer la lista de ingredientes (cursor o ciclo) y hacer los inserts correspondients.
*/

DELIMITER //

DROP PROCEDURE IF EXISTS ps_add_pizza_con_ingredientes;
CREATE PROCEDURE ps_add_pizza_con_ingredientes(IN p_presentacion_producto INT, IN p_tipo_producto VARCHAR(50), IN p_nombre_pizza VARCHAR(100), IN p_precio DECIMAL(10,2), IN p_ids_ingredientes INT)
BEGIN

    DECLARE _tipo_producto_id INT;
    DECLARE _producto_id INT;
    DECLARE _ingrediente_id INT;
    DECLARE fin INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT id FROM ingrediente WHERE id IN (p_ids_ingredientes);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin = 1;


    INSERT INTO tipo_producto(
        nombre
    ) VALUES (p_tipo_producto);
    SET _tipo_producto_id = LAST_INSERT_ID();
    
    INSERT INTO producto(
        nombre,
        tipo_producto_id
    ) VALUES (
        p_nombre_pizza, _tipo_producto_id
    );

    SET _producto_id = LAST_INSERT_ID();

    INSERT INTO producto_presentacion(
        producto_id,
        presentacion_id,
        precio
    ) VALUES(
        _producto_id, 
        p_presentacion_producto,
        p_precio
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO _ingrediente_id;

        IF fin THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO ingredientes_extra(detalle_id, ingrediente_id, cantidad)
        VALUES (1, _ingrediente_id, 1);

    END LOOP;
    CLOSE cur;
        
END //

DELIMITER //

CALL ps_add_pizza_con_ingredientes(1, 'Pizza', 'Pizza adrian esto no sirve', 15000.00, '2');
-- Debido al modelo de la base de datos no se puede insertar directamente un ingrediente a una pizza
-- Cada pizza esta enlazada a un pedido y un pedido a un cliente osea no podemos crear pizzas e ingredientes a la vez sin un cliente
-- lo cual en un modelo logico esta mal

/* 2. **`ps_actualizar_precio_pizza`**
   Procedimiento que reciba `p_pizza_id` y `p_nuevo_precio` y actualice el precio.

   - Antes de actualizar, valide con un `IF` que el nuevo precio sea mayor que 0; de lo contrario, lance un `SIGNAL`.
*/

DELIMITER //

DROP PROCEDURE IF EXISTS ps_actualizar_precio_pizza;
CREATE PROCEDURE ps_actualizar_precio_pizza(IN p_pizza_id INT, IN p_nuevo_precio DECIMAL(10,2))
BEGIN 
    DECLARE _nuevo_precio DECIMAL(10,2);
    DECLARE _pro_presentacion_id INT;
    DECLARE _columnas_afectadas INT;
    DECLARE fin INT DEFAULT FALSE;
    
    DECLARE cur_pro CURSOR FOR
        SELECT presentacion_id FROM producto_presentacion WHERE producto_id = p_pizza_id AND presentacion_id <> 1;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin = 1;

    UPDATE producto_presentacion
    SET precio = p_nuevo_precio
    WHERE producto_id = p_pizza_id AND presentacion_id = 1;

    IF ROW_COUNT() <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se encontro la presentacion de la pipsha';

    
    ELSE
        SET _nuevo_precio = p_nuevo_precio;
        OPEN cur_pro;

        leerloop: LOOP
            FETCH cur_pro INTO _pro_presentacion_id;
            
            IF fin THEN
                LEAVE leerloop;
            END IF;

            SET _nuevo_precio = _nuevo_precio + (_nuevo_precio * 0.30);

            UPDATE producto_presentacion
            SET precio = _nuevo_precio
            WHERE producto_id  = p_pizza_id AND presentacion_id = _pro_presentacion_id;

            IF ROW_COUNT() > 0 THEN
                SET _columnas_afectadas = _columnas_afectadas + 1;
            END IF;

        END LOOP leerloop;
        CLOSE cur_pro;

        IF _columnas_afectadas <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se actualizo el precio de las otras presentaciones del producto';
        END IF;

    END IF;

END //

DELIMITER //

CALL ps_actualizar_precio_pizza(1, 7000.00)


/* **`ps_cancelar_pedido`**
   Recibe `p_pedido_id` y:

   - Marca el pedido como “cancelado” (p. ej. actualiza un campo `estado`),
   - Elimina todas sus líneas de detalle (`DELETE FROM detalle_pedido WHERE pedido_id = …`).
   - Devuelve el número de líneas eliminadas.
   */

ALTER TABLE pedido ADD COLUMN estado_pedido VARCHAR(20) DEFAULT 'activo';

ALTER TABLE detalle_pedido_producto
DROP FOREIGN KEY detalle_pedido_producto_ibfk_1;

ALTER TABLE detalle_pedido_producto
ADD CONSTRAINT fk_dp_producto_detalle
FOREIGN KEY (detalle_id) REFERENCES detalle_pedido(id)
ON DELETE CASCADE;

ALTER TABLE detalle_pedido_combo
DROP FOREIGN KEY detalle_pedido_combo_ibfk_1;

ALTER TABLE detalle_pedido_combo
ADD CONSTRAINT fk_dp_combo_detalle
FOREIGN KEY (detalle_id) REFERENCES detalle_pedido(id)
ON DELETE CASCADE;

ALTER TABLE ingredientes_extra
DROP FOREIGN KEY ingredientes_extra_ibfk_1;

ALTER TABLE ingredientes_extra
ADD CONSTRAINT fk_dp_ingrediente_detalle
FOREIGN KEY (detalle_id) REFERENCES detalle_pedido(id)
ON DELETE CASCADE;


DELIMITER //

DROP PROCEDURE IF EXISTS ps_cancelar_pedido;

CREATE PROCEDURE ps_cancelar_pedido(IN p_pedido_id INT)
BEGIN
    DECLARE _lineas_eliminadas INT DEFAULT 0;

    UPDATE pedido
    SET estado = 'cancelado'
    WHERE id = p_pedido_id;

    DELETE FROM detalle_pedido
    WHERE pedido_id = p_pedido_id;

    SET _lineas_eliminadas = ROW_COUNT();

    SELECT _lineas_eliminadas AS lineas_eliminadas;
END //

DELIMITER ;

CALL ps_cancelar_pedido(1);



/* Funciones */

/* 
1. *fc_calcular_subtotal_pizza*
   - Parámetro: p_pizza_id
   - Retorna el precio base de la pizza más la suma de precios de sus ingredientes.
*/

DELIMITER //

DROP FUNCTION IF EXISTS fc_calcular_subtotal_pizza;
CREATE FUNCTION fc_calcular_subtotal_pizza(p_pizza_id INT)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN

    DECLARE _total DECIMAL(10,2);
    DECLARE _presentacion_precio DECIMAL(10,2);
    DECLARE _ingrediente_precio DECIMAL(10,2);


    SELECT pp.precio INTO _presentacion_precio
    FROM detalle_pedido dp
    INNER JOIN detalle_pedido_producto dppr ON dppr.detalle_id = dp.id
    INNER JOIN producto pro ON dppr.producto_id = pro.id 
    INNER JOIN producto_presentacion pp ON pp.producto_id = pro.id
    WHERE dp.id = p_pizza_id
    LIMIT 1;

    SELECT COALESCE(SUM(ing.precio * ie.cantidad), 0) INTO _ingrediente_precio
    FROM pedido pe
    INNER JOIN detalle_pedido dp ON dp.pedido_id = pe.id
    INNER JOIN ingredientes_extra ie ON ie.detalle_id = dp.id
    INNER JOIN ingrediente ing ON ing.id = ie.ingrediente_id
    WHERE dp.id = p_pizza_id;

    SET _total = _presentacion_precio + _ingrediente_precio;

    RETURN _total;
END //

DELIMITER ;

SELECT fc_calcular_subtotal_pizza(5) AS Total_pedido

/*
2. *fc_descuento_por_cantidad*
   - Parámetros: p_cantidad INT, p_precio_unitario DECIMAL
   - Si p_cantidad ≥ 5 aplica 10% de descuento, sino 0%. Retorna el monto de descuento.
*/

DELIMITER //

DROP FUNCTION IF EXISTS fc_descuento_por_cantidad;
CREATE FUNCTION fc_descuento_por_cantidad(p_cantidad INT, p_precio_unitario DECIMAL)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    DECLARE _descuento DECIMAL(10,2) DEFAULT 0.00;
    
    IF p_cantidad <= 0 THEN /* Yo a ud lo conozco */
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Por qué intenta romper el programa? ponga cantidades positivas';
    END IF;
    
    
    IF p_cantidad >= 5 THEN
        SET _descuento = p_precio_unitario * 0.1;
        RETURN _descuento;
    ELSE
        RETURN _descuento;
    END IF;

END //

DELIMITER ;

SELECT fc_descuento_por_cantidad(5, 10000.00) AS Descuento_aplicado

/*

3. *fc_precio_final_pedido*
   - Parámetros: p_pedido_id INT
   - Usa calcular_subtotal_pizza y descuento_por_cantidad para devolver el total a pagar.
*/

DELIMITER //

DROP FUNCTION IF EXISTS fc_precio_final_pedido;
CREATE FUNCTION fc_precio_final_pedido(p_pedido_id INT)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN

    DECLARE _subtotal DECIMAL(10,2);
    DECLARE _cantidad INT;
    DECLARE _total DECIMAL(10,2);

    SELECT total INTO _subtotal
    FROM pedido
    WHERE pedido.id = p_pedido_id;

    SELECT SUM(cantidad) INTO _cantidad
    FROM detalle_pedido dp
    INNER JOIN pedido pe ON pe.id = dp.pedido_id
    WHERE pe.id = p_pedido_id;

    IF _cantidad >= 4 THEN
        SET _total = _subtotal * 0.9;
        RETURN _total;
    ELSE
        RETURN _subtotal;
    END IF;

END //

DELIMITER ;


SELECT fc_precio_final_pedido(2) AS precio_final;

/*
4. *fc_obtener_stock_ingrediente*
   - Parámetro: p_ingrediente_id INT
   - Retorna el stock disponible del ingrediente.


*/
DELIMITER //

DROP FUNCTION IF EXISTS fc_obtener_stock_ingrediente;
CREATE FUNCTION fc_obtener_stock_ingrediente(p_ingrediente_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE _cantidad INT;

    SELECT stock INTO _cantidad
    FROM ingrediente ing
    WHERE ing.id = p_ingrediente_id;

    IF _cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Producto sin stock';
    END IF;

    RETURN _cantidad;

END //

DELIMITER ;

SELECT fc_obtener_stock_ingrediente(1) AS Stock_disponible;


/*
5. *fc_es_pizza_popular*
   - Parámetro: p_pizza_id INT
   - Retorna 1 si la pizza ha sido pedida más de 50 veces (contando en detalle_pedido_pizza), sino 0.

   */

DELIMITER //

DROP FUNCTION IF EXISTS fc_obtener_stock_ingrediente;
CREATE FUNCTION fc_obtener_stock_ingrediente(p_ingrediente_id INT)
RETURNS INT
DETERMINISTIC
BEGIN

    DECLARE _cantidad INT;
    DECLARE _boolean TINYINT;

    SELECT SUM(dp.cantidad) INTO _cantidad
    FROM ingrediente ing
    INNER JOIN ingredientes_extra ie ON ing.id = ie.ingrediente_id
    INNER JOIN detalle_pedido dp ON dp.id = ie.detalle_id
    WHERE ing.id = p_ingrediente_id;

    IF _cantidad > 50 THEN
        SET _boolean = 1;
    ELSE
        SET _boolean = 0;
    END IF;

    RETURN _boolean;

END //

DELIMITER //


SELECT fc_obtener_stock_ingrediente(1) AS Disponible;

##  Ejercicios de **Triggers** 

/*  **`tg_before_insert_detalle_pedido`**
   - `BEFORE INSERT` en `detalle_pedido`
   - Valida que la cantidad sea ≥ 1; si no, `SIGNAL` de error.
*/

DELIMITER //
DROP TRIGGER IF EXISTS tg_before_insert_detalle_pedido;
CREATE TRIGGER tg_before_insert_detalle_pedido BEFORE INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    IF NEW.cantidad < 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cantidad debe ser mayor a 1';
    END IF;
END //

/*  **`tg_after_insert_detalle_pedido_pizza`**
   - `AFTER INSERT` en `detalle_pedido_pizza`
   - Disminuye el `stock` correspondiente en `ingrediente` según la receta de la pizza.
*/

DELIMITER //

CREATE TRIGGER tg_after_insert_detalle_pedido_pizza
AFTER INSERT ON detalle_pedido_producto
FOR EACH ROW
BEGIN
  DECLARE fin INT DEFAULT 0;
  DECLARE _ingrediente_id INT;
  DECLARE _cantidad INT;

  DECLARE cur CURSOR FOR
    SELECT ingrediente_id, cantidad
    FROM ingredientes_extra
    WHERE detalle_id = NEW.detalle_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin = 1;

  OPEN cur;

  read_loop: LOOP
    FETCH cur INTO _ingrediente_id, _cantidad;
    IF fin THEN
      LEAVE read_loop;
    END IF;

    UPDATE ingrediente
    SET stock = stock - _cantidad
    WHERE id = _ingrediente_id;
  END LOOP;

  CLOSE cur;
END //

DELIMITER ;

/* 3. **`tg_after_update_pizza_precio`**
   - `AFTER UPDATE` en `pizza`
   - Inserta en una tabla `auditoria_precios` la pizza_id, precio antiguo y nuevo, y timestamp.
*/
DELIMITER //

DROP TRIGGER IF EXISTS tg_after_update_pizza_precio;
CREATE TRIGGER tg_after_update_pizza_precio
AFTER UPDATE ON producto_presentacion
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO auditoria_precios (
            producto_id,
            presentacion_id,
            precio_anterior,
            precio_nuevo
        )
        VALUES (
            NEW.producto_id,
            NEW.presentacion_id,
            OLD.precio,
            NEW.precio
        );
    END IF;
END;
//

DELIMITER ;

CALL ps_actualizar_precio_pizza(1, 7000.00);

SELECT * FROM auditoria_precios;
CREATE TABLE auditoria_precios (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    producto_id INT UNSIGNED NOT NULL,
    presentacion_id INT UNSIGNED NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (producto_id) REFERENCES producto(id),
    FOREIGN KEY (presentacion_id) REFERENCES presentacion(id)
);
DROP TABLE IF EXISTS auditoria_precios;

/* 4. **`tg_before_delete_pizza`**
   - `BEFORE DELETE` en `pizza`
   - Impide borrar si la pizza aparece en algún `detalle_pedido_pizza` (lanza `SIGNAL`).

*/

USE pizzas_trabajo;
DELIMITER //

DROP TRIGGER IF EXISTS tg_before_delete_pizza;

CREATE TRIGGER tg_before_delete_pizza
BEFORE DELETE ON producto
FOR EACH ROW
BEGIN

    DECLARE _detalle_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO _detalle_existe
    FROM detalle_pedido_producto
    WHERE producto_id = OLD.id;

    IF _detalle_existe > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar';
    END IF;

END //

DELIMITER ;


/* 5. **`tg_after_insert_factura`**
   - `AFTER INSERT` en `factura`
   - Actualiza el pedido asociado marcándolo como “facturado”.
*/

ALTER TABLE pedido ADD estado VARCHAR(20) DEFAULT 'pendiente';

-- Profesor por favor.. que es esa base de datos

DELIMITER //

DROP TRIGGER IF EXISTS tg_after_insert_factura;

CREATE TRIGGER tg_after_insert_factura
AFTER INSERT ON factura
FOR EACH ROW
BEGIN
    UPDATE pedido
    SET estado = 'facturado'
    WHERE id = NEW.pedido_id;
END //

DELIMITER ;

INSERT INTO factura(total, fecha, pedido_id, cliente_id) VALUES
(35000, '2025-06-10 12:05:00', 1, 1)

SELECT * FROM pedido;

/* **`tg_after_update_ingrediente_stock`**
   - `AFTER UPDATE` en `ingrediente`
   - Si el stock cae por debajo de 10 unidades, inserta una alerta en `notificacion_stock_bajo`.
*/

USE pizzas_trabajo;
DROP TABLE IF EXISTS notificacion_stock_bajo;

CREATE TABLE notificacion_stock_bajo (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ingrediente_id INT UNSIGNED NOT NULL,
    mensaje TEXT NOT NULL,
    FOREIGN KEY (ingrediente_id) REFERENCES ingrediente(id)
);
DELIMITER //

DROP TRIGGER IF EXISTS tg_after_update_ingrediente_stock;

CREATE TRIGGER tg_after_update_ingrediente_stock
AFTER UPDATE ON ingrediente
FOR EACH ROW
BEGIN
    IF NEW.stock < 10 THEN
        INSERT INTO notificacion_stock_bajo (
            ingrediente_id, 
            mensaje
        )
        VALUES (
            NEW.id,
            'Stock bajo para ese ingrediente'
        );
    END IF;
END //

DELIMITER ;