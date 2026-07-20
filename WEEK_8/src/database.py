import sqlite3
import pandas as pd

DB_NAME = "ecommerce.db"

conn = sqlite3.connect(DB_NAME)
cursor = conn.cursor()

customers = pd.read_csv("output/cleaned_customers.csv")
products = pd.read_csv("output/cleaned_products.csv")
orders = pd.read_csv("output/cleaned_orders.csv")
order_items = pd.read_csv("output/cleaned_order_items.csv")

customers.to_sql(
    "customers",
    conn,
    if_exists="replace",
    index=False
)

products.to_sql(
    "products",
    conn,
    if_exists="replace",
    index=False
)

orders.to_sql(
    "orders",
    conn,
    if_exists="replace",
    index=False
)

order_items.to_sql(
    "order_items",
    conn,
    if_exists="replace",
    index=False
)

conn.commit()
conn.close()

print("SQLite database created successfully!")
print("Database Name:", DB_NAME)