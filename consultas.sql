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
