{{
  config(
    tags=['marts', 'bridge']
  )
}}

with
    order_reasons as (
        select
            sales_order_id
            , sales_reason_id
        from {{ ref('int_sales_order_reasons') }}
    )

    -- orders without reason point to the 'No reason' member (-1)
    , final as (
        select
            sales_order_id
            , {{ dbt_utils.generate_surrogate_key(['coalesce(sales_reason_id, -1)']) }} as sales_reason_sk
        from order_reasons
    )

select *
from final
