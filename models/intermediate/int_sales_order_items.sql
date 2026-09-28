{{
  config(
    tags=['intermediate', 'sales']
  )
}}

with
    order_details as (
        select *
        from {{ ref('stg_sales_sales_order_detail') }}
    )

    , order_headers as (
        select *
        from {{ ref('stg_sales_sales_order_header') }}
    )

    , joined as (
        select
            order_details.sales_order_detail_id
            , order_details.sales_order_id
            , order_details.product_id
            , order_details.special_offer_id
            , order_headers.customer_id
            , order_headers.ship_to_address_id
            , order_headers.bill_to_address_id
            , order_headers.credit_card_id
            , order_headers.order_date
            , order_headers.due_date
            , order_headers.ship_date
            , order_headers.order_status
            , case order_headers.order_status
                when 1 then 'In process'
                when 2 then 'Approved'
                when 3 then 'Backordered'
                when 4 then 'Rejected'
                when 5 then 'Shipped'
                when 6 then 'Cancelled'
            end as order_status_name
            , order_headers.is_online_order
            , order_details.order_quantity
            , order_details.unit_price
            , order_details.unit_price_discount_pct
            , cast(
                order_details.order_quantity * order_details.unit_price
                as decimal(19, 4)
            ) as gross_amount
            , cast(
                order_details.order_quantity * order_details.unit_price * order_details.unit_price_discount_pct
                as decimal(19, 4)
            ) as discount_amount
        from order_details
        inner join order_headers
            on order_details.sales_order_id = order_headers.sales_order_id
    )

    , final as (
        select
            *
            , gross_amount - discount_amount as net_amount
        from joined
    )

select *
from final
