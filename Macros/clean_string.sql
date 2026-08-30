-- FILE: macros/clean_string.sql
-- Reusable string cleaning
-- Used across all staging models

{% macro clean_string(
    column_name,
    default_value='UNKNOWN'
) %}

    CASE
        WHEN {{ column_name }} IS NULL
        THEN '{{ default_value }}'
        WHEN TRIM({{ column_name }}) = ''
        THEN '{{ default_value }}'
        ELSE UPPER(TRIM({{ column_name }}))
    END

{% endmacro %}

/*
USAGE:
{{ clean_string('territory_id') }}
{{ clean_string('product_code', 'NO_PRODUCT') }}

COMPILES TO:
CASE
    WHEN territory_id IS NULL THEN 'UNKNOWN'
    WHEN TRIM(territory_id) = '' THEN 'UNKNOWN'
    ELSE UPPER(TRIM(territory_id))
END

REAL SCENARIO:
IQVIA sends territory_id as:
't001', 'T001 ', ' T001' -- all same territory
Without macro: silent join failures
With macro: all become 'T001' consistently
*/
