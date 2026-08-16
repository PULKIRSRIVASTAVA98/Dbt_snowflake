-- FILE: models/dw/dim_time.sql
-- COMPASS-specific time dimension
-- Maps time buckets to date ranges

{{
    config(
        materialized='table',
        tags=['dw', 'dimension']
    )
}}

SELECT
    TIME_BUCKET                     AS time_bucket,
    TIME_BUCKET_DESC                AS time_bucket_desc,
    {{ time_bucket_days(
        'TIME_BUCKET'
    ) }}                            AS days_in_period,
    DATEADD(
        day,
        -{{ time_bucket_days('TIME_BUCKET') }},
        CURRENT_DATE
    )                               AS period_start_date,
    CURRENT_DATE                    AS period_end_date,
    YEAR(CURRENT_DATE)              AS fiscal_year,
    QUARTER(CURRENT_DATE)           AS fiscal_quarter

FROM (
    SELECT 'C4W'  AS TIME_BUCKET,
           'Current 4 Weeks' AS TIME_BUCKET_DESC
    UNION ALL
    SELECT 'C13W', 'Current 13 Weeks'
    UNION ALL
    SELECT 'C26W', 'Current 26 Weeks'
    UNION ALL
    SELECT 'MAT',  'Moving Annual Total'
)

/*
REAL SCENARIO:
Power BI slicers use time_bucket
Business users select C4W or MAT
dim_time tells Power BI what date range
each bucket represents
Drives all period-based filtering
in COMPASS dashboards
*/
