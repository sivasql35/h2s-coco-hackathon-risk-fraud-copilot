-- =============================================================================
-- 00: Synthetic Data Seed Script for RISK_COPILOT.RAW
-- =============================================================================
-- Generates ~2000 customers, ~2800 accounts, ~150K transactions, ~800 loans,
-- 30 days of HQLA & cashflow positions, 18 policy docs, watchlist, and
-- 25 labelled fraud scenarios (12 mule, 7 structuring, 6 round-trip).
-- Run AFTER 01_database_and_schemas.sql and 02_raw_tables.sql.
-- =============================================================================

USE SCHEMA RISK_COPILOT.RAW;

-- ============================================================
-- 1. CUSTOMERS  (~2000 rows)
-- ============================================================
INSERT INTO CUSTOMERS
WITH
  first_names AS (SELECT $1 nm FROM VALUES ('Aarav'),('Arjun'),('Vihaan'),('Rohan'),('Sai'),('Aditya'),('Karan'),('Ishaan'),('Vikram'),('Rahul'),('Neha'),('Priya'),('Ananya'),('Isha'),('Meera'),('Diya'),('Kavya'),('Sanjay'),('Ravi'),('Amit')),
  last_names  AS (SELECT $1 nm FROM VALUES ('Sharma'),('Patel'),('Mehta'),('Das'),('Singh'),('Iyer'),('Nair'),('Reddy'),('Kumar'),('Gupta')),
  cities      AS (SELECT $1 ct FROM VALUES ('Mumbai'),('Delhi'),('Bangalore'),('Hyderabad'),('Chennai'),('Kolkata'),('Pune'),('Jaipur'),('Ahmedabad'),('Lucknow')),
  segments    AS (SELECT $1 sg FROM VALUES ('INDIVIDUAL'),('CORPORATE'),('MSME')),
  kyc_levels  AS (SELECT $1 kl FROM VALUES ('LOW'),('MEDIUM'),('HIGH')),
  occupations AS (SELECT $1 oc FROM VALUES ('Salaried'),('Business'),('Self-Employed'),('Retired'),('Student')),
  nums        AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn FROM TABLE(GENERATOR(ROWCOUNT => 2001)))
SELECT
  'CUST' || LPAD(n.rn, 6, '0'),
  fn.nm || ' ' || ln.nm,
  sg.sg,
  kl.kl,
  ct.ct,
  UNIFORM(1, 100, RANDOM()) <= 3,  -- ~3% PEP
  DATEADD(day, -UNIFORM(180, 3600, RANDOM()), '2026-09-28'::DATE),
  oc.oc,
  UNIFORM(200000, 5000000, RANDOM())
FROM nums n
JOIN first_names fn ON MOD(HASH(n.rn, 1), 20) = fn.nm::VARIANT - fn.nm::VARIANT + MOD(ABS(HASH(n.rn, 1)), 20)
JOIN last_names ln ON TRUE
JOIN cities ct ON TRUE
JOIN segments sg ON TRUE
JOIN kyc_levels kl ON TRUE
JOIN occupations oc ON TRUE
WHERE fn.nm = (SELECT nm FROM first_names ORDER BY ABS(HASH(n.rn, 1) + HASH(nm)) LIMIT 1)
  AND ln.nm = (SELECT nm FROM last_names ORDER BY ABS(HASH(n.rn, 2) + HASH(nm)) LIMIT 1)
  AND ct.ct = (SELECT ct FROM cities ORDER BY ABS(HASH(n.rn, 3) + HASH(ct)) LIMIT 1)
  AND sg.sg = (SELECT sg FROM segments ORDER BY ABS(HASH(n.rn, 4) + HASH(sg)) LIMIT 1)
  AND kl.kl = (SELECT kl FROM kyc_levels ORDER BY ABS(HASH(n.rn, 5) + HASH(kl)) LIMIT 1)
  AND oc.oc = (SELECT oc FROM occupations ORDER BY ABS(HASH(n.rn, 6) + HASH(oc)) LIMIT 1);


