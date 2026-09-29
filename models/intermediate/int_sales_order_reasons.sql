{{
  config(
    tags=['intermediate', 'sales']
  )
}}

with
    order_headers as (
        select
            sales_order_id
        from {{ ref('stg_sales_sales_order_header') }}
    )

    , order_reasons as (
        select
            sales_order_id
            , sales_reason_id
        from {{ ref('stg_sales_sales_order_header_sales_reason') }}
    )

    -- orders without any reason are kept with a null sales_reason_id
    , final as (
        select
            order_headers.sales_order_id
            , order_reasons.sales_reason_id
        from order_headers
        left join order_reasons
            on order_headers.sales_order_id = order_reasons.sales_order_id
    )

select *
from final
