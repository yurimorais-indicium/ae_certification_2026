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
| `order_date` | FK → `dim_date` |
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

**`dim_product`** — `product_sk`, `product_id`, `product_name`, `product_number`, `color`, `size`, `product_line`, `class`, `style`, `standard_cost`, `list_price`, `subcategory_name`, `category_name`.

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
5. **Customer name.** Uses the person's full name when the customer is an individual, otherwise the store name (701 customers are stores with no person).
6. **Order status** is kept as degenerate attributes in the fact (code + description), as it is an order-level attribute with only 6 possible values. Currently all orders are `Shipped`.
7. **Total transaction value = gross revenue** (`gross_amount`). It is the headline metric for questions a, c, d and e and matches the audited figure. Net revenue (`net_amount`) is used for the average order value (question b).
8. **Header-level amounts** (`taxamt`, `freight`, `totaldue`) are not included in the fact, as they would require allocation across lines and are not needed by the business questions.

## Business question coverage

| # | Question | Answered by |
|---|---|---|
| a | Orders, quantity and transaction value (`gross_amount`) by product, card type, sales reason, date, customer, status, city, state, country | `fct_sales` + all dimensions + bridge |
| b | Products with the highest average order value by month, year, city, state, country | `fct_sales.net_amount` / distinct `sales_order_id`, `dim_product`, `dim_date`, `dim_location` |
| c | Top 10 customers by transaction value (`gross_amount`) | `fct_sales` + `dim_customer` |
| d | Top 5 cities by transaction value (`gross_amount`) | `fct_sales` + `dim_location` |
| e | Orders, quantity and transaction value by month and year | `fct_sales` + `dim_date` |
| f | Product with the most units purchased for the "Promotion" reason | `fct_sales` + bridge + `dim_sales_reason` (`sales_reason_type = 'Promotion'`) + `dim_product` |

## Data quality anchor

Gross sales for 2011 (`sum(gross_amount)` where `year(order_date) = 2011`) must equal **$12,646,112.16**, as verified by the accounting audit team. Validated against the raw data during profiling; it will be enforced as a dbt test on `fct_sales`.
