{{
  config(
    tags=['marts', 'dimension']
  )
}}

with
    customers as (
        select
            customer_id
            , customer_name
            , customer_type
            , person_id
            , store_id
            , store_name
        from {{ ref('int_customers') }}
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_sk
            , customer_id
            , customer_name
            , customer_type
            , person_id
            , store_id
            , store_name
        from customers
    )

select *
from final
