-- FILE: macros/safe_numeric.sql
-- Safe numeric conversion with defaults
-- Prevents null/negative corruption in KPIs

{% macro safe_numeric(
    column_name,
    min_value=0,
    default_value=0
) %}

    CASE
        WHEN {{ column_name }} IS NULL
        THEN {{ default_value }}
        WHEN TRY_TO_NUMBER(
            CAST({{ column_name }} AS VARCHAR)
        ) IS NULL
        THEN {{ default_value }}
        WHEN {{ column_name }} < {{ min_value }}
        THEN {{ default_value }}
        ELSE {{ column_name }}
    END

{% endmacro %}

/*
USAGE:
{{ safe_numeric('curr_trx') }}
{{ safe_numeric('curr_nbrx', min_value=0) }}

COMPILES TO:
CASE
    WHEN curr_trx IS NULL THEN 0
    WHEN TRY_TO_NUMBER(CAST(curr_trx AS VARCHAR))
         IS NULL THEN 0
    WHEN curr_trx < 0 THEN 0
    ELSE curr_trx
END

REAL SCENARIO:
IQVIA adjustment records have negative TRx
safe_numeric defaults them to 0
Prevents negative KPI values
in Power BI dashboards
*/
