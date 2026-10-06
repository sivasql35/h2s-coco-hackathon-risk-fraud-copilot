---
name: risk-fraud-reg-copilot
description: "Risk, Fraud & Regulatory Intelligence Copilot for banking and NBFC operations. Use when: investigating fraud alerts, generating SAR/STR drafts, running liquidity stress tests, reviewing credit EWS, querying AML/Basel/RBI policy, managing investigation cases, or asking natural language questions about risk data. Triggers: fraud alert, SAR, STR, AML, money mule, structuring, round-tripping, LCR, liquidity, Basel III, credit risk, SMA, NPA, IFRS9, EWS, watchlist, sanctions, investigation case, risk score, compliance, regulatory report, policy citation."
---

# Risk, Fraud & Regulatory Copilot

An end-to-end copilot that surfaces risk and fraud signals and produces audit-ready regulatory outputs from natural language questions. Combines transaction and account data with policy and filing text across four domains:

1. **Real-Time Fraud & Financial Crime** — velocity spikes, device switching, mule accounts, structuring, round-tripping
2. **ALM & Liquidity Risk** — HQLA tracking, LCR/NSFR forecasting, parameterised stress testing
3. **Credit Risk & Early Warning** — SMA-0/1/2, NPA, IFRS 9 staging, industry concentration
4. **Regulatory Reporting & AML Compliance** — SAR/STR narratives, FinCEN/PMLA/RBI/Basel III citations

## Prerequisites

| Requirement | Value |
|-------------|-------|
| Database | `RISK_COPILOT` |
| Warehouse | `COMPUTE_WH` |
| Role | `ACCOUNTADMIN` (or equivalent grants) |
| LLM | Claude Sonnet 4.5 (for SAR generation) |
| Cortex Search | `RISK_COPILOT.CURATED.POLICY_SEARCH` |
| Semantic View | `RISK_COPILOT.CURATED.RISK_INTELLIGENCE_SV` |
| Agent | `RISK_COPILOT.APP.RISK_FRAUD_REG_COPILOT` |

## Workflow

### Step 1: Identify the Domain

Route the user's question to the correct domain:

| Signal | Domain | Action |
|--------|--------|--------|
| Fraud alerts, mule, structuring, round-trip, risk score, red flags | **Fraud Detection** | Query `CURATED.DT_FRAUD_ALERTS` or `DT_ACCOUNT_SIGNALS` |
| LCR, HQLA, liquidity, stress test, Basel III, ALM | **Liquidity Risk** | Query `CURATED.DT_LCR_DAILY` or call `APP.RUN_LIQUIDITY_STRESS` |
| SMA, NPA, DPD, IFRS9, EWS, loan, credit, concentration | **Credit Risk** | Query `CURATED.DT_LOAN_EWS` or `V_INDUSTRY_CONCENTRATION` |
| SAR, STR, filing, policy, regulation, FinCEN, PMLA, RBI KYC | **Regulatory/AML** | Search `CURATED.POLICY_SEARCH` or call `APP.GENERATE_SAR_DRAFT` |
| Case, investigation, review, approve, reject | **Case Management** | Query `APP.CASES` or call `APP.REVIEW_CASE` |
| Executive summary, dashboard, overview | **Executive** | Query `CURATED.V_EXECUTIVE_SUMMARY` |

**If the domain is ambiguous, ask the user before proceeding.**

### Step 2: Execute the Query or Procedure

#### 2a. Analytical Questions (use Cortex Analyst)

For quantitative questions across alerts, accounts, loans, LCR, or concentration:

```
cortex analyst query "<question>" --view=RISK_COPILOT.CURATED.RISK_INTELLIGENCE_SV
```

Or run SQL directly against the relevant dynamic table or view.

#### 2b. Policy and Regulatory Questions (use Cortex Search)

