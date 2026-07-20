# E-Commerce Order Analytics System

## Overview

This project is an end-to-end E-Commerce Order Analytics System built using **Python, Pandas, SQLite, and SQL**.

The project demonstrates the complete data pipeline, starting from generating realistic e-commerce datasets, cleaning the data, loading it into a SQLite database, performing SQL analysis, and generating reports through a command-line interface.

---

## Features

- Generate realistic e-commerce datasets using Faker
- Introduce intentional data quality issues
- Clean datasets using Pandas
- Validate referential integrity
- Load cleaned data into SQLite
- Perform SQL analytics using:
  - Joins
  - Aggregations
  - Window Functions
  - CTEs
- Generate reports using a CLI application
- Test common edge cases using SQLite

---

## Technologies Used

- Python
- Pandas
- SQLite
- SQL
- Faker

---

## Project Structure

```
WEEK_8/
│
├── Raw Data/
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
│
├── Cleaned Data/
│   ├── cleaned_customers.csv
│   ├── cleaned_products.csv
│   ├── cleaned_orders.csv
│   └── cleaned_order_items.csv
│
├── sql/
│   ├── schema.sql
│   └── queries.sql
│
├── src/
│   ├── data_generator.py
│   ├── data_cleaning.py
│   ├── load_database.py
│   ├── report_cli.py
│   └── test_cases.py
│
├── ecommerce.db
├── README.md

```

---

## Workflow

```
Generate Raw Data
        ↓
Clean Data
        ↓
Load into SQLite
        ↓
Execute SQL Queries
        ↓
Generate Reports
        ↓
Run Edge Case Tests
```

---

## How to Run

### Step 1 – Install Dependencies

```bash
pip install -r requirements.txt
```

---

### Step 2 – Generate Raw Data

```bash
python src/data_generator.py
```

This generates:

- customers.csv
- products.csv
- orders.csv
- order_items.csv

inside the **Raw Data** folder.

---

### Step 3 – Clean the Data

```bash
python src/data_cleaning.py
```

This generates cleaned CSV files inside the **Cleaned Data** folder.

---

### Step 4 – Load SQLite Database

```bash
python src/load_database.py
```

This creates:

```
ecommerce.db
```

and imports the cleaned datasets into SQLite.

---

### Step 5 – SQL Analysis

Execute the queries available in:

```
sql/queries.sql
```

using SQLite Viewer or any SQLite client.

---

### Step 6 – Generate Reports

```bash
python src/report_cli.py
```

The CLI allows generating:

- Revenue Report
- Top Customers
- Revenue by Category

---

### Step 7 – Run Edge Case Tests

```bash
python src/test_cases.py
```

Tests include:

- Invalid Order IDs
- Discount greater than 100%
- Zero Quantity
- Future Order Dates

---

## SQL Analytics

The project includes queries for:

- Revenue per Category
- Top Customers
- Monthly Order Count
- Customer Analytics
- Product Analytics
- Return Rate
- Running Totals
- Dense Rank
- LAG Analysis
- Customer Segmentation
- Cohort-style Analysis
- Product Pair Analysis

---

## Author

**Balla Nikhil**