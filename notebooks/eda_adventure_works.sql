-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Adventure Works — Exploratory Data Analysis
-- MAGIC
-- MAGIC **Goal:** understand the Adventure Works sales data, validate its quality and surface the insights that
-- MAGIC drive the KPI selection and the commercial dashboard.
-- MAGIC
-- MAGIC | Source | Location | Used for |
-- MAGIC |---|---|---|
-- MAGIC | Raw OLTP data | `fea_academy.adventure_works` | Dataset overview and data quality |
-- MAGIC | dbt marts (star schema) | `fea_academy.adventure_works_marts` | Business analysis |
-- MAGIC
-- MAGIC **Structure:** 1. Dataset overview · 2. Data quality · 3. Revenue over time · 4. Sales channels ·
-- MAGIC 5. Products · 6. Geography · 7. Customers · 8. Sales reasons and promotions · 9. Payment ·
-- MAGIC 10. Conclusions, KPIs and recommendations
-- MAGIC
-- MAGIC > Charts are configured with the Databricks visualization editor (`+` → *Visualization* on each result).
-- MAGIC > Each chart cell describes the suggested visualization.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Dataset overview

-- COMMAND ----------

select
    count(*) as total_orders
    , count(distinct customerid) as customers_with_orders
    , min(orderdate) as first_order_date
    , max(orderdate) as last_order_date
    , sum(case when onlineorderflag then 1 else 0 end) as online_orders
from fea_academy.adventure_works.sales_salesorderheader

-- COMMAND ----------

select 'sales order lines' as entity, count(*) as row_count from fea_academy.adventure_works.sales_salesorderdetail
union all select 'customers', count(*) from fea_academy.adventure_works.sales_customer
union all select 'products', count(*) from fea_academy.adventure_works.production_product
union all select 'addresses', count(*) from fea_academy.adventure_works.person_address

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** the data covers **31,465 orders** and **121,317 order lines** from **2011-05-31 to 2014-06-30**,
-- MAGIC placed by **19,119 of the 19,820 customers**. It matches the company profile given by leadership
-- MAGIC (~31k orders, ~20k customers, 500+ products). 88% of the orders (27,659) were placed online.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Data quality
-- MAGIC
-- MAGIC ### 2.1 Audit reconciliation — gross sales 2011
-- MAGIC The CEO requires the modeled figures to match the accounting audit: **gross sales 2011 = $12,646,112.16**.

-- COMMAND ----------

select
    round(sum(detail.orderqty * detail.unitprice), 2) as gross_sales_2011_raw
from fea_academy.adventure_works.sales_salesorderdetail as detail
inner join fea_academy.adventure_works.sales_salesorderheader as header
    on detail.salesorderid = header.salesorderid
where year(header.orderdate) = 2011

-- COMMAND ----------

select round(sum(gross_amount), 2) as gross_sales_2011_marts
from fea_academy.adventure_works_marts.fct_sales
where year(order_date) = 2011

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** both the raw data and the `fct_sales` mart return **$12,646,112.16**, which defines the business rule
-- MAGIC *gross sales = order quantity × unit price* (before discounts, taxes and freight). The check is enforced as the dbt
-- MAGIC test `assert_gross_sales_2011_matches_audit`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.2 Sales reasons: many-to-many and missing for resellers

-- COMMAND ----------

select
    coalesce(reasons.reason_count, 0) as reasons_per_order
    , count(*) as orders
from fea_academy.adventure_works.sales_salesorderheader as header
left join (
    select salesorderid, count(*) as reason_count
    from fea_academy.adventure_works.sales_salesorderheadersalesreason
    group by salesorderid
) as reasons
    on header.salesorderid = reasons.salesorderid
group by 1
order by 1

-- COMMAND ----------

select
    header.onlineorderflag as is_online_order
    , count(*) as orders
    , sum(case when reasons.salesorderid is null then 1 else 0 end) as orders_without_reason
from fea_academy.adventure_works.sales_salesorderheader as header
left join (
    select distinct salesorderid
    from fea_academy.adventure_works.sales_salesorderheadersalesreason
) as reasons
    on header.salesorderid = reasons.salesorderid
