{{
  config(
    tags=['staging', 'person']
  )
}}

with
    renamed as (
        select
            -- Namibia's ISO code 'NA' was loaded as null during ingestion
            cast(
                case
                    when countryregioncode is null and name = 'Namibia' then 'NA'
                    else countryregioncode
                end as string
            ) as country_region_code
            , cast(name as string) as country_region_name
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'person_countryregion') }}
    )

    , final as (
        select
            country_region_code
            , country_region_name
            , modified_at
        from renamed
    )

select *
from final
