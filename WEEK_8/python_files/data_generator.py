from faker import Faker
import pandas as pd
import random
import os

fake = Faker()

random.seed(42)
Faker.seed(42)

NUM_CUSTOMERS = 600
NUM_PRODUCTS = 500
NUM_ORDERS = 1000

CUSTOMER_TYPES = ["REGULAR", "PREMIUM", "VIP"]

ORDER_STATUS = [
    "PLACED",
    "SHIPPED",
    "DELIVERED",
    "CANCELLED",
    "RETURNED"
]

REGIONS = ["NORTH", "SOUTH", "EAST", "WEST"]

PRODUCTS = {
    "Electronics": {
        "subcategory": ["Mobiles", "Laptops", "Accessories"],
        "items": [
            "iPhone 15",
            "Samsung Galaxy S24",
            "Dell Laptop",
            "HP Laptop",
            "Monitor",
            "Webcam",
            "Wireless Mouse",
            "Mechanical Keyboard",
            "USB Cable",
            "Power Bank"
        ]
    },
    "Clothing": {
        "subcategory": ["Men", "Women", "Kids"],
        "items": [
            "T-Shirt",
            "Jeans",
            "Jacket",
            "Sneakers",
            "Kurta",
            "Cap",
            "Sweatshirt",
            "Polo Shirt"
        ]
    },
    "Home": {
        "subcategory": ["Kitchen", "Furniture", "Decor"],
        "items": [
            "Dining Table",
            "Chair",
            "Sofa",
            "Microwave",
            "Mixer Grinder",
            "Pressure Cooker",
            "LED Lamp",
            "Wall Clock"
        ]
    },
    "Books": {
        "subcategory": ["Programming", "Education", "Fiction"],
        "items": [
            "Python Programming",
            "SQL Cookbook",
            "Machine Learning Basics",
            "Clean Code",
            "Atomic Habits",
            "Operating Systems",
            "Computer Networks",
            "DSA Handbook"
        ]
    }
}


def generate_customers():
    customers = []

    for customer_id in range(1, NUM_CUSTOMERS + 1):

        email = fake.email()

        # Around 2% invalid emails
        if random.random() < 0.02:
            if random.choice([True, False]):
                email = email.replace("@", "")
            else:
                email = email.split("@")[0]

        customers.append({
            "customer_id": customer_id,
            "customer_name": fake.name(),
            "email": email,
            "registration_date": fake.date_between(start_date="-3y", end_date="today"),
            "customer_type": random.choice(CUSTOMER_TYPES)
        })

    return pd.DataFrame(customers)


def generate_products():

    products = []

    for product_id in range(1, NUM_PRODUCTS + 1):

        category = random.choice(list(PRODUCTS.keys()))

        product_name = random.choice(PRODUCTS[category]["items"])

        subcategory = random.choice(PRODUCTS[category]["subcategory"])

        chance = random.random()

        # Dirty product names
        if chance < 0.05:
            product_name = "   " + product_name + "   "
        elif chance < 0.10:
            product_name = product_name.swapcase()

        products.append({
            "product_id": product_id,
            "product_name": product_name,
            "category": category,
            "subcategory": subcategory,
            "cost_price": round(random.uniform(100, 50000), 2)
        })

    return pd.DataFrame(products)


def generate_orders():

    orders = []

    for order_id in range(1, NUM_ORDERS + 1):

        if random.random() < 0.05:
            customer_id = None
        else:
            customer_id = random.randint(1, NUM_CUSTOMERS)

        order_date = fake.date_time_between(
            start_date="-2y",
            end_date="now"
        )

        if random.random() < 0.05:
            order_date = order_date.strftime("%d-%m-%Y %H:%M:%S")
        else:
            order_date = order_date.strftime("%Y-%m-%d %H:%M:%S")

        orders.append({
            "order_id": order_id,
            "customer_id": customer_id,
            "order_date": order_date,
            "status": random.choice(ORDER_STATUS),
            "region_code": random.choice(REGIONS)
        })

    return pd.DataFrame(orders)

def generate_order_items(products_df, orders_df):

    order_items = []
    item_id = 1

    # Store cost price for each product so we can use it as unit_price
    product_prices = products_df.set_index("product_id")["cost_price"].to_dict()

    for order_id in orders_df["order_id"]:

        num_products = random.randint(1, 5)

        selected_products = random.sample(
            range(1, NUM_PRODUCTS + 1),
            num_products
        )

        for product_id in selected_products:

            quantity = random.randint(1, 5)

            # Around 3% negative quantity
            if random.random() < 0.03:
                quantity *= -1

            order_items.append({
                "item_id": item_id,
                "order_id": order_id,
                "product_id": product_id,
                "quantity": quantity,
                "unit_price": product_prices[product_id],
                "discount_percent": round(random.uniform(0, 100), 2)
            })

            item_id += 1

    return pd.DataFrame(order_items)


def main():

    os.makedirs("data", exist_ok=True)

    print("Generating customers...")
    customers_df = generate_customers()

    print("Generating products...")
    products_df = generate_products()

    print("Generating orders...")
    orders_df = generate_orders()

    print("Generating order items...")
    order_items_df = generate_order_items(products_df, orders_df)

    customers_df.to_csv("data/customers.csv", index=False)
    products_df.to_csv("data/products.csv", index=False)
    orders_df.to_csv("data/orders.csv", index=False)
    order_items_df.to_csv("data/order_items.csv", index=False)

    print("\nCSV files generated successfully!\n")

    print(f"Customers    : {len(customers_df)}")
    print(f"Products     : {len(products_df)}")
    print(f"Orders       : {len(orders_df)}")
    print(f"Order Items  : {len(order_items_df)}")


if __name__ == "__main__":
    main()