USE pizzas_trabajo;

/* Ejercicios de **Procedimientos Almacenados** */
SELECT * FROM presentacion;
DELIMITER //

DROP PROCEDURE IF EXISTS ps_add_pizza_con_ingredientes;
CREATE PROCEDURE ps_add_pizza_con_ingredientes(IN p_presentacion_producto INT, IN p_tipo_producto VARCHAR, IN p_nombre_pizza VARCHAR, IN p_precio DECIMAL(10,2), IN p_ids_ingredientes INT)
BEGIN

    DECLARE _tipo_producto_id INT;
    DECLARE _producto_id INT;

    INSERT INTO tipo_producto(
        nombre
    ) VALUES (p_tipo_producto);
    SET _tipo_producto_id = LAST_INSERT_ID();
    
    INSERT INTO producto(
        nombre,
        tipo_producto_id
    ) VALUES (
        p_nombre_pizza, _tipo_producto_id
    )

    SET _producto_id = LAST_INSERT_ID();

    INSERT INTO producto_presentacion(
        producto_id,
        presentacion_id
        precio
    ) VALUES(
        _producto_id, 
        p_presentacion_producto,
        p_precio
    )


END;

DELIMITER //


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
