--------------------------------------------------
-- Query 1 : Total Revenue Per Category
--------------------------------------------------

SELECT
    p.category,
    ROUND(
        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ),
        2
    ) AS total_revenue
FROM order_items oi
JOIN products p
ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;


--------------------------------------------------
-- Query 2 : Top 10 Customers By Total Order Value
--------------------------------------------------

SELECT
    c.customer_id,
    c.customer_name,
    ROUND(
        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ),
        2
    ) AS total_order_value
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_order_value DESC
LIMIT 10;


--------------------------------------------------
-- Query 3 : Month-wise Order Count
--------------------------------------------------

SELECT
    strftime('%Y-%m', order_date) AS month,
    COUNT(*) AS total_orders
FROM orders
GROUP BY month
ORDER BY month DESC
LIMIT 12;


--------------------------------------------------
-- Query 4 : Customers Who Never Had Delivered Items
--------------------------------------------------

SELECT DISTINCT
    c.customer_id,
    c.customer_name
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
WHERE c.customer_id NOT IN
(
    SELECT DISTINCT customer_id
    FROM orders
    WHERE status='DELIVERED'
);


--------------------------------------------------
-- Query 5 : Products Having More Returns Than Purchases
--------------------------------------------------

SELECT
    p.product_id,
    p.product_name,

    SUM(
        CASE
            WHEN oi.quantity < 0
            THEN ABS(oi.quantity)
            ELSE 0
        END
    ) AS returned,

    SUM(
        CASE
            WHEN oi.quantity > 0
            THEN oi.quantity
            ELSE 0
        END
    ) AS purchased

FROM products p
JOIN order_items oi
ON p.product_id = oi.product_id

GROUP BY
    p.product_id,
    p.product_name

HAVING returned > purchased;


--------------------------------------------------
-- Query 6 : Return Rate Per Category
--------------------------------------------------

SELECT
    p.category,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN oi.quantity < 0
                THEN ABS(oi.quantity)
                ELSE 0
            END
        ) /

        SUM(ABS(oi.quantity)),

        2
    ) AS return_rate

FROM products p
JOIN order_items oi
ON p.product_id = oi.product_id

GROUP BY p.category;

----------------------------------------------------------
-- Query 7 : Running Totals With Window Functions
----------------------------------------------------------

WITH daily_sales AS
(
    SELECT

        o.region_code,

        DATE(o.order_date) AS order_date,

        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ) AS daily_revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        o.region_code,
        DATE(o.order_date)
)

SELECT

    region_code,

    order_date,

    ROUND(daily_revenue,2) AS daily_revenue,

    ROUND(

        SUM(daily_revenue)

        OVER(

            PARTITION BY region_code

            ORDER BY order_date

        ),

        2

    ) AS running_total

FROM daily_sales

ORDER BY
    region_code,
    order_date;



----------------------------------------------------------
-- Query 8 : Ranking Products By Revenue (DENSE_RANK)
----------------------------------------------------------

SELECT

    p.category,

    p.product_name,

    ROUND(

        SUM(

            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)

        ),

        2

    ) AS total_revenue,

    DENSE_RANK()

    OVER(

        PARTITION BY p.category

        ORDER BY

            SUM(

                oi.quantity *
                oi.unit_price *
                (1 - oi.discount_percent / 100.0)

            ) DESC

    ) AS rank_in_category

FROM products p

JOIN order_items oi
    ON p.product_id = oi.product_id

GROUP BY
    p.category,
    p.product_name

ORDER BY
    p.category,
    rank_in_category;

----------------------------------------------------------
-- Query 9 : Days Between Consecutive Orders (LAG)
----------------------------------------------------------

