CREATE OR REPLACE PACKAGE pkg_turismo AS
    -- 1. Función para calcular el valor de la estadía cruzando temporadas
    FUNCTION fn_valor_estadia(p_id_habitacion IN NUMBER, p_fecha_in IN DATE, p_fecha_out IN DATE) RETURN NUMBER;
    
    -- 2. Procedimiento para crear reservas con validaciones
    PROCEDURE sp_crear_reserva(
        p_id_cliente IN NUMBER,
        p_id_habitacion IN NUMBER,
        p_fecha_in IN DATE,
        p_fecha_out IN DATE,
        p_huespedes IN NUMBER
    );
    
    -- 3. Procedimiento masivo usando un cursor explícito parametrizado
    PROCEDURE sp_liquidacion_mensual(p_anio IN NUMBER, p_mes IN NUMBER);
END pkg_turismo;
/

CREATE OR REPLACE PACKAGE BODY pkg_turismo AS

    FUNCTION fn_valor_estadia(p_id_habitacion IN NUMBER, p_fecha_in IN DATE, p_fecha_out IN DATE) RETURN NUMBER IS
        v_total NUMBER(14,2) := 0;
    BEGIN
        SELECT SUM( (LEAST(p_fecha_out, t.fecha_fin + 1) - GREATEST(p_fecha_in, t.fecha_inicio)) * tf.valor_noche )
        INTO v_total
        FROM temporada t
        JOIN tarifa tf ON tf.id_temporada = t.id_temporada
        WHERE tf.id_habitacion = p_id_habitacion
          AND t.fecha_inicio < p_fecha_out
          AND t.fecha_fin >= p_fecha_in;
          
        RETURN NVL(v_total, 0);
    END fn_valor_estadia;

    PROCEDURE sp_crear_reserva(
        p_id_cliente IN NUMBER, p_id_habitacion IN NUMBER, 
        p_fecha_in IN DATE, p_fecha_out IN DATE, p_huespedes IN NUMBER
    ) IS
        v_capacidad NUMBER;
        v_solapes NUMBER;
        v_id_reserva NUMBER;
    BEGIN
        -- Excepción 1: Fechas inválidas
        IF p_fecha_out <= p_fecha_in THEN
            RAISE_APPLICATION_ERROR(-20001, 'La fecha de checkout debe ser posterior al checkin.');
        END IF;

        -- Excepción 2: Capacidad excedida
        SELECT capacidad INTO v_capacidad FROM habitacion WHERE id_habitacion = p_id_habitacion;
        IF p_huespedes > v_capacidad THEN
            RAISE_APPLICATION_ERROR(-20002, 'La cantidad de huéspedes excede la capacidad máxima de la habitación ('||v_capacidad||').');
        END IF;

        -- Excepción 3: Habitación no disponible
        SELECT COUNT(*) INTO v_solapes
        FROM reserva_habitacion rh
        JOIN reserva r ON r.id_reserva = rh.id_reserva
        WHERE rh.id_habitacion = p_id_habitacion
          AND r.estado IN ('CONFIRMADA', 'COMPLETADA')
          AND rh.fecha_checkin < p_fecha_out 
          AND rh.fecha_checkout > p_fecha_in;
          
        IF v_solapes > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'La habitación no está disponible para las fechas seleccionadas.');
        END IF;

        -- Insertar cabecera
        INSERT INTO reserva (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado, numero_huespedes)
        VALUES (p_id_cliente, SYSDATE, p_fecha_in, p_fecha_out, 'PENDIENTE', p_huespedes)
        RETURNING id_reserva INTO v_id_reserva;

        -- Insertar detalle
        INSERT INTO reserva_habitacion (id_reserva, id_habitacion, fecha_checkin, fecha_checkout, huespedes)
        VALUES (v_id_reserva, p_id_habitacion, p_fecha_in, p_fecha_out, p_huespedes);
        
        COMMIT;
    END sp_crear_reserva;

    PROCEDURE sp_liquidacion_mensual(p_anio IN NUMBER, p_mes IN NUMBER) IS
        -- Cursor explícito con parámetros
        CURSOR c_liquidacion(v_anio NUMBER, v_mes NUMBER) IS
            SELECT a.nombre AS alojamiento, SUM(p.monto) AS total_recaudado
            FROM alojamiento a
            JOIN reserva_habitacion rh ON rh.id_habitacion IN (SELECT id_habitacion FROM habitacion WHERE id_alojamiento = a.id_alojamiento)
            JOIN reserva r ON r.id_reserva = rh.id_reserva
            JOIN pago p ON p.id_reserva = r.id_reserva
            WHERE p.estado = 'EXITOSO'
              AND EXTRACT(YEAR FROM p.fecha_pago) = v_anio
              AND EXTRACT(MONTH FROM p.fecha_pago) = v_mes
            GROUP BY a.nombre;
            
        v_total_mes NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- LIQUIDACIÓN MENSUAL: ' || p_mes || '/' || p_anio || ' ---');
        FOR reg IN c_liquidacion(p_anio, p_mes) LOOP
            DBMS_OUTPUT.PUT_LINE('Alojamiento: ' || reg.alojamiento || ' - Recaudo: $' || reg.total_recaudado);
            v_total_mes := v_total_mes + reg.total_recaudado;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('TOTAL DEL MES: $' || v_total_mes);
    END sp_liquidacion_mensual;

END pkg_turismo;
/