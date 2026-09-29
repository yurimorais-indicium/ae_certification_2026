{{
  config(
    tags=['staging', 'sales']
  )
}}

with
    renamed as (
        select
            cast(salesorderid as bigint) as sales_order_id
            , cast(revisionnumber as int) as revision_number
            , cast(orderdate as date) as order_date
            , cast(duedate as date) as due_date
            , cast(shipdate as date) as ship_date
            , cast(status as int) as order_status
            , cast(onlineorderflag as boolean) as is_online_order
            , cast(purchaseordernumber as string) as purchase_order_number
            , cast(accountnumber as string) as account_number
            , cast(customerid as bigint) as customer_id
            , cast(salespersonid as bigint) as sales_person_id
            , cast(territoryid as bigint) as territory_id
            , cast(billtoaddressid as bigint) as bill_to_address_id
            , cast(shiptoaddressid as bigint) as ship_to_address_id
            , cast(shipmethodid as bigint) as ship_method_id
            , cast(creditcardid as bigint) as credit_card_id
            , cast(creditcardapprovalcode as string) as credit_card_approval_code
            , cast(currencyrateid as bigint) as currency_rate_id
            , cast(subtotal as decimal(19, 4)) as subtotal
            , cast(taxamt as decimal(19, 4)) as tax_amount
            , cast(freight as decimal(19, 4)) as freight_amount
            , cast(totaldue as decimal(19, 4)) as total_due
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'sales_salesorderheader') }}
    )

    , final as (
        select
            sales_order_id
            , revision_number
            , order_date
            , due_date
            , ship_date
            , order_status
            , is_online_order
            , purchase_order_number
            , account_number
            , customer_id
            , sales_person_id
            , territory_id
            , bill_to_address_id
            , ship_to_address_id
            , ship_method_id
            , credit_card_id
            , credit_card_approval_code
            , currency_rate_id
            , subtotal
            , tax_amount
            , freight_amount
            , total_due
            , modified_at
        from renamed
    )

select *
from final
