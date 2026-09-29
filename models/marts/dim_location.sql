{{
  config(
    tags=['marts', 'dimension']
  )
}}

with
    locations as (
        select
            address_id
            , city
            , postal_code
            , state_province_code
            , state_province_name
            , country_region_code
            , country_region_name
        from {{ ref('int_locations') }}
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['address_id']) }} as location_sk
            , address_id
            , city
            , postal_code
            , state_province_code
            , state_province_name
            , country_region_code
            , country_region_name
        from locations
    )

select *
from final
