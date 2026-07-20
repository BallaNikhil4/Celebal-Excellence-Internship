import sqlite3

DB_NAME = "ecommerce.db"


def execute_query(query, params=()):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute(query, params)

    rows = cursor.fetchall()

    conn.close()

    return rows


def revenue_report(start_date, end_date):

    query = """
    SELECT
        COUNT(DISTINCT o.order_id),
        ROUND(
            SUM(
                oi.quantity *
                oi.unit_price *
                (1 - oi.discount_percent / 100.0)
            ),
            2
        ),
        COUNT(DISTINCT o.customer_id)
    FROM orders o
    JOIN order_items oi
    ON o.order_id = oi.order_id
    WHERE DATE(o.order_date)
    BETWEEN ? AND ?;
    """

    result = execute_query(query, (start_date, end_date))[0]

    print("\n========== Revenue Report ==========\n")

    print(f"Total Orders       : {result[0]}")
    print(f"Total Revenue      : {result[1]}")
    print(f"Unique Customers   : {result[2]}")

    print("\nTop 3 Products\n")

    query = """
    SELECT
        p.product_name,
        ROUND(
            SUM(
                oi.quantity *
                oi.unit_price *
                (1 - oi.discount_percent / 100.0)
            ),
            2
        ) revenue

    FROM products p

    JOIN order_items oi
    ON p.product_id = oi.product_id

    GROUP BY p.product_name

    ORDER BY revenue DESC

    LIMIT 3;
    """

    products = execute_query(query)

    for i, product in enumerate(products, start=1):
        print(f"{i}. {product[0]} - {product[1]}")


def top_customers():

    query = """
    SELECT
        c.customer_name,

        ROUND(
            SUM(
                oi.quantity *
                oi.unit_price *
                (1 - oi.discount_percent / 100.0)
            ),
            2
        ) total_spent

    FROM customers c

    JOIN orders o
    ON CAST(o.customer_id AS INTEGER)=c.customer_id

    JOIN order_items oi
    ON o.order_id=oi.order_id

    GROUP BY c.customer_name

    ORDER BY total_spent DESC

    LIMIT 10;
    """

    rows = execute_query(query)

    print("\n========== Top Customers ==========\n")

    for i, row in enumerate(rows, start=1):
        print(f"{i}. {row[0]} - {row[1]}")


def category_revenue():

    query = """
    SELECT
        p.category,

        ROUND(
            SUM(
                oi.quantity *
                oi.unit_price *
                (1 - oi.discount_percent / 100.0)
            ),
            2
        ) revenue

    FROM products p

    JOIN order_items oi
    ON p.product_id=oi.product_id

    GROUP BY p.category

    ORDER BY revenue DESC;
    """

    rows = execute_query(query)

    print("\n========== Revenue By Category ==========\n")

    for row in rows:
        print(f"{row[0]} : {row[1]}")


def main():

    while True:

        print("\n========== MENU ==========")
        print("1. Revenue Report")
        print("2. Top Customers")
        print("3. Revenue By Category")
        print("4. Exit")

        choice = input("\nEnter choice : ")

        if choice == "1":

            start = input("Start Date (YYYY-MM-DD): ")
            end = input("End Date (YYYY-MM-DD): ")

            revenue_report(start, end)

        elif choice == "2":

            top_customers()

        elif choice == "3":

            category_revenue()

        elif choice == "4":

            print("\nThank you!\n")
            break

        else:

            print("Invalid choice.")


if __name__ == "__main__":
    main()