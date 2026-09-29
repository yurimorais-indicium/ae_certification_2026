{{
  config(
    tags=['marts', 'fact']
  )
}}

with
    order_items as (
        select
            sales_order_detail_id
            , sales_order_id
            , product_id
            , customer_id
            , ship_to_address_id
            , credit_card_id
            , order_date
            , ship_date
            , due_date
            , order_status
            , order_status_name
            , is_online_order
            , order_quantity
            , unit_price
            , unit_price_discount_pct
            , gross_amount
            , discount_amount
            , net_amount
        from {{ ref('int_sales_order_items') }}
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['sales_order_detail_id']) }} as sales_sk
            , sales_order_detail_id
            , sales_order_id
            , {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_sk
            , {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_sk
            , {{ dbt_utils.generate_surrogate_key(['ship_to_address_id']) }} as ship_to_location_sk
            -- orders without credit card point to the 'No credit card' member (-1)
            , {{ dbt_utils.generate_surrogate_key(['coalesce(credit_card_id, -1)']) }} as credit_card_sk
            , order_date
            , ship_date
            , due_date
            , order_status
            , order_status_name
            , is_online_order
            , order_quantity
            , unit_price
            , unit_price_discount_pct
            , gross_amount
            , discount_amount
            , net_amount
        from order_items
    )

select *
from final
