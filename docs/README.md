# Risk, Fraud & Regulatory Intelligence Copilot

An end-to-end risk intelligence system built on Snowflake, combining rule-based fraud detection, credit early warning, Basel III liquidity monitoring, and AI-powered SAR/STR generation with citation guardrails.

## Architecture

```
RAW (source tables)
 |
 v
CURATED (dynamic tables + views)
 |   - DT_ACCOUNT_SIGNALS  (15-min lag, behavioural signals)
 |   - DT_FRAUD_ALERTS      (15-min lag, explainable alerts)
 |   - DT_LCR_DAILY         (1-hr lag, Basel III LCR)
 |   - DT_LOAN_EWS          (1-hr lag, credit EWS)
 |
 v
EVIDENCE (findings + evidence chain)
 |   - Stream on RAW.TRANSACTIONS triggers task pipeline
 |   - T_BUILD_RISK_FINDINGS -> T_BUILD_EVIDENCE
 |
 v
APP (agent, procedures, cases, audit log)
     - Cortex Agent: RISK_FRAUD_REG_COPILOT
     - Cortex Search: POLICY_SEARCH (RAG over policy docs)
     - Semantic View: RISK_INTELLIGENCE_SV
     - Procedures: GENERATE_SAR_DRAFT, REVIEW_CASE, RUN_LIQUIDITY_STRESS
```

## Folder Structure

```
h2s-coco-hackathon-risk-fraud-copilot/
│
├── app/
│   ├── 06_app_tables_and_views.sql       -- Cases, audit log, validation suite
│   ├── 07_functions.sql                  -- Citation guardrail UDF
│   └── 08_procedures.sql                -- SAR draft, review, stress test, triage
│
├── cortex/
│   ├── 09_cortex_search.sql              -- Cortex Search service (policy RAG)
│   ├── 10_semantic_view.sql              -- Semantic view for Cortex Analyst
│   └── 11_cortex_agent.sql               -- Cortex Agent definition
│
├── data-pipeline/
│   ├── 03_curated_dynamic_tables.sql     -- Dynamic tables (signals, alerts, LCR, EWS)
│   ├── 04_curated_views.sql              -- Analytical views
│   ├── 05_evidence_tables_and_stream.sql -- Evidence chain tables + stream
│   ├── 12_tasks.sql                      -- Scheduled tasks (findings, evidence, auto-triage)
│   └── 13_document_ingestion.sql         -- Stage + AI_PARSE_DOCUMENT pipeline for PDF ingestion
│
├── docs/
│   └── README.md
│
├── risk-copilot-dashboard/               -- Streamlit executive dashboard
│   ├── .streamlit/
│   │   └── config.toml
│   ├── pyproject.toml
│   ├── snowflake.yml
│   └── streamlit_app.py
│
├── skill/                                -- Reusable CoCo skill definition
│   └── SKILL.md                          -- Shareable skill (also in .snowflake/cortex/skills/)
│
└── setup/
    ├── 00_seed_data.sql                  -- Synthetic data generation (~150K+ rows)
    ├── 01_database_and_schemas.sql       -- Database & schema creation
    └── 02_raw_tables.sql                 -- Source/landing zone tables
```

## Deployment Order

Run scripts in numbered order (01 through 12):

1. `setup/01_database_and_schemas.sql`
2. `setup/02_raw_tables.sql`
3. `setup/00_seed_data.sql` (generates all synthetic data)
4. `data-pipeline/03_curated_dynamic_tables.sql`
5. `data-pipeline/04_curated_views.sql`
6. `data-pipeline/05_evidence_tables_and_stream.sql`
7. `app/06_app_tables_and_views.sql`
8. `app/07_functions.sql`
9. `app/08_procedures.sql`
10. `cortex/09_cortex_search.sql`
11. `cortex/10_semantic_view.sql`
12. `cortex/11_cortex_agent.sql`
13. `data-pipeline/12_tasks.sql`
14. `data-pipeline/13_document_ingestion.sql`
15. Resume tasks when ready
16. Open `risk-copilot-dashboard/streamlit_app.py` in Workspace and click **Run**

## Key Features