-- ============================================================
-- 2. ACCOUNTS  (~2800 rows: mix of SAVINGS, CURRENT, LOAN)
-- ============================================================
INSERT INTO ACCOUNTS
WITH cust AS (SELECT CUSTOMER_ID, ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID) rn FROM CUSTOMERS),
     acct_types AS (
       SELECT rn, CUSTOMER_ID, 'SAVINGS' acct_type FROM cust
       UNION ALL SELECT rn, CUSTOMER_ID, 'CURRENT' FROM cust WHERE MOD(rn, 3) = 0
       UNION ALL SELECT rn, CUSTOMER_ID, 'LOAN' FROM cust WHERE MOD(rn, 2.4) < 1
     )
SELECT
  'ACC' || LPAD(ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID, acct_type), 7, '0'),
  CUSTOMER_ID,
  acct_type,
  DATEADD(day, -UNIFORM(100, 3000, RANDOM()), '2026-09-28'::DATE),
  'ACTIVE',
  UNIFORM(10000, 1000000, RANDOM())
FROM acct_types;


-- ============================================================
-- 3. SYNTH_SCENARIOS  (25 labelled fraud accounts)
-- ============================================================
-- Pick specific accounts for reproducible detection validation
INSERT INTO SYNTH_SCENARIOS
WITH mule_accts AS (
  SELECT ACCOUNT_ID, CUSTOMER_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) rn
  FROM ACCOUNTS WHERE ACCOUNT_TYPE = 'SAVINGS'
  QUALIFY ROW_NUMBER() OVER (ORDER BY HASH(ACCOUNT_ID, 42)) <= 12
),
struct_accts AS (
  SELECT ACCOUNT_ID, CUSTOMER_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) rn
  FROM ACCOUNTS WHERE ACCOUNT_TYPE IN ('SAVINGS','CURRENT')
    AND ACCOUNT_ID NOT IN (SELECT ACCOUNT_ID FROM mule_accts)
  QUALIFY ROW_NUMBER() OVER (ORDER BY HASH(ACCOUNT_ID, 99)) <= 7
),
rt_accts AS (
  SELECT ACCOUNT_ID, CUSTOMER_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) rn
  FROM ACCOUNTS WHERE ACCOUNT_TYPE = 'CURRENT'
    AND ACCOUNT_ID NOT IN (SELECT ACCOUNT_ID FROM mule_accts)
    AND ACCOUNT_ID NOT IN (SELECT ACCOUNT_ID FROM struct_accts)
  QUALIFY ROW_NUMBER() OVER (ORDER BY HASH(ACCOUNT_ID, 77)) <= 6
)
SELECT ACCOUNT_ID, CUSTOMER_ID, 'MULE' FROM mule_accts
UNION ALL SELECT ACCOUNT_ID, CUSTOMER_ID, 'STRUCTURING' FROM struct_accts
UNION ALL SELECT ACCOUNT_ID, CUSTOMER_ID, 'ROUND_TRIP' FROM rt_accts;


-- ============================================================
-- 4. TRANSACTIONS  (~150K rows, 60 days, bulk normal + fraud patterns)
-- ============================================================

-- 4a. Normal transactions (~148K across all accounts)
INSERT INTO TRANSACTIONS
WITH all_accts AS (
  SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) rn, COUNT(*) OVER () tot
  FROM ACCOUNTS WHERE ACCOUNT_TYPE <> 'LOAN'
),
txn_gen AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 148000))
)
SELECT
  'TXN-' || UUID_STRING(),
  a.ACCOUNT_ID,
  'ACC' || LPAD(UNIFORM(1, 2800, RANDOM()), 7, '0'),
  DATEADD(minute, -UNIFORM(0, 86400, RANDOM()), DATEADD(day, -MOD(t.seq, 60), '2026-09-28 23:58:00'::TIMESTAMP_NTZ)),
  CASE UNIFORM(1,5,RANDOM()) WHEN 1 THEN 'UPI' WHEN 2 THEN 'NEFT' WHEN 3 THEN 'IMPS' WHEN 4 THEN 'RTGS' ELSE 'CARD' END,
  IFF(UNIFORM(1,2,RANDOM())=1, 'CREDIT', 'DEBIT'),
  ROUND(UNIFORM(100, 500000, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100, 2),
  'DEV-' || LPAD(UNIFORM(1, 2000, RANDOM()), 5, '0'),
  UNIFORM(1, 255, RANDOM()) || '.' || UNIFORM(0, 255, RANDOM()) || '.' || UNIFORM(0, 255, RANDOM()) || '.' || UNIFORM(0, 255, RANDOM()),
  'IN',
  'NORMAL'
FROM txn_gen t
JOIN all_accts a ON a.rn = MOD(t.seq, a.tot) + 1;


-- 4b. Mule inflow pattern: 15+ credits from distinct remitters in 48h
INSERT INTO TRANSACTIONS
WITH mule AS (SELECT ACCOUNT_ID FROM SYNTH_SCENARIOS WHERE SCENARIO = 'MULE'),
     seq AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) rn FROM TABLE(GENERATOR(ROWCOUNT => 20)))
SELECT
  'TXN-' || UUID_STRING(),
  m.ACCOUNT_ID,
  'ACC' || LPAD(UNIFORM(1, 2800, RANDOM()), 7, '0'),
  DATEADD(minute, -UNIFORM(0, 2880, RANDOM()), '2026-09-28 23:58:00'::TIMESTAMP_NTZ),
  CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'NEFT' WHEN 2 THEN 'IMPS' ELSE 'UPI' END,
  'CREDIT',
  ROUND(UNIFORM(10000, 80000, RANDOM()), 2),
  'DEV-' || LPAD(UNIFORM(1, 2000, RANDOM()), 5, '0'),
  IFF(UNIFORM(1,5,RANDOM())=1, '185.' || UNIFORM(0,255,RANDOM()) || '.0.1',
      UNIFORM(10,220,RANDOM()) || '.' || UNIFORM(0,255,RANDOM()) || '.0.1'),
  IFF(UNIFORM(1,5,RANDOM())=1, 'AE', 'IN'),
  'MULE_INFLOW'
FROM mule m, seq s;

-- 4c. Mule outflow pattern: rapid pass-through via RTGS/NEFT
INSERT INTO TRANSACTIONS
WITH mule AS (SELECT ACCOUNT_ID FROM SYNTH_SCENARIOS WHERE SCENARIO = 'MULE'),
     seq AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) rn FROM TABLE(GENERATOR(ROWCOUNT => 5)))
SELECT
  'TXN-' || UUID_STRING(),
  m.ACCOUNT_ID,
  'ACC' || LPAD(UNIFORM(1, 2800, RANDOM()), 7, '0'),
  DATEADD(minute, -UNIFORM(0, 1440, RANDOM()), '2026-09-28 23:00:00'::TIMESTAMP_NTZ),
  IFF(UNIFORM(1,2,RANDOM())=1, 'RTGS', 'NEFT'),
  'DEBIT',
  ROUND(UNIFORM(50000, 300000, RANDOM()), 2),
  'DEV-' || LPAD(UNIFORM(1, 2000, RANDOM()), 5, '0'),
  IFF(UNIFORM(1,3,RANDOM())=1, '185.' || UNIFORM(0,255,RANDOM()) || '.0.1',
      UNIFORM(10,220,RANDOM()) || '.' || UNIFORM(0,255,RANDOM()) || '.0.1'),
  IFF(UNIFORM(1,4,RANDOM())=1, 'AE', 'IN'),
  'MULE_OUTFLOW'
FROM mule m, seq s;


-- 4d. Structuring pattern: 3+ cash deposits between 9-10 lakh in 10 days
INSERT INTO TRANSACTIONS
WITH struct AS (SELECT ACCOUNT_ID FROM SYNTH_SCENARIOS WHERE SCENARIO = 'STRUCTURING'),
     seq AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) rn FROM TABLE(GENERATOR(ROWCOUNT => 5)))
SELECT
  'TXN-' || UUID_STRING(),
  st.ACCOUNT_ID,
  st.ACCOUNT_ID,
  DATEADD(day, -UNIFORM(0, 10, RANDOM()), '2026-09-28 12:00:00'::TIMESTAMP_NTZ),
  'CASH',
  'CREDIT',
  ROUND(UNIFORM(900000, 999999, RANDOM()), 0),
  'BRANCH',
  '10.0.0.1',
  'IN',
  'STRUCTURING'
FROM struct st, seq s;


-- 4e. Round-trip pattern: circular flows A->B->C->A within 72h
INSERT INTO TRANSACTIONS
WITH rt AS (
  SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) rn
  FROM SYNTH_SCENARIOS WHERE SCENARIO = 'ROUND_TRIP'
),
triplets AS (
  SELECT a.ACCOUNT_ID AS A1, b.ACCOUNT_ID AS A2, c.ACCOUNT_ID AS A3
  FROM rt a JOIN rt b ON b.rn = a.rn + 1 AND MOD(a.rn, 2) = 1
  JOIN rt c ON c.rn = a.rn + 2 AND MOD(a.rn, 2) = 1
)
-- Leg 1: A1 -> A2
SELECT 'TXN-' || UUID_STRING(), A1, A2,
  DATEADD(hour, -60, '2026-09-28 23:00:00'::TIMESTAMP_NTZ), 'NEFT', 'DEBIT',
  ROUND(UNIFORM(1000000, 5000000, RANDOM()), 0),
  'DEV-' || LPAD(UNIFORM(1,500,RANDOM()),5,'0'), '10.1.1.1', 'IN', 'ROUND_TRIP'
FROM triplets
UNION ALL
-- Leg 2: A2 -> A3
SELECT 'TXN-' || UUID_STRING(), A2, A3,
  DATEADD(hour, -36, '2026-09-28 23:00:00'::TIMESTAMP_NTZ), 'RTGS', 'DEBIT',
  ROUND(UNIFORM(1000000, 5000000, RANDOM()), 0),
  'DEV-' || LPAD(UNIFORM(1,500,RANDOM()),5,'0'), '10.1.1.2', 'IN', 'ROUND_TRIP'
FROM triplets
UNION ALL
-- Leg 3: A3 -> A1 (completes the cycle)
SELECT 'TXN-' || UUID_STRING(), A3, A1,
  DATEADD(hour, -12, '2026-09-28 23:00:00'::TIMESTAMP_NTZ), 'NEFT', 'DEBIT',
  ROUND(UNIFORM(1000000, 5000000, RANDOM()), 0),
  'DEV-' || LPAD(UNIFORM(1,500,RANDOM()),5,'0'), '10.1.1.3', 'IN', 'ROUND_TRIP'
FROM triplets;


-- ============================================================
-- 5. LOANS  (~827 rows)
-- ============================================================
INSERT INTO LOANS
WITH loan_accts AS (
  SELECT a.ACCOUNT_ID, a.CUSTOMER_ID, c.SEGMENT, a.OPEN_DATE,
    ROW_NUMBER() OVER (ORDER BY a.ACCOUNT_ID) rn
  FROM ACCOUNTS a JOIN CUSTOMERS c ON c.CUSTOMER_ID = a.CUSTOMER_ID
  WHERE a.ACCOUNT_TYPE = 'LOAN'
),
products   AS (SELECT $1 p FROM VALUES ('PERSONAL'),('TERM_LOAN'),('HOME'),('GOLD'),('WORKING_CAPITAL'),('AUTO')),
industries AS (SELECT $1 i FROM VALUES ('Construction'),('Real Estate'),('Textiles'),('Hospitality'),('IT Services'),('Retail Trade'),('Pharma'),('Agriculture'),('NBFC Lending'),('Auto Components')),
collateral AS (SELECT $1 c FROM VALUES ('RECEIVABLES'),('PROPERTY'),('GOLD'),('VEHICLE'),('UNSECURED'))
SELECT
  la.ACCOUNT_ID,
  la.CUSTOMER_ID,
  la.SEGMENT,
  (SELECT p FROM products ORDER BY ABS(HASH(la.rn, 10) + HASH(p)) LIMIT 1),
  (SELECT i FROM industries ORDER BY ABS(HASH(la.rn, 20) + HASH(i)) LIMIT 1),
  UNIFORM(500000, 50000000, RANDOM()),
  la.OPEN_DATE,
  ROUND(UNIFORM(700, 1400, RANDOM()) / 100, 2),
  (SELECT c FROM collateral ORDER BY ABS(HASH(la.rn, 30) + HASH(c)) LIMIT 1),
  UNIFORM(400, 850, RANDOM()),
  UNIFORM(100000, 40000000, RANDOM()),
  ROUND(UNIFORM(10, 100, RANDOM()), 1),
  CASE UNIFORM(1, 10, RANDOM())
    WHEN 1 THEN UNIFORM(1, 30, RANDOM())
    WHEN 2 THEN UNIFORM(31, 60, RANDOM())
    WHEN 3 THEN UNIFORM(61, 90, RANDOM())
    WHEN 4 THEN UNIFORM(91, 180, RANDOM())
    ELSE 0 END,
  UNIFORM(0, 5, RANDOM()),
  ROUND(UNIFORM(-50, 30, RANDOM()), 1)
