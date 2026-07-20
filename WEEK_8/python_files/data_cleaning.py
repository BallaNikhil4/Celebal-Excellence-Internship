import os
import re
import pandas as pd

DATA_FOLDER = "data"
OUTPUT_FOLDER = "output"

os.makedirs(OUTPUT_FOLDER, exist_ok=True)


def clean_orders(orders_df):

    issues = []

    # Fix date format
    for index, value in orders_df["order_date"].items():

        if pd.isna(value):
            continue

        try:
            pd.to_datetime(value, format="%Y-%m-%d %H:%M:%S")
        except:
            try:
                new_date = pd.to_datetime(
                    value,
                    format="%d-%m-%Y %H:%M:%S"
                ).strftime("%Y-%m-%d %H:%M:%S")

                orders_df.at[index, "order_date"] = new_date
                issues.append(f"Row {index+1}: Date format corrected")

            except:
                issues.append(f"Row {index+1}: Invalid date")

    missing = orders_df["customer_id"].isna().sum()

    # orders_df["customer_id"] = orders_df["customer_id"].fillna("UNKNOWN")

    issues.append(f"Missing customer_id fixed: {missing}")

    return orders_df, issues


def clean_products(products_df):

    issues = []

    original = products_df["product_name"].copy()

    products_df["product_name"] = (
        products_df["product_name"]
        .str.strip()
        .str.title()
    )

    changed = (original != products_df["product_name"]).sum()

    issues.append(f"Product names normalized: {changed}")

    return products_df, issues


def validate_emails(customers_df):

    pattern = r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

    invalid = customers_df[
        ~customers_df["email"].str.match(pattern, na=False)
    ]

    return invalid["customer_id"].tolist()


def check_referential_integrity(order_items_df, orders_df):

    valid_orders = set(orders_df["order_id"])

    invalid = order_items_df[
        ~order_items_df["order_id"].isin(valid_orders)
    ]

    return invalid


def main():

    customers = pd.read_csv(f"{DATA_FOLDER}/customers.csv")
    products = pd.read_csv(f"{DATA_FOLDER}/products.csv")
    orders = pd.read_csv(f"{DATA_FOLDER}/orders.csv")
    order_items = pd.read_csv(f"{DATA_FOLDER}/order_items.csv")

    orders, order_issues = clean_orders(orders)

    products, product_issues = clean_products(products)

    invalid_customers = validate_emails(customers)

    invalid_orders = check_referential_integrity(
        order_items,
        orders
    )

    customers.to_csv(
        f"{OUTPUT_FOLDER}/cleaned_customers.csv",
        index=False
    )

    products.to_csv(
        f"{OUTPUT_FOLDER}/cleaned_products.csv",
        index=False
    )

    orders.to_csv(
        f"{OUTPUT_FOLDER}/cleaned_orders.csv",
        index=False
    )

    order_items.to_csv(
        f"{OUTPUT_FOLDER}/cleaned_order_items.csv",
        index=False
    )

    with open(f"{OUTPUT_FOLDER}/issue_report.txt", "w") as file:

        file.write("DATA QUALITY REPORT\n")
        file.write("=" * 40 + "\n\n")

        for issue in order_issues:
            file.write(issue + "\n")

        for issue in product_issues:
            file.write(issue + "\n")

        file.write(
            f"\nInvalid Emails : {len(invalid_customers)}\n"
        )

        file.write(
            f"Invalid Order References : {len(invalid_orders)}\n"
        )

    print("Cleaning completed successfully.")
    print("Check output folder for cleaned files.")


if __name__ == "__main__":
    main()