CREATE DATABASE cityreads;
use cityreads;


-- PIPELINE METADATA 
CREATE TABLE pipeline_metadata (
    table_name       VARCHAR(100)  PRIMARY KEY,
    last_loaded_at   DATETIME      NOT NULL DEFAULT '2000-01-01 00:00:00',
    rows_loaded      INT           DEFAULT 0,
    status           VARCHAR(20)   DEFAULT 'PENDING'
);

INSERT INTO pipeline_metadata (table_name, last_loaded_at, rows_loaded, status) VALUES
    ('bronze_books',     '1900-01-01 00:00:00', 0, 'PENDING'),
    ('bronze_customers', '2000-01-01 00:00:00', 0, 'PENDING'),
    ('bronze_orders',    '2000-01-01 00:00:00', 0, 'PENDING'),
    ('bronze_loans',     '2000-01-01 00:00:00', 0, 'PENDING'),
    ('bronze_reviews',   '2000-01-01 00:00:00', 0, 'PENDING');
    
    
-- 1. BRONZE LAYER — raw replica + audit columns, no constraints on
--    business values (Bronze must accept dirty data as-is)
DROP TABLE IF EXISTS bronze_books;
CREATE TABLE bronze_books (
    book_id         INT,
    title           VARCHAR(255),
    author          VARCHAR(255),
    genre           VARCHAR(50),
    price           DECIMAL(10,2),
    stock           INT,
    published_on    DATE,
    -- audit columns (Section 2 requirement)
    ingested_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id        VARCHAR(40)  NOT NULL
);

DROP TABLE IF EXISTS bronze_customers;
CREATE TABLE bronze_customers (
    customer_id     INT,
    name            VARCHAR(255),
    email           VARCHAR(255),
    city            VARCHAR(100),
    joined_on       DATE,
    membership      VARCHAR(50),
    ingested_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id        VARCHAR(40)  NOT NULL
);

DROP TABLE IF EXISTS bronze_orders;
CREATE TABLE bronze_orders (
    order_id        INT,
    customer_id     INT,
    book_id         INT,
    order_date      DATE,
    quantity        INT,
    status          VARCHAR(50),
    ingested_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id        VARCHAR(40)  NOT NULL
);

DROP TABLE IF EXISTS bronze_loans;
CREATE TABLE bronze_loans (
    loan_id         INT,
    customer_id     INT,
    book_id         INT,
    loan_date       DATE,
    due_date        DATE,
    return_date     DATE NULL,
    ingested_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id        VARCHAR(40)  NOT NULL
);

DROP TABLE IF EXISTS bronze_reviews;
CREATE TABLE bronze_reviews (
    review_id       INT,
    customer_id     INT,
    book_id         INT,
    rating          INT,
    review_text     TEXT,
    created_at      DATETIME,
    ingested_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id        VARCHAR(40)  NOT NULL
);

-- Indexes to support Task 2's incremental watermark filter and Task 3's dedup scan.
CREATE INDEX idx_bronze_orders_date       ON bronze_orders (order_date);
CREATE INDEX idx_bronze_reviews_created   ON bronze_reviews (created_at);
CREATE INDEX idx_bronze_loans_loandate    ON bronze_loans (loan_date);
CREATE INDEX idx_bronze_orders_pk_ingest  ON bronze_orders (order_id, ingested_at);
CREATE INDEX idx_bronze_loans_pk_ingest   ON bronze_loans (loan_id, ingested_at);
CREATE INDEX idx_bronze_reviews_pk_ingest ON bronze_reviews (review_id, ingested_at);


-- 2. SILVER LAYER — cleaned, deduplicated, validated, enriched
--    Constraints ARE enforced here — this is the trust boundary.