FROM loan_accts la;


-- ============================================================
-- 6. HQLA_HOLDINGS  (7 instruments x 30 days = 210 rows)
-- ============================================================
INSERT INTO HQLA_HOLDINGS
WITH dates AS (SELECT DATEADD(day, -SEQ4(), '2026-09-28'::DATE) AS dt FROM TABLE(GENERATOR(ROWCOUNT => 30))),
instruments AS (
  SELECT * FROM VALUES
    ('CASH & CRR EXCESS',   'LEVEL_1', 0,    95000000000),
    ('G-SEC 7.26% 2033',    'LEVEL_1', 0,   444000000000),
    ('T-BILL 364D',         'LEVEL_1', 0,   190000000000),
    ('AA+ CORPORATE BONDS', 'LEVEL_2A', 0.15, 149000000000),
    ('PSU BONDS AAA',       'LEVEL_2A', 0.15,  95000000000),
    ('AA- CORPORATE BONDS', 'LEVEL_2B', 0.5,   32000000000),
    ('NIFTY50 EQUITIES',    'LEVEL_2B', 0.5,   42000000000)
  AS t(INSTRUMENT, HQLA_LEVEL, HAIRCUT, BASE_VALUE)
)
SELECT
  d.dt,
  i.INSTRUMENT,
  i.HQLA_LEVEL,
  i.HAIRCUT,
  ROUND(i.BASE_VALUE * (1 + (UNIFORM(-5, 5, RANDOM()) / 100.0)))
FROM dates d CROSS JOIN instruments i;


-- ============================================================
-- 7. CASHFLOW_POSITIONS  (8 categories x 3 buckets x 30 days = 720 rows)
-- ============================================================
INSERT INTO CASHFLOW_POSITIONS
WITH dates AS (SELECT DATEADD(day, -SEQ4(), '2026-09-28'::DATE) AS dt FROM TABLE(GENERATOR(ROWCOUNT => 30))),
categories AS (
  SELECT * FROM VALUES
    ('Retail deposits - stable',              'OUTFLOW', 0.05, 1677000000000),
    ('Retail deposits - less stable',         'OUTFLOW', 0.10, 1269000000000),
    ('Unsecured wholesale - operational',     'OUTFLOW', 0.25,  272000000000),
    ('Unsecured wholesale - non-operational', 'OUTFLOW', 0.40,  331000000000),
    ('Undrawn committed credit facilities',   'OUTFLOW', 0.10,  316000000000),
    ('Derivative net outflows',               'OUTFLOW', 1.00,   18000000000),
    ('Performing loan inflows (50%)',         'INFLOW',  0.50,  135000000000),
    ('Interbank placements maturing',         'INFLOW',  1.00,   36000000000)
  AS t(CATEGORY, FLOW_TYPE, RATE, BASE_BAL)
),
buckets AS (SELECT $1 bk FROM VALUES ('1-7D'),('8-14D'),('15-30D'))
SELECT
  d.dt,
  c.CATEGORY,
  c.FLOW_TYPE,
  c.RATE,
  b.bk,
  ROUND(c.BASE_BAL * (1 + (UNIFORM(-3, 3, RANDOM()) / 100.0)) *
    CASE b.bk WHEN '1-7D' THEN 0.35 WHEN '8-14D' THEN 0.30 ELSE 0.35 END)
