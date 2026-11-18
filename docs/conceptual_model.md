# Conceptual Data Model — Adventure Works Sales

Star schema built to answer the commercial questions of the Analytics Engineer Certification challenge.
All source tables live in `fea_academy.adventure_works`.

## Overview

```
                 dim_date        dim_customer      dim_credit_card
                     \                |                /
                      \               |               /
   dim_product ------ fct_sales (order line) ------ bridge_sales_order_reason ---- dim_sales_reason
                              |
                         dim_location
```

| Model | Type | Grain | Source tables |
|---|---|---|---|
| `fct_sales` | Fact | One row per sales order line | `sales_salesorderdetail`, `sales_salesorderheader` |
| `dim_product` | Dimension | One row per product | `production_product`, `production_productsubcategory`, `production_productcategory` |
| `dim_customer` | Dimension | One row per customer | `sales_customer`, `person_person`, `sales_store` |
| `dim_location` | Dimension | One row per address | `person_address`, `person_stateprovince`, `person_countryregion` |
| `dim_credit_card` | Dimension | One row per credit card (+ "No credit card" member) | `sales_creditcard` |
| `dim_sales_reason` | Dimension | One row per sales reason (+ "No reason" member) | `sales_salesreason` |
| `bridge_sales_order_reason` | Bridge | One row per sales order × sales reason | `sales_salesorderheadersalesreason`, `sales_salesorderheader` |
| `dim_date` | Dimension | One row per calendar day | Generated (`dbt_utils.date_spine`) over the order date range |

## Fact table — `fct_sales`

Grain: **one row per sales order line** (`salesorderdetailid`). Order-level attributes are denormalized onto each line.

| Column | Description |
|---|---|
| `sales_sk` | Surrogate key (PK) |
| `sales_order_detail_id` | Natural key of the order line |
| `sales_order_id` | Degenerate dimension — order number (used to count orders and to join the bridge) |
| `product_sk` | FK → `dim_product` |
| `customer_sk` | FK → `dim_customer` |
| `ship_to_location_sk` | FK → `dim_location` (ship-to address) |
| `credit_card_sk` | FK → `dim_credit_card` |
| `order_date` | FK → `dim_date` (calendar-year basis, audited) |
| `closing_date` | FK → `dim_date` (second role). Equals `order_date` for online orders; `order_date − 1 day` for reseller orders. Used for monthly series and like-for-like comparisons |
| `ship_date`, `due_date` | Order dates |
| `order_status`, `order_status_name` | Order status code and description |
| `is_online_order` | Online vs. sales-rep order |
| `order_quantity` | Units purchased |
| `unit_price` | Unit price |
| `unit_price_discount_pct` | Discount percentage applied to the unit price |
| `gross_amount` | `order_quantity × unit_price` |
| `discount_amount` | `order_quantity × unit_price × unit_price_discount_pct` |
| `net_amount` | `gross_amount − discount_amount` |

## Dimensions

**`dim_product`** — `product_sk`, `product_id`, `product_name`, `product_number`, `color`, `size`, `product_line`, `product_class`, `product_style`, `standard_cost`, `list_price`, `subcategory_name`, `category_name`.

**`dim_customer`** — `customer_sk`, `customer_id`, `customer_name`, `customer_type`, `person_id`, `store_id`, `store_name`.

**`dim_location`** — `location_sk`, `address_id`, `city`, `postal_code`, `state_province_code`, `state_province_name`, `country_region_code`, `country_region_name`.

**`dim_credit_card`** — `credit_card_sk`, `credit_card_id`, `card_type`. Card number and expiry are intentionally excluded (sensitive, no analytical value).

**`dim_sales_reason`** — `sales_reason_sk`, `sales_reason_id`, `sales_reason_name`, `sales_reason_type`.

**`bridge_sales_order_reason`** — `sales_order_id`, `sales_reason_sk`.

**`dim_date`** — `date_day`, `year`, `quarter`, `month`, `month_name`, `year_month`, `day_of_week`, `day_name`, `is_weekend`.

## Modeling decisions

