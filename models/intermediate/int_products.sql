{{
  config(
    tags=['intermediate', 'production']
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
            , is_finished_good
            , sell_start_date
            , sell_end_date
            , product_subcategory_id
        from {{ ref('stg_production_product') }}
    )

    , product_subcategories as (
        select
            product_subcategory_id
            , product_category_id
            , product_subcategory_name
        from {{ ref('stg_production_product_subcategory') }}
    )

    , product_categories as (
        select
            product_category_id
            , product_category_name
        from {{ ref('stg_production_product_category') }}
    )

    -- products without subcategory are components never sold directly
    , final as (
        select
            products.product_id
            , products.product_name
            , products.product_number
            , products.color
            , products.size
            , products.product_line
            , products.product_class
            , products.product_style
            , products.standard_cost
            , products.list_price
            , products.is_finished_good
            , products.sell_start_date
            , products.sell_end_date
            , coalesce(product_subcategories.product_subcategory_name, 'Uncategorized') as subcategory_name
            , coalesce(product_categories.product_category_name, 'Uncategorized') as category_name
        from products
        left join product_subcategories
            on products.product_subcategory_id = product_subcategories.product_subcategory_id
        left join product_categories
            on product_subcategories.product_category_id = product_categories.product_category_id
    )

select *
from final
