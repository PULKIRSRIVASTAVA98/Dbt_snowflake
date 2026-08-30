-- FILE: macros/time_bucket.sql
-- COMPASS-specific time bucket calculation
-- Converts raw dates to business time buckets
-- C4W = Current 4 Weeks = last 28 days
-- C13W = Current 13 Weeks = last 91 days
-- MAT = Moving Annual Total = last 365 days

{% macro time_bucket_filter(
    date_column,
    bucket_column='TIME_BUCKET'
) %}

    CASE {{ bucket_column }}
        WHEN 'C4W'
        THEN {{ date_column }}
             >= DATEADD(day, -28, CURRENT_DATE)
        WHEN 'C13W'
        THEN {{ date_column }}
             >= DATEADD(day, -91, CURRENT_DATE)
        WHEN 'C26W'
        THEN {{ date_column }}
             >= DATEADD(day, -182, CURRENT_DATE)
        WHEN 'MAT'
        THEN {{ date_column }}
             >= DATEADD(day, -365, CURRENT_DATE)
        ELSE TRUE
    END

{% endmacro %}

---

{% macro time_bucket_days(bucket_name) %}

    CASE '{{ bucket_name }}'
        WHEN 'C4W'  THEN 28
        WHEN 'C13W' THEN 91
        WHEN 'C26W' THEN 182
        WHEN 'MAT'  THEN 365
        ELSE 0
    END

{% endmacro %}

/*
REAL SCENARIO:
COMPASS reporting uses C4W as primary view
Territory managers see rolling 4-week TRx
Field directors see C13W trends
Executive team sees MAT performance

Instead of hardcoding 28 days everywhere
macro keeps it consistent across all models
Business decides to change C4W to 30 days?
Change one macro — all models update
*/