FROM dates d CROSS JOIN categories c CROSS JOIN buckets b;


-- ============================================================
-- 8. POLICY_DOCS  (18 rows - verbatim policy/regulation chunks)
-- ============================================================
INSERT INTO POLICY_DOCS VALUES
('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 3.1 Customer Risk Categorisation','AML','2026-04-01',
 'Customers are categorised LOW, MEDIUM or HIGH risk at onboarding and reviewed periodically. HIGH risk customers (PEPs, sanctions near-matches, complex ownership, high cash intensity) require Enhanced Due Diligence and senior management approval. Periodic KYC updation: HIGH every 2 years, MEDIUM every 8 years, LOW every 10 years, aligned to the RBI KYC Master Direction.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 4.2 Money Mule Red Flags','FRAUD','2026-04-01',
 'Money mule red flags: (a) account opened within 180 days or dormant for 30+ days followed by a sudden burst of inward credits; (b) 15 or more inward credits from distinct remitters within 48 hours; (c) 80% or more of inward value moved out within 24 hours, particularly via RTGS/NEFT to new beneficiaries; (d) access from multiple devices or foreign/unusual IP ranges; (e) transaction volume inconsistent with declared occupation or income (e.g. Student). Two or more red flags require an immediate debit freeze pending investigation and L2 review within 4 business hours.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 4.3 Structuring / Threshold Avoidance','AML','2026-04-01',
 'Structuring is the deliberate splitting of cash deposits to remain below the INR 10 lakh Cash Transaction Report (CTR) threshold. Three or more cash deposits between INR 9 lakh and INR 10 lakh within 10 days from the same customer shall be escalated as suspected structuring and assessed for STR filing.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 4.4 Round-Tripping and Layering','AML','2026-04-01',
 'Round-tripping: funds that leave an account and return to the originator through one or more intermediary accounts within a short window (72 hours) with no evident economic purpose. Circular flows among related current accounts of similar value are indicators of layering and must be escalated to the Principal Officer.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 6.1 STR Filing Timeline','AML','2026-04-01',
 'Once the Principal Officer is satisfied that a transaction is suspicious, the STR must be furnished to FIU-IND within 7 working days, consistent with the PML (Maintenance of Records) Rules. No tipping-off: the customer must not be informed that an STR has been or will be filed. All STR drafts require human (maker-checker) approval before submission.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 6.2 STR Narrative Standard','AML','2026-04-01',
 'The STR narrative must describe Who (customer, KYC risk, linked parties), What (transaction types and values), When (exact date range and timestamps), Where (channels, branches, geographies, IPs), Why (red flags triggered and why activity is inconsistent with profile) and How (flow of funds). It must cite transaction IDs and list missing documents required before submission.'),

('AML-POL-01','Internal AML & CFT Policy v4.1','INTERNAL_POLICY','AML-POL 7.1 Sanctions Screening','AML','2026-04-01',
 'All customers and counterparties are screened against sanctions lists (UN consolidated list, OFAC SDN and domestic lists) at onboarding and on list updates. Match score >= 0.85 requires L2 disposition before any outward transaction is released. Confirmed true matches require account freeze and reporting as mandated.'),

('CR-POL-03','Internal Credit Risk & EWS Policy v2.4','INTERNAL_POLICY','CR-POL 4.1 SMA Classification','CREDIT','2026-02-01',
 'Special Mention Account classification based on days past due (DPD) of principal or interest: SMA-0 = 1-30 days, SMA-1 = 31-60 days, SMA-2 = 61-90 days. Accounts overdue beyond 90 days are classified as Non-Performing Assets (NPA). For IFRS 9 / Ind AS 109 staging, Stage 2 is presumed at 30+ DPD and Stage 3 at 90+ DPD.'),

