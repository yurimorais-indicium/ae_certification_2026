{{
  config(
    tags=['staging', 'person']
  )
}}

with
    renamed as (
        select
            cast(addressid as bigint) as address_id
            , cast(addressline1 as string) as address_line_1
            , cast(addressline2 as string) as address_line_2
            , cast(city as string) as city
            , cast(stateprovinceid as bigint) as state_province_id
            , cast(postalcode as string) as postal_code
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'person_address') }}
    )

    , final as (
        select
            address_id
            , address_line_1
            , address_line_2
            , city
            , state_province_id
            , postal_code
            , modified_at
        from renamed
    )

select *
from final
