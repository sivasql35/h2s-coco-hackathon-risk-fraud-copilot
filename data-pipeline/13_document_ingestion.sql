-- =============================================================================
-- 13: Document Ingestion Pipeline
-- Stage + AI_PARSE_DOCUMENT flow for policy PDF ingestion into POLICY_DOCS
-- =============================================================================
USE SCHEMA RISK_COPILOT.RAW;

-- 1. Create internal stage for policy PDFs
CREATE STAGE IF NOT EXISTS POLICY_PDF_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Upload policy/regulation PDFs here for automated parsing into POLICY_DOCS';

-- 2. Staging table to track parsed files (prevents re-processing)
CREATE TABLE IF NOT EXISTS POLICY_PDF_PARSED (
    FILE_PATH VARCHAR NOT NULL,
    FILE_SIZE NUMBER,
    PARSED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    DOC_COUNT NUMBER,
    STATUS VARCHAR DEFAULT 'SUCCESS',
    ERROR_MESSAGE VARCHAR,
    CONSTRAINT PK_PARSED PRIMARY KEY (FILE_PATH)
);

-- 3. Stored procedure: parse all new PDFs from stage into POLICY_DOCS
CREATE OR REPLACE PROCEDURE INGEST_POLICY_PDFS()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Scans POLICY_PDF_STAGE for new PDFs, parses each with AI_PARSE_DOCUMENT (LAYOUT mode, page_split), and inserts chunks into POLICY_DOCS.'
EXECUTE AS CALLER
AS '
DECLARE
  v_new_files ARRAY DEFAULT ARRAY_CONSTRUCT();
  v_processed ARRAY DEFAULT ARRAY_CONSTRUCT();
  v_failed ARRAY DEFAULT ARRAY_CONSTRUCT();
  v_path STRING;
  v_size NUMBER;
  v_parsed VARIANT;
  v_page VARIANT;
  v_doc_title STRING;
  v_doc_type STRING;
  v_domain STRING;
  v_section STRING;
  v_chunk STRING;
  v_page_idx NUMBER;
  v_doc_count NUMBER;
  c_files CURSOR FOR
    SELECT RELATIVE_PATH, SIZE
    FROM DIRECTORY(@RISK_COPILOT.RAW.POLICY_PDF_STAGE)
    WHERE RELATIVE_PATH ILIKE ''%.pdf''
      AND RELATIVE_PATH NOT IN (SELECT FILE_PATH FROM RISK_COPILOT.RAW.POLICY_PDF_PARSED WHERE STATUS = ''SUCCESS'');
