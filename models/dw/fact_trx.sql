-- FILE: models/dw/fact_trx.sql
-- Core fact table for prescription KPIs
-- Grain: one row per HCP + Product + Time Bucket
-- per reporting cycle

{{
    config(
        materialized='incremental',
        unique_key=[
            'mdm_id',
            'product_code',
            'time_bucket',
            'load_date'
        ],
        tags=['dw', 'fact']
    )
}}

WITH staging_data AS (
    SELECT *
    FROM {{ ref('stg_iqvia_trx') }}

    {% if is_incremental() %}
    WHERE stg_loaded_at > (
        SELECT MAX(stg_loaded_at)
        FROM {{ this }}
    )
    {% endif %}
),

-- Get correct customer version
-- for historical accuracy
customer_dim AS (
    SELECT *
    FROM {{ ref('snap_dim_customer') }}
),

product_dim AS (
    SELECT *
    FROM {{ ref('dim_product') }}
),

territory_dim AS (
    SELECT *
    FROM {{ ref('dim_territory') }}
)

SELECT
    -- Surrogate keys for fact
    {{ dbt_utils.generate_surrogate_key([
        's.mdm_id',
        's.product_code',
        's.time_bucket',
        'CURRENT_DATE'
    ]) }} AS fact_sk,

    -- Foreign keys to dimensions
    c.customer_sk,
    p.product_sk,
    s.territory_id,
    s.time_bucket,

    -- Business keys (for debugging)
    s.mdm_id,
    s.product_code,

    -- KPI measures
    s.curr_trx,
    s.prev_trx,
    s.curr_nbrx,
    s.prev_nbrx,

    -- Derived measures
    s.trx_change,
    s.trx_growth_pct,

    -- Patient metrics
    s.curr_trx - s.curr_nbrx
        AS refill_trx,

    -- Share of voice proxy
    ROUND(
        s.curr_trx * 100.0 /
        NULLIF(
            SUM(s.curr_trx) OVER (
                PARTITION BY
                    s.territory_id,
                    s.time_bucket
            ),
            0
        ),
        2
    ) AS territory_trx_share_pct,

    -- Dimension attributes
    -- denormalised for BI performance
    c.customer_name,
    c.specialty,
    c.segment_code,
    c.territory_id AS hcp_territory,

    p.product_name,
    p.product_segment,
    p.therapeutic_area,

    -- Audit
    CURRENT_DATE    AS load_date,
    CURRENT_TIMESTAMP AS loaded_at

FROM staging_data s

-- SCD2 join — critical
-- Get HCP version active at load time
JOIN customer_dim c
    ON s.mdm_id = c.mdm_id
    AND CURRENT_DATE
        BETWEEN c.dbt_valid_from
        AND c.dbt_valid_to

JOIN product_dim p
    ON s.product_code = p.product_code

JOIN territory_dim t
    ON s.territory_id = t.territory_id

WHERE s.mdm_id IS NOT NULL
AND s.curr_trx >= 0

/*
CRITICAL DESIGN DECISIONS:

1. SCD2 JOIN:
   CURRENT_DATE BETWEEN dbt_valid_from
   AND dbt_valid_to
   Ensures fact row gets HCP's CURRENT
   territory assignment
   Not historical version
   For reporting this is correct
   Historical analysis uses snap directly

2. WINDOW FUNCTION in fact:
   territory_trx_share_pct
   Calculated here once
   Not in every RPT query
   Better performance at BI layer

3. INCREMENTAL on fact:
   Same pattern as staging
   Only process new staging records
   Prevents 4B row rebuilds daily
*/
