
-- 4A.1 — gold_kpi_revenue_growth
-- Business purpose: Month-over-month % change in DELIVERED order revenue.
-- Per-row: does THIS month individually clear the 5% bar (month_status).
-- Every row also repeats the overall KPI verdict (kpi_status): did a
-- streak of >=3 consecutive qualifying months ever occur in the data.

use cityreads;
CREATE OR REPLACE VIEW gold_kpi_revenue_growth AS
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS `year_month`,
        SUM(order_value)                 AS total_revenue
    FROM silver_orders
    WHERE status = 'DELIVERED'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
),
growth AS (
    SELECT
        `year_month`,
        total_revenue,
        LAG(total_revenue) OVER (ORDER BY `year_month`) AS prev_month_revenue
    FROM monthly_revenue
),
growth_calc AS (
    SELECT
        `year_month`,
        total_revenue,
        CASE WHEN prev_month_revenue IS NULL OR prev_month_revenue = 0 THEN NULL
             ELSE ROUND((total_revenue - prev_month_revenue) / prev_month_revenue * 100, 2)
        END AS mom_growth_pct
    FROM growth
),
flagged AS (
    SELECT
        *,
        CASE WHEN mom_growth_pct >= 5 THEN 1 ELSE 0 END AS meets_threshold
    FROM growth_calc
),

-- Gaps-and-islands: the gap between two row-number sequences is constant
-- within a run of consecutive equal values, and changes at every break.
-- That constant value groups each unbroken streak into its own "island".
islands AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY `year_month`)
          - ROW_NUMBER() OVER (PARTITION BY meets_threshold ORDER BY `year_month`) AS island_id
    FROM flagged
),
streak_lengths AS (
    SELECT island_id, COUNT(*) AS streak_len
    FROM islands
    WHERE meets_threshold = 1
    GROUP BY island_id
),
overall AS (
    SELECT MAX(streak_len) AS longest_streak FROM streak_lengths
)
SELECT
    i.year_month,
    i.total_revenue,
    i.mom_growth_pct AS kpi_value,
    5.00  AS kpi_target,
    CASE
        WHEN i.mom_growth_pct IS NULL THEN 'N/A'
        WHEN i.mom_growth_pct >= 5 THEN 'PASS'
        ELSE 'FAIL'
    END   AS month_status,
    o.longest_streak   AS longest_qualifying_streak,
    CASE WHEN o.longest_streak >= 3 THEN 'PASS' ELSE 'FAIL' END  AS kpi_status,
    NOW()  AS calculated_at
FROM islands i
CROSS JOIN overall o
ORDER BY i.year_month;

-- 4A.2 — gold_kpi_retention_rate
-- Business purpose: % of customers with DELIVERED orders in 2 consecutive
-- calendar months, out of all validated customers.
CREATE OR REPLACE VIEW gold_kpi_retention_rate AS
WITH delivered_months AS (
    SELECT DISTINCT
        customer_id,
        DATE_FORMAT(order_date, '%Y-%m-01') AS month_start
    FROM silver_orders
    WHERE status = 'DELIVERED'
),
consecutive_check AS (
    SELECT
        customer_id,
        month_start,
        LEAD(month_start) OVER (PARTITION BY customer_id ORDER BY month_start) AS next_month
    FROM delivered_months
),
retained AS (
    SELECT DISTINCT customer_id
    FROM consecutive_check
    WHERE next_month = DATE_ADD(month_start, INTERVAL 1 MONTH)
)
SELECT
    ROUND((SELECT COUNT(*) FROM retained) / (SELECT COUNT(*) FROM silver_customers) * 100, 2) AS kpi_value,
    60.00 AS kpi_target,
    CASE
        WHEN ROUND((SELECT COUNT(*) FROM retained) / (SELECT COUNT(*) FROM silver_customers) * 100, 2) >= 60
        THEN 'PASS' ELSE 'FAIL'
    END AS status,
    NOW() AS calculated_at;



-- 4A.3 — gold_kpi_sell_through
-- Business purpose: % of the book catalogue with at least one DELIVERED order.

CREATE OR REPLACE VIEW gold_kpi_sell_through AS
WITH sold_books AS (
    SELECT COUNT(DISTINCT book_id) AS n FROM silver_orders WHERE status = 'DELIVERED'
),
catalogue AS (
    SELECT COUNT(*) AS n FROM silver_books
)
SELECT
    ROUND(sold_books.n / catalogue.n * 100, 2) AS kpi_value,
    70.00 AS kpi_target,
    CASE WHEN ROUND(sold_books.n / catalogue.n * 100, 2) >= 70 THEN 'PASS' ELSE 'FAIL' END AS status,
    NOW() AS calculated_at
