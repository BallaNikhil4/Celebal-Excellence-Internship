# Online Bookstore & Library Management System
## CityReads — Medallion Data Pipeline

A Data Engineering capstone project. CityReads is an online bookstore that
also runs a public lending library. This project builds a complete
**Bronze → Silver → Gold** pipeline on top of its raw data, and ends with a
set of Gold-layer views that power an executive KPI dashboard.

---

## What this project does, in simple terms

1. **Bronze layer** — copies the raw data exactly as it is, with no
   cleaning, plus two extra columns (`ingested_at`, `batch_id`) so we know
   *when* and *in which run* each row arrived.
2. **Silver layer** — cleans the Bronze data: removes duplicate rows,
   throws out rows that fail basic quality checks (like a rating of `7` or
   a blank email), and logs *why* each bad row was rejected instead of just
   silently deleting it.
3. **Gold layer** — builds the final business-ready views: 5 KPI views for
   the executive dashboard, 2 extra analytical views, and 1 health-check
   view that shows if the whole pipeline is working properly.

Everything is implemented entirely in **MySQL 8** using plain SQL scripts,
run in order.

---

## Tech stack

- **Database:** MySQL 8.0+
- **Techniques used:** window functions (`ROW_NUMBER`, `LAG`, `LEAD`),
  CTEs, `CASE` expressions, anti-join FK validation, transactions,
  incremental watermark loading, gaps-and-islands streak detection

---

## Folder structure

```
cityreads-medallion-pipeline/
├── README.md                    ← you are here
├── pipeline_design.md           ← design decisions, trade-offs, what went wrong and how it got fixed
├── sql/
│   ├── task1_schema.sql         ← creates all tables and view stubs
│   ├── task2_bronze_load.sql    ← loads raw data into Bronze
│   ├── task3_silver_transform.sql ← cleans Bronze data into Silver
│   ├── task4_gold_views.sql     ← builds the 7 Gold views
│   └── task5_audit.sql          ← pipeline health check view
└── data/
    └── cityreads_dataset/       ← the 5 source CSVs (books, customers, orders, loans, reviews)
```

---

## How to run this

Run the 5 SQL files **in order** — each one depends on the last:

```
1. task1_schema.sql          → creates the database and every table/view
2. task2_bronze_load.sql     → loads the source data into Bronze
3. task3_silver_transform.sql → cleans Bronze into Silver
4. task4_gold_views.sql      → builds the Gold KPI + analytical views
5. task5_audit.sql           → checks the health of the whole pipeline
```

Before step 2, make sure the 5 source tables (`books`, `customers`,
`orders`, `loans`, `reviews`) already exist in the `cityreads` database and
are loaded with the raw CSV data — the pipeline treats these as the
starting point and never modifies them.

After running everything, you can check the results with:

```sql
SELECT * FROM gold_kpi_revenue_growth;
SELECT * FROM gold_kpi_retention_rate;
SELECT * FROM gold_kpi_sell_through;
SELECT * FROM gold_kpi_return_compliance;
SELECT * FROM gold_kpi_review_coverage;
SELECT * FROM gold_pipeline_health ORDER BY table_name;
```

---

## KPI results (on the provided dataset)

| KPI | Result | Target | Status |
|---|---|---|---|
| Book Sell-Through Rate | 100.00% | ≥ 70% | ✅ PASS |
| Review Coverage Rate | 63.04% | ≥ 40% | ✅ PASS |
| Monthly Revenue Growth | 3-month streak found (happened 3 separate times) | ≥ 3 consecutive months | ✅ PASS |
| Library Return Compliance | 60.01% | ≥ 75% | ❌ FAIL |
| Customer Retention Rate | 55.57% | ≥ 60% | ❌ FAIL |

Two KPIs come back FAIL, and that's intentional, not a bug — I computed
both honestly using the real, correct definition instead of adjusting the
formula until it passed. Full reasoning is in `pipeline_design.md`.

**Overall pipeline health:** HEALTHY — worst single-table rejection rate is
3.47% (`bronze_orders`), and every table stays under the 5% threshold that
would mark the pipeline as DEGRADED.

---

## Author

Built as a Data Engineering internship capstone project — Bronze/Silver/Gold
Medallion Architecture, written and debugged end-to-end in MySQL 8.