- **Fraud Detection**: 9 rule-based red flags (structuring, round-tripping, mule patterns, PEP, watchlist)
- **Credit EWS**: SMA-0/1/2/NPA classification, IFRS9 staging, EWS triggers
- **Liquidity**: Basel III LCR with L2 caps, stress testing, gap analysis
- **SAR Generation**: AI-powered STR drafts with citation guardrails and maker-checker workflow
- **Policy RAG**: Cortex Search over AML/ALM/Credit policy documents
- **Validation Suite**: 14 automated tests covering detection recall, data integrity, and guardrails
- **Executive Dashboard**: Streamlit app with 5 tabs (summary, fraud, LCR, credit, cases)
- **Document Ingestion**: AI_PARSE_DOCUMENT pipeline — upload PDFs to stage, auto-parse into POLICY_DOCS
- **Reusable CoCo Skill**: Shareable skill definition for the copilot

## Streamlit Dashboard

The `risk-copilot-dashboard/` folder contains a Workspace Streamlit app with:

| Tab | Content |
|-----|---------|
| **Executive Summary** | KPI cards — open alerts, freeze alerts, pending/filed SARs, outflow exposure, LCR, NPA %, SMA |
| **Fraud Alerts** | Filterable alert table with typology/action/score filters, distribution charts |
| **Liquidity (LCR)** | Latest LCR & stress metrics, 30-day trend chart, gap bucket analysis |
| **Credit EWS** | Asset classification, industry concentration vs limits, loan book with EWS actions |
| **Cases & Validation** | Investigation case tracker + 14-test validation suite with pass/fail |

**To run:** Open `risk-copilot-dashboard/streamlit_app.py` in the Workspace and click **Run**. The app uses `COMPUTE_WH` and `SYSTEM_COMPUTE_POOL_CPU`.

## Prerequisites

- Snowflake account with Cortex AI features enabled
- `COMPUTE_WH` warehouse
- `SYSTEM_COMPUTE_POOL_CPU` compute pool (for Streamlit dashboard)
- `ACCOUNTADMIN` role (or equivalent grants)
- Claude Sonnet 4.5 model access for SAR generation

## CoCo Lifecycle Evidence

The entire solution was built end-to-end using Snowflake CoCo (Cortex Code) across all four hackathon phases.

### Phase 1: Planning

CoCo was used to explore the existing `RISK_COPILOT` database, understand table structures, and design the solution architecture before any code was written.

| Activity | How CoCo Was Used |
|----------|-------------------|
| Database exploration | `SHOW SCHEMAS`, `INFORMATION_SCHEMA.TABLES` to map all 28 objects across 4 schemas |
| Data profiling | Queried distinct values, row counts, and sample data across all RAW tables to understand domains |
| Architecture design | CoCo drafted the 4-layer architecture (RAW → CURATED → EVIDENCE → APP) with schema separation |
| Gap analysis | Audited the hackathon problem statement against existing objects to identify missing components |

### Phase 2: Development

Every SQL file, procedure, view, agent definition, Streamlit app, and skill was authored through CoCo.

| Component | CoCo Actions |
|-----------|--------------|
| **Synthetic data** (`00_seed_data.sql`) | Generated ~150K+ rows of referentially consistent data by analyzing existing patterns — Indian names, account types, transaction channels, fraud scenarios (12 mule, 7 structuring, 6 round-trip) |
| **Dynamic tables** (03) | CoCo extracted DDL via `GET_DDL()` for all 4 dynamic tables (DT_ACCOUNT_SIGNALS, DT_FRAUD_ALERTS, DT_LCR_DAILY, DT_LOAN_EWS) and structured them into deployment scripts |
| **Views** (04) | 7 analytical views including V_EXECUTIVE_SUMMARY, V_NETWORK_GRAPH, V_INDUSTRY_CONCENTRATION |
| **Evidence pipeline** (05) | Tables + TRANSACTION_CHANGE_STREAM for incremental processing |
| **Procedures** (08) | 6 stored procedures — GENERATE_SAR_DRAFT (AI_COMPLETE with citation guardrails), REVIEW_CASE (maker-checker), RUN_LIQUIDITY_STRESS (parameterised Basel III), AUTO_TRIAGE (batch processing), CREATE_INVESTIGATION_CASE, GENERATE_AUDIT_PACKAGE |
| **Functions** (07) | VALIDATE_CITATIONS guardrail UDF — regex + array matching to detect fabricated policy references |
| **Cortex Search** (09) | POLICY_SEARCH service over 18 policy/regulation documents |
| **Semantic View** (10) | RISK_INTELLIGENCE_SV with 6 tables, 2 relationships, 16 facts, 30 dimensions, 14 metrics, 4 verified queries |
| **Cortex Agent** (11) | RISK_FRAUD_REG_COPILOT with 5 tools (Cortex Analyst, Cortex Search, 3 procedure-backed tools) |
| **Tasks** (12) | 3 scheduled tasks — T_BUILD_RISK_FINDINGS (stream-triggered), T_BUILD_EVIDENCE (child task), T_AUTO_TRIAGE (hourly CRON) |
| **Document ingestion** (13) | AI_PARSE_DOCUMENT pipeline — stage, tracking table, parser procedure, hourly task |
| **Streamlit dashboard** | 5-tab executive dashboard (357 lines) with KPI cards, filterable tables, charts, validation suite |
| **CoCo Skill** | Reusable `/risk-fraud-reg-copilot` skill with domain routing, tool integration, guardrails, and sample questions |

