-- =============================================================================
-- 07: Functions (Citation Guardrail)
-- =============================================================================
USE SCHEMA RISK_COPILOT.APP;

CREATE OR REPLACE FUNCTION VALIDATE_CITATIONS(
    "NARRATIVE" VARCHAR,
    "CITED" ARRAY,
    "ALLOWED" ARRAY,
    "CONTEXT" VARCHAR
)
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Guardrail: returns citations (bracketed policy refs or Section/Rule N mentions) not grounded in retrieved context'
AS '
  SELECT COALESCE(ARRAY_AGG(DISTINCT ref), ARRAY_CONSTRUCT()) FROM (
    SELECT c.value::STRING ref,
           TRIM(REGEXP_REPLACE(c.value::STRING, ''\\[|\\]|\\([a-z0-9]+\\)'', '''')) norm
    FROM TABLE(FLATTEN(INPUT => ARRAY_CAT(COALESCE(CITED, ARRAY_CONSTRUCT()),
                                           REGEXP_SUBSTR_ALL(COALESCE(NARRATIVE,''''), ''\\[[A-Za-z-]+ [0-9][^\\]]*\\]'')))) c
    UNION ALL
    SELECT m.value::STRING, m.value::STRING
    FROM TABLE(FLATTEN(INPUT => REGEXP_SUBSTR_ALL(COALESCE(NARRATIVE,''''), ''(Section|Rule|Regulation|Clause|Article) [0-9]+[A-Z-]*''))) m
  ) x
  WHERE NOT ARRAYS_OVERLAP(ARRAY_CONSTRUCT(TRUE), TRANSFORM(ALLOWED, a -> STARTSWITH(a::STRING, x.norm)))
    AND NOT CONTAINS(CONTEXT, x.norm)
';