('CR-POL-03','Internal Credit Risk & EWS Policy v2.4','INTERNAL_POLICY','CR-POL 5.3 EWS Triggers and Actions','CREDIT','2026-02-01',
 'EWS triggers: limit utilisation greater than 90 percent for 60 days, 2 or more NACH/cheque bounces in 90 days, 30 percent or more decline in primary account sales velocity, bureau score below 600. Actions: 1 trigger - watchlist; 2 triggers - limit freeze and collateral revaluation; 3 or more triggers or SMA-2 - restructuring discussion and Credit Committee referral.'),

('CR-POL-03','Internal Credit Risk & EWS Policy v2.4','INTERNAL_POLICY','CR-POL 7.1 Concentration Limits','CREDIT','2026-02-01',
 'Single industry exposure must not exceed 15 percent of total funded exposure; Real Estate and NBFC Lending sectors are capped at 10 percent each. Breaches require CRO sign-off and a remediation plan within 30 days.'),

('ALM-POL-02','Internal ALM & Liquidity Risk Policy v3.0','INTERNAL_POLICY','ALM-POL 5.1 Internal LCR Buffer','LIQUIDITY','2026-01-01',
 'The Board-approved internal LCR floor is 110 percent, above the 100 percent regulatory minimum. A breach of 115 percent triggers an amber alert to ALCO; a breach of 110 percent triggers the Contingency Funding Plan (CFP), including drawing on repo/LAF facilities, reducing wholesale non-operational reliance, and reviewing retail deposit pricing.'),

('ALM-POL-02','Internal ALM & Liquidity Risk Policy v3.0','INTERNAL_POLICY','ALM-POL 6.2 Stress Scenarios','LIQUIDITY','2026-01-01',
 'Mandatory stress scenarios: (S1) 15 percent retail deposit run with 30 percent markdown on Level 2A HQLA; (S2) 50 percent wholesale non-operational withdrawal; (S3) combined idiosyncratic and market-wide stress. Survival horizon under S1 must remain at least 30 days.'),

('REG-BASEL-LCR','Basel III Liquidity Coverage Ratio - Reference Summary','REGULATION_SUMMARY','LCR Minimum and HQLA Composition','LIQUIDITY','2019-01-01',
 'LCR = Stock of HQLA / Total net cash outflows over the next 30 calendar days, and must be at least 100 percent on an ongoing basis. Level 1 assets carry 0 percent haircut. Level 2A assets carry a minimum 15 percent haircut; Level 2B assets carry a 50 percent haircut (for eligible corporate debt and equities). Level 2 assets may not exceed 40 percent of total HQLA and Level 2B may not exceed 15 percent of total HQLA after haircuts. Total inflows are capped at 75 percent of total outflows. [Reference summary; verify against BCBS and RBI LCR guidelines.]'),

('REG-BASEL-LCR','Basel III Liquidity Coverage Ratio - Reference Summary','REGULATION_SUMMARY','LCR Run-off Rates','LIQUIDITY','2019-01-01',
 'Indicative run-off factors: stable retail deposits 5 percent, less stable retail deposits 10 percent, operational unsecured wholesale deposits 25 percent, non-operational unsecured wholesale from non-financial corporates 40 percent, undrawn committed credit facilities to non-financial corporates 10 percent. [Reference summary; verify against RBI LCR circular for local calibration.]'),

('REG-FINCEN-SAR','FinCEN SAR Filing Requirements (31 CFR 1020.320)','REGULATION_SUMMARY','FinCEN SAR Filing Standard Section 2.4','AML','2024-01-15',
 'Financial institutions must file a SAR for any suspicious transaction involving $5,000 or more if the institution knows, suspects, or has reason to suspect that the transaction involves funds derived from illegal activity, is designed to evade BSA requirements, or has no business or apparent lawful purpose. Safe harbor protections apply under 31 U.S.C. 5318(g)(3). Strict prohibition on tipping off.'),

