{{
  config(
    tags=['staging', 'production']
  )
}}

with
    renamed as (
        select
            cast(productsubcategoryid as bigint) as product_subcategory_id
            , cast(productcategoryid as bigint) as product_category_id
            , cast(name as string) as product_subcategory_name
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'production_productsubcategory') }}
    )

    , final as (
        select *
        from renamed
    )

select *
from final
