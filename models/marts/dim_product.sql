{{
  config(
    tags=['marts', 'dimension']
  )
}}

with
    products as (
        select
            product_id
            , product_name
            , product_number
            , color
            , size
            , product_line
            , product_class
            , product_style
            , standard_cost
            , list_price
            , subcategory_name
            , category_name
        from {{ ref('int_products') }}
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_sk
            , product_id
            , product_name
            , product_number
            , color
            , size
            , product_line
            , product_class
            , product_style
            , standard_cost
            , list_price
            , subcategory_name
            , category_name
        from products
    )

select *
from final
