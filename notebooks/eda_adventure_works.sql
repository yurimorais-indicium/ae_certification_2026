-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Adventure Works — Exploratory Data Analysis
-- MAGIC
-- MAGIC **Goal:** understand the Adventure Works sales data, validate its quality and surface the insights that
-- MAGIC drive the KPI selection and the commercial dashboard.
-- MAGIC
-- MAGIC | Source | Location | Used for |
-- MAGIC |---|---|---|
-- MAGIC | Raw OLTP data | `fea_academy.adventure_works` | Dataset overview, data quality and the special-offer check in section 8 |
-- MAGIC | dbt marts (star schema) | `fea_academy.adventure_works_marts` | Business analysis |
-- MAGIC
-- MAGIC **Structure:** 1. Dataset overview · 2. Data quality · 3. Revenue over time · 4. Sales channels ·
-- MAGIC 5. Products · 6. Geography · 7. Customers · 8. Sales reasons and promotions · 9. Payment ·
-- MAGIC 10. Conclusions, KPIs and recommendations
-- MAGIC
-- MAGIC **Two reading conventions**, both established in section 2.4, apply to every monthly series and year-over-year
-- MAGIC comparison in this notebook: a reseller order is dated by the month its batch closes, and year-over-year comparisons
-- MAGIC use January–April. Calendar-year figures keep the order date, the basis of the audited figures.
-- MAGIC

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
-- MAGIC **Insight:** the data covers **31,465 orders** and **121,317 order lines** from **2011-05-31 to 2014-06-30**.
-- MAGIC The 19,820 customer records describe **19,185 customers** (18,484 individuals and 701 stores), because 635 stores
-- MAGIC appear twice (section 2.3), and **19,119** of them placed an order: every individual and 635 of the stores. It matches
-- MAGIC the company profile given by leadership (~31k orders, ~20k customers, 500+ products). 88% of the orders (27,659) were
-- MAGIC placed online.

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
select concat('countries with null ISO code: ', concat_ws(', ', collect_list(name))), count(*)
from fea_academy.adventure_works.person_countryregion
where countryregioncode is null
union all
select 'orders where bill-to differs from ship-to', count(*)
from fea_academy.adventure_works.sales_salesorderheader
where billtoaddressid <> shiptoaddressid
union all
select 'stores in the customer table', count(distinct storeid)
from fea_academy.adventure_works.sales_customer
union all
select 'stores with two customer records', count(*)
from (
    select storeid
    from fea_academy.adventure_works.sales_customer
    where storeid is not null
    group by storeid
    having count(*) = 2
) as store_twins
union all
select 'store customer records that never placed an order', count(*)
from fea_academy.adventure_works.sales_customer as customers
where customers.storeid is not null
    and not exists (
        select 1
        from fea_academy.adventure_works.sales_salesorderheader as header
        where header.customerid = customers.customerid
    )
union all
select 'individual customer records that never placed an order', count(*)
from fea_academy.adventure_works.sales_customer as customers
where customers.storeid is null
    and not exists (
        select 1
        from fea_academy.adventure_works.sales_salesorderheader as header
        where header.customerid = customers.customerid
    )
union all
select 'orders with a status other than Shipped', count(*)
from fea_academy.adventure_works.sales_salesorderheader
where status <> 5
union all
select 'raw columns named like a date', count(*)
from fea_academy.information_schema.columns
where table_schema = 'adventure_works'
    and lower(column_name) like '%date%'
union all
select 'raw date columns typed as string', count(*)
from fea_academy.information_schema.columns
where table_schema = 'adventure_works'
    and lower(column_name) like '%date%'
    and data_type = 'STRING'
union all
select 'raw key columns (ending in id) typed as double', count(*)
from fea_academy.information_schema.columns
where table_schema = 'adventure_works'
    and lower(column_name) like '%id'
    and data_type = 'DOUBLE'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **1,131 orders have no credit card** → mapped to a `No credit card` member so they are not lost in filters.
-- MAGIC - **Namibia's ISO code `NA` was loaded as null** during ingestion (a classic "NA = missing value" parsing issue). It is
-- MAGIC   restored in staging and kept as a warning-level source test.
-- MAGIC - Bill-to and ship-to addresses differ in only 99 orders → the **ship-to address** defines the sale location.
-- MAGIC - **635 of the 701 stores appear twice** in the customer table, once as the store and once as the store's contact
-- MAGIC   person, and each of them orders through one record only. The 701 records that never ordered are all store records:
-- MAGIC   the 635 empty twins and the 66 stores that never bought. Every individual record has orders. The dbt test
-- MAGIC   `assert_store_twin_rows_never_both_sell` fails if a store ever orders through both records.
-- MAGIC - **All 31,465 orders have the status Shipped**, so status separates nothing today: question a's breakdown by status
-- MAGIC   returns a single row.
-- MAGIC - Dates arrive as strings (105 of the 107 date columns) and 11 key columns as doubles → typed in the staging layer.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.4 Reseller orders arrive as one batch per month, and each channel stops on a different date

-- COMMAND ----------

-- Reseller orders arrive as one batch per month: each booking date, assigned to the month it closes (one day back)
with
    reseller_dates as (
        select
            order_date
            , count(distinct sales_order_id) as orders
            , sum(gross_amount) as gross_amount
        from fea_academy.adventure_works_marts.fct_sales
        where not is_online_order
        group by order_date
    )

select
    date_format(date_sub(order_date, 1), 'yyyy-MM') as closing_month
    , count(*) as booking_dates
    , concat_ws(', ', sort_array(collect_list(cast(order_date as string)))) as booked_on
    , sum(orders) as reseller_orders
    , round(sum(gross_amount), 0) as gross_amount
from reseller_dates
group by 1
order by 1

-- COMMAND ----------

-- Where each part of the series starts and stops, by channel and category
select
    case when sales.is_online_order then 'Online' else 'Reseller' end as channel
    , products.category_name
    , min(sales.order_date) as first_order_date
    , max(sales.order_date) as last_order_date
    , count(distinct sales.sales_order_id) as orders
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
group by 1, 2
order by 1, 2

-- COMMAND ----------

-- Active trading days per month at both ends of the series
select
    date_format(order_date, 'yyyy-MM') as year_month
    , count(distinct order_date) as active_days
    , count(distinct sales_order_id) as orders
    , round(sum(gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.fct_sales
where date_format(order_date, 'yyyy-MM') in ('2011-05', '2011-06', '2014-05', '2014-06')
group by 1
order by 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:** the series has three timing quirks. None of them is a business event; all three come from how the data
-- MAGIC was booked and extracted.
-- MAGIC
-- MAGIC - **Reseller orders arrive as one batch per month**: 36 batches for the 36 months from May 2011 to April 2014, none
-- MAGIC   missing. A batch is booked in the last days of its month or on the 1st of the next, and in 2014 every batch is split
-- MAGIC   across two consecutive days. Counted by calendar month, a batch booked on the 1st lands in the wrong month:
-- MAGIC   **June, September and November 2011 show no reseller orders at all** (their batches are dated 1 July, 1 October and
-- MAGIC   1 December), while August and October 2011 and January 2012 show two batches each. This alone creates the sawtooth
-- MAGIC   of the calendar monthly series. **From here on, monthly series and year-over-year comparisons date a reseller order
-- MAGIC   by the month its batch closes** (order date minus one day); online orders keep their own date, and calendar-year
-- MAGIC   figures keep the order date, the audited basis.
-- MAGIC - **Each channel stops on a different date.** The last reseller batch closes April 2014 (booked on 30 April and 1 May):
-- MAGIC   there is no May or June 2014 batch. Online bikes stop on 30 May 2014. Online accessories and clothing, which only went
-- MAGIC   on sale online on **30 May 2013**, continue until 30 June 2014. **April 2014 is the last month in which every channel
-- MAGIC   and category is complete**; June 2014's $49k ($52 per order) is the tail of online accessories and clothing, not a
-- MAGIC   collapse in demand.
-- MAGIC - **The series opens on 31 May 2011**, a single day that carries the May reseller batch (38 orders, $489k) and 5 online
-- MAGIC   orders.
-- MAGIC
-- MAGIC **Consequence:** year-over-year comparisons use **January–April by closing month**, the longest window in which every
-- MAGIC year holds exactly four reseller batches and every channel is complete. A calendar January–May window would compare six
-- MAGIC reseller batches in 2012 with five in 2013 and four in 2014.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Revenue over time

-- COMMAND ----------

-- Business question e, by month: orders, units and gross sales as a time series
-- Visualization 1a: line - X: year_month, Y: gross_amount
-- Visualization 1b: line - X: year_month, Y: orders_index and gross_index on one axis (2012 monthly average = 100)
-- Reseller orders are assigned to the month their batch closes (section 2.4); online orders keep their own date
with
    monthly as (
        select
            date_format(
                case when is_online_order then order_date else date_sub(order_date, 1) end
                , 'yyyy-MM'
            ) as year_month
            , count(distinct sales_order_id) as orders
            , sum(order_quantity) as units
            , sum(gross_amount) as gross_amount
        from fea_academy.adventure_works_marts.fct_sales
        group by 1
    )

-- only the 35 months in which both channels are complete (section 2.4)
select
    year_month
    , orders
    , units
    , round(gross_amount, 0) as gross_amount
    , round(orders * 100 / avg(case when year_month like '2012-%' then orders end) over (), 0) as orders_index
    , round(gross_amount * 100 / avg(case when year_month like '2012-%' then gross_amount end) over (), 0) as gross_index
from monthly
where year_month between '2011-06' and '2014-04'
order by 1

-- COMMAND ----------

-- Business question e, by year: calendar years by order date, the basis of the audited figures
-- (2011 holds 7 months and 7 reseller batches; 2012 holds 13, because December 2011's batch was booked on
-- 1 January 2012; 2014 holds resellers to April)
select
    year(order_date) as order_year
    , count(distinct sales_order_id) as orders
    , sum(order_quantity) as units
    , round(sum(gross_amount), 0) as gross_amount
    , round(sum(net_amount), 0) as net_amount
    , round(sum(discount_amount) / sum(gross_amount) * 100, 2) as discount_pct
    , round(sum(net_amount) / count(distinct sales_order_id), 0) as avg_order_value
from fea_academy.adventure_works_marts.fct_sales
group by 1
order by 1

-- COMMAND ----------

-- Like-for-like comparison: January to April by closing month, the longest window that is complete in every year
-- (four reseller batches per year; the May 2014 batch is not in the data)
with
    sales_by_closing_month as (
        select
            sales_order_id
            , gross_amount
            , case when is_online_order then order_date else date_sub(order_date, 1) end as sales_date
        from fea_academy.adventure_works_marts.fct_sales
    )

select
    year(sales_date) as order_year
    , count(distinct sales_order_id) as orders
    , round(sum(gross_amount), 0) as gross_amount
    , round(sum(gross_amount) * 100 / lag(sum(gross_amount)) over (order by year(sales_date)) - 100, 1) as growth_pct
from sales_by_closing_month
where month(sales_date) <= 4
    and year(sales_date) >= 2012
group by 1
order by 1

-- COMMAND ----------

-- Why the average order value falls: order value by channel and year, and what an online bike sells for
with
    orders as (
        select
            sales.sales_order_id
            , year(min(sales.order_date)) as order_year
            , max(customers.customer_type) as customer_type
            , max(case when products.category_name = 'Bikes' then 1 else 0 end) as has_bike
            , sum(sales.net_amount) as net_amount
            , sum(case when products.category_name = 'Bikes' then sales.gross_amount end) as bike_gross
            , sum(case when products.category_name = 'Bikes' then sales.order_quantity end) as bike_units
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_customer as customers
            on sales.customer_sk = customers.customer_sk
        inner join fea_academy.adventure_works_marts.dim_product as products
            on sales.product_sk = products.product_sk
        group by sales.sales_order_id
    )

select
    customer_type
    , order_year
    , count(*) as orders
    , round(avg(net_amount), 0) as avg_order_value
    , round(100 - avg(has_bike) * 100, 1) as orders_without_bike_pct
    , round(avg(case when has_bike = 0 then net_amount end), 0) as avg_value_without_bike
    , round(sum(bike_gross) / sum(bike_units), 0) as gross_per_bike_unit
from orders
group by 1, 2
order by 1, 2

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - Gross sales grew from $12.6M (2011, 7 months) to **$33.7M in 2012** and **$43.9M in 2013**, in calendar years, the
-- MAGIC   basis of the audited figures (calendar 2012 holds 13 reseller batches). Like-for-like, January–April by closing month
-- MAGIC   grew **+24.9% in 2013** and **+74.7% in 2014** ($8.3M → $10.4M → $18.1M).
-- MAGIC - Dated by closing month, every month holds exactly one reseller batch (section 2.4): the calendar sawtooth, months with
-- MAGIC   no batch next to months with two, disappears, and what remains is the real variation in batch size. **Month-over-month
-- MAGIC   comparisons on calendar months are misleading**; the dashboard should date reseller orders the same way and favor
-- MAGIC   year-over-year views.
-- MAGIC - From July 2013, **orders run at 5.4 to 7.2 times their 2012 level** (orders index 544–722) while **gross sales run at
-- MAGIC   1.3 to 2.0 times** (gross index 125–197). The break is the online catalog launch of 30 May 2013 (section 5): it added
-- MAGIC   accessory and clothing orders worth about $51 each.
-- MAGIC - The **average order value falls from $8.6k in 2012 to $3.1k in 2013** in calendar years (2014's $1.7k mixes resellers
-- MAGIC   to April with online orders to June), and the table by channel shows why: resellers keep ordering around $20k per
-- MAGIC   order, while online falls from $2,330 to $853, because half of online orders (50.2%) now hold no bike and gross sales
-- MAGIC   per online bike unit fell by 30% ($2,330 → $1,629). **AOV must always be read by channel.**

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

-- Visualization: grouped bar - X: order_year, Y: gross_amount, group: customer_type (January to April by closing month)
with
    sales_by_closing_month as (
        select
            sales_order_id
            , customer_sk
            , gross_amount
            , case when is_online_order then order_date else date_sub(order_date, 1) end as sales_date
        from fea_academy.adventure_works_marts.fct_sales
    )

select
    year(sales.sales_date) as order_year
    , customers.customer_type
    , count(distinct sales.sales_order_id) as orders
    , count(distinct sales.customer_sk) as active_customers
    , round(sum(sales.gross_amount), 0) as gross_amount
from sales_by_closing_month as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
where month(sales.sales_date) <= 4
    and year(sales.sales_date) >= 2012
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
-- MAGIC | Growth January–April 2014 vs. 2013, by closing month | +41.1% ($8.3M → $11.7M) | **+210.7% ($2.1M → $6.4M)** |
-- MAGIC
-- MAGIC - **Resellers are the revenue base**: few, large, recurring orders, and still growing (+41.1% like-for-like; active
-- MAGIC   resellers went from 326 to 456).
-- MAGIC - **Online is the growth engine**: active online customers went from 1,178 to 7,323 (January–April) and online reached
-- MAGIC   35% of January–April 2014 gross sales, up from 20% a year earlier. Both channels need their own KPIs and targets.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Products

-- COMMAND ----------

-- Visualization: bar — X: category_name, Y: gross_amount
-- Second visualization: bar — X: category_name, Y: orders (the claim about order counts needs its own chart)
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
    , max(sales.order_date) as last_order_date
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
group by 1, 2
having count(distinct sales.sales_order_id) >= 30
order by 4 desc
limit 10

-- COMMAND ----------

-- Business question b, by year and by country: the product with the highest average order value in each slice
-- (same formula, (gross revenue - discounts) / orders, and at least 30 orders in the slice)
with
    product_slices as (
        select
            'Year' as slice_type
            , cast(year(sales.order_date) as string) as slice
            , products.product_name
            , count(distinct sales.sales_order_id) as orders
            , sum(sales.gross_amount) - sum(sales.discount_amount) as net_amount
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_product as products
            on sales.product_sk = products.product_sk
        group by 1, 2, 3
        union all
        select
            'Country'
            , locations.country_region_name
            , products.product_name
            , count(distinct sales.sales_order_id)
            , sum(sales.gross_amount) - sum(sales.discount_amount)
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_product as products
            on sales.product_sk = products.product_sk
        inner join fea_academy.adventure_works_marts.dim_location as locations
            on sales.ship_to_location_sk = locations.location_sk
        group by 1, 2, 3
    )

    , ranked as (
        select
            slice_type
            , slice
            , product_name
            , orders
            , round(net_amount / orders, 0) as avg_order_value
            , row_number() over (partition by slice_type, slice order by net_amount / orders desc) as position
        from product_slices
        where orders >= 30
    )

select
    slice_type
    , slice
    , product_name
    , orders
    , avg_order_value
from ranked
where position = 1
order by 1 desc, 2

-- COMMAND ----------

-- Online orders by category around the online catalog launch (30 May 2013)
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

-- Online baskets since accessories and clothing went on sale online (30 May 2013)
with
    online_orders as (
        select
            sales.sales_order_id
            , sales.customer_sk
            , min(sales.order_date) as order_date
            , max(case when products.category_name = 'Bikes' then 1 else 0 end) as has_bike
            , max(case when products.category_name in ('Accessories', 'Clothing') then 1 else 0 end) as has_add_on
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_product as products
            on sales.product_sk = products.product_sk
        where sales.is_online_order
        group by sales.sales_order_id, sales.customer_sk
    )

    , first_orders as (
        select
            customer_sk
            , order_date as first_order_date
            , has_bike as first_order_has_bike
        from (
            select
                customer_sk
                , order_date
                , has_bike
                , row_number() over (partition by customer_sk order by order_date, sales_order_id) as position
            from online_orders
        ) as ordered
        where position = 1
    )

    , accessory_first_customers as (
        select
            first_orders.customer_sk
            , max(case when later.order_date > first_orders.first_order_date then later.has_bike else 0 end) as later_bought_bike
        from first_orders
        inner join online_orders as later
            on first_orders.customer_sk = later.customer_sk
        where first_orders.first_order_has_bike = 0
        group by first_orders.customer_sk
    )

select 'bike orders since 2013-05-30' as metric, count(*) as value
from online_orders
where has_bike = 1
    and order_date >= '2013-05-30'
union all
select 'bike orders since 2013-05-30 with an accessory or clothing item', count(*)
from online_orders
where has_bike = 1
    and has_add_on = 1
    and order_date >= '2013-05-30'
union all
select 'customers whose first online order had no bike', count(*)
from accessory_first_customers
union all
select 'of whom bought a bike in a later order', sum(later_bought_bike)
from accessory_first_customers

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **Bikes generate 86.2% of gross sales** ($95.1M); Components 10.7%, Clothing 1.9%, Accessories 1.2%. Components are
-- MAGIC   sold to resellers only.
-- MAGIC - Accessories and clothing are low-value but **appear in many orders**: Accessories reach 19,524 orders, the most of any
-- MAGIC   category and slightly more than bikes (18,368); Clothing appears in 9,877.
-- MAGIC - **Accessories and clothing only went on sale online on 30 May 2013.** Until then every online order contained a bike;
-- MAGIC   by July 2013, 1,309 online orders a month included an accessory. This launch drives most of the jump in order volume
-- MAGIC   seen in section 3 (online bike orders also rose, from 333 in May to 608 in August 2013, while accessory orders went
-- MAGIC   from 22 to 1,400) and, together with the lower value of each online bike unit, the fall in average order value.
-- MAGIC - **Cross-selling onto bike orders already works**: 88% of the online bike orders placed since the launch include an
-- MAGIC   accessory or clothing item. The opposite path does not exist yet: **none of the 9,352 customers whose first online
-- MAGIC   order had no bike went on to buy one**. Turning accessory buyers into bike buyers is the open opportunity.
-- MAGIC - Answer to question b: the highest average order values come from the **Mountain-100** line, $5.0k–5.7k per order
-- MAGIC   across its eight variants (each of the top 10 has more than 200 orders, far above the 30-order minimum). But the line
-- MAGIC   was last sold in May 2012, and the leader changes with the slice: Touring-1000 leads 2013, 2014 and three of the six
-- MAGIC   countries, Road-150 leads Australia. This notebook answers question b overall, by year and by country; the month,
-- MAGIC   state and city slices are left to the dashboard filters.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Geography

-- COMMAND ----------

-- Visualization: horizontal bar — Y: country_region_name, X: gross_amount (largest at the top)
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

-- Visualization: horizontal stacked bar - Y: country_region_name, X: gross_amount, group: customer_type
select
    locations.country_region_name
    , customers.customer_type
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100
        / sum(sum(sales.gross_amount)) over (partition by locations.country_region_name), 1) as share_of_country_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_location as locations
    on sales.ship_to_location_sk = locations.location_sk
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
group by 1, 2
order by 1, 2

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - The **United States represents 57.4%** of gross sales, followed by Canada (14.9%), Australia (9.7%),
-- MAGIC   United Kingdom (7.0%), France (6.6%) and Germany (4.5%).
-- MAGIC - Australia has the second-highest number of orders (6,843) but only 9.7% of revenue: it is an **online-driven market**
-- MAGIC   (85% of its revenue from individuals, only 125 reseller orders), a candidate for reseller expansion.
-- MAGIC - The opposite happens in Canada, where **resellers generate 88% of revenue** ($14.5M), which helps explain why
-- MAGIC   Toronto is the top city.
-- MAGIC - Answer to question d: **Toronto ($4.5M)**, London ($2.8M), Paris ($2.0M), Seattle ($1.6M) and Burnaby ($1.3M).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Customers

-- COMMAND ----------

-- Visualization: horizontal bar — Y: customer_name, X: gross_amount (largest at the top)
-- Business question c: top 10 customers by total transaction value
-- Grouped by customer key, not by name: two different stores are both called "Friendly Bike Shop"
select
    customers.customer_name
    , customers.customer_type
    , count(distinct sales.sales_order_id) as orders
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 2) as share_pct
    , round(sum(sum(sales.gross_amount)) over (
            order by sum(sales.gross_amount) desc rows between unbounded preceding and current row
        ) * 100 / sum(sum(sales.gross_amount)) over (), 1) as cumulative_share_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
group by customers.customer_sk, customers.customer_name, customers.customer_type
order by 4 desc
limit 10

-- COMMAND ----------

-- Revenue concentration and repeat purchase, overall and by channel
with
    customer_revenue as (
        select
            sales.customer_sk
            , customers.customer_type
            , count(distinct sales.sales_order_id) as orders
            , sum(sales.gross_amount) as gross_amount
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_customer as customers
            on sales.customer_sk = customers.customer_sk
        group by 1, 2
    )

    , ranked as (
        select
            customer_type
            , orders
            , gross_amount
            , percent_rank() over (order by gross_amount desc) as revenue_rank
        from customer_revenue
    )

select
    coalesce(customer_type, 'All customers') as customer_type
    , count(*) as customers
    , round(sum(gross_amount) * 100 / (select sum(gross_amount) from customer_revenue), 1) as gross_share_pct
    , sum(case when revenue_rank < 0.01 then 1 else 0 end) as customers_in_top_1pct
    , round(sum(case when revenue_rank < 0.01 then gross_amount else 0 end) * 100
        / (select sum(gross_amount) from customer_revenue), 1) as top_1pct_gross_share_pct
    , sum(case when revenue_rank < 0.10 then 1 else 0 end) as customers_in_top_10pct
    , round(sum(case when revenue_rank < 0.10 then gross_amount else 0 end) * 100
        / (select sum(gross_amount) from customer_revenue), 1) as top_10pct_gross_share_pct
    , round(avg(case when orders > 1 then 100.0 else 0 end), 1) as repeat_customers_pct
    , round(avg(orders), 2) as avg_orders_per_customer
from ranked
group by rollup(customer_type)
order by 2 desc

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - Answer to question c: the **top 10 customers are all resellers** ($732k–$882k each). The largest holds 0.8% of gross
-- MAGIC   sales and the ten together 7.2%: **no single account is critical**.
-- MAGIC - Concentration is a **channel effect**, not an account effect: the top 1% of buyers (192) generate 59.5% of gross sales
-- MAGIC   and every one of them is a reseller; the top 10% (1,914 buyers: 495 resellers and 1,419 individuals) generate 81.7%.
-- MAGIC   The revenue risk to manage is the reseller channel as a whole, not one account.
-- MAGIC - Repeat purchase splits by channel too: **95.3% of resellers ordered more than once** (6.0 orders each) against
-- MAGIC   **37.1% of online customers** (1.5 orders). The 39.1% overall rate describes neither channel, so repeat purchase must
-- MAGIC   be tracked per channel; for online it is the loyalty lever.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Sales reasons and promotions (online channel only)

-- COMMAND ----------

-- Visualization: horizontal bar - Y: sales_reason_name, X: orders, group: reason_kind, stacked (online orders only)
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
    , case when reasons.sales_reason_name = 'No reason' then 'No reason recorded' else 'Declared reason' end as reason_kind
    , count(distinct online_sales.sales_order_id) as orders
    , sum(online_sales.order_quantity) as units
    , round(sum(online_sales.gross_amount), 0) as gross_amount
from fea_academy.adventure_works_marts.dim_sales_reason as reasons
left join fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
    on reasons.sales_reason_sk = bridge.sales_reason_sk
left join online_sales
    on bridge.sales_order_id = online_sales.sales_order_id
group by 1, 2, 3
order by 4 desc

-- COMMAND ----------

-- The list of reasons offered to online customers changed over time: orders citing each reason, by year
select
    reasons.sales_reason_name
    , count(distinct case when year(sales.order_date) = 2011 then sales.sales_order_id end) as orders_2011
    , count(distinct case when year(sales.order_date) = 2012 then sales.sales_order_id end) as orders_2012
    , count(distinct case when year(sales.order_date) = 2013 then sales.sales_order_id end) as orders_2013
    , count(distinct case when year(sales.order_date) = 2014 then sales.sales_order_id end) as orders_2014
    , min(sales.order_date) as first_cited
    , max(sales.order_date) as last_cited
from fea_academy.adventure_works_marts.fct_sales as sales
inner join fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
    on sales.sales_order_id = bridge.sales_order_id
inner join fea_academy.adventure_works_marts.dim_sales_reason as reasons
    on bridge.sales_reason_sk = reasons.sales_reason_sk
where sales.is_online_order
group by 1
order by 6, 1

-- COMMAND ----------

-- Business question f: product with the most units purchased for the Promotion reason
-- The data has a single reason of type Promotion, named On Promotion
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

-- What the orders citing "On Promotion" contain, by product category
with
    promotion_orders as (
        select distinct bridge.sales_order_id
        from fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
        inner join fea_academy.adventure_works_marts.dim_sales_reason as reasons
            on bridge.sales_reason_sk = reasons.sales_reason_sk
        where reasons.sales_reason_type = 'Promotion'
    )

select
    products.category_name
    , sum(sales.order_quantity) as units
    , round(sum(sales.gross_amount), 0) as gross_amount
    , round(sum(sales.gross_amount) * 100 / sum(sum(sales.gross_amount)) over (), 1) as gross_share_pct
from fea_academy.adventure_works_marts.fct_sales as sales
inner join promotion_orders
    on sales.sales_order_id = promotion_orders.sales_order_id
inner join fea_academy.adventure_works_marts.dim_product as products
    on sales.product_sk = products.product_sk
group by 1
order by 3 desc

-- COMMAND ----------

-- Do orders citing "On Promotion" get a price benefit? Discounted lines and special offers, by channel
with
    promotion_orders as (
        select distinct header_reason.salesorderid
        from fea_academy.adventure_works.sales_salesorderheadersalesreason as header_reason
        inner join fea_academy.adventure_works.sales_salesreason as reasons
            on header_reason.salesreasonid = reasons.salesreasonid
        where reasons.name = 'On Promotion'
    )

    , order_lines as (
        select
            detail.salesorderid
            , case when header.onlineorderflag then 'Online' else 'Reseller' end as channel
            , case when promotion_orders.salesorderid is not null then 'On Promotion' else 'Other orders' end as order_group
            , detail.specialofferid
            , detail.unitpricediscount
            , detail.orderqty * detail.unitprice as gross_amount
            , detail.orderqty * detail.unitprice * detail.unitpricediscount as discount_amount
        from fea_academy.adventure_works.sales_salesorderdetail as detail
        inner join fea_academy.adventure_works.sales_salesorderheader as header
            on detail.salesorderid = header.salesorderid
        left join promotion_orders
            on detail.salesorderid = promotion_orders.salesorderid
    )

select
    channel
    , order_group
    , count(distinct salesorderid) as orders
    , sum(case when unitpricediscount > 0 then 1 else 0 end) as discounted_lines
    , round(sum(case when unitpricediscount > 0 then 1 else 0 end) * 100 / count(*), 2) as discounted_lines_pct
    , round(sum(discount_amount) * 100 / sum(gross_amount), 2) as discount_pct_of_gross
    , count(distinct case when specialofferid <> 1 then salesorderid end) as orders_with_special_offer
from order_lines
group by 1, 2
order by 1, 2

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 8.1 Does the promotion itself lift the order, or is it product mix and timing?

-- COMMAND ----------

-- Visualization: grouped bar - X: comparison, Y: avg_order_value, group: order_group
-- Four ways to measure what a promotion adds to an online order, from the naive one to the one that holds product and timing constant
with
    promotion_orders as (
        select distinct bridge.sales_order_id
        from fea_academy.adventure_works_marts.bridge_sales_order_reason as bridge
        inner join fea_academy.adventure_works_marts.dim_sales_reason as reasons
            on bridge.sales_reason_sk = reasons.sales_reason_sk
        where reasons.sales_reason_name = 'On Promotion'
    )

    , online_orders as (
        select
            sales.sales_order_id
            , min(sales.order_date) as order_date
            , date_format(min(sales.order_date), 'yyyy-MM') as year_month
            , max(case when promotion_orders.sales_order_id is not null then 1 else 0 end) as is_promotion
            , max(case when products.category_name = 'Bikes' then 1 else 0 end) as has_bike
            , count(distinct case when products.category_name = 'Bikes' then products.product_sk end) as bike_products
            , max(case when products.category_name = 'Bikes' then products.product_sk end) as bike_product_sk
            , sum(sales.net_amount) as net_amount
        from fea_academy.adventure_works_marts.fct_sales as sales
        inner join fea_academy.adventure_works_marts.dim_product as products
            on sales.product_sk = products.product_sk
        left join promotion_orders
            on sales.sales_order_id = promotion_orders.sales_order_id
        where sales.is_online_order
        group by sales.sales_order_id
    )

    -- the reason is only recorded between these two dates
    , promotion_window as (
        select
            min(order_date) as first_day
            , max(order_date) as last_day
        from online_orders
        where is_promotion = 1
    )

    -- what a non-promotion order for the same single bike was worth in the same month
    , benchmark as (
        select
            bike_product_sk
            , year_month
            , avg(net_amount) as expected_value
        from online_orders
        where is_promotion = 0
            and bike_products = 1
        group by 1, 2
    )

    , matched as (
        select
            online_orders.net_amount
            , benchmark.expected_value
        from online_orders
        inner join benchmark
            on online_orders.bike_product_sk = benchmark.bike_product_sk
            and online_orders.year_month = benchmark.year_month
        where online_orders.is_promotion = 1
            and online_orders.bike_products = 1
    )

    , comparisons as (
        select '1. All online orders' as comparison, is_promotion, net_amount
        from online_orders
        union all
        select '2. Bike orders, whole period', is_promotion, net_amount
        from online_orders
        where has_bike = 1
        union all
        select '3. Bike orders, same period', is_promotion, net_amount
        from online_orders
        cross join promotion_window
        where online_orders.has_bike = 1
            and online_orders.order_date between promotion_window.first_day and promotion_window.last_day
        union all
        select '4. Same bike, same month', 1, net_amount
        from matched
        union all
        select '4. Same bike, same month', 0, expected_value
        from matched
    )

    , summary as (
        select
            comparison
            , is_promotion
            , count(*) as orders
            , avg(net_amount) as avg_value
        from comparisons
        group by 1, 2
    )

select
    comparison
    , case when is_promotion = 1 then 'Promotion orders' else 'Comparison orders' end as order_group
    , orders
    , round(avg_value, 0) as avg_order_value
    , round((max(case when is_promotion = 1 then avg_value end) over (partition by comparison)
        / max(case when is_promotion = 0 then avg_value end) over (partition by comparison) - 1) * 100, 1) as promotion_gap_pct
