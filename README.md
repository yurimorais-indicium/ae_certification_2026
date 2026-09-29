# Adventure Works — Sales Analytics (dbt + Databricks)

Analytics Engineering project built for the **Indicium Analytics Engineer Certification 2026**.
It turns the raw Adventure Works OLTP data into a tested, documented star schema that answers the
commercial team's questions about orders, products, customers, sales reasons and locations.

## Business context

Adventure Works is a bicycle manufacturer with 500+ products, ~20,000 customers and ~31,000 orders
(May 2011 – June 2014). Leadership wants to become data-driven, starting with the sales area. The CEO
asked for guaranteed data quality: modeled figures must match the accounting audit — for example,
**gross sales in 2011 = $12,646,112.16**, which is enforced as a dbt test.

## Architecture

```
fea_academy.adventure_works (raw)
        │  14 source tables, tested at source level
        ▼
  staging (views)       stg_*   1:1 with sources — rename, cast types, light cleaning
        ▼
  intermediate (views)  int_*   joins and business rules
        ▼
  marts (tables)        fct_* / dim_* / bridge_*   star schema consumed by the BI tool
```

| Layer | Schema | Materialization | Responsibility |
|---|---|---|---|
| Staging | `<target_schema>_staging` | view | Snake_case names, explicit casts (string dates → `date`, double keys → `bigint`, money → `decimal(19,4)`), drop technical and sensitive columns |
| Intermediate | `<target_schema>_intermediate` | view | Join entities, derive metrics and business rules |
| Marts | `<target_schema>_marts` | table | Surrogate keys, unknown members, full column documentation persisted to Unity Catalog |

## Data model

Star schema at **sales order line** grain. Full description in
[docs/conceptual_model.md](docs/conceptual_model.md) (diagram: [docs/conceptual_model.drawio](docs/conceptual_model.drawio)).

| Model | Grain | Built from |
|---|---|---|
| `fct_sales` | Sales order line | `int_sales_order_items` |
| `dim_product` | Product | `int_products` |
| `dim_customer` | Customer | `int_customers` |
| `dim_location` | Address (ship-to) | `int_locations` |
| `dim_credit_card` | Credit card + `No credit card` member | `stg_sales_credit_card` |
| `dim_sales_reason` | Sales reason + `No reason` member | `stg_sales_sales_reason` |
| `dim_date` | Calendar day (2011–2014) | `dbt_utils.date_spine` |
| `bridge_sales_order_reason` | Sales order × reason | `int_sales_order_reasons` |

## Key business rules

- **Total transaction value = gross revenue** (`gross_amount = order_quantity × unit_price`).
  Net revenue (`net_amount = gross_amount − discount_amount`) is used for the average order value.
- **Sales reasons are many-to-many** (0–3 per order) and are modeled through a bridge table so revenue
  is never duplicated. Totals per reason are correct; the sum across reasons is not additive.
- **Unknown members:** orders without a credit card → `No credit card`; orders without a reason → `No reason`.
- **Location** uses the order's ship-to address.
- **Customers linked to a store are resellers** (`customer_type = 'Store'`) and are named after the store;
  all other customers are `Individual`.
- **Order status** codes are translated (1 In process … 5 Shipped, 6 Cancelled).
- **Data fix:** Namibia's ISO code `NA` was loaded as null during ingestion; it is restored in staging and
  kept as a warning-level source test for visibility.

## Tests

| Type | Where | Examples |
|---|---|---|
| Source tests | `models/staging/_adventure_works_sources.yml` | `unique` / `not_null` on primary keys, `relationships` on foreign keys |
| Primary keys | every model's `.yml` | `unique` + `not_null`, `unique_combination_of_columns` for composite keys |
| Referential integrity | marts | every `fct_sales` foreign key → its dimension |
| Data quality | intermediate and marts | `equal_rowcount` (joins never duplicate rows), `net = gross − discount`, `accepted_values`, `accepted_range` |
| Audit reconciliation | `tests/assert_gross_sales_2011_matches_audit.sql` | 2011 gross sales = $12,646,112.16 |

## How to run

**Prerequisites:** Python 3.10+, a Databricks SQL warehouse and a personal access token.

```powershell
# 1. Create the virtual environment and install dbt
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 2. Configure credentials (never committed)
copy .env.example .env    # then fill in host, http_path, token, catalog and schema

# 3. Install packages and check the connection
dbt deps
dbt debug
```

dbt loads `.env` automatically from the project root. Variables already set in the operating
system take precedence over `.env`, so remove any stale `DBT_DATABRICKS_*` variables if the
connection fails.

```powershell
dbt build                          # run all models and tests in DAG order
dbt run                            # build models only
dbt test --select "source:*"       # source tests only
dbt test                           # all tests
dbt docs generate; dbt docs serve  # documentation site and lineage graph
```

## Project structure

```
├── models/
│   ├── staging/        _adventure_works_sources.yml + stg_<schema>_<table>.sql/.yml
│   ├── intermediate/   int_<entity>.sql/.yml
│   └── marts/          fct_*, dim_*, bridge_* (.sql/.yml)
├── tests/              singular tests (audit reconciliation)
├── docs/               conceptual data model
├── dbt_project.yml / packages.yml / profiles.yml
├── requirements.txt / .env.example
```

## Conventions

- Everything in English; snake_case; one `.yml` per model.
- Model names: `stg_<source_schema>_<table>`, `int_<entity>`, `fct_<process>`, `dim_<entity>`, `bridge_<relationship>`.
- SQL style: CTEs, leading commas, explicit column lists — `select *` only in the final `select * from final`.
- Surrogate keys (`*_sk`) exist only in marts, generated with `dbt_utils.generate_surrogate_key`.
