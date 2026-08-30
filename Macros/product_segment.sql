-- FILE: macros/product_segment.sql
-- Segments products into business categories
-- Used in DW transformation layer

{% macro product_segment(product_column) %}

    CASE UPPER(TRIM({{ product_column }}))
        WHEN 'REXULTI'
        THEN 'CNS_SCHIZOPHRENIA'
        WHEN 'JYNARQUE'
        THEN 'RENAL_PKD'
        WHEN 'ABILIFY'
        THEN 'CNS_BIPOLAR'
        WHEN 'SAMSCA'
        THEN 'RENAL_HYPONATREMIA'
        ELSE 'OTHER'
    END

{% endmacro %}

---

{% macro therapeutic_area(product_column) %}

    CASE UPPER(TRIM({{ product_column }}))
        WHEN 'REXULTI' THEN 'CNS'
        WHEN 'ABILIFY'  THEN 'CNS'
        WHEN 'JYNARQUE' THEN 'RENAL'
        WHEN 'SAMSCA'   THEN 'RENAL'
        ELSE 'UNKNOWN'
    END

{% endmacro %}

/*
REAL SCENARIO:
Business wants to slice performance
by therapeutic area CNS vs RENAL
Without macro: CASE statement in
every model that references product
With macro: call therapeutic_area('product_code')
Business adds new product?
Update one macro, all models reflect it
*/