DROP TABLE IF EXISTS silver_books;
CREATE TABLE silver_books (
    book_id         INT PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    author          VARCHAR(255),
    genre           VARCHAR(50),
    price           DECIMAL(10,2) NOT NULL CHECK (price > 0),
    stock           INT NOT NULL CHECK (stock >= 0),
    published_on    DATE,
    silver_loaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
DROP TABLE IF EXISTS silver_customers;
CREATE TABLE silver_customers (
    customer_id     INT PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    email           VARCHAR(255) NOT NULL,
    city            VARCHAR(100),
    joined_on       DATE,
    membership      VARCHAR(20) NOT NULL CHECK (membership IN ('BASIC','PREMIUM','LIBRARY')),
    silver_loaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_silver_customers_email (email)
);
DROP TABLE IF EXISTS silver_orders;

CREATE TABLE silver_orders (
    order_id          INT PRIMARY KEY,
    customer_id       INT NOT NULL,
    book_id           INT NOT NULL,
    order_date        DATE NOT NULL,
    quantity          INT NOT NULL CHECK (quantity > 0),
    status            VARCHAR(20) NOT NULL
        CHECK (status IN ('PENDING','SHIPPED','DELIVERED','CANCELLED')),
    order_value       DECIMAL(12,2) NOT NULL,          -- Derived: quantity * price
    silver_loaded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver_loans;

CREATE TABLE silver_loans (
    loan_id           INT PRIMARY KEY,
    customer_id       INT NOT NULL,
    book_id           INT NOT NULL,
    loan_date         DATE NOT NULL,
    due_date          DATE NOT NULL,
    return_date       DATE NULL,
    days_overdue      INT NOT NULL DEFAULT 0,
    overdue_category  VARCHAR(20) NOT NULL DEFAULT 'ON TIME',
    silver_loaded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_silver_loans_dates
        CHECK (due_date > loan_date)
);

DROP TABLE IF EXISTS silver_reviews;

CREATE TABLE silver_reviews (
    review_id         INT PRIMARY KEY,
    customer_id       INT NOT NULL,
    book_id           INT NOT NULL,
    rating            INT NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    review_text       TEXT,
    created_at        DATETIME NOT NULL,
    silver_loaded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver_rejected_rows;
CREATE TABLE silver_rejected_rows (
    rejection_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name       VARCHAR(50)  NOT NULL,   -- which bronze_* table the row came from
    source_id        VARCHAR(50)  NOT NULL,   -- the natural PK value, stored as text (varies by table)
    rejection_reason VARCHAR(255) NOT NULL,   -- human-readable, e.g. 'quantity <= 0'
    rejected_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rejected_table_name ON silver_rejected_rows (table_name);

-- Read-heavy indexes on Silver
CREATE INDEX idx_silver_orders_date      ON silver_orders (order_date);
CREATE INDEX idx_silver_orders_status    ON silver_orders (status);
CREATE INDEX idx_silver_orders_customer  ON silver_orders (customer_id);
CREATE INDEX idx_silver_orders_book      ON silver_orders (book_id);
CREATE INDEX idx_silver_loans_duedate    ON silver_loans (due_date);
CREATE INDEX idx_silver_reviews_customer_book ON silver_reviews (customer_id, book_id);


-- 3. GOLD LAYER — view stubs

CREATE OR REPLACE VIEW gold_kpi_revenue_growth AS
SELECT NULL AS kpi_value, NULL AS kpi_target, NULL AS status, NOW() AS calculated_at LIMIT 0;

CREATE OR REPLACE VIEW gold_kpi_retention_rate AS
SELECT NULL AS kpi_value, NULL AS kpi_target, NULL AS status, NOW() AS calculated_at LIMIT 0;

CREATE OR REPLACE VIEW gold_kpi_sell_through AS
SELECT NULL AS kpi_value, NULL AS kpi_target, NULL AS status, NOW() AS calculated_at LIMIT 0;

CREATE OR REPLACE VIEW gold_kpi_return_compliance AS
SELECT NULL AS kpi_value, NULL AS kpi_target, NULL AS status, NOW() AS calculated_at LIMIT 0;

CREATE OR REPLACE VIEW gold_kpi_review_coverage AS
SELECT NULL AS kpi_value, NULL AS kpi_target, NULL AS status, NOW() AS calculated_at LIMIT 0;

CREATE OR REPLACE VIEW gold_top_books AS
SELECT NULL AS genre, NULL AS book_id, NULL AS title, NULL AS total_revenue,
	NULL AS avg_rating, NULL AS units_sold LIMIT 0;

CREATE OR REPLACE VIEW gold_customer_segments AS
SELECT NULL AS customer_id, NULL AS total_spend, NULL AS segment LIMIT 0;

CREATE OR REPLACE VIEW gold_pipeline_health AS
SELECT NULL AS table_name, NULL AS last_loaded_at, NULL AS rows_in_bronze,
       NULL AS rows_in_silver, NULL AS rows_rejected, NULL AS rejection_rate_pct,
       NULL AS pipeline_status LIMIT 0;

SELECT * FROM pipeline_metadata;
       
