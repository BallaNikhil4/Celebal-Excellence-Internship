"""
Part 5: Edge Case Handling

This script tests common edge cases using an in-memory SQLite database.
The production database (ecommerce.db) is NOT modified.

Run:
python tests/test_cases.py
"""

import sqlite3

PASS = "PASS"
FAIL = "FAIL"


def build_test_db():

    conn = sqlite3.connect(":memory:")

    conn.executescript("""

    CREATE TABLE orders(
        order_id INTEGER PRIMARY KEY,
        customer_id INTEGER,
        order_date TEXT,
        status TEXT,
        region_code TEXT
    );

    CREATE TABLE order_items(
        item_id INTEGER PRIMARY KEY,
        order_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        unit_price REAL,
        discount_percent REAL
    );

    CREATE TABLE products(
        product_id INTEGER PRIMARY KEY,
        product_name TEXT,
        category TEXT,
        subcategory TEXT,
        cost_price REAL
    );

    INSERT INTO orders VALUES
    (1,101,'2024-06-01 10:00:00','DELIVERED','NORTH');

    INSERT INTO orders VALUES
    (2,102,'2024-07-15 14:30:00','PLACED','SOUTH');

    INSERT INTO products VALUES
    (1,'Laptop','Electronics','Laptops',40000);

    INSERT INTO order_items VALUES
    (1,1,1,2,50000,10);

    INSERT INTO order_items VALUES
    (2,2,1,1,50000,5);

    """)

    return conn


# ----------------------------------------------------
# Test 1
# ----------------------------------------------------

def test_orphan_order_id():

    print("\nTest 1 : Invalid order_id")

    conn = build_test_db()

    conn.execute("""
    INSERT INTO order_items
    VALUES
    (99,999999,1,2,50000,10)
    """)

    conn.commit()

    cur = conn.cursor()

    cur.execute("""

    SELECT COUNT(*)

    FROM order_items oi

    WHERE NOT EXISTS
    (
        SELECT 1

        FROM orders o

        WHERE o.order_id=oi.order_id
    )

    """)

    count = cur.fetchone()[0]

    if count==1:
        print(f"{PASS} : Invalid order detected.")
    else:
        print(f"{FAIL}")

    conn.close()


# ----------------------------------------------------
# Test 2
# ----------------------------------------------------

def test_discount_over_100():

    print("\nTest 2 : Discount > 100")

    conn = build_test_db()

    conn.execute("""
    INSERT INTO order_items
    VALUES
    (100,1,1,1,10000,150)
    """)

    conn.commit()

    cur = conn.cursor()

    cur.execute("""

    SELECT

    quantity*
    unit_price*
    (1-discount_percent/100.0)

    FROM order_items

    WHERE item_id=100

    """)

    revenue = cur.fetchone()[0]

    if revenue<0:

        print(f"{PASS} : Negative revenue detected.")

    else:

        print(f"{FAIL}")

    conn.close()


# ----------------------------------------------------
# Test 3
# ----------------------------------------------------

def test_zero_quantity():

    print("\nTest 3 : Quantity = 0")

    conn = build_test_db()

    conn.execute("""

    INSERT INTO order_items

    VALUES

    (101,1,1,0,50000,10)

    """)

    conn.commit()

    cur = conn.cursor()

    cur.execute("""

    SELECT COUNT(*)

    FROM order_items

    WHERE quantity=0

    """)

    count = cur.fetchone()[0]

    if count==1:

        print(f"{PASS} : Zero quantity detected.")

    else:

        print(f"{FAIL}")

    conn.close()


# ----------------------------------------------------
# Test 4
# ----------------------------------------------------

def test_future_order_date():

    print("\nTest 4 : Future Order Date")

    conn = build_test_db()

    conn.execute("""

    INSERT INTO orders

    VALUES

    (999,101,'2099-12-31 00:00:00','PLACED','EAST')

    """)

    conn.commit()

    cur = conn.cursor()

    cur.execute("""

    SELECT COUNT(*)

    FROM orders

    WHERE DATE(order_date)>DATE('now')

    """)

    count = cur.fetchone()[0]

    if count==1:

        print(f"{PASS} : Future date detected.")

    else:

        print(f"{FAIL}")

    conn.close()


if __name__=="__main__":

    print("="*50)
    print("Running Edge Case Tests")
    print("="*50)

    test_orphan_order_id()
    test_discount_over_100()
    test_zero_quantity()
    test_future_order_date()

    print("\nAll tests completed.")