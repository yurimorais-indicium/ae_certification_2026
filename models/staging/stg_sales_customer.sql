{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(customerid as bigint) as customer_id
            , cast(personid as bigint) as person_id
            , cast(storeid as bigint) as store_id
            , cast(territoryid as bigint) as territory_id
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_customer') }}
    )

    , final as (
        select
            customer_id
            , person_id
            , store_id
            , territory_id
            , modified_at
        from renamed
    )

select *
from final
