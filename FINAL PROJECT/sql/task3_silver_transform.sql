
-- TASK 3: SILVER TRANSFORMATION — Clean, Validate, Enrich
-- Load order matters: books, customers first (no FK deps),
-- then orders/loans/reviews (validated against silver_customers/silver_books)

USE cityreads;



-- 3.1 BOOKS

DROP TEMPORARY TABLE IF EXISTS stg_books;
CREATE TEMPORARY TABLE stg_books AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY book_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_books
)
SELECT
    book_id,
    TRIM(title)  AS title,
    TRIM(author) AS author,
    TRIM(genre)  AS genre,
    price,
    stock,
    published_on,
    CASE
        WHEN book_id IS NULL                       THEN 'book_id is null'
        WHEN title IS NULL OR TRIM(title) = ''      THEN 'title is null/blank'
        WHEN price IS NULL OR price <= 0            THEN 'price <= 0 or null'
        WHEN stock IS NULL OR stock < 0             THEN 'stock < 0 or null'
        ELSE NULL
    END AS reject_reason
FROM deduped
WHERE rn = 1;

INSERT INTO silver_books (book_id, title, author, genre, price, stock, published_on)
SELECT book_id, title, author, genre, price, stock, published_on
FROM stg_books
WHERE reject_reason IS NULL;

INSERT INTO silver_rejected_rows (table_name, source_id, rejection_reason)
SELECT 'bronze_books', CAST(book_id AS CHAR), reject_reason
FROM stg_books
WHERE reject_reason IS NOT NULL;


-- 3.2 CUSTOMERS

DROP TEMPORARY TABLE IF EXISTS stg_customers;
CREATE TEMPORARY TABLE stg_customers AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_customers
)
SELECT
    customer_id,
    TRIM(name)              AS name,
    TRIM(email)              AS email,
    TRIM(city)                AS city,
    joined_on,
    UPPER(TRIM(membership))   AS membership,   -- standardize BEFORE validating
    CASE
        WHEN customer_id IS NULL                              THEN 'customer_id is null'
        WHEN name IS NULL OR TRIM(name) = ''                  THEN 'name is null/blank'
        WHEN email IS NULL OR TRIM(email) = ''                THEN 'email is null/blank'
        WHEN UPPER(TRIM(membership)) NOT IN ('BASIC','PREMIUM','LIBRARY')
                                                                THEN 'invalid membership value'
        ELSE NULL
    END AS reject_reason
FROM deduped
WHERE rn = 1;

INSERT INTO silver_customers (customer_id, name, email, city, joined_on, membership)
SELECT customer_id, name, email, city, joined_on, membership
FROM stg_customers
WHERE reject_reason IS NULL;

INSERT INTO silver_rejected_rows (table_name, source_id, rejection_reason)
SELECT 'bronze_customers', CAST(customer_id AS CHAR), reject_reason
FROM stg_customers
WHERE reject_reason IS NOT NULL;



-- 3.3 ORDERS  (depends on silver_customers, silver_books)

DROP TEMPORARY TABLE IF EXISTS stg_orders;
CREATE TEMPORARY TABLE stg_orders AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_orders
)
SELECT
    d.order_id,
    d.customer_id,
    d.book_id,
    d.order_date,
    d.quantity,
    UPPER(TRIM(d.status)) AS status,
    sb.price               AS book_price,          -- NULL if book_id invalid
    CASE
        WHEN d.order_id IS NULL                                          THEN 'order_id is null'
        WHEN d.quantity IS NULL OR d.quantity <= 0                       THEN 'quantity <= 0 or null'
        WHEN UPPER(TRIM(d.status)) NOT IN ('PENDING','SHIPPED','DELIVERED','CANCELLED')
                                                                            THEN 'invalid status value'
        WHEN sc.customer_id IS NULL                                       THEN 'customer_id not found in silver_customers'
        WHEN sb.book_id IS NULL                                           THEN 'book_id not found in silver_books'
        ELSE NULL
    END AS reject_reason
FROM deduped d
LEFT JOIN silver_customers sc ON sc.customer_id = d.customer_id
LEFT JOIN silver_books     sb ON sb.book_id     = d.book_id
WHERE d.rn = 1;

INSERT INTO silver_orders (order_id, customer_id, book_id, order_date, quantity, status, order_value)
SELECT order_id, customer_id, book_id, order_date, quantity, status,
       quantity * book_price AS order_value
FROM stg_orders
WHERE reject_reason IS NULL;

INSERT INTO silver_rejected_rows (table_name, source_id, rejection_reason)
SELECT 'bronze_orders', CAST(order_id AS CHAR), reject_reason
FROM stg_orders
WHERE reject_reason IS NOT NULL;


-- 3.4 LOANS  (depends on silver_customers, silver_books)

DROP TEMPORARY TABLE IF EXISTS stg_loans;
CREATE TEMPORARY TABLE stg_loans AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_loans
)
SELECT
    d.loan_id,
    d.customer_id,
    d.book_id,
    d.loan_date,
    d.due_date,
    d.return_date,
    CASE
        WHEN d.loan_id IS NULL  THEN 'loan_id is null'
        WHEN d.due_date IS NULL OR d.loan_date IS NULL THEN 'loan_date/due_date is null'
        WHEN d.due_date <= d.loan_date THEN 'due_date <= loan_date'
        WHEN sc.customer_id IS NULL THEN 'customer_id not found in silver_customers'
        WHEN sb.book_id IS NULL THEN 'book_id not found in silver_books'
        ELSE NULL
    END AS reject_reason
