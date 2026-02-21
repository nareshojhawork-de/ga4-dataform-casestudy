-- ============================================================================
-- DDL 03: Gold Layer — top_traffic_source_medium
-- ============================================================================
-- Run this AFTER 01_create_datasets.sql.
--
-- NOTE: Dataform will create this table automatically on first run.
--       This DDL is provided for documentation, manual pre-creation,
--       or if you need to recreate the table outside of Dataform.
--
-- Persistence : Table (full rebuild on each Dataform run)
-- Clustered   : report_month
-- Grain       : One row per (report_month × traffic_source_medium)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
(
  report_month            DATE          NOT NULL    OPTIONS (description = 'First day of the month (truncated from event_date)'),
  traffic_source_medium   STRING        NOT NULL    OPTIONS (description = 'Traffic source medium — NULL values coalesced to (not set)'),
  purchased_value_usd     FLOAT64                   OPTIONS (description = 'Total purchase value in USD for the month'),
  total_purchased_items   INT64                     OPTIONS (description = 'Total items purchased across all transactions in the month'),
  total_purchases         INT64                     OPTIONS (description = 'Number of purchase events (transactions) in the month'),
  avg_items_per_purchase  FLOAT64                   OPTIONS (description = 'Average number of items per transaction')
)
CLUSTER BY report_month
OPTIONS (
  description = 'Gold layer — monthly aggregation of purchase KPIs by traffic source medium. Ranks mediums by value and volume to identify the most impactful acquisition channels.',
  labels = [('layer', 'gold'), ('project', 'ga4_case_study')]
);
