-- TASK 5: PIPELINE AUDIT & DATA QUALITY REPORT

-- gold_pipeline_health
-- Business purpose: single-query health check across the whole pipeline —
-- per-table row counts at each layer, rejection rate, and a per-table
-- HEALTHY/DEGRADED verdict driven by the 5% rejection-rate threshold.

USE cityreads;

CREATE OR REPLACE VIEW gold_pipeline_health AS
WITH bronze_counts AS (
    SELECT 'bronze_books'     AS table_name, COUNT(*) AS rows_in_bronze FROM bronze_books
    UNION ALL SELECT 'bronze_customers', COUNT(*) FROM bronze_customers
    UNION ALL SELECT 'bronze_orders',    COUNT(*) FROM bronze_orders
    UNION ALL SELECT 'bronze_loans',     COUNT(*) FROM bronze_loans
    UNION ALL SELECT 'bronze_reviews',   COUNT(*) FROM bronze_reviews
),
silver_counts AS (
    SELECT 'bronze_books'     AS table_name, COUNT(*) AS rows_in_silver FROM silver_books
    UNION ALL SELECT 'bronze_customers', COUNT(*) FROM silver_customers
    UNION ALL SELECT 'bronze_orders',    COUNT(*) FROM silver_orders
    UNION ALL SELECT 'bronze_loans',     COUNT(*) FROM silver_loans
    UNION ALL SELECT 'bronze_reviews',   COUNT(*) FROM silver_reviews
),
rejected_counts AS (
    SELECT table_name, COUNT(*) AS rows_rejected
    FROM silver_rejected_rows
    GROUP BY table_name
)
SELECT
    pm.table_name,
    pm.last_loaded_at,
    COALESCE(bc.rows_in_bronze, 0) AS rows_in_bronze,
    COALESCE(sc.rows_in_silver, 0) AS rows_in_silver,
    COALESCE(rc.rows_rejected, 0)  AS rows_rejected,
    ROUND(COALESCE(rc.rows_rejected, 0) / NULLIF(bc.rows_in_bronze, 0) * 100, 2) AS rejection_rate_pct,
    CASE
        WHEN COALESCE(rc.rows_rejected, 0) / NULLIF(bc.rows_in_bronze, 0) * 100 > 5 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END AS pipeline_status
FROM pipeline_metadata pm
LEFT JOIN bronze_counts   bc ON bc.table_name = pm.table_name
LEFT JOIN silver_counts   sc ON sc.table_name = pm.table_name
LEFT JOIN rejected_counts rc ON rc.table_name = pm.table_name
ORDER BY pm.table_name;


-- Overall pipeline verdict 

SELECT
    ROUND(SUM(rows_rejected) / SUM(rows_in_bronze) * 100, 2) AS overall_rejection_rate_pct,
    MAX(rejection_rate_pct)                                   AS worst_table_rejection_rate_pct,
    CASE
        WHEN MAX(rejection_rate_pct) > 5 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END AS overall_pipeline_verdict,
    NOW() AS evaluated_at
FROM gold_pipeline_health;

SELECT * FROM gold_pipeline_health ORDER BY table_name;
