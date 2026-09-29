{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(salesorderdetailid as bigint) as sales_order_detail_id
            , cast(salesorderid as bigint) as sales_order_id
            , cast(carriertrackingnumber as string) as carrier_tracking_number
            , cast(orderqty as int) as order_quantity
            , cast(productid as bigint) as product_id
            , cast(specialofferid as bigint) as special_offer_id
            , cast(unitprice as decimal(19, 4)) as unit_price
            , cast(unitpricediscount as decimal(19, 4)) as unit_price_discount_pct
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_salesorderdetail') }}
    )

    , final as (
        select
            sales_order_detail_id
            , sales_order_id
            , carrier_tracking_number
            , order_quantity
            , product_id
            , special_offer_id
            , unit_price
            , unit_price_discount_pct
            , modified_at
        from renamed
    )

select *
from final
