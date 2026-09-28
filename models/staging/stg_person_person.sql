{{
  config(
    tags=['staging', 'person']
  )
}}

with
    renamed as (
        select
            cast(businessentityid as bigint) as person_id
            , cast(persontype as string) as person_type
            , cast(title as string) as title
            , cast(firstname as string) as first_name
            , cast(middlename as string) as middle_name
            , cast(lastname as string) as last_name
            , cast(suffix as string) as suffix
            , cast(emailpromotion as int) as email_promotion
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'person_person') }}
    )

    , final as (
        select *
        from renamed
    )

select *
from final
