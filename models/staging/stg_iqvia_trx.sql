-- FILE: models/staging/stg_iqvia_trx.sql
-- Landing to Staging incremental model
-- unique_key = mdm_id + product_code + time_bucket
-- Processes only new/changed records

{{
    config(
        materialized='incremental',
        unique_key=[
            'mdm_id',
            'product_code',
            'time_bucket'
        ],
        on_schema_change='sync_all_columns',
        tags=['staging', 'iqvia']
    )
}}

SELECT
    -- Primary grain
    {{ clean_string('MDM_ID') }}
        AS mdm_id,
    {{ clean_string('PRODUCT_CODE',
                    'NO_PRODUCT') }}
        AS product_code,
    {{ clean_string('TIME_BUCKET') }}
        AS time_bucket,

    -- Territory
    {{ clean_string('TERRITORY_ID',
                    'UNASSIGNED') }}
        AS territory_id,

    -- KPI measures — safe numeric
    {{ safe_numeric('CURR_TRX') }}
        AS curr_trx,
    {{ safe_numeric('PREV_TRX') }}
        AS prev_trx,
    {{ safe_numeric('CURR_NBRX') }}
        AS curr_nbrx,
    {{ safe_numeric('PREV_NBRX') }}
        AS prev_nbrx,

    -- Derived metrics
    {{ safe_numeric('CURR_TRX') }} -
    {{ safe_numeric('PREV_TRX') }}
        AS trx_change,

    CASE
        WHEN {{ safe_numeric('PREV_TRX') }} = 0
        THEN 0
        ELSE ROUND(
            ({{ safe_numeric('CURR_TRX') }} -
             {{ safe_numeric('PREV_TRX') }})
            * 100.0
            / {{ safe_numeric('PREV_TRX') }},
            2
        )
    END AS trx_growth_pct,

    -- Product segmentation using macro
    {{ product_segment('PRODUCT_CODE') }}
        AS product_segment,
    {{ therapeutic_area('PRODUCT_CODE') }}
        AS therapeutic_area,

    -- Audit columns
    LOADED_AT AS source_loaded_at,
    CURRENT_TIMESTAMP AS stg_loaded_at

FROM {{ source('IQVIA_STG', 'LND_IQVIA_TRX') }}

-- Only process new or updated records
{% if is_incremental() %}
WHERE LOADED_AT > (
    SELECT MAX(source_loaded_at)
    FROM {{ this }}
)
{% endif %}

-- Exclude invalid records
-- Already caught by tests
-- But defensive filter here too
WHERE MDM_ID IS NOT NULL
AND PRODUCT_CODE IS NOT NULL
AND TIME_BUCKET IS NOT NULL

/*
WHAT HAPPENS:
First run: loads ALL records from landing
Subsequent runs: only NEW records
                 (loaded after last run)

unique_key on three columns:
If same MDM_ID + PRODUCT_CODE + TIME_BUCKET
appears again in source = UPSERT
dbt generates MERGE statement:
Match on grain = UPDATE existing row
No match = INSERT new row

REAL SCENARIO:
IQVIA sends corrections to previous data
Same HCP + product + time bucket
but different TRx value
Incremental with MERGE handles it
Without unique_key: duplicate rows
With unique_key: correction applied correctly
*/
