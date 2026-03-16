
-- Programar con pg_cron o ejecutar nocturnamente
-------------------------------- Crear Función de Mantenimiento
CREATE OR REPLACE FUNCTION run_maintenance()
RETURNS void AS $$
BEGIN
    -- Refresh materialized view
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_summary;
    
    -- Analyze tables
    ANALYZE products;
    ANALYZE inventory;
    ANALYZE sales;
    ANALYZE customers;
    
    -- Vacuum tablas críticas
    VACUUM ANALYZE inventory;
    VACUUM ANALYZE sales;
    
    RAISE NOTICE 'Mantenimiento completado en %', NOW();
END;
$$ LANGUAGE plpgsql;
-- 1. Row-Level Security (RLS) para Multi-Tenancy
-- Habilitar RLS en tablas sensibles
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Política de ejemplo
CREATE POLICY products_isolation ON products
    USING (
        -- Solo ver productos de su empresa
        organization_id = current_setting('app.current_org_id')::UUID
    );
--2. Función para Sanitizar Entradas
CREATE OR REPLACE FUNCTION sanitize_input(input TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Remover caracteres peligrosos
    RETURN regexp_replace(input, '[<>''"]', '', 'g');
END;
$$ LANGUAGE plpgsql IMMUTABLE;
--📈 MONITOREO Y OBSERVABILIDAD
--- 1. Vista de Queries Lentas
CREATE OR REPLACE VIEW v_slow_queries AS
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 100 -- más de 100ms
ORDER BY total_exec_time DESC
LIMIT 20;
--2. Vista de Uso de Índices
CREATE OR REPLACE VIEW v_unused_indexes AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelid::regclass::text NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;
--3
