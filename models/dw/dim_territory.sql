-- FILE: models/dw/dim_territory.sql
-- Territory dimension
-- Grain: one row per territory_id
-- Referenced by fact_trx and rpt_field_insights for
-- territory-level rollups and rep assignment

{{
    config(
        materialized='table',
        tags=['dw', 'dimension']
    )
}}

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key([
        'territory_id'
    ]) }} AS territory_sk,

    -- Business key
    {{ clean_string('territory_id') }}
        AS territory_id,

    -- Attributes
    {{ clean_string('territory_name',
                    'UNKNOWN_TERRITORY') }}
        AS territory_name,

    {{ clean_string('region',
                    'UNASSIGNED_REGION') }}
        AS region,

    {{ clean_string('area_director',
                    'UNASSIGNED') }}
        AS area_director,

    is_active

FROM {{ ref('territory_master') }}
-- seed file, same pattern as product_master
-- swap for a landing/source table if territory
-- data instead arrives via COPY INTO

/*
REAL SCENARIO:
territory_id shows up as a raw code (e.g. T001)
on both the IQVIA and Veeva feeds, but neither
feed carries a readable name, region, or the
rep/director who owns it.
dim_territory gives fact_trx and rpt_field_insights
something to join to so Power BI can show
"Northeast — Jane Smith" instead of "T001".
*/