SELECT
    CAST(customer_id AS INTEGER) AS customer_id,
    order_date,

    LAG(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previous_order_date,

    ROUND(
        julianday(order_date) -
        julianday(
            LAG(order_date) OVER (
                PARTITION BY customer_id
                ORDER BY order_date
            )
        ),
        2
    ) AS days_gap

FROM orders

WHERE customer_id IS NOT NULL
  AND customer_id != 'UNKNOWN';



----------------------------------------------------------
-- Query 10 : Customers At Risk
----------------------------------------------------------

WITH gaps AS (
    SELECT
        CAST(customer_id AS INTEGER) AS customer_id,

        julianday(order_date) -
        julianday(
            LAG(order_date) OVER (
                PARTITION BY customer_id
                ORDER BY order_date
            )
        ) AS gap

    FROM orders

    WHERE customer_id IS NOT NULL
      AND customer_id != 'UNKNOWN'
)

SELECT
    customer_id,

    ROUND(AVG(gap), 2) AS average_gap,

    CASE
        WHEN AVG(gap) > 30 THEN 'At Risk'
        ELSE 'Active'
    END AS customer_status

FROM gaps

GROUP BY customer_id;



----------------------------------------------------------
-- Query 11 : Customer Revenue Segmentation
----------------------------------------------------------

WITH revenue AS (
    SELECT
        CAST(o.customer_id AS INTEGER) AS customer_id,

        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ) AS revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.customer_id != 'UNKNOWN'

    GROUP BY customer_id
)

SELECT
    customer_id,

    ROUND(revenue, 2) AS total_revenue,

    CASE
        WHEN revenue > 100000 THEN 'High'
        WHEN revenue > 50000 THEN 'Medium'
        ELSE 'Low'
    END AS revenue_group

FROM revenue

ORDER BY revenue DESC;



----------------------------------------------------------
-- Query 12 : Customer Quartiles
----------------------------------------------------------

WITH customer_value AS (
    SELECT
        CAST(o.customer_id AS INTEGER) AS customer_id,

        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ) AS lifetime_value

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.customer_id != 'UNKNOWN'

    GROUP BY customer_id
)

SELECT
    customer_id,

    ROUND(lifetime_value, 2) AS lifetime_value,

    NTILE(4) OVER (
        ORDER BY lifetime_value DESC
    ) AS quartile

FROM customer_value;



----------------------------------------------------------
-- Query 13 : First Purchased Category
----------------------------------------------------------

WITH ranked AS (
    SELECT
        CAST(o.customer_id AS INTEGER) AS customer_id,

        p.category,

        o.order_date,

        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date
        ) AS rn

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.customer_id != 'UNKNOWN'
)

SELECT
    customer_id,

    category AS first_category

FROM ranked

WHERE rn = 1;



----------------------------------------------------------
-- Query 14 : Most Recent Purchased Category
----------------------------------------------------------

WITH ranked AS (
    SELECT
        CAST(o.customer_id AS INTEGER) AS customer_id,

        p.category,

        o.order_date,

        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date DESC
        ) AS rn

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.customer_id != 'UNKNOWN'
)

SELECT
    customer_id,

    category AS latest_category

FROM ranked

WHERE rn = 1;



----------------------------------------------------------
-- Query 15 : Cumulative Revenue Percentage
----------------------------------------------------------

WITH customer_revenue AS (
    SELECT
        CAST(o.customer_id AS INTEGER) AS customer_id,

        SUM(
            oi.quantity *
            oi.unit_price *
            (1 - oi.discount_percent / 100.0)
        ) AS revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.customer_id != 'UNKNOWN'

    GROUP BY customer_id
)

SELECT
    customer_id,

    ROUND(revenue, 2) AS revenue,

    ROUND(
        SUM(revenue) OVER (
            ORDER BY revenue DESC
        ),
        2
    ) AS cumulative_revenue

FROM customer_revenue;



----------------------------------------------------------
-- Query 16 : Top Product Pairs
----------------------------------------------------------

SELECT
    oi1.product_id AS product_a,

    oi2.product_id AS product_b,

    COUNT(*) AS times_bought_together

FROM order_items oi1

JOIN order_items oi2
    ON oi1.order_id = oi2.order_id
   AND oi1.product_id < oi2.product_id

GROUP BY
    product_a,
    product_b

ORDER BY
    times_bought_together DESC

LIMIT 20;