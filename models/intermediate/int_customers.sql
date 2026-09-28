{{
  config(
    tags=['intermediate', 'sales']
  )
}}

with
    customers as (
        select *
        from {{ ref('stg_sales_customer') }}
    )

    , persons as (
        select *
        from {{ ref('stg_person_person') }}
    )

    , stores as (
        select *
        from {{ ref('stg_sales_store') }}
    )

    , joined as (
        select
            customers.customer_id
            , customers.person_id
            , customers.store_id
            , customers.territory_id
            , concat_ws(' ', persons.first_name, persons.middle_name, persons.last_name) as person_full_name
            , stores.store_name
        from customers
        left join persons
            on customers.person_id = persons.person_id
        left join stores
            on customers.store_id = stores.store_id
    )

    -- for resellers the buyer is the store; the linked person is only the store contact
    , final as (
        select
            customer_id
            , person_id
            , store_id
            , territory_id
            , coalesce(store_name, person_full_name) as customer_name
            , case
                when store_id is not null then 'Store'
                else 'Individual'
            end as customer_type
            , person_full_name
            , store_name
        from joined
    )

select *
from final
