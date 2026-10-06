# Risk, Fraud & Regulatory Intelligence Copilot

## 1. Project Overview

The **Risk, Fraud & Regulatory Intelligence Copilot** is an end-to-end financial risk management solution built on **Snowflake**.

The system helps banks and financial institutions detect suspicious transactions, monitor credit risk, check liquidity risk, and generate regulatory reports.

It combines:

* Fraud detection
* Credit early-warning monitoring
* Basel III liquidity monitoring
* Policy and regulatory document search
* AI-powered SAR/STR draft generation
* Investigation case management
* Evidence collection
* Audit and validation controls
* Streamlit dashboard
* Snowflake Cortex Agent and Cortex Search

The main goal is to provide a single platform where a risk or compliance analyst can ask a question in natural language and receive an explainable answer backed by transaction data, evidence, and policy information.

---

# 2. High-Level Architecture

The solution has four major layers:

```text
RAW
  ↓
CURATED
  ↓
EVIDENCE
  ↓
APP
```

### RAW Layer

The RAW layer contains the original source data.

Examples include:

* Customer information
* Accounts
* Transactions
* Loans
* Liquidity information
* Policy documents

This layer is mainly used as the source for downstream processing.

### CURATED Layer

The CURATED layer processes the raw data and creates useful analytical datasets.

Important objects include:

**DT_ACCOUNT_SIGNALS**

Identifies customer/account behavioural signals.

**DT_FRAUD_ALERTS**

Creates explainable fraud alerts based on defined rules.

**DT_LCR_DAILY**

Calculates Basel III Liquidity Coverage Ratio information.

**DT_LOAN_EWS**

Provides credit early-warning signals.

Dynamic tables are used so that the analytical information can be refreshed automatically.

### EVIDENCE Layer

The EVIDENCE layer connects risk findings with supporting evidence.

A Snowflake stream monitors transaction changes.

Tasks then process the changes and create:

* Risk findings
* Supporting evidence
* Investigation information

This creates an evidence chain that can be used by analysts and auditors.

### APP Layer

The APP layer provides the user-facing intelligence and actions.

It contains:

* Cortex Agent
* Cortex Search
* Semantic View
* Stored procedures
* Investigation cases
* Audit logs

The main Cortex Agent is:

```text
RISK_FRAUD_REG_COPILOT
```

The agent can use analytical data, policy documents, and controlled procedures to answer risk-related questions.

---

# 3. Project Structure

The project is organized into several folders.

```text
h2s-coco-hackathon-risk-fraud-copilot/

├── setup/
├── data-pipeline/
├── app/
├── cortex/
├── risk-copilot-dashboard/
├── skill/
└── docs/
```

### setup

Contains database creation, raw tables, and synthetic data generation.

### data-pipeline

Contains:

* Dynamic tables
* Analytical views
* Streams
* Tasks
* Evidence processing
* Document ingestion

### app

Contains:

* Application tables
* Audit logs
* Validation functions
* Stored procedures

### cortex

Contains:

* Cortex Search
* Semantic View
* Cortex Agent

### risk-copilot-dashboard

Contains the Streamlit dashboard.

### skill

Contains the reusable CoCo skill definition.

This structure keeps data engineering, application logic, AI components, and user interface components separate.

---

# 4. Deployment Order

The SQL scripts should be executed in sequence.

The basic deployment process is:

1. Create the database and schemas.
2. Create the RAW tables.
3. Generate synthetic data.
4. Create CURATED dynamic tables.
5. Create analytical views.
6. Create evidence tables and streams.
7. Create application tables and views.
8. Create validation functions.
9. Create stored procedures.
10. Create Cortex Search.
11. Create the Semantic View.
12. Create the Cortex Agent.
13. Create scheduled tasks.
14. Configure document ingestion.
15. Resume tasks.
16. Start the Streamlit dashboard.

This order is important because later components depend on objects created earlier.

---

# 5. Main Features

## Fraud Detection

The system uses rule-based fraud detection to identify suspicious behaviour.

It covers patterns such as:

* Structuring
* Round-tripping
* Mule activity
* PEP-related activity
* Watchlist-related activity

The system creates explainable alerts rather than simply producing a risk score.

## Credit Early Warning

The system monitors loans and identifies credit risk.

It supports:

* SMA classification
* NPA classification
* IFRS9 staging
* Early-warning triggers

This allows risk teams to identify potentially problematic loans earlier.

## Liquidity Monitoring

The system calculates Basel III Liquidity Coverage Ratio information.

It also supports:

* Liquidity stress testing
* Gap analysis
* L2 asset limits
* Liquidity exposure monitoring

## SAR/STR Generation

The system can create AI-assisted drafts for suspicious transaction reporting.

However, the system includes controls so that the generated information is grounded in available evidence and policy information.

A maker-checker workflow is also included so that human review remains part of the process.

## Policy RAG

Cortex Search is used to search AML, ALM, credit, and regulatory policy documents.

This allows the AI system to use relevant policy information when explaining a finding.

## Validation

The solution contains automated tests for:

* Fraud detection
* Data integrity
* Credit rules
* Liquidity rules
* Citation guardrails
* Governance

## Dashboard

A Streamlit dashboard provides a visual view of the system.

---

# 6. Streamlit Dashboard

The dashboard contains five main areas.

### Executive Summary

Shows important KPIs such as:

* Open alerts
* Freeze alerts
* SAR status
* Outflow exposure
* LCR
* NPA percentage
* SMA information

### Fraud Alerts

Shows fraud alerts with filters for:

