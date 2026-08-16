-- FILE: models/dw/dim_customer.sql
-- Customer dimension built from snapshot
-- Current version only for BI consumption

{{
    config(
        materialized='table',
        tags=['dw', 'dimension']
    )
}}

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key([
        'mdm_id'
    ]) }} AS customer_sk,

    -- Business key
    mdm_id,

    -- Attributes
    {{ clean_string('customer_name') }}
        AS customer_name,
    {{ clean_string('specialty',
                    'UNKNOWN_SPECIALTY') }}
        AS specialty,
    {{ clean_string('territory_id') }}
        AS territory_id,
    {{ clean_string('segment_code',
                    'UNASSIGNED') }}
        AS segment_code,
    {{ clean_string('prescriber_type',
                    'UNKNOWN') }}
        AS prescriber_type,
    is_active,

    -- SCD2 columns from snapshot
    dbt_valid_from  AS effective_from,
    dbt_valid_to    AS effective_to,
    dbt_is_current  AS is_current

FROM {{ ref('snap_dim_customer') }}
-- dim_customer has ALL versions
-- for historical fact joins

/*
FOR CURRENT VERSION ONLY:
Add WHERE dbt_is_current = TRUE
Used in Power BI for current state reporting

FOR HISTORICAL JOINS:
Join fact table to snapshot directly
using date between valid_from and valid_to
*/
