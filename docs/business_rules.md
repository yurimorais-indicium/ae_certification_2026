# Business Rules — Adventure Works Sales Analytics

How every number in the data warehouse and the dashboard is calculated, and why. Each rule is enforced in the dbt
models (`models/`) and protected by an automated test.

Data: `fea_academy.adventure_works`, **31,465 orders** and **121,317 order lines**, 2011-05-31 to 2014-06-30.

## 1. Metric definitions

| Metric | Definition | Notes |
|---|---|---|
| **Gross revenue** (total transaction value) | `order_quantity × unit_price` | Headline metric. Before discounts, tax and freight. Reproduces the audited 2011 figure to the cent |
| **Discount** | `order_quantity × unit_price × discount %` | Only reseller lines carry discounts (0.65% of reseller gross revenue) |
| **Net revenue** | Gross revenue − discount | Basis of the average order value |
| **Average order value** | (Gross revenue − discounts) ÷ distinct orders | Formula from the brief. Always read **by channel**: about $21,148 for resellers, $1,061 online. Product rankings require at least 30 orders |
| **Orders** | `count(distinct sales_order_id)` | One order has several lines; never count lines |
| **Units** | `sum(order_quantity)` | |
| **Purchasing customers** | `count(distinct customer_sk)` taken from the fact table | 19,119. Never use the row count of `dim_customer` |

## 2. Rules that change the numbers

- **Two dates.** `order_date` drives calendar-year totals (the audited basis). `closing_date` drives monthly
  trends: reseller orders arrive as one batch per month, often booked on the 1st of the next month, so each
  reseller order is dated one day back, to the month its batch closes. Online orders keep their own date.
- **Like-for-like growth** compares **January–April by closing month**, the longest window in which every year
  holds four reseller batches and every channel is complete. Trends cover June 2011 to April 2014; the first and
  last months are partial.
- **Channel.** Customers linked to a store are **resellers** and are named after the store; all others are
  **online individuals**. Resellers are 12.1% of orders but 73.4% of gross revenue.
- **Store twins.** The source holds two customer records per selling store, and only one ever orders. This is
  safe for revenue, and a test fails if both ever sell.
- **Location** is the **ship-to address**: it differs from the bill-to address in only 99 orders.
- **Sales reasons** are many-to-many (0 to 3 per order) and go through a bridge table so revenue is never
  duplicated. Totals per reason are correct, but **the sum across reasons is not additive**. Reasons exist only for
  **online orders**.
- **Unknown members.** Orders without a credit card (1,131) or without a sales reason (8,453) point to explicit
  `No credit card` and `No reason` members, so no order disappears when a user filters.
- **Promotion** means a reason of type `Promotion` (a single reason, *On Promotion*). Question f is answered in
  units. No online line carries a discount, so promotion ROI cannot be measured today.
- **Data fixes.** Namibia's ISO code `NA` was loaded as null and is restored in staging; string dates and double
  keys are cast to proper types. Card numbers and expiry dates are never loaded into the marts.

## 3. Validation

| Rule | Automated test |
|---|---|
| Gross sales 2011 = **$12,646,112.16** (accounting audit) | `assert_gross_sales_2011_matches_audit` |
| Store twins never both sell | `assert_store_twin_rows_never_both_sell` |
| Net = gross − discount; valid quantities and discounts | `expression_is_true`, `accepted_range` |
| Joins never duplicate lines | `equal_rowcount` between fact and source lines |
| Keys and relationships | `unique`, `not_null`, `relationships` on every fact key; 49 source tests |

Last run (2026-11-14): `dbt run` built 27 of 27 models; `dbt test` passed 172 of 173 tests. The one warning is the
documented Namibia source issue and is expected.

## 4. Known limitations

- Each channel's data ends on a different date, so trends stop at April 2014.
- Sales reasons describe only the online channel; every order has the status *Shipped*.
- Margin and profit are out of scope.