group by 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - An order can have **0 to 3 sales reasons** (4,482 orders have more than one). A direct join would duplicate revenue,
-- MAGIC   so the model uses a **bridge table** (`bridge_sales_order_reason`) and a `No reason` member.
-- MAGIC - **100% of the 3,806 reseller orders have no sales reason**, as do 4,647 online orders. Any analysis by sales reason
-- MAGIC   therefore describes **only the online channel** — this caveat is shown on the dashboard.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.3 Other data quality findings

-- COMMAND ----------

select 'orders without credit card' as finding, count(*) as occurrences
from fea_academy.adventure_works.sales_salesorderheader
where creditcardid is null
union all
select 'countries with null ISO code', count(*)
from fea_academy.adventure_works.person_countryregion
where countryregioncode is null
union all
select 'orders where bill-to differs from ship-to', count(*)
from fea_academy.adventure_works.sales_salesorderheader
where billtoaddressid <> shiptoaddressid

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **1,131 orders have no credit card** → mapped to a `No credit card` member so they are not lost in filters.
-- MAGIC - **Namibia's ISO code `NA` was loaded as null** during ingestion (a classic "NA = missing value" parsing issue). It is
-- MAGIC   restored in staging and kept as a warning-level source test.
-- MAGIC - Bill-to and ship-to addresses differ in only 99 orders → the **ship-to address** defines the sale location.
-- MAGIC - All dates arrive as strings and several keys as doubles → typed in the staging layer.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.4 June 2014 is incomplete

-- COMMAND ----------

select
    date_format(sales.order_date, 'yyyy-MM') as year_month
    , customers.customer_type
    , products.category_name
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
where date_format(sales.order_date, 'yyyy-MM') in ('2014-05', '2014-06')
group by 1, 2, 3
order by 1, 2, 3

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** June 2014 has 939 orders but only **$49k of gross sales**: it contains **only online accessories and
-- MAGIC clothing — no bikes and no reseller orders**, while May 2014 had $5.4M. The extraction was likely cut mid-month.
-- MAGIC **Year-over-year comparisons must use January–May** (like-for-like), and June 2014 is flagged as incomplete.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Revenue over time

-- COMMAND ----------

