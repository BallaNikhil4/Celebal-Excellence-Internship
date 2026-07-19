
-- TASK 2: BRONZE INGESTION — Incremental Load with Watermark

-- Assumes: source tables (books, customers, orders, loans, reviews) already exist in this database, pre-populated, per the spec's

USE cityreads;

-- One batch_id per pipeline execution, shared across all 5 table loads
SET @batch_id = CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));



-- 2.1 BOOKS  (pseudo-watermark: published_on — see trade-off note above)
SET @last_load_books = (
    SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_books'
);

START TRANSACTION;

INSERT INTO bronze_books (book_id, title, author, genre, price, stock, published_on, ingested_at, batch_id)
SELECT book_id, title, author, genre, price, stock, published_on, NOW(), @batch_id
FROM books
WHERE published_on > @last_load_books;

UPDATE pipeline_metadata
SET last_loaded_at = NOW(),
    rows_loaded     = ROW_COUNT(),
    status          = 'SUCCESS'
WHERE table_name = 'bronze_books';

COMMIT;


-- 2.2 CUSTOMERS  (pseudo-watermark: joined_on — see trade-off note above)
SET @last_load_customers = (
    SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_customers'
);

START TRANSACTION;

INSERT INTO bronze_customers (customer_id, name, email, city, joined_on, membership, ingested_at, batch_id)
SELECT customer_id, name, email, city, joined_on, membership, NOW(), @batch_id
FROM customers
WHERE joined_on > @last_load_customers;

UPDATE pipeline_metadata
SET last_loaded_at = NOW(),
    rows_loaded     = ROW_COUNT(),
    status          = 'SUCCESS'
WHERE table_name = 'bronze_customers';

COMMIT;


-- 2.3 ORDERS  (true event-time watermark: order_date)

SET @last_load_orders = (
    SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_orders'
);

START TRANSACTION;

INSERT INTO bronze_orders (order_id, customer_id, book_id, order_date, quantity, status, ingested_at, batch_id)
SELECT order_id, customer_id, book_id, order_date, quantity, status, NOW(), @batch_id
FROM orders
WHERE order_date > @last_load_orders;

UPDATE pipeline_metadata
SET last_loaded_at = NOW(),
    rows_loaded = ROW_COUNT(),
    status = 'SUCCESS'
WHERE table_name = 'bronze_orders';

COMMIT;


-- 2.4 LOANS  (true event-time watermark: loan_date)
SET @last_load_loans = (
    SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_loans'
);

START TRANSACTION;

INSERT INTO bronze_loans (loan_id, customer_id, book_id, loan_date, due_date, return_date, ingested_at, batch_id)
SELECT loan_id, customer_id, book_id, loan_date, due_date, return_date, NOW(), @batch_id
FROM loans
WHERE loan_date > @last_load_loans;

UPDATE pipeline_metadata
SET last_loaded_at = NOW(),
    rows_loaded     = ROW_COUNT(),
    status          = 'SUCCESS'
WHERE table_name = 'bronze_loans';

COMMIT;


-- 2.5 REVIEWS  (true event-time watermark: created_at)
SET @last_load_reviews = (
    SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_reviews'
);

START TRANSACTION;

INSERT INTO bronze_reviews (review_id, customer_id, book_id, rating, review_text, created_at, ingested_at, batch_id)
SELECT review_id, customer_id, book_id, rating, review_text, created_at, NOW(), @batch_id
FROM reviews
WHERE created_at > @last_load_reviews;

UPDATE pipeline_metadata
SET last_loaded_at = NOW(),
    rows_loaded     = ROW_COUNT(),
    status          = 'SUCCESS'
WHERE table_name = 'bronze_reviews';

COMMIT;


-- 2.6 Post-load sanity check (not a Gold view, just a quick eyeball query)
SELECT * FROM pipeline_metadata ORDER BY table_name;

 