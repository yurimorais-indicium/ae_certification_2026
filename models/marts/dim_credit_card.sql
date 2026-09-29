{{
  config(
    tags=['marts', 'dimension']
  )
}}

with
    credit_cards as (
        select
            credit_card_id
            , card_type
        from {{ ref('stg_sales_credit_card') }}
    )

    -- unknown member for orders paid without a credit card
    , no_credit_card as (
        select
            cast(-1 as bigint) as credit_card_id
            , 'No credit card' as card_type
    )

    , unioned as (
        select * from credit_cards
        union all
        select * from no_credit_card
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['credit_card_id']) }} as credit_card_sk
            , credit_card_id
            , card_type
        from unioned
    )

select *
from final