('REG-FINCEN-STR','FinCEN Guidance on Structuring (31 CFR 1010.314)','REGULATION_SUMMARY','FinCEN AML Structuring Guidance Section 3.1','AML','2024-01-15',
 'FinCEN Structuring Rule (31 CFR 1010.314 and 31 U.S.C. 5324): Prohibits structuring transactions to evade Currency Transaction Reporting (CTR) requirements for currency deposits above $10,000. Indicators include multiple cash deposits just below the $10,000 threshold (e.g., $9,000-$9,900) across multiple branches or short timeframes without a clear legitimate business purpose. Reporting entities must file a Suspicious Activity Report (SAR) within 30 days of initial detection.'),

('REG-KYC-MD','RBI Master Direction - KYC - Reference Summary','REGULATION_SUMMARY','KYC MD - Cash Transaction Reports','AML','2025-06-12',
 'Reporting entities must report all cash transactions of value more than INR 10 lakh, or series of integrally connected cash transactions aggregating above INR 10 lakh within a month, to FIU-IND by the 15th of the succeeding month (CTR). [Reference summary for demo; verify against the official Master Direction.]'),

('REG-PMLA','Prevention of Money Laundering Act, 2002 - Reference Summary','REGULATION_SUMMARY','PMLA Section 12','AML','2023-03-07',
 'Section 12 of the PMLA places obligations on every reporting entity (including banks and NBFCs) to maintain records of transactions and to furnish information on prescribed transactions (including suspicious transactions) to the Director, FIU-IND, and to verify the identity of clients. Records must be preserved for five years. [Reference summary for demo; verify against the official gazette text before reliance.]');


-- ============================================================
-- 9. WATCHLIST  (~42 rows: sanctions near-matches + PEP entries)
-- ============================================================
INSERT INTO WATCHLIST
WITH scenario_custs AS (
  SELECT ss.CUSTOMER_ID, c.FULL_NAME, ss.SCENARIO
  FROM SYNTH_SCENARIOS ss JOIN CUSTOMERS c ON c.CUSTOMER_ID = ss.CUSTOMER_ID
),
extra_custs AS (
  SELECT CUSTOMER_ID, FULL_NAME
  FROM CUSTOMERS
  WHERE CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM SYNTH_SCENARIOS)
  QUALIFY ROW_NUMBER() OVER (ORDER BY HASH(CUSTOMER_ID, 55)) <= 17
)
-- High-confidence matches for fraud scenario customers
SELECT
  IFF(MOD(ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID), 2) = 0, 'OFAC_SDN_SYNTH', 'UN_CONSOLIDATED_SYNTH'),
  FULL_NAME,
  CUSTOMER_ID,
  ROUND(UNIFORM(88, 97, RANDOM()) / 100.0, 2),
  '2025-11-01'::DATE,
  'Synthetic name-match hit; requires L2 disposition'
FROM scenario_custs
UNION ALL
-- Lower-confidence matches for non-scenario customers
SELECT
  IFF(MOD(ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID), 3) = 0, 'OFAC_SDN_SYNTH',
    IFF(MOD(ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID), 3) = 1, 'UN_CONSOLIDATED_SYNTH', 'PEP_DOMESTIC')),
  FULL_NAME,
  CUSTOMER_ID,
  ROUND(UNIFORM(60, 84, RANDOM()) / 100.0, 2),
  '2025-11-01'::DATE,
  'Synthetic low-confidence match; likely false positive'
FROM extra_custs;


-- ============================================================
-- Verification
-- ============================================================
SELECT 'CUSTOMERS' tbl, COUNT(*) cnt FROM CUSTOMERS
UNION ALL SELECT 'ACCOUNTS', COUNT(*) FROM ACCOUNTS
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM TRANSACTIONS
UNION ALL SELECT 'LOANS', COUNT(*) FROM LOANS
UNION ALL SELECT 'CASHFLOW_POSITIONS', COUNT(*) FROM CASHFLOW_POSITIONS
UNION ALL SELECT 'HQLA_HOLDINGS', COUNT(*) FROM HQLA_HOLDINGS
UNION ALL SELECT 'POLICY_DOCS', COUNT(*) FROM POLICY_DOCS
UNION ALL SELECT 'WATCHLIST', COUNT(*) FROM WATCHLIST
UNION ALL SELECT 'SYNTH_SCENARIOS', COUNT(*) FROM SYNTH_SCENARIOS
ORDER BY tbl;
