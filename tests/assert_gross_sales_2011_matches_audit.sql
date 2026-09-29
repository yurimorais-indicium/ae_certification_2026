-- Gross sales for 2011 must match the figure verified by the accounting audit team: $12,646,112.16
-- The test fails (returns a row) when the modeled value differs.

with
    gross_sales_2011 as (
        select round(sum(gross_amount), 2) as gross_amount
        from {{ ref('fct_sales') }}
        where year(order_date) = 2011
    )

select *
from gross_sales_2011
where gross_amount != 12646112.16
