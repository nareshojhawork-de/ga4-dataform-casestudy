-- ============================================================================
-- DDL 01: Create Datasets
-- ============================================================================
-- Run this FIRST in the BigQuery Console (SQL Workspace).
--
-- Creates two datasets:
--   1. ga4_dataform            — All Bronze/Silver/Gold tables live here
--   2. ga4_dataform_assertions — Dataform assertion results are stored here
-- ============================================================================

-- Primary dataset for all pipeline tables
CREATE SCHEMA IF NOT EXISTS `p-ga4-dataform-demo-dev.ga4_dataform`
OPTIONS (
  description = 'GA4 Dataform Case Study — Bronze/Silver/Gold medallion pipeline tables.',
  location = 'US',
  default_table_expiration_days = NULL,
  labels = [('project', 'ga4_case_study'), ('layer', 'all')]
);

-- Assertions dataset (Dataform writes test results here)
CREATE SCHEMA IF NOT EXISTS `p-ga4-dataform-demo-dev.ga4_dataform_assertions`
OPTIONS (
  description = 'Dataform assertion results for the GA4 pipeline.',
  location = 'US',
  labels = [('project', 'ga4_case_study'), ('purpose', 'assertions')]
);
