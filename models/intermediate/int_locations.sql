{{
  config(
    tags=['intermediate', 'person']
  )
}}

with
    addresses as (
        select *
        from {{ ref('stg_person_address') }}
    )

    , state_provinces as (
        select *
        from {{ ref('stg_person_state_province') }}
    )

    , country_regions as (
        select *
        from {{ ref('stg_person_country_region') }}
    )

    , final as (
        select
            addresses.address_id
            , addresses.city
            , addresses.postal_code
            , state_provinces.state_province_id
            , state_provinces.state_province_code
            , state_provinces.state_province_name
            , country_regions.country_region_code
            , country_regions.country_region_name
        from addresses
        inner join state_provinces
            on addresses.state_province_id = state_provinces.state_province_id
        inner join country_regions
            on state_provinces.country_region_code = country_regions.country_region_code
    )

select *
from final
