-- Tablespace Propio
-- Justificación: Separar el histórico de reservas en un tablespace distinto mejora el rendimiento 
-- de lectura/escritura (I/O) al aislar datos transaccionales pesados del resto del catálogo.
-- Además, facilita políticas de respaldo independientes y compresión de datos antiguos.
CREATE TABLESPACE ts_historico_reservas
    DATAFILE 'historico_reservas_01.dbf' SIZE 50M
    AUTOEXTEND ON NEXT 10M MAXSIZE 500M
    LOGGING;

-- Vista Materializada de ocupación mensual
-- Justificación de política de refresco: Se usa "COMPLETE ON DEMAND" porque la ocupación mensual
-- es un reporte gerencial consolidado que no requiere cálculo en tiempo real. Puede ser refrescado 
-- mediante un Job programado en horas de baja carga (ej. medianoche), ahorrando recursos durante el día.
CREATE MATERIALIZED VIEW mv_ocupacion_mensual
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
AS
SELECT 
    EXTRACT(YEAR FROM r.fecha_checkin) AS anio,
    EXTRACT(MONTH FROM r.fecha_checkin) AS mes,
    a.nombre AS alojamiento,
    COUNT(rh.id_habitacion) AS noches_ocupadas
FROM reserva r
JOIN reserva_habitacion rh ON r.id_reserva = rh.id_reserva
JOIN habitacion h ON rh.id_habitacion = h.id_habitacion
JOIN alojamiento a ON h.id_alojamiento = a.id_alojamiento
WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
GROUP BY EXTRACT(YEAR FROM r.fecha_checkin), EXTRACT(MONTH FROM r.fecha_checkin), a.nombre;