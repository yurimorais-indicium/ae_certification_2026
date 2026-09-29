{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(businessentityid as bigint) as store_id
            , cast(name as string) as store_name
            , cast(salespersonid as bigint) as sales_person_id
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_store') }}
    )

    , final as (
        select
            store_id
            , store_name
            , sales_person_id
            , modified_at
        from renamed
    )

select *
from final
