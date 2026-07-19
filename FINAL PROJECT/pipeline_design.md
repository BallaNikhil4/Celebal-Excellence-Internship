# Pipeline Design Document — CityReads Medallion Pipeline

This document explains three things: how I picked the watermark column for each
table, one trade-off I made while cleaning data in the Silver layer, and which
KPI was the hardest to build and why. I've tried to explain everything in plain
language, with real numbers from my own pipeline run, instead of just repeating
textbook definitions.

---

## 1. How I picked the watermark column for each table

A "watermark" is just a saved timestamp that says "I have already loaded
everything up to this point — next time, only give me rows newer than this."
It's what makes the pipeline pick up *only new data* each time it runs,
instead of reloading everything from scratch.

For a watermark to work properly, the column needs to be something that
**never changes once a row is created**. Here's what I picked and why:

| Table | Watermark column | Why |
|---|---|---|
| `orders` | `order_date` | The day someone places an order never changes afterward. This is a real "event happened at this time" column, so it's a safe watermark. |
| `loans` | `loan_date` | Same idea — the day a book was borrowed is a fixed fact that never gets edited later. |
| `reviews` | `created_at` | Same idea, just with a full date+time instead of only a date, since people can post more than one review a day. |
| `books` | `published_on` | This one is different. `books` doesn't have any column that tells us "when did this row get added to our system." So I reused `published_on` (when the book was originally published) as a stand-in. It's not a perfect fit, but it was the closest thing available. |
| `customers` | `joined_on` | Same reasoning as `books` — there's no real "row created" column, so I used the closest available date instead. |

**Why I'm calling out `books` and `customers` separately:** using a "pretend"
watermark column (one that wasn't actually designed to track when a row
arrived) is risky, and I actually hit that risk for real while building this.

I first set `bronze_books`'s starting watermark to `2000-01-01`. But some
books in the catalogue were published as far back as **1960**. Since the
load rule is "only bring in rows where `published_on` is *after* the
watermark," every book published before the year 2000 got silently skipped
— no error, no warning, they just never showed up. My first Bronze load
only brought in **88 out of 190 books** instead of all of them. I caught
this only because I compared row counts against the source table and the
numbers didn't match.

The fix: I reset the starting watermark for `bronze_books` all the way back
to `1900-01-01`, so it's guaranteed to be older than any real publish date,
and reloaded. Now all 190 books load correctly, and I baked this fixed
starting value directly into the schema so the bug can't come back.

`customers` has the exact same weak spot — if some customer's `joined_on`
date happened to be earlier than the seed watermark, they'd get silently
skipped too. In this specific dataset every customer joined after 2019, so
it never actually broke, but the risk is still there. I decided to leave it
as-is and just document it, instead of "fixing" a bug that isn't actually
firing, because the real lesson is bigger than one column: **a column that
was never built to track "when did this arrive" will eventually fail to
work as a watermark.** In a real company, `books` and `customers` should
each get a proper `last_updated_at` column that the source system updates
automatically, instead of borrowing a business-meaning date for a job it
was never meant to do.

---

## 2. One trade-off I made in the Silver layer

In the Silver layer, every table checks that its `customer_id` actually
exists in `silver_customers` and its `book_id` actually exists in
`silver_books`, using a `LEFT JOIN` that looks for missing matches. This is
necessary because I removed the database-level `FOREIGN KEY` constraints in
my schema, so nothing stops a bad `customer_id` from sneaking through
unless I check for it myself in the SQL.

This led to a real decision I had to make: **if a customer gets rejected
from `silver_customers`** (because their email was blank or their
membership value was invalid), **what happens to that customer's orders,
loans, and reviews?** Should they still be allowed into Silver even though
the customer who created them technically doesn't exist there anymore?

I chose to **reject them too.** If a customer is thrown out, every order,
loan, and review that points to that customer_id gets thrown out as well,
with the reason `'customer_id not found in silver_customers'`.

**The other option** would have been to let those orders/loans/reviews
through anyway, keeping more data in Silver, but at the cost of having rows
that point to a customer who "doesn't exist" as far as Silver is concerned.
That would cause problems later — any report that joins orders to
customers would either quietly drop those rows or show blank/broken
customer info, and nobody looking at the final dashboard would know why.

**Real cost of this choice, measured from my own data:** 34 customers got
rejected in total, and because of the cascade, that pulled down **326
orders, 136 loans, and 69 reviews** along with them — 531 extra rows lost,
even though those specific orders/loans/reviews were otherwise perfectly
fine on their own. That's the actual trade-off: I gave up some raw row
count in exchange for being able to trust that every row in Silver
connects to a real, valid customer. For a dashboard that executives are
going to make decisions from, I think that trust is worth more than the
extra rows — but it's worth knowing exactly how much data that decision
actually costs.

---

## 3. Which KPI was hardest to compute, and why

The hardest one was **Monthly Revenue Growth** — not because the SQL itself
was hard to write, but because the KPI's wording didn't match the format
every other KPI view was supposed to follow.

The spec says every KPI view should return **one row**: a value, a target,
and PASS or FAIL. But the actual target for this KPI is *"revenue grew by
at least 5% in any 3 consecutive months"* — that's not something you can
answer with a single row, because you need to look at the whole timeline of
months and check if 3 of them in a row all hit the target together.

I made two real mistakes while building this, and both were things I only
caught by rereading my own SQL carefully, not because the query threw an
error:

**Mistake 1 — mixing up what "kpi_value" meant.**
My first version showed the *raw rupee amount of revenue* as `kpi_value`,
sitting right next to a `kpi_target` of `5.00` (which is a percentage, not
a rupee amount). The PASS/FAIL logic underneath was actually calculating
things correctly, but the columns *labeled* the numbers in a confusing,
mismatched way — a rupee number and a percentage side by side, like they
were meant to be compared directly. I fixed this by making `kpi_value`
actually *be* the month-over-month growth percentage, which is the real
thing being measured against the 5% target.

**Mistake 2 — checking each month by itself instead of checking for a streak.**
My first version gave every month its own PASS or FAIL depending on
whether *that one month* grew by 5% or more. That technically works and
does show PASS/FAIL like the spec wants, but it doesn't actually answer
the real question, which is about **three months in a row**, not one month
at a time. Imagine growth of 7%, 8%, then 2% — my first version would show
PASS, PASS, FAIL for those three months, but never actually says whether a
3-month streak happened anywhere in the data.

To fix this properly, I used a SQL trick called **"gaps and islands."** In
simple terms: I gave every month a flag of 1 if it hit the 5% target and 0
if it didn't, then grouped together every unbroken run of consecutive 1s
(an "island"), and measured how long each island was. The longest island
tells me the longest real streak of good months, back to back.

Once I fixed it properly, I found something good: a real 3-month streak of
5%+ growth happens **three separate times** across the five years of data
(May–July 2020, May–July 2021, and March–May 2023) — so the KPI genuinely
passes, and it's not just barely scraping by on one lucky month.

**The real lesson here:** the hardest part of this KPI wasn't the SQL
syntax — window functions and `CASE` statements aren't that complicated on
their own. The hard part was reading the business requirement carefully
enough to notice that "one row, one PASS/FAIL" doesn't naturally fit a
question that's really about a *pattern across time*, not a single number.
