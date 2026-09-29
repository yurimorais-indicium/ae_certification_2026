{{
  config(
    tags=['staging', 'sales']
  )
}}

-- card number and expiration are intentionally not selected (sensitive, no analytical value)
with
    renamed as (
        select
            cast(creditcardid as bigint) as credit_card_id
            , cast(cardtype as string) as card_type
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_creditcard') }}
    )

    , final as (
        select
            credit_card_id
            , card_type
            , modified_at
        from renamed
    )

select *
from final