1. **Fact grain = order line.** Product is only known at line level, and every business question slices by product.
2. **Sales reason is many-to-many.** An order can have 0 to 3 reasons (8,453 orders have none; 4,482 have more than one). Joining reasons directly to the fact would duplicate revenue, so reasons are modeled through `bridge_sales_order_reason`. Orders without a reason are linked to a `No reason` member so filters stay complete. When filtering by reason, totals per reason are correct; the sum across reasons is not additive (an order with two reasons counts in both).
3. **Orders without a credit card** (1,131) point to a `No credit card` member in `dim_credit_card`.
4. **Location = ship-to address.** Bill-to and ship-to differ in only 99 of 31,465 orders; the ship-to address represents where the sale was delivered.
5. **Customer name and type.** Customers linked to a store are resellers (`customer_type = 'Store'`) and are named after the store — the linked person is only the store contact (`person_type = 'SC'`). All other customers are `Individual` and use the person's full name. Resellers are 635 selling stores with 3,806 orders but ~73% of gross revenue.

   **Known source grain quirk:** `sales_customer` holds **two customer records per selling store** (same `store_id` and
   name) — one carrying the store-contact `person_id` and all of the orders, one with no contact and no orders. All 635
   selling stores follow this pattern exactly. `dim_customer` therefore has 19,820 rows but represents ~19,185 real
   customers. Of the 701 rows with no orders, **635 are these inactive twins and only 66 are genuinely inactive stores**.
   The dimension stays at one row per `customer_id` (faithful to the source), and because the twin never carries orders
   it cannot double-count revenue: every fact-based metric is unaffected. Counting customers must be done from
   `fct_sales` (19,119 purchasing customers), never from the dimension row count.
6. **Order status** is kept as degenerate attributes in the fact (code + description), as it is an order-level attribute with only 6 possible values. Currently all orders are `Shipped`.
7. **Total transaction value = gross revenue** (`gross_amount`). It is the headline metric for questions a, c, d and e and matches the audited figure. Net revenue (`net_amount`) is used for the average order value (question b).
8. **Two date roles.** Reseller orders arrive as one batch per month, booked at month end or on the 1st of the next month, so a calendar-month series puts some batches in the wrong month. `closing_date` moves each reseller order one day back so every batch lands in the month it closes. `dim_date` is a role-playing dimension: `order_date` keeps calendar-year totals on the audited basis, `closing_date` serves monthly trends.
9. **Header-level amounts** (`taxamt`, `freight`, `totaldue`) are not included in the fact, as they would require allocation across lines and are not needed by the business questions.

## Business question coverage

| # | Question | Answered by | In the dashboard |
|---|---|---|---|
| a | Orders, quantity and transaction value (`gross_amount`) by product, card type, sales reason, date, customer, status, city, state, country | `fct_sales` + all dimensions + bridge | Page 4 (Sales Explorer): a breakdown selector for product, category, card type, sales reason, customer, channel, status, city, state, country, month and year |
| b | Products with the highest average order value by month, year, city, state, country | `fct_sales.net_amount` / distinct `sales_order_id`, `dim_product`, `dim_date`, `dim_location` | Page 3: top 10 products by average order value; month, state and city come from the filter pane |
| c | Top 10 customers by transaction value (`gross_amount`) | `fct_sales` + `dim_customer` | Page 2: top 10 customers, filterable by product, card type, sales reason, date, status, city, state and country |
| d | Top 5 cities by transaction value (`gross_amount`) | `fct_sales` + `dim_location` | Page 2: top 5 cities, with the same filters plus customer |
| e | Orders, quantity and transaction value by month and year | `fct_sales` + `dim_date` (`closing_date` for months, `order_date` for calendar years) | Page 1: monthly sales by channel, January–April by year and a table by calendar year |
| f | Product with the most units purchased for the "Promotion" reason | `fct_sales` + bridge + `dim_sales_reason` (`sales_reason_type = 'Promotion'`) + `dim_product` | Page 3: top products on promotion |

## Data quality anchor

Gross sales for 2011 (`sum(gross_amount)` where `year(order_date) = 2011`) must equal **$12,646,112.16**, as verified by the accounting audit team. Validated against the raw data during profiling and enforced as the dbt test `assert_gross_sales_2011_matches_audit` on `fct_sales`.