-- Visualization: line chart — X: year_month, Y: gross_amount (and orders on a secondary axis)
select
    dates.year_month
    , count(distinct sales.sales_order_id) as orders
    , sum(sales.order_quantity) as units
    , round(sum(sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_date as dates
    on sales.order_date = dates.date_day
group by 1
order by 1

-- COMMAND ----------

select
    year(order_date) as order_year
    , count(distinct sales_order_id) as orders
    , round(sum(gross_amount), 0) as gross_amount
    , round(sum(net_amount), 0) as net_amount
    , round(sum(discount_amount) / sum(gross_amount) * 100, 2) as discount_pct
    , round(sum(net_amount) / count(distinct sales_order_id), 0) as avg_order_value
from fea_academy.adventure_works_marts.fct_sales
group by 1
order by 1

-- COMMAND ----------

-- Like-for-like comparison: January to May of each year
select
    year(order_date) as order_year
    , count(distinct sales_order_id) as orders
    , round(sum(gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales
where month(order_date) <= 5
    and year(order_date) >= 2012
group by 1
order by 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - Gross sales grew from $12.6M (2011, 7 months) to **$33.7M in 2012** and **$43.9M in 2013**.
-- MAGIC - The monthly series oscillates strongly because **reseller orders follow an irregular cycle**: in 2014 resellers
-- MAGIC   ordered almost only in odd months (Jan: 175, Mar: 271, May: 179 orders vs. Feb: 3 and Apr: 2), creating peaks
-- MAGIC   (Mar/2014: $7.2M) and valleys (Feb/2014: $1.3M). **Month-over-month comparisons are misleading** — the dashboard
-- MAGIC   should favor year-over-year and year-to-date views.
-- MAGIC - Orders jump from ~430/month to **~1,800/month from July 2013**, while revenue does not follow at the same pace.
-- MAGIC - The **average order value drops from $8.6k (2012) to $1.7k (2014)**: not a price problem, but a **channel mix
-- MAGIC   shift** (see section 4). AOV must always be read by channel.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Sales channels: resellers vs. online

-- COMMAND ----------

-- Visualization: bar — X: customer_type, Y: gross_share_pct and orders_share_pct
select
    customers.customer_type
    , sales.is_online_order
    , count(distinct customers.customer_id) as customers
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 1) as gross_share_pct
    , round(count(distinct sales.sales_order_id) * 100 / sum(count(distinct sales.sales_order_id)) over (), 1) as orders_share_pct
    , round(sum(sales.net_amount) / count(distinct sales.sales_order_id), 0) as avg_order_value
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
group by 1, 2

-- COMMAND ----------

-- Visualization: grouped bar — X: order_year, Y: gross_amount, group: customer_type (January to May)
select
    year(sales.order_date) as order_year
    , customers.customer_type
    , count(distinct sales.sales_order_id) as orders
    , count(distinct sales.customer_sk) as active_customers
    , round(sum(sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
where month(sales.order_date) <= 5
    and year(sales.order_date) >= 2012
group by 1, 2
order by 2, 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** Adventure Works runs two very different businesses:
-- MAGIC
-- MAGIC | | Resellers (stores) | Online (individuals) |
-- MAGIC |---|---|---|
-- MAGIC | Customers | 635 | 18,484 |
-- MAGIC | Orders | 3,806 | 27,659 |
-- MAGIC | Share of gross sales | **73.4%** | 26.6% |
-- MAGIC | Average order value | **$21,148** | $1,061 |
-- MAGIC | Growth Jan–May 2014 vs 2013 | +6.2% ($11.0M → $11.7M) | **+217% ($2.6M → $8.3M)** |
-- MAGIC
-- MAGIC - **Resellers are the revenue base**: few, large, recurring orders.
-- MAGIC - **Online is the growth engine**: active online customers went from 1,507 to 9,217 (Jan–May) and online already
-- MAGIC   represents 42% of 2014 gross sales. Both channels need their own KPIs and targets.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Products

-- COMMAND ----------

-- Visualization: bar — X: category_name, Y: gross_amount
select
    products.category_name
    , count(distinct sales.sales_order_id) as orders
    , sum(sales.order_quantity) as units
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 1) as gross_share_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
group by 1
order by 4 desc

-- COMMAND ----------

-- Business question b: products with the highest average order value (net revenue / orders), min. 30 orders
select
    products.product_name
    , products.category_name
    , count(distinct sales.sales_order_id) as orders
    , round((sum(sales.gross_amount) - sum(sales.discount_amount)) / count(distinct sales.sales_order_id), 0) as avg_order_value
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
group by 1, 2
having count(distinct sales.sales_order_id) >= 30
order by 4 desc
limit 10

-- COMMAND ----------

-- Online accessories before and after July 2013
select
    date_format(sales.order_date, 'yyyy-MM') as year_month
    , products.category_name
    , count(distinct sales.sales_order_id) as orders
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
where sales.is_online_order
    and date_format(sales.order_date, 'yyyy-MM') between '2013-04' and '2013-09'
group by 1, 2
order by 1, 2

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **Bikes generate 86.2% of gross sales** ($95.1M); Components 10.7%, Clothing 1.9%, Accessories 1.2%.
-- MAGIC - Accessories and clothing are low-value but **appear in far more orders** (Accessories: 19,524 orders, the most of any
-- MAGIC   category) — they are the entry point for online customers.
-- MAGIC - From **July 2013, online accessory orders tripled** (408 → 1,309 orders/month): this explains the jump in order
-- MAGIC   volume and the drop in average order value. There is a clear **cross-sell opportunity** (bike + accessories).
-- MAGIC - The highest average order values come from the **Mountain-100** line (~$5.4k–5.7k per order).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Geography

-- COMMAND ----------

-- Visualization: map or bar — gross_amount by country_region_name
select
    locations.country_region_name
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 1) as gross_share_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_location as locations
    on sales.ship_to_location_sk = locations.location_sk
group by 1
order by 3 desc

-- COMMAND ----------

-- Business question d: top 5 cities by total transaction value
select
    locations.city
    , locations.state_province_name
    , locations.country_region_name
    , round(sum(sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_location as locations
    on sales.ship_to_location_sk = locations.location_sk
group by 1, 2, 3
order by 4 desc
limit 5

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - The **United States represents 57.4%** of gross sales, followed by Canada (14.9%), Australia (9.7%),
-- MAGIC   United Kingdom (7.0%), France (6.6%) and Germany (4.5%).
-- MAGIC - Australia has the second-highest number of orders (6,843) but only 9.7% of revenue: it is an **online-driven market**
-- MAGIC   (85% of its revenue from individuals, only 125 reseller orders) — a candidate for reseller expansion.
-- MAGIC - The opposite happens in Canada, where **resellers generate 88% of revenue** ($14.5M) — which helps explain
-- MAGIC   why Toronto is the top city.
-- MAGIC - Top cities: **Toronto ($4.5M)**, London ($2.8M), Paris ($2.0M), Seattle ($1.6M) and Burnaby ($1.3M).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Customers

-- COMMAND ----------

-- Business question c: top 10 customers by total transaction value
select
    customers.customer_name
    , customers.customer_type
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
group by 1, 2
order by 4 desc
limit 10

-- COMMAND ----------

-- Revenue concentration and repeat purchase
with
    customer_revenue as (
        select
            customer_sk
            , count(distinct sales_order_id) as orders
            , sum(gross_amount) as gross_amount
        from fea_academy.adventure_works_marts.fct_sales
        group by customer_sk
    )

    , ranked as (
        select
            orders
            , gross_amount
            , percent_rank() over (order by gross_amount desc) as revenue_rank
        from customer_revenue
    )

select
    round(sum(case when revenue_rank < 0.01 then gross_amount end) * 100 / sum(gross_amount), 1) as top_1pct_customers_share
    , round(sum(case when revenue_rank < 0.10 then gross_amount end) * 100 / sum(gross_amount), 1) as top_10pct_customers_share
    , round(sum(case when orders > 1 then 1 else 0 end) * 100 / count(*), 1) as repeat_customers_pct
    , round(avg(orders), 2) as avg_orders_per_customer
from ranked

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - The **top 10 customers are all resellers** (≈ $730k–880k each) and together hold only 7.2% of sales —
-- MAGIC   no single account is critical.
-- MAGIC - But revenue is **highly concentrated by segment**: the **top 1% of customers generate 59.5%** of gross sales and the
-- MAGIC   **top 10% generate 81.7%**. Retaining key reseller accounts is the main revenue risk to manage.
-- MAGIC - Only **39.1% of customers bought more than once** (1.65 orders on average) — repeat purchase is a lever for the
-- MAGIC   online channel.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Sales reasons and promotions (online channel only)

-- COMMAND ----------

-- Visualization: horizontal bar — Y: sales_reason_name, X: orders (online orders only)
with
    online_sales as (
        select
            sales_order_id
            , order_quantity
            , gross_amount
        from fea_academy.adventure_works_marts.fct_sales
        where is_online_order
    )

select
    reasons.sales_reason_name
    , reasons.sales_reason_type
    , count(distinct online_sales.sales_order_id) as orders
    , sum(online_sales.order_quantity) as units
    , round(sum(online_sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.dim_sales_reason as reasons
left join fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
    on reasons.sales_reason_sk = bridge.sales_reason_sk
left join online_sales
    on bridge.sales_order_id = online_sales.sales_order_id
group by 1, 2
order by 3 desc

-- COMMAND ----------

-- Business question f: product with the most units purchased for the Promotion reason
select
    products.product_name
    , sum(sales.order_quantity) as units
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
    on sales.sales_order_id = bridge.sales_order_id
inner join fea_academy.adventure_works_marts.dim_sales_reason as reasons
    on bridge.sales_reason_sk = reasons.sales_reason_sk
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
where reasons.sales_reason_type = 'Promotion'
group by 1
order by 2 desc
limit 5

-- COMMAND ----------

-- Do orders declared as "On Promotion" actually receive a discount?
with
    promotion_orders as (
        select distinct bridge.sales_order_id
        from fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
        inner join fea_academy.adventure_works_marts.dim_sales_reason as reasons
            on bridge.sales_reason_sk = reasons.sales_reason_sk
        where reasons.sales_reason_name = 'On Promotion'
    )

select
    case when promotion_orders.sales_order_id is not null then 'On Promotion' else 'Other orders' end as order_group
    , round(sum(case when sales.unit_price_discount_pct > 0 then 1 else 0 end) * 100 / count(*), 1) as discounted_lines_pct
    , round(sum(sales.discount_amount) * 100 / sum(sales.gross_amount), 2) as discount_pct_of_gross
from fea_academy.adventure_works_marts.fct_sales as sales
left join promotion_orders
    on sales.sales_order_id = promotion_orders.sales_order_id
group by 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **Price** is the most declared reason (17,473 online orders), followed by **On Promotion** (3,515 orders, $6.4M).
-- MAGIC   4,647 online orders (17%) have no reason at all.
-- MAGIC - Answer to question f: **Water Bottle - 30 oz.** is the product with the most units bought for the Promotion
-- MAGIC   reason (546 units), followed by Road Bottle Cage (416) and AWC Logo Cap (301).
-- MAGIC - **Orders declared as "On Promotion" received 0% discount.** Discounts exist only in 2.7% of all order lines
-- MAGIC   (0.48% of gross sales). The promotion the customer mentions is **not linked to any recorded price benefit**, so
-- MAGIC   today the company **cannot measure promotion ROI** — a key argument for the Commercial Director, who wants to invest
-- MAGIC   in promotions.
-- MAGIC - Marketing reasons: **Magazine Advertisement, Demo Event and Sponsorship have zero orders**, and Television
-- MAGIC   Advertisement brought 722 orders but only $27k. Marketing spend should be reviewed against these results.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 9. Payment

-- COMMAND ----------

select
    cards.card_type
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 1) as gross_share_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_credit_card as cards
    on sales.credit_card_sk = cards.credit_card_sk
group by 1
order by 3 desc

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** orders are evenly split across the four card brands (~7,400–7,700 orders each); ColonialVoice leads in
-- MAGIC revenue (29.6%). Only 1.2% of revenue comes from orders without a card. Card type is a **filter**, not a headline KPI.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Conclusions
-- MAGIC
-- MAGIC ### What the EDA taught us about the dataset
-- MAGIC 1. The data is **reliable for the audited figures** (2011 gross sales reconcile to the cent) but needs modeling care:
-- MAGIC    many-to-many sales reasons, missing cards and reasons, string-typed dates and one ingestion bug (Namibia).
-- MAGIC 2. **June 2014 is incomplete** → time comparisons use January–May (like-for-like).
-- MAGIC 3. **Channel mix drives every aggregate**: resellers (73% of revenue, $21k tickets) and online (88% of orders,
-- MAGIC    $1k tickets). Averages without a channel split are misleading.
-- MAGIC 4. **Sales reasons exist only for online orders**.
-- MAGIC
-- MAGIC ### Proposed KPIs
-- MAGIC
-- MAGIC | KPI | Definition | Why it matters |
-- MAGIC |---|---|---|
-- MAGIC | Gross sales | Σ quantity × unit price | Headline metric, reconciled with the audit |
-- MAGIC | Gross sales growth (YoY, like-for-like) | Jan–May vs. same period last year | Monthly series is too volatile for MoM |
-- MAGIC | Orders | Distinct sales orders | Commercial activity volume |
-- MAGIC | Units sold | Σ order quantity | Operational volume, promotion analysis (question f) |
-- MAGIC | Average order value | Net sales ÷ orders, **by channel** | Tracks ticket size without the mix distortion |
-- MAGIC | Channel share | % of gross sales from resellers vs. online | Monitors the shift towards online |
-- MAGIC | Active customers | Customers with ≥ 1 order in the period | Growth of the customer base |
-- MAGIC | Repeat customer rate | % of customers with > 1 order | Loyalty lever for online |
-- MAGIC | Top 10% customer share | % of gross sales from the top 10% customers | Concentration risk |
-- MAGIC | Promotion-driven sales | Gross sales of orders with the Promotion reason | Only available measure of promotion impact |
-- MAGIC
-- MAGIC ### Recommendations for the commercial team
-- MAGIC 1. **Protect the reseller base** — a key account program for the top reseller accounts (top 10% = 81.7% of sales).
-- MAGIC 2. **Invest in online growth** (+217% like-for-like) with **bike + accessories cross-sell**, and track repeat purchase.
-- MAGIC 3. **Make promotions measurable** — link every promotion to a special offer / discount code, so the ROI of promotional
-- MAGIC    spend can be compared with other investments (today: 0% discount on "promotion" orders).
-- MAGIC 4. **Review marketing channels** with zero attributed orders (Magazine, Demo Event, Sponsorship).
-- MAGIC 5. **Capture sales reasons for reseller orders** (100% missing) to understand 73% of the revenue.
-- MAGIC 6. **Fix the data extraction for June 2014** before using it in reports.
