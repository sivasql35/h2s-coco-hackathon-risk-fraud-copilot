-- =============================================================================
-- 09: Cortex Search Service (Policy RAG)
-- =============================================================================
USE SCHEMA RISK_COPILOT.CURATED;

CREATE OR REPLACE CORTEX SEARCH SERVICE POLICY_SEARCH
    ON CHUNK_TEXT
    ATTRIBUTES DOC_TITLE, DOC_TYPE, SECTION, DOMAIN
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 day'
AS (
    SELECT DOC_ID, DOC_TITLE, DOC_TYPE, SECTION, DOMAIN, EFFECTIVE_DATE, CHUNK_TEXT
    FROM RISK_COPILOT.RAW.POLICY_DOCS
);