FROM deduped d
LEFT JOIN silver_customers sc ON sc.customer_id = d.customer_id
LEFT JOIN silver_books     sb ON sb.book_id     = d.book_id
WHERE d.rn = 1;

INSERT INTO silver_loans (loan_id, customer_id, book_id, loan_date, due_date, return_date,
                           days_overdue, overdue_category)
SELECT
    loan_id, customer_id, book_id, loan_date, due_date, return_date,
    CASE
        WHEN return_date IS NULL AND CURDATE() > due_date THEN DATEDIFF(CURDATE(), due_date)
        WHEN return_date IS NOT NULL AND return_date > due_date THEN DATEDIFF(return_date, due_date)
        ELSE 0
    END AS days_overdue,
    CASE
        WHEN (CASE
                WHEN return_date IS NULL AND CURDATE() > due_date THEN DATEDIFF(CURDATE(), due_date)
                WHEN return_date IS NOT NULL AND return_date > due_date THEN DATEDIFF(return_date, due_date)
                ELSE 0
              END) = 0  THEN 'ON TIME'
        WHEN (CASE
                WHEN return_date IS NULL AND CURDATE() > due_date THEN DATEDIFF(CURDATE(), due_date)
                WHEN return_date IS NOT NULL AND return_date > due_date THEN DATEDIFF(return_date, due_date)
                ELSE 0
              END) <= 7  THEN 'MILD'
        WHEN (CASE
                WHEN return_date IS NULL AND CURDATE() > due_date THEN DATEDIFF(CURDATE(), due_date)
                WHEN return_date IS NOT NULL AND return_date > due_date THEN DATEDIFF(return_date, due_date)
                ELSE 0
              END) <= 30 THEN 'SEVERE'
        ELSE 'CRITICAL'
    END AS overdue_category
FROM stg_loans
WHERE reject_reason IS NULL;

INSERT INTO silver_rejected_rows (table_name, source_id, rejection_reason)
SELECT 'bronze_loans', CAST(loan_id AS CHAR), reject_reason
FROM stg_loans
WHERE reject_reason IS NOT NULL;


-- 3.5 REVIEWS  (depends on silver_customers, silver_books)

DROP TEMPORARY TABLE IF EXISTS stg_reviews;
CREATE TEMPORARY TABLE stg_reviews AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_reviews
)
SELECT
    d.review_id,
    d.customer_id,
    d.book_id,
    d.rating,
    d.review_text,
    d.created_at,
    CASE
        WHEN d.review_id IS NULL THEN 'review_id is null'
        WHEN d.rating IS NULL OR d.rating NOT BETWEEN 1 AND 5  THEN 'rating out of range'
        WHEN sc.customer_id IS NULL  THEN 'customer_id not found in silver_customers'
        WHEN sb.book_id IS NULL  THEN 'book_id not found in silver_books'
        ELSE NULL
    END AS reject_reason
FROM deduped d
LEFT JOIN silver_customers sc ON sc.customer_id = d.customer_id
LEFT JOIN silver_books sb ON sb.book_id = d.book_id
WHERE d.rn = 1;

INSERT INTO silver_reviews (review_id, customer_id, book_id, rating, review_text, created_at)
SELECT review_id, customer_id, book_id, rating, review_text, created_at
FROM stg_reviews
WHERE reject_reason IS NULL;

INSERT INTO silver_rejected_rows (table_name, source_id, rejection_reason)
SELECT 'bronze_reviews', CAST(review_id AS CHAR), reject_reason
FROM stg_reviews
WHERE reject_reason IS NOT NULL;


-- 3.6 SUMMARY — accepted vs rejected per table (required deliverable)

SELECT
    'books' AS source_table,
    (SELECT COUNT(*) FROM stg_books)  AS bronze_deduped_rows,
    (SELECT COUNT(*) FROM silver_books)  AS accepted,
    (SELECT COUNT(*) FROM silver_rejected_rows WHERE table_name = 'bronze_books') AS rejected
UNION ALL
SELECT 'customers',
    (SELECT COUNT(*) FROM stg_customers),
    (SELECT COUNT(*) FROM silver_customers),
    (SELECT COUNT(*) FROM silver_rejected_rows WHERE table_name = 'bronze_customers')
UNION ALL
SELECT 'orders',
    (SELECT COUNT(*) FROM stg_orders),
    (SELECT COUNT(*) FROM silver_orders),
    (SELECT COUNT(*) FROM silver_rejected_rows WHERE table_name = 'bronze_orders')
UNION ALL
SELECT 'loans',
    (SELECT COUNT(*) FROM stg_loans),
    (SELECT COUNT(*) FROM silver_loans),
    (SELECT COUNT(*) FROM silver_rejected_rows WHERE table_name = 'bronze_loans')
UNION ALL
SELECT 'reviews',
    (SELECT COUNT(*) FROM stg_reviews),
    (SELECT COUNT(*) FROM silver_reviews),
    (SELECT COUNT(*) FROM silver_rejected_rows WHERE table_name = 'bronze_reviews');