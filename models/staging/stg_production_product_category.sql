{{
  config(
    tags=['staging', 'production']
  )
}}

with
    renamed as (
        select
            cast(productcategoryid as bigint) as product_category_id
            , cast(name as string) as product_category_name
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'production_productcategory') }}
    )

    , final as (
        select *
        from renamed
    )

select *
from final
