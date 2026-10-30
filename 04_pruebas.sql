SET SERVEROUTPUT ON;

-- 1. Prueba fn_valor_estadia
DECLARE
    v_valor NUMBER;
BEGIN
    v_valor := pkg_turismo.fn_valor_estadia(1, DATE '2024-03-20', DATE '2024-03-27');
    DBMS_OUTPUT.PUT_LINE('Valor estadía cruzando temporadas: $' || v_valor);
END;
/

-- 2. Prueba de Auditoría (Trigger 1)
UPDATE tarifa SET valor_noche = valor_noche + 5000 WHERE id_habitacion = 1 AND id_temporada = 1;
COMMIT;
SELECT * FROM auditoria_tarifa;

-- 3. Prueba Procedimiento y Trigger 2 (Excepciones personalizadas)
BEGIN
    pkg_turismo.sp_crear_reserva(1, 1, DATE '2026-10-01', DATE '2026-10-05', 99);
END;
/

-- 4. Prueba de Liquidación Mensual (Cursor explícito)
BEGIN
    pkg_turismo.sp_liquidacion_mensual(2025, 4);
END;
/