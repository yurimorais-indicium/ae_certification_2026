-- Known source grain quirk: sales_customer holds two customer records per selling store
-- (same store_id and name) -- one carrying the store-contact person_id and all of the orders,
-- one with no contact and no orders.
--
-- This is faithful to the source and is safe ONLY while the twin never carries orders: if both
-- rows ever sold, store-level revenue would be split across two customer keys and every
-- customer-level ranking would be wrong.
--
-- The test fails (returns a row) when any store has more than one customer record with orders.

with
    orders_per_customer as (
        select
            customer_sk
            , count(*) as order_lines
        from {{ ref('fct_sales') }}
        group by customer_sk
    )

    , selling_rows_per_store as (
        select
            customers.store_id
            , count(*) as selling_customer_rows
        from {{ ref('dim_customer') }} as customers
        inner join orders_per_customer
            on customers.customer_sk = orders_per_customer.customer_sk
        where customers.store_id is not null
        group by customers.store_id
    )

select *
from selling_rows_per_store
where selling_customer_rows > 1
