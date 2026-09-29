{{
  config(
    tags=['marts', 'dimension']
  )
}}

with
    sales_reasons as (
        select
            sales_reason_id
            , sales_reason_name
            , sales_reason_type
        from {{ ref('stg_sales_sales_reason') }}
    )

    -- unknown member for orders without any sales reason
    , no_reason as (
        select
            cast(-1 as bigint) as sales_reason_id
            , 'No reason' as sales_reason_name
            , 'No reason' as sales_reason_type
    )

    , unioned as (
        select * from sales_reasons
        union all
        select * from no_reason
    )

    , final as (
        select
            {{ dbt_utils.generate_surrogate_key(['sales_reason_id']) }} as sales_reason_sk
            , sales_reason_id
            , sales_reason_name
            , sales_reason_type
        from unioned
    )

select *
from final
