-- =============================================================================
-- 10: Semantic View (Cortex Analyst)
-- =============================================================================
USE SCHEMA RISK_COPILOT.CURATED;

CREATE OR REPLACE SEMANTIC VIEW RISK_INTELLIGENCE_SV
    TABLES (
        ALERTS AS RISK_COPILOT.CURATED.DT_FRAUD_ALERTS PRIMARY KEY (ALERT_ID)
            WITH SYNONYMS=('fraud alerts','AML alerts','suspicious accounts')
            COMMENT='Explainable fraud/AML alerts with red flags mapped to policy sections',
        SIGNALS AS RISK_COPILOT.CURATED.DT_ACCOUNT_SIGNALS PRIMARY KEY (ACCOUNT_ID)
            COMMENT='Per-account behavioural signals for all deposit accounts',
        LOANS AS RISK_COPILOT.CURATED.DT_LOAN_EWS PRIMARY KEY (LOAN_ID)
            WITH SYNONYMS=('loan book','credit portfolio','borrowers')
            COMMENT='Loan book with SMA/NPA class, IFRS9 stage and EWS triggers',
        LCR AS RISK_COPILOT.CURATED.DT_LCR_DAILY PRIMARY KEY (AS_OF_DATE)
            WITH SYNONYMS=('liquidity','liquidity coverage','ALM')
            COMMENT='Daily Basel III LCR, stress LCR and liquidity gap buckets. One row per date.',
        CONC AS RISK_COPILOT.CURATED.V_INDUSTRY_CONCENTRATION PRIMARY KEY (INDUSTRY)
            WITH SYNONYMS=('concentration','sector exposure')
            COMMENT='Industry exposure concentration vs policy limits',
        RISK_COPILOT.APP.CASES PRIMARY KEY (CASE_ID)
            WITH SYNONYMS=('investigations','STR drafts','SAR')
            COMMENT='Investigation cases and STR drafts'
    )
    RELATIONSHIPS (
        ALERTS_TO_SIGNALS AS ALERTS(ACCOUNT_ID) REFERENCES SIGNALS(ACCOUNT_ID),
        CASES_TO_ALERTS AS CASES(ALERT_ID) REFERENCES ALERTS(ALERT_ID)
    )
    FACTS (
        ALERTS.RISK_SCORE_F AS RISK_SCORE,
        ALERTS.INFLOW_48H AS INFLOW_AMT_48H,
        ALERTS.OUTFLOW_48H AS OUTFLOW_AMT_48H,
        SIGNALS.INFLOW_AMT_48H_F AS INFLOW_AMT_48H,
        LOANS.OUTSTANDING_F AS OUTSTANDING,
        LOANS.SANCTIONED_LIMIT_F AS SANCTIONED_LIMIT,
        LOANS.DPD_F AS DPD,
        LCR.LCR_PCT_F AS LCR_PCT,
        LCR.LCR_STRESS_F AS LCR_STRESS_S1_PCT,
        LCR.HQLA_F AS HQLA_STOCK,
        LCR.NET_OUTFLOWS_F AS NET_CASH_OUTFLOWS_30D,
        LCR.GAP_1_7_F AS NET_OUT_1_7D,
        LCR.GAP_8_14_F AS NET_OUT_8_14D,
        LCR.GAP_15_30_F AS NET_OUT_15_30D,
        CONC.SHARE_PCT_F AS SHARE_PCT,
        CONC.OUTSTANDING_INR_F AS OUTSTANDING_INR
    )
    DIMENSIONS (
        ALERTS.ALERT_ID AS ALERT_ID,
        ALERTS.ACCOUNT_ID AS ACCOUNT_ID,
        ALERTS.CUSTOMER_ID AS CUSTOMER_ID,
        ALERTS.CUSTOMER_NAME AS FULL_NAME WITH SYNONYMS=('customer','name'),
        ALERTS.TYPOLOGY AS TYPOLOGY WITH SYNONYMS=('fraud type','alert type','scheme')
            COMMENT='MONEY_MULE, AML_LAYERING (structuring/round-tripping), SANCTIONS, OTHER',
        ALERTS.RECOMMENDED_ACTION AS RECOMMENDED_ACTION
            COMMENT='FREEZE_ACCOUNT, PLACE_HOLD, STEP_UP_AUTH, REVIEW_AND_CLEAR',
        ALERTS.KYC_RISK AS KYC_RISK_RATING,
        ALERTS.SEGMENT AS SEGMENT,
        ALERTS.FLAG_NAMES AS FLAG_NAMES COMMENT='Array of red flag codes',
        ALERTS.ALERT_RISK_SCORE AS RISK_SCORE COMMENT='Alert risk score 1-100',
        SIGNALS.CITY AS CITY,
        SIGNALS.OCCUPATION AS OCCUPATION,
        SIGNALS.ACCOUNT_TYPE AS ACCOUNT_TYPE,
        SIGNALS.WATCHLIST_HIT AS WATCHLIST_HIT,
        LOANS.LOAN_ID AS LOAN_ID,
        LOANS.BORROWER AS FULL_NAME,
        LOANS.PRODUCT AS PRODUCT,
        LOANS.INDUSTRY AS INDUSTRY WITH SYNONYMS=('sector'),
        LOANS.LOAN_SEGMENT AS SEGMENT,
        LOANS.ASSET_CLASS AS ASSET_CLASS WITH SYNONYMS=('SMA bucket','NPA status')
            COMMENT='STANDARD, SMA-0, SMA-1, SMA-2, NPA',
        LOANS.IFRS9_STAGE AS IFRS9_STAGE,
        LOANS.EWS_ACTION AS EWS_ACTION,
        LOANS.COLLATERAL_TYPE AS COLLATERAL_TYPE,
        LOANS.EWS_TRIGGER_COUNT AS EWS_TRIGGER_COUNT,
        LCR.AS_OF_DATE AS AS_OF_DATE WITH SYNONYMS=('date','reporting date'),
        LCR.LCR_STATUS AS LCR_STATUS
            COMMENT='GREEN, AMBER_ALCO (<115), RED_CFP_TRIGGER (<110), REGULATORY_BREACH (<100)',
        CONC.CONC_INDUSTRY AS INDUSTRY,
        CONC.CONC_STATUS AS STATUS,
        CONC.LIMIT_PCT AS LIMIT_PCT,
        CASES.CASE_ID AS CASE_ID,
        CASES.CASE_STATUS AS STATUS,
        CASES.CASE_TYPOLOGY AS TYPOLOGY,
        CASES.CREATED_AT AS CREATED_AT,
        CASES.REVIEWED_BY AS REVIEWED_BY
    )
    METRICS (
        ALERTS.ALERT_COUNT AS COUNT(alerts.alert_id),
        ALERTS.AVG_RISK_SCORE AS AVG(alerts.risk_score_f),
        ALERTS.TOTAL_INFLOW_48H AS SUM(alerts.inflow_48h),
        ALERTS.TOTAL_OUTFLOW_48H AS SUM(alerts.outflow_48h)
            COMMENT='Value moved out of flagged accounts in last 48h (INR)',
        LOANS.LOAN_COUNT AS COUNT(loans.loan_id),
        LOANS.TOTAL_OUTSTANDING AS SUM(loans.outstanding_f) COMMENT='Outstanding exposure INR',
        LOANS.NPA_RATIO_PCT AS ROUND(100 * SUM(IFF(loans.dpd_f > 90, loans.outstanding_f, 0)) / NULLIF(SUM(loans.outstanding_f),0), 2)
            COMMENT='Gross NPA % of outstanding',
        LOANS.SMA_EXPOSURE AS SUM(IFF(loans.dpd_f BETWEEN 1 AND 90, loans.outstanding_f, 0))
            COMMENT='Exposure in SMA-0/1/2 buckets INR',
        LCR.LATEST_LCR AS MAX_BY(lcr.lcr_pct_f, lcr.as_of_date)
            COMMENT='Most recent LCR %. Do not group by LCR_STATUS when asking for the latest value.',
        LCR.AVG_LCR AS AVG(lcr.lcr_pct_f),
        LCR.MIN_LCR AS MIN(lcr.lcr_pct_f),
        LCR.AVG_STRESS_LCR AS AVG(lcr.lcr_stress_f),
        CONC.MAX_INDUSTRY_SHARE AS MAX(conc.share_pct_f),
        CASES.CASE_COUNT AS COUNT(cases.case_id)
    )
    COMMENT='Risk, Fraud & Regulatory Intelligence semantic layer (synthetic data)'
    AI_SQL_GENERATION 'Amounts are INR. For "latest", "current" or "today" liquidity questions, filter lcr to the row with the maximum AS_OF_DATE instead of aggregating by status. LCR internal floor is 110% and regulatory minimum is 100%. Always include identifiers (ALERT_ID, ACCOUNT_ID, LOAN_ID) when listing records so answers are evidence-backed. Order alert lists by RISK_SCORE descending.'
    AI_VERIFIED_QUERIES (
        LATEST_LCR_VQ AS (
            QUESTION 'What is the current LCR and status?'
            VERIFIED_BY '(owner = alm_team)'
            SQL 'SELECT as_of_date, lcr_pct_f AS lcr_pct, lcr_stress_f AS stress_lcr_pct, lcr_status, gap_1_7_f, gap_8_14_f, gap_15_30_f FROM __lcr ORDER BY as_of_date DESC LIMIT 1'),
        TOP_ALERTS_VQ AS (
            QUESTION 'Show the highest risk fraud alerts'
            ONBOARDING_QUESTION true
            SQL 'SELECT alert_id, account_id, customer_name, typology, alert_risk_score, recommended_action, outflow_48h FROM __alerts ORDER BY alert_risk_score DESC, alert_id LIMIT 20'),
        STRUCTURING_VQ AS (
            QUESTION 'Which customers show structuring behavior today?'
            SQL 'SELECT alert_id, account_id, customer_name, typology, alert_risk_score, recommended_action FROM __alerts WHERE typology = ''AML_LAYERING'' OR ARRAY_CONTAINS(''STRUCTURING''::VARIANT, flag_names) ORDER BY alert_risk_score DESC'),
        SMA_BY_INDUSTRY_VQ AS (
            QUESTION 'What is the SMA and NPA exposure by industry?'
            SQL 'SELECT industry, asset_class, COUNT(loan_id) AS loans, SUM(outstanding_f) AS outstanding_inr FROM __loans WHERE asset_class <> ''STANDARD'' GROUP BY industry, asset_class ORDER BY industry, asset_class')
    );