For policy lookups, regulatory rules, definitions, or thresholds:

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'RISK_COPILOT.CURATED.POLICY_SEARCH',
    '<user question>'
  )
)['results'] AS RESULTS;
```

Always ground citations — flag any unverified clause as `[MANUAL POLICY LOOKUP REQUIRED]`.

#### 2c. SAR/STR Generation

When the user asks to draft a SAR or STR for an alert:

```sql
CALL RISK_COPILOT.APP.GENERATE_SAR_DRAFT('<ALERT_ID>');
```

This assembles evidence, retrieves policies, generates a governed narrative with citation guardrails, and creates a `PENDING_REVIEW` case. Always remind the user: **automated STR drafts require human maker-checker review before submission.**

#### 2d. Liquidity Stress Testing

For parameterised LCR stress scenarios:

```sql
CALL RISK_COPILOT.APP.RUN_LIQUIDITY_STRESS(
  <retail_run_pct>, <l2a_markdown_pct>, <wholesale_run_pct>
);
```

#### 2e. Case Review (Maker-Checker)

For approving, rejecting, or requesting info on a case:

```sql
CALL RISK_COPILOT.APP.REVIEW_CASE('<CASE_ID>', '<DECISION>', '<NOTES>');
-- DECISION: APPROVE_FOR_FILING | REJECT | REQUEST_INFO
```

The maker cannot approve their own case (enforced in the procedure).

### Step 3: Format the Response

Structure every answer as:

1. **Finding / Risk Score** (1-100 where applicable)
2. **Contributing Factors & Evidence** (exact IDs, amounts, dates, channels)
3. **Regulatory / Policy Basis** (bracketed citations from policy_search)
4. **Actionable Recommendation** (Freeze Account, Place Hold, Step-Up Auth, File SAR)

**Guardrails:**
- Never invent data or regulatory clause numbers
- Flag unverified clauses as `[MANUAL POLICY LOOKUP REQUIRED]`
- All data is synthetic — remind user when applicable
- Always include identifiers (ALERT_ID, ACCOUNT_ID, LOAN_ID) for evidence-backed answers

### Step 4: Validate (if requested)

Run the validation suite:

```sql
SELECT * FROM RISK_COPILOT.APP.V_VALIDATION_RESULTS;
```

13 tests covering detection recall, data integrity, credit classification, liquidity rules, guardrails, and governance.

## Key Objects Reference

### Dynamic Tables (CURATED schema)

| Table | Lag | Purpose |
|-------|-----|---------|
| `DT_ACCOUNT_SIGNALS` | 15 min | Per-account behavioural signals (velocity, devices, structuring, round-trips) |
| `DT_FRAUD_ALERTS` | 15 min | Rule-based alerts with 9 red flags, each mapped to a policy section |
| `DT_LCR_DAILY` | 1 hour | Basel III LCR with L2 caps, stress LCR, gap buckets |
| `DT_LOAN_EWS` | 1 hour | SMA/NPA classification, IFRS9 staging, EWS triggers and actions |

### Procedures (APP schema)

| Procedure | Purpose |
|-----------|---------|
| `GENERATE_SAR_DRAFT(alert_id)` | Evidence assembly + policy RAG + LLM narrative + guardrail + case creation |
| `REVIEW_CASE(case_id, decision, notes)` | Maker-checker approval (APPROVE/REJECT/REQUEST_INFO) |
| `RUN_LIQUIDITY_STRESS(retail%, l2a%, wholesale%)` | Parameterised LCR stress test |
| `AUTO_TRIAGE(max_drafts)` | Unattended batch: drafts STRs for top alerts + LCR threshold logging |
| `CREATE_INVESTIGATION_CASE(finding_id, priority, summary)` | Create investigation from evidence findings |
| `GENERATE_AUDIT_PACKAGE(finding_id)` | Audit-ready finding + evidence bundle |

### Views (CURATED schema)

| View | Purpose |
|------|---------|
| `V_EXECUTIVE_SUMMARY` | Single-row KPI dashboard (alerts, LCR, NPA, SMA, cases) |
| `V_INDUSTRY_CONCENTRATION` | Sector exposure vs policy limits with breach flags |
| `V_NETWORK_GRAPH` | Transaction flow + shared device links for flagged accounts |
| `V_RECENT_HIGH_RISK_TXNS` | Last 48h transactions for accounts with risk score >= 45 |

### Tasks (automated pipeline)

| Task | Schedule | Condition |
|------|----------|-----------|
| `T_BUILD_RISK_FINDINGS` | 5 min | `SYSTEM$STREAM_HAS_DATA` on TRANSACTION_CHANGE_STREAM |
| `T_BUILD_EVIDENCE` | After T_BUILD_RISK_FINDINGS | Child task |
| `T_AUTO_TRIAGE` | Hourly (CRON) | Always runs |

## Sample Questions

- "Why should I file a SAR for customer CUST-9821?"
- "Which customers show structuring behavior today?"
- "What is our current LCR, and what happens under a 15% retail run with a 30% Level 2A markdown?"
- "Explain why account ACC0000524 was flagged, citing the policy for each red flag"
- "Which industries breach concentration limits and how much SMA-2 exposure do they carry?"
- "Show the network of accounts connected to Customer CUST000371"

## Stopping Points

- After Step 1 if domain is ambiguous — ask user to clarify
- After Step 2c (SAR generation) — remind about maker-checker review
- After Step 2e (case review) — confirm the decision was applied

## Output

Evidence-backed, policy-grounded answers with exact identifiers, citations, and actionable recommendations. SAR drafts include guardrail validation and require human approval before filing.