BEGIN
  FOR rec IN c_files DO
    v_path := rec.RELATIVE_PATH;
    v_size := rec.SIZE;
    v_doc_count := 0;

    BEGIN
      -- Parse the PDF with layout mode and page splitting
      SELECT PARSE_JSON(
        AI_PARSE_DOCUMENT(
          TO_FILE(@RISK_COPILOT.RAW.POLICY_PDF_STAGE, :v_path),
          {''mode'': ''LAYOUT'', ''page_split'': TRUE}
        )
      ) INTO :v_parsed;

      -- Derive doc metadata from filename
      -- Expected format: DOMAIN_DOCTYPE_Title.pdf  (e.g. AML_INTERNAL_POLICY_Anti-Money-Laundering.pdf)
      v_doc_title := REPLACE(REPLACE(REGEXP_SUBSTR(:v_path, ''[^/]+$''), ''.pdf'', ''''), ''_'', '' '');
      v_doc_type := COALESCE(
        CASE
          WHEN :v_path ILIKE ''%regulation%'' OR :v_path ILIKE ''%reg_%'' THEN ''REGULATION_SUMMARY''
          WHEN :v_path ILIKE ''%policy%'' OR :v_path ILIKE ''%pol_%'' THEN ''INTERNAL_POLICY''
          ELSE ''DOCUMENT''
        END, ''DOCUMENT'');
      v_domain := COALESCE(
        CASE
          WHEN :v_path ILIKE ''%aml%'' OR :v_path ILIKE ''%fraud%'' OR :v_path ILIKE ''%fincen%'' OR :v_path ILIKE ''%pmla%'' THEN ''AML''
          WHEN :v_path ILIKE ''%credit%'' OR :v_path ILIKE ''%loan%'' OR :v_path ILIKE ''%npa%'' THEN ''CREDIT''
          WHEN :v_path ILIKE ''%liquidity%'' OR :v_path ILIKE ''%lcr%'' OR :v_path ILIKE ''%alm%'' OR :v_path ILIKE ''%basel%'' THEN ''LIQUIDITY''
          ELSE ''GENERAL''
        END, ''GENERAL'');

      -- Insert one row per page as a chunk
      FOR i IN 0 TO ARRAY_SIZE(:v_parsed:pages) - 1 DO
        v_page := :v_parsed:pages[i];
        v_page_idx := :v_page:index::NUMBER;
        v_chunk := :v_page:content::STRING;
        v_section := :v_doc_title || '' - Page '' || (:v_page_idx + 1)::STRING;

        IF (LENGTH(:v_chunk) > 10) THEN
          INSERT INTO RISK_COPILOT.RAW.POLICY_DOCS (DOC_ID, DOC_TITLE, DOC_TYPE, SECTION, DOMAIN, EFFECTIVE_DATE, CHUNK_TEXT)
          VALUES (
            ''PDF-'' || MD5(:v_path || ''-'' || :v_page_idx::STRING),
            :v_doc_title,
            :v_doc_type,
            :v_section,
            :v_domain,
            CURRENT_DATE(),
            :v_chunk
          );
          v_doc_count := v_doc_count + 1;
        END IF;
      END FOR;

      -- Track successful parse
      INSERT INTO RISK_COPILOT.RAW.POLICY_PDF_PARSED (FILE_PATH, FILE_SIZE, DOC_COUNT, STATUS)
      VALUES (:v_path, :v_size, :v_doc_count, ''SUCCESS'');

      v_processed := ARRAY_APPEND(v_processed, OBJECT_CONSTRUCT(''file'', v_path, ''pages'', v_doc_count));

    EXCEPTION WHEN OTHER THEN
      -- Track failed parse
      INSERT INTO RISK_COPILOT.RAW.POLICY_PDF_PARSED (FILE_PATH, FILE_SIZE, DOC_COUNT, STATUS, ERROR_MESSAGE)
      VALUES (:v_path, :v_size, 0, ''FAILED'', SQLERRM);

      v_failed := ARRAY_APPEND(v_failed, OBJECT_CONSTRUCT(''file'', v_path, ''error'', SQLERRM));
    END;
  END FOR;

  RETURN OBJECT_CONSTRUCT(
    ''processed'', v_processed,
    ''failed'', v_failed,
    ''total_new_files'', ARRAY_SIZE(v_processed) + ARRAY_SIZE(v_failed)
  );
END;
';


-- 4. Stream on POLICY_DOCS to trigger Cortex Search refresh
CREATE STREAM IF NOT EXISTS POLICY_DOCS_CHANGE_STREAM
    ON TABLE RISK_COPILOT.RAW.POLICY_DOCS
    APPEND_ONLY = TRUE;


-- 5. Scheduled task: check for new PDFs every hour
CREATE OR REPLACE TASK T_INGEST_POLICY_PDFS
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 30 * * * * Asia/Kolkata'
    COMMENT = 'Hourly scan of POLICY_PDF_STAGE for new PDFs, parse via AI_PARSE_DOCUMENT, insert into POLICY_DOCS'
AS
CALL RISK_COPILOT.RAW.INGEST_POLICY_PDFS();

-- Resume when ready:
-- ALTER TASK RISK_COPILOT.RAW.T_INGEST_POLICY_PDFS RESUME;


-- =============================================================================
-- Usage:
--   1. Upload PDFs:  PUT file:///path/to/policy.pdf @RISK_COPILOT.RAW.POLICY_PDF_STAGE;
--   2. Run manually: CALL RISK_COPILOT.RAW.INGEST_POLICY_PDFS();
--   3. Or let the hourly task handle it automatically
--   4. Check parse status: SELECT * FROM RISK_COPILOT.RAW.POLICY_PDF_PARSED;
--   5. Cortex Search (POLICY_SEARCH) auto-refreshes from POLICY_DOCS
-- =============================================================================
