-- =============================================================================
-- 01: Database & Schemas
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS RISK_COPILOT;

CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.RAW;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.CURATED;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.EVIDENCE;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.APP;
