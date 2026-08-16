-- FILE: models/dw/dim_product.sql

{{
    config(
        materialized='table',
        tags=['dw', 'dimension']
    )
}}

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key([
        'product_code'
    ]) }} AS product_sk,

    -- Business key
    {{ clean_string('product_code') }}
        AS product_code,

    -- Attributes
    {{ clean_string('product_name') }}
        AS product_name,

    {{ product_segment('product_code') }}
        AS product_segment,

    {{ therapeutic_area('product_code') }}
        AS therapeutic_area,

    LAUNCH_DATE AS launch_date,
    IS_ACTIVE   AS is_active

FROM {{ ref('stg_product_master') }}
-- or from seed file
