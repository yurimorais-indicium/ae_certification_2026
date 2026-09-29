{{
  config(
    tags=['staging', 'person']
  )
}}

with
    renamed as (
        select
            cast(stateprovinceid as bigint) as state_province_id
            , cast(trim(stateprovincecode) as string) as state_province_code
            , cast(countryregioncode as string) as country_region_code
            , cast(isonlystateprovinceflag as boolean) as is_only_state_province
            , cast(name as string) as state_province_name
            , cast(territoryid as bigint) as territory_id
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'person_stateprovince') }}
    )

    , final as (
        select
            state_province_id
            , state_province_code
            , country_region_code
            , is_only_state_province
            , state_province_name
            , territory_id
            , modified_at
        from renamed
    )

select *
from final