### Phase 3: Execution

CoCo executed and orchestrated the complete solution including task management and monitoring.

| Activity | How CoCo Was Used |
|----------|-------------------|
| Task monitoring | `SHOW TASKS IN DATABASE RISK_COPILOT` to inspect schedules and states |
| Task history | `SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY` to review 20 most recent runs — identified the task was running every minute instead of every 5 |
| Task management | `ALTER TASK ... SUSPEND` when stream had no data; verified with `SYSTEM$STREAM_HAS_DATA()` |
| Stream monitoring | Checked stream freshness and data availability before task operations |
| SQL debugging | Fixed `INFORMATION_SCHEMA.TASK_HISTORY` compilation error (missing database prefix) |
| Project organization | Created structured folder layout, moved files, and maintained README throughout |

### Phase 4: Testing & Validation

CoCo ran the full validation suite and verified correctness across all domains.

| Test Category | Tests | Result |
|---------------|-------|--------|
| **Detection recall** | Mule (12/12), Structuring (7/7), Round-trip (6/6) | All PASS |
| **False positives** | Zero alerts on clean accounts | PASS |
| **Explainability** | Every red flag maps to an existing policy section | PASS |
| **Data integrity** | No orphan transactions, no duplicate TXN_IDs | All PASS |
| **Credit rules** | SMA classification consistent with DPD | PASS |
| **Liquidity rules** | L2 share <= 40% HQLA, LCR status matches thresholds | All PASS |
| **Guardrails** | Fabricated citations caught, grounded citations pass | All PASS |
| **Governance** | Every case has `human_review_required = TRUE` | PASS |

**Result: 13/13 tests PASS** — validated via `SELECT * FROM RISK_COPILOT.APP.V_VALIDATION_RESULTS`

### CoCo Features Demonstrated

| CoCo Capability | Where Used |
|-----------------|------------|
| **Synthetic data generation** | `00_seed_data.sql` — ~150K rows with fraud patterns |
| **Data pipeline creation** | Dynamic tables, streams, tasks (incremental + near-real-time) |
| **Semantic model authoring** | RISK_INTELLIGENCE_SV with verified queries |
| **Streamlit app generation** | 5-tab executive dashboard scaffolded and written by CoCo |
| **Document processing** | AI_PARSE_DOCUMENT pipeline for policy PDF ingestion |
| **Reusable skill creation** | `/risk-fraud-reg-copilot` published to `.snowflake/cortex/skills/` |
| **Guardrails & fallback** | Citation validation UDF, maker-checker enforcement, `[MANUAL POLICY LOOKUP REQUIRED]` fallback |
| **Testing & validation** | 13-test automated suite covering detection, data, rules, and governance |
| **Custom tools & function calling** | Agent tools backed by stored procedures (SAR draft, stress test, case review) |
| **SQL authoring & debugging** | Fixed compilation errors, optimized queries, authored all DDL |
| **Working across surfaces** | Same solution accessible via Snowsight Agent, CoCo Snowsight, CoCo CLI, and Slack |

### Working Across Surfaces

The solution is designed to be accessed from every CoCo surface, giving different users the right interface for their role.