* Fraud type
* Action
* Risk score

Charts can also be used to understand alert distribution.

### Liquidity

Shows:

* Current LCR
* Stress metrics
* LCR trends
* Liquidity gap information

### Credit EWS

Shows:

* Loan classification
* Industry concentration
* EWS actions
* Loan-level information

### Cases & Validation

Shows investigation cases and validation results.

The application can be opened in Snowflake Workspace and run as a Streamlit application.

---

# 7. CoCo Development Lifecycle

One of the major strengths of this project is that **Snowflake CoCo was used across the complete development lifecycle**.

## Phase 1 — Planning

CoCo was used to:

* Explore the Snowflake database
* Understand existing tables
* Profile data
* Design the architecture
* Identify missing components

The architecture was designed around:

```text
RAW → CURATED → EVIDENCE → APP
```

## Phase 2 — Development

CoCo was used to build:

* Synthetic datasets
* Dynamic tables
* Views
* Evidence pipelines
* Stored procedures
* Validation functions
* Cortex Search
* Semantic View
* Cortex Agent
* Streamlit dashboard
* Reusable CoCo skill

The synthetic dataset contains approximately 150K+ rows and includes fraud scenarios such as mule activity, structuring, and round-tripping.

## Phase 3 — Execution

CoCo was used to monitor and manage:

* Tasks
* Streams
* Task schedules
* Task history
* SQL execution
* SQL debugging

It was also used to identify and correct task scheduling and SQL issues.

## Phase 4 — Testing

The solution was tested for:

* Fraud detection
* False positives
* Explainability
* Data integrity
* Credit classification
* Liquidity calculations
* Citation validation
* Governance

The document reports successful validation of the listed tests.

---

# 8. CoCo Capabilities Demonstrated

The project demonstrates several CoCo capabilities.

### Data Generation

CoCo generated synthetic financial data containing realistic fraud patterns.

### Data Engineering

CoCo helped create:

* Dynamic tables
* Streams
* Tasks
* Views

### Semantic Modeling

The project includes a semantic view called:

```text
RISK_INTELLIGENCE_SV
```

This allows business questions to be answered using a structured semantic model.

### AI and Document Processing

The project uses AI document processing to ingest policy PDFs.

### Reusable Skills

A reusable:

```text
/risk-fraud-reg-copilot
```

skill is included.

### Guardrails

The solution includes citation validation and human-review controls.

### Custom Tools

Stored procedures are exposed as controlled tools for operations such as:

* SAR generation
* Liquidity stress testing
* Case review

### Testing

Automated validation checks the quality of the overall solution.

---

# 9. Different Ways to Use the System

The solution can be accessed through different Snowflake/CoCo surfaces.

## Snowsight Agent

Compliance officers can ask questions in natural language.

For example:

> What are the highest-risk fraud alerts right now?

or:

> Why was this customer flagged?

The agent can combine analytical information, policy search, and procedures to provide an answer.

## CoCo Snowsight

Developers and data engineers can use CoCo to:

* Build SQL
* Debug pipelines
* Run queries
* Test the system
* Use the reusable skill
* Run the Streamlit dashboard

## CoCo CLI

The same solution can be used from the command line for automation and development activities.

Examples include querying analytical information, searching policies, running validation, and checking task health.

## Slack

The solution can also be integrated with Slack so that teams can interact with the risk copilot from their messaging environment.

---

# 10. Users and Responsibilities

Different users can use different parts of the solution.

### Compliance Officer

Uses the Cortex Agent and Slack to:

* Investigate alerts
* Review SAR drafts
* Review cases

### Risk Analyst

Uses the Streamlit dashboard to:

* Monitor KPIs
* Review fraud alerts
* Monitor liquidity
* Track risk trends

### Data Engineer

Uses CoCo Snowsight and CoCo CLI to:

* Build pipelines
* Debug SQL
* Monitor tasks
* Run validations
* Deploy changes

### Management / CISO

Uses dashboards and alerts for:

* Executive summaries
* Risk escalation
* Overall risk monitoring

### Auditor

Uses the Agent to:

* Review evidence
* Check policy grounding
* Generate audit information

---

# 11. Simple End-to-End Flow

The complete project can be explained simply as:

```text
Customer / Transaction Data
          ↓
       RAW Layer
          ↓
 Fraud + Credit + Liquidity Processing
          ↓
     CURATED Layer
          ↓
    Risk Finding Created
          ↓
      EVIDENCE Layer
          ↓
 Policy / Regulatory Search
          ↓
      Cortex Agent
          ↓
 Explainable Risk Response
          ↓
 Investigation / SAR / Audit
```

For example, if a customer's transaction activity looks suspicious, the system can identify the fraud pattern, calculate the relevant risk information, collect supporting evidence, search applicable policy documents, and provide the analyst with an explainable finding.

The analyst can then review the case and decide the appropriate next step.

---

# 12. Overall Value

The main value of this project is that it brings multiple financial-risk activities into one Snowflake-based platform.

Instead of having separate systems for fraud, credit risk, liquidity, policy documents, and investigations, the solution connects them through a common architecture.

The most important concept is:

**Signal → Evidence → Explanation → Human Review → Action**

The system is therefore not simply an AI chatbot. It combines Snowflake data engineering, automated pipelines, rule-based risk detection, AI capabilities, policy search, evidence tracking, governance, and human review.

This makes it suitable as a demonstration of an end-to-end **Risk, Fraud and Regulatory Intelligence Copilot** built using Snowflake and CoCo.
