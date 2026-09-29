{{
  config(
    tags=['staging', 'production']
  )
}}

-- discontinueddate is not selected: it is empty in the source (typed as double)
with
    renamed as (
        select
            cast(productid as bigint) as product_id
            , cast(name as string) as product_name
            , cast(productnumber as string) as product_number
            , cast(makeflag as boolean) as is_manufactured_in_house
            , cast(finishedgoodsflag as boolean) as is_finished_good
            , cast(color as string) as color
            , cast(safetystocklevel as int) as safety_stock_level
            , cast(reorderpoint as int) as reorder_point
            , cast(standardcost as decimal(19, 4)) as standard_cost
            , cast(listprice as decimal(19, 4)) as list_price
            , cast(size as string) as size
            , cast(sizeunitmeasurecode as string) as size_unit_measure_code
            , cast(weightunitmeasurecode as string) as weight_unit_measure_code
            , cast(weight as decimal(10, 2)) as weight
            , cast(daystomanufacture as int) as days_to_manufacture
            , cast(trim(productline) as string) as product_line
            , cast(trim(class) as string) as product_class
            , cast(trim(style) as string) as product_style
            , cast(productsubcategoryid as bigint) as product_subcategory_id
            , cast(productmodelid as bigint) as product_model_id
            , cast(sellstartdate as date) as sell_start_date
            , cast(sellenddate as date) as sell_end_date
            , date_trunc('second', cast(modifieddate as timestamp)) as modified_at
        from {{ source('adventure_works', 'production_product') }}
    )

    , final as (
        select
            product_id
            , product_name
            , product_number
            , is_manufactured_in_house
            , is_finished_good
            , color
            , safety_stock_level
            , reorder_point
            , standard_cost
            , list_price
            , size
            , size_unit_measure_code
            , weight_unit_measure_code
            , weight
            , days_to_manufacture
            , product_line
            , product_class
            , product_style
            , product_subcategory_id
            , product_model_id
            , sell_start_date
            , sell_end_date
            , modified_at
        from renamed
    )

select *
from final