from summary
order by 1, 2 desc

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Insight:**
-- MAGIC - **Price** is the most declared reason (17,473 online orders), followed by **On Promotion** (3,515 orders, $6.4M);
-- MAGIC   4,647 online orders (17%) have no reason at all. Read these counts against their recording window: the list of
-- MAGIC   reasons offered online changed on 30 May 2012 (Quality removed, On Promotion and Review added) and again from
-- MAGIC   30 May 2013, the day the online catalog launched (Price that day, Other and Television Advertisement in June).
-- MAGIC   Price leads partly because it arrived together with the online volume.
-- MAGIC - Answer to question f: the data has a single reason of type Promotion, named On Promotion. **Water Bottle - 30 oz.**
-- MAGIC   is the product with the most units bought for it (546 units), followed by Road Bottle Cage (416) and AWC Logo Cap
-- MAGIC   (301). Units favor cheap add-ons: by revenue, **bikes are 98.6% of promotion sales** and accessories 0.9%.
-- MAGIC - **The promotion reason is only ever recorded on bike orders**: all 3,515 contain a bike. What a promotion adds to an
-- MAGIC   order therefore depends entirely on the comparison (section 8.1): **+90%** against all other online orders, **−5.4%**
-- MAGIC   against other bike orders over the whole period, **+12.2%** against bike orders of the same period, and **−0.7%**
-- MAGIC   against orders for the same bike in the same month. Only the last one holds both the product and the timing constant
-- MAGIC   (2,525 of the 3,515 promotion orders have such a match), and it shows **no lift**: an order that cites a promotion is
-- MAGIC   worth what the same purchase is worth without one.
-- MAGIC - **No online order line has ever carried a discount**, promotion or not: all 3,282 discounted lines are reseller lines
-- MAGIC   (5.4% of reseller lines; the discounts amount to 0.65% of reseller gross sales). The source does have a special-offer
-- MAGIC   mechanism, and resellers use it; 1,277 promotion orders even point to a special offer, yet none was discounted. The
-- MAGIC   promotion customers cite is **not tied to any recorded price benefit**, so today the company **cannot measure promotion
-- MAGIC   ROI**, and the same-bike, same-month proxy finds no effect on order value. This is the key argument for the Commercial
-- MAGIC   Director, who believes the project's budget would be better spent on promotions.
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
-- MAGIC    many-to-many sales reasons, missing cards and reasons, stores recorded twice in the customer table, string-typed
-- MAGIC    dates and one ingestion bug (Namibia).
-- MAGIC 2. **Reseller booking dates are not business dates**: resellers order in one batch per month, booked on the month
-- MAGIC    boundary, so monthly series and year-over-year comparisons date reseller orders by the month the batch closes, while
-- MAGIC    calendar-year totals keep the order date that reconciles with the audit. The data also stops on a different date for
-- MAGIC    each channel: **April 2014 is the last complete month**, and year-over-year comparisons use January–April.
-- MAGIC 3. **Channel mix drives every aggregate**: resellers (73% of revenue, $21k tickets, 95% repeat) and online (88% of
-- MAGIC    orders, $1k tickets, 37% repeat). Averages without a channel split are misleading.
-- MAGIC 4. **Sales reasons exist only for online orders**, and the list of reasons changed over time, so a reason's share is
-- MAGIC    only comparable within the period in which it was offered.
-- MAGIC
-- MAGIC ### Where the brief is answered
-- MAGIC
-- MAGIC | Question | Where it is answered |
-- MAGIC |---|---|
-- MAGIC | a. Orders, quantity and value by product, card type, sales reason, date, customer, status, city, state and country | Each dimension is profiled in its own section (products 5, card type 9, sales reason 8, date 3, customers 7, status 2.3, city and country 6); the full breakdown, state included, is the dashboard's Sales Explorer |
-- MAGIC | b. Products with the highest average order value | Section 5: overall, by year and by country |
-- MAGIC | c. Top 10 customers by total transaction value | Section 7 |
-- MAGIC | d. Top 5 cities by total transaction value | Section 6 |
-- MAGIC | e. Orders, quantity and value by month and year | Section 3: the monthly series and the calendar years |
-- MAGIC | f. Product with the most units for the Promotion reason | Section 8 |
-- MAGIC
-- MAGIC ### Proposed KPIs
-- MAGIC
-- MAGIC | KPI | Definition | Why it matters |
-- MAGIC |---|---|---|
-- MAGIC | Gross sales | Σ quantity × unit price | Headline metric, reconciled with the audit |
-- MAGIC | Gross sales growth (YoY, like-for-like) | January–April by closing month vs. the same period last year | The longest window complete in every year |
-- MAGIC | Orders | Distinct sales orders | Commercial activity volume |
-- MAGIC | Units sold | Σ order quantity | Operational volume, promotion analysis (question f) |
-- MAGIC | Average order value | (Gross sales − discounts) ÷ orders, **by channel** | The brief's formula, without the channel-mix distortion |
-- MAGIC | Channel share | % of gross sales from resellers vs. online | Monitors the shift towards online |
-- MAGIC | Active customers | Customers with ≥ 1 order in the period, by channel | Growth of the customer base |
-- MAGIC | Repeat customer rate | % of customers with > 1 order, **by channel** | Loyalty lever for online (37% vs. 95% for resellers) |
-- MAGIC | Largest-account share | % of gross sales from the largest customer and from the top 10 | Account-level concentration risk (0.8% and 7.2% today) |
-- MAGIC | Accessory-to-bike conversion | % of customers whose first online order had no bike who later buy one | The open online growth path (0% today) |
-- MAGIC | Same-bike, same-month promotion lift | Order value of promotion orders vs. orders for the same bike in the same month | The only promotion measure that controls for product and timing |
-- MAGIC
-- MAGIC ### Recommendations for the commercial team
-- MAGIC 1. **Protect the reseller channel**: resellers are 73.4% of revenue and grew +41% like-for-like. No account exceeds 0.8%,
-- MAGIC    so the risk is the channel rather than one customer: run a key account program for the 192 resellers that make up
-- MAGIC    59.5% of sales.
-- MAGIC 2. **Invest in online growth** (+211% like-for-like) and **turn accessory buyers into bike buyers**: none of the 9,352
-- MAGIC    customers whose first online order had no bike has bought one, while cross-selling onto bike orders already works
-- MAGIC    (88%).
-- MAGIC 3. **Make promotions measurable before spending more on them**: no online order line carries a discount and the
-- MAGIC    promotion customers cite is tied to no price benefit, so promotion ROI cannot be computed today; and compared with
-- MAGIC    orders for the same bike in the same month, promotion orders are worth the same as orders without one (−0.7%).
-- MAGIC    Record every online promotion as a special offer whose discount is applied on the order line (1,277 promotion orders
-- MAGIC    already point to a special offer, yet none carries a discount; reseller offers do), then measure its lift against
-- MAGIC    the same bike in the same period.
-- MAGIC 4. **Review marketing channels** with zero attributed orders (Magazine, Demo Event, Sponsorship).
-- MAGIC 5. **Capture sales reasons for reseller orders** (100% missing) to understand 73% of the revenue.
-- MAGIC 6. **Complete the extraction after April 2014** (reseller batches stop in April, online bikes on 30 May) and report
-- MAGIC    trends through April 2014 until then. In the warehouse, store the batch closing month next to the order date of
-- MAGIC    every reseller order, so every trend reads the same calendar while calendar-year totals keep the order date that
-- MAGIC    reconciles with the audit.
