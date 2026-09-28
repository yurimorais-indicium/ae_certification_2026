{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(salesreasonid as bigint) as sales_reason_id
            -- source has double spaces in some names (e.g. 'Television  Advertisement')
            , cast(regexp_replace(trim(name), ' +', ' ') as string) as sales_reason_name
            , cast(reasontype as string) as sales_reason_type
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_salesreason') }}
    )

    , final as (
        select *
        from renamed
    )

select *
from final
