{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(salesorderid as bigint) as sales_order_id
            , cast(salesreasonid as bigint) as sales_reason_id
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_salesorderheadersalesreason') }}
    )

    , final as (
        select *
        from renamed
    )

select *
from final
