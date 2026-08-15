-- FILE: models/staging/stg_veeva_calls.sql
-- Landing to Staging incremental model
-- unique_key = call_id (already unique on the source)
-- Processes only new/changed records

{{
    config(
        materialized='incremental',
        unique_key='call_id',
        on_schema_change='sync_all_columns',
        tags=['staging', 'veeva']
    )
}}

SELECT
    -- Primary grain
    {{ clean_string('CALL_ID') }}
        AS call_id,

    {{ clean_string('MDM_ID') }}
        AS mdm_id,

    {{ clean_string('REP_ID',
                    'UNASSIGNED_REP') }}
        AS rep_id,

    CALL_DATE
        AS call_date,

    -- Territory / product — cleaned for
    -- consistent joins downstream
    {{ clean_string('TERRITORY_ID',
                    'UNASSIGNED') }}
        AS territory_id,

    {{ clean_string('PRODUCT_CODE',
                    'NO_PRODUCT') }}
        AS product_code,

    -- Product segmentation using macro
    -- keeps call activity comparable
    -- to prescription data by segment
    {{ product_segment('PRODUCT_CODE') }}
        AS product_segment,
    {{ therapeutic_area('PRODUCT_CODE') }}
        AS therapeutic_area,

    -- Audit columns
    LOADED_AT AS source_loaded_at,
    CURRENT_TIMESTAMP AS stg_loaded_at

FROM {{ source('VEEVA_STG', 'LND_VEEVA_CALLS') }}

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
WHERE CALL_ID IS NOT NULL
AND MDM_ID IS NOT NULL

/*
WHAT HAPPENS:
First run: loads ALL call records from landing
Subsequent runs: only NEW calls
                 (loaded after last run)

unique_key on call_id:
Veeva calls are already unique per CALL_ID
(unlike IQVIA, which needs a composite key),
so a straight MERGE on call_id is enough.

REAL SCENARIO:
Reps log calls throughout the day and Veeva
occasionally re-sends a corrected record for
the same call (e.g. wrong product logged).
Incremental MERGE on call_id applies the
correction instead of creating a duplicate row.
*/