FROM sold_books, catalogue;



-- 4A.4 — gold_kpi_return_compliance
-- Business purpose: % of loans returned on or before due_date, out of
-- ALL validated loans (an unreturned loan counts against compliance).

CREATE OR REPLACE VIEW gold_kpi_return_compliance AS
WITH compliance AS (
    SELECT
        COUNT(*) AS total_loans,
        SUM(CASE WHEN return_date IS NOT NULL AND return_date <= due_date THEN 1 ELSE 0 END) AS on_time_loans
    FROM silver_loans
)
SELECT
    ROUND(on_time_loans / total_loans * 100, 2) AS kpi_value,
    75.00 AS kpi_target,
    CASE WHEN ROUND(on_time_loans / total_loans * 100, 2) >= 75 THEN 'PASS' ELSE 'FAIL' END AS status,
    NOW() AS calculated_at
FROM compliance;



-- 4A.5 — gold_kpi_review_coverage
-- Business purpose: % of DELIVERED orders that have a matching review
-- from the same customer for the same book.

CREATE OR REPLACE VIEW gold_kpi_review_coverage AS
WITH delivered AS (
    SELECT order_id, customer_id, book_id
    FROM silver_orders
    WHERE status = 'DELIVERED'
),
covered AS (
    SELECT d.order_id
    FROM delivered d
    WHERE EXISTS (
        SELECT 1 FROM silver_reviews sr
        WHERE sr.customer_id = d.customer_id AND sr.book_id = d.book_id
    )
)
SELECT
    ROUND((SELECT COUNT(*) FROM covered) / (SELECT COUNT(*) FROM delivered) * 100, 2) AS kpi_value,
    40.00 AS kpi_target,
    CASE WHEN ROUND((SELECT COUNT(*) FROM covered) / (SELECT COUNT(*) FROM delivered) * 100, 2) >= 40
         THEN 'PASS' ELSE 'FAIL' END AS status,
    NOW() AS calculated_at;



-- 4B.1 — gold_top_books
-- Business purpose: Top 10 books by revenue within each genre, with
-- average rating and total units sold — powers a "bestsellers by genre" widget.

CREATE OR REPLACE VIEW gold_top_books AS
WITH book_revenue AS (
    SELECT
        b.genre,
        b.book_id,
        b.title,
        SUM(so.order_value) AS total_revenue,
        SUM(so.quantity)    AS units_sold
    FROM silver_orders so
    JOIN silver_books b ON b.book_id = so.book_id
    WHERE so.status = 'DELIVERED'
    GROUP BY b.genre, b.book_id, b.title
),
book_ratings AS (
    SELECT book_id, ROUND(AVG(rating), 2) AS avg_rating
    FROM silver_reviews
    GROUP BY book_id
),
ranked AS (
    SELECT
        br.genre, br.book_id, br.title, br.total_revenue, br.units_sold,
        bra.avg_rating,
        ROW_NUMBER() OVER (PARTITION BY br.genre ORDER BY br.total_revenue DESC) AS rn
    FROM book_revenue br
    LEFT JOIN book_ratings bra ON bra.book_id = br.book_id
)
SELECT genre, book_id, title, total_revenue, avg_rating, units_sold
FROM ranked
WHERE rn <= 10
ORDER BY genre, total_revenue DESC;


-- 4B.2 — gold_customer_segments
-- Business purpose: Classifies every validated customer by total delivered
-- spend, including zero-spend customers, for targeted marketing/retention.

CREATE OR REPLACE VIEW gold_customer_segments AS
WITH customer_spend AS (
    SELECT customer_id, SUM(order_value) AS total_spend
    FROM silver_orders
    WHERE status = 'DELIVERED'
    GROUP BY customer_id
)
SELECT
    sc.customer_id,
    COALESCE(cs.total_spend, 0) AS total_spend,
    CASE
        WHEN COALESCE(cs.total_spend, 0) > 20000 THEN 'HIGH VALUE'
        WHEN COALESCE(cs.total_spend, 0) >= 5000  THEN 'MID VALUE'
        ELSE 'LOW VALUE'
    END AS segment
FROM silver_customers sc
LEFT JOIN customer_spend cs ON cs.customer_id = sc.customer_id;


SELECT * FROM gold_kpi_revenue_growth;
SELECT * FROM gold_kpi_retention_rate;
SELECT * FROM gold_kpi_sell_through;
SELECT * FROM gold_kpi_return_compliance;
SELECT * FROM gold_kpi_review_coverage;
SELECT * FROM gold_top_books;
SELECT * FROM gold_customer_segments;