#### 1. Snowsight Cloud Agent (Compliance Officers & Analysts)

The Cortex Agent `RISK_COPILOT.APP.RISK_FRAUD_REG_COPILOT` is accessible directly in Snowsight under **AI & ML > Cortex Agents**. Business users interact in natural language without SQL:

```
User: "Why should I file a SAR for customer CUST-9821?"
Agent: [calls risk_analytics + policy_search + generate_str_draft]
       → Returns structured finding with evidence, policy citations, and draft narrative
```

**How to access:** Navigate to Snowsight > AI & ML > Cortex Agents > `RISK_FRAUD_REG_COPILOT`

Sample questions the agent handles:
- "What are the highest-risk fraud alerts right now?"
- "Run a liquidity stress test with 15% retail run and 30% L2A markdown"
- "Which industries breach concentration limits?"
- "Approve case CASE-ACC0000524-20261005070000 with notes: evidence sufficient"

#### 2. CoCo in Snowsight (Developers & Data Engineers)

CoCo in Snowsight Workspaces was used to build, test, and iterate on the entire solution. The reusable skill makes the copilot available in any CoCo session:

```
/risk-fraud-reg-copilot
> "Show me all FREEZE_ACCOUNT alerts with risk score above 80"
```

CoCo Snowsight is also where the Streamlit dashboard runs — open `risk-copilot-dashboard/streamlit_app.py` and click **Run** for the visual executive view.

#### 3. CoCo CLI (DevOps & Automation)

The same skill and queries work from the CoCo CLI for scripting, CI/CD, and headless operation:

```bash
# Query the agent via Cortex Analyst CLI
cortex analyst query "What is the current LCR and stress LCR?" \
  --view=RISK_COPILOT.CURATED.RISK_INTELLIGENCE_SV

# Search policies
cortex search object "AML structuring threshold" --types=table

# Run validation suite
snow sql -q "SELECT * FROM RISK_COPILOT.APP.V_VALIDATION_RESULTS"

# Check task health
snow sql -q "SELECT NAME, STATE, SCHEDULED_TIME FROM TABLE(
  RISK_COPILOT.INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'T_BUILD_RISK_FINDINGS',
    RESULT_LIMIT => 5
  )) ORDER BY SCHEDULED_TIME DESC"
```

#### 4. Slack Integration (Operations & Escalation)

The Cortex Agent can be surfaced through Snowflake's Slack integration, enabling real-time alerts and investigation from messaging:

**Setup:**
1. Configure the Snowflake Slack connector in your Snowflake account
2. Add the `RISK_FRAUD_REG_COPILOT` agent to a Slack channel
3. Team members can then query directly from Slack:

```
@Snowflake Why was account ACC0000524 flagged?
@Snowflake What is today's LCR status?
@Snowflake Generate a SAR draft for alert ALR-ACC0009821
```

**Use cases by role:**

| Role | Primary Surface | Use Case |
|------|----------------|----------|
| Compliance Officer | Snowsight Agent + Slack | Investigate alerts, review SAR drafts, approve cases |
| Risk Analyst | Streamlit Dashboard | Monitor KPIs, filter alerts, track LCR trends |
| Data Engineer | CoCo Snowsight + CLI | Build pipelines, debug tasks, run validations |
| CISO / Management | Slack + Dashboard | Executive summary, escalation alerts |
| Auditor | Snowsight Agent | Generate audit packages, verify policy grounding |

#### Surface Comparison

| Capability | Snowsight Agent | CoCo Snowsight | CoCo CLI | Slack |
|-----------|:-:|:-:|:-:|:-:|
| Natural language fraud investigation | Y | Y | Y | Y |
| SAR/STR draft generation | Y | Y | Y | Y |
| Liquidity stress testing | Y | Y | Y | Y |
| Case review (maker-checker) | Y | Y | Y | Y |
| Policy search (RAG) | Y | Y | - | Y |
| SQL execution & debugging | - | Y | Y | - |
| Streamlit dashboard | - | Y | - | - |
| Task monitoring & management | - | Y | Y | - |
| Skill development & iteration | - | Y | Y | - |
| Pipeline deployment | - | Y | Y | - |
| Scheduled automations | - | Y | Y | - |


