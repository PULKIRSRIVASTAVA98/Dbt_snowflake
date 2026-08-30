-- FILE: models/rpt/rpt_field_insights.sql
-- Final reporting table
-- Consumed directly by Power BI
-- Grain: HCP + Product + Territory + Time Bucket

{{
    config(
        materialized='table',
        tags=['rpt', 'compass_rpt']
    )
}}

WITH fact_base AS (
    SELECT *
    FROM {{ ref('fact_trx') }}
    WHERE load_date = CURRENT_DATE
),

territory_rollup AS (
    SELECT
        territory_id,
        time_bucket,
        product_code,
        product_segment,
        therapeutic_area,

        -- Territory level KPIs
        SUM(curr_trx)  AS territory_curr_trx,
        SUM(prev_trx)  AS territory_prev_trx,
        SUM(curr_nbrx) AS territory_curr_nbrx,
        SUM(prev_nbrx) AS territory_prev_nbrx,

        COUNT(DISTINCT mdm_id)
            AS unique_hcps,

        -- Territory TRx growth
        CASE
            WHEN SUM(prev_trx) = 0 THEN 0
            ELSE ROUND(
                (SUM(curr_trx) - SUM(prev_trx))
                * 100.0 / SUM(prev_trx),
                2
            )
        END AS territory_trx_growth_pct,

        -- Writers (HCPs who prescribed)
        COUNT(
            DISTINCT CASE
                WHEN curr_trx > 0
                THEN mdm_id
            END
        ) AS ttl_writers,

        -- Targets (HCPs in territory)
        COUNT(DISTINCT mdm_id)
            AS ttl_targets,

        -- Writer rate
        ROUND(
            COUNT(
                DISTINCT CASE
                    WHEN curr_trx > 0
                    THEN mdm_id
                END
            ) * 100.0
            / NULLIF(COUNT(DISTINCT mdm_id), 0),
            2
        ) AS writer_rate_pct

    FROM fact_base
    GROUP BY
        territory_id,
        time_bucket,
        product_code,
        product_segment,
        therapeutic_area
)

SELECT
    -- HCP level detail
    f.mdm_id,
    f.customer_name,
    f.specialty,
    f.segment_code,
    f.hcp_territory          AS territory_id,
    f.time_bucket,
    f.product_code,
    f.product_name,
    f.product_segment,
    f.therapeutic_area,

    -- HCP KPIs
    f.curr_trx,
    f.prev_trx,
    f.curr_nbrx,
    f.prev_nbrx,
    f.trx_change,
    f.trx_growth_pct,
    f.refill_trx,
    f.territory_trx_share_pct,

    -- Territory rollup KPIs
    t.territory_curr_trx,
    t.territory_prev_trx,
    t.territory_trx_growth_pct,
    t.ttl_writers,
    t.ttl_targets,
    t.writer_rate_pct,

    -- HCP rank within territory
    RANK() OVER (
        PARTITION BY
            f.hcp_territory,
            f.product_code,
            f.time_bucket
        ORDER BY f.curr_trx DESC
    ) AS hcp_rank_in_territory,

    -- Top HCP flag
    CASE
        WHEN RANK() OVER (
            PARTITION BY
                f.hcp_territory,
                f.product_code,
                f.time_bucket
            ORDER BY f.curr_trx DESC
        ) <= 10
        THEN TRUE
        ELSE FALSE
    END AS is_top_10_hcp,

    -- Audit
    f.load_date,
    CURRENT_TIMESTAMP AS rpt_loaded_at

FROM fact_base f
JOIN territory_rollup t
    ON f.hcp_territory = t.territory_id
    AND f.time_bucket = t.time_bucket
    AND f.product_code = t.product_code

/*
THIS IS WHAT POWER BI READS:
One table with everything
HCP level detail + territory rollup
Pre-calculated KPIs + rankings
Import mode in Power BI
Cached for fast dashboard performance

FIELD TEAM USES:
territory_curr_trx → how territory doing
hcp_rank_in_territory → who to call
writer_rate_pct → how many HCPs prescribing
is_top_10_hcp → priority targets
trx_growth_pct → trajectory
*/
