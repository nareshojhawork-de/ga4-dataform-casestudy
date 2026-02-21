-- ============================================================================
-- DDL 05: Populate Gold — top_traffic_source_medium
-- ============================================================================
-- Standalone BigQuery SQL equivalent of the Dataform table action.
-- Use this for manual execution or validation outside of Dataform.
--
-- This is always a full rebuild (CREATE OR REPLACE) since the gold layer
-- is a small aggregate table.
-- ============================================================================

CREATE OR REPLACE TABLE `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
CLUSTER BY report_month
OPTIONS (
  description = 'Gold layer — monthly aggregation of purchase KPIs by traffic source medium.',
  labels = [('layer', 'gold'), ('project', 'ga4_case_study')]
)
AS
SELECT
  DATE_TRUNC(event_date, MONTH)                              AS report_month,
  COALESCE(traffic_source_medium, '(not set)')               AS traffic_source_medium,
  ROUND(SUM(event_value_in_usd), 2)                          AS purchased_value_usd,
  SUM(total_items)                                            AS total_purchased_items,
  COUNT(*)                                                    AS total_purchases,
  ROUND(SAFE_DIVIDE(SUM(total_items), COUNT(*)), 2)           AS avg_items_per_purchase
FROM
  `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`
GROUP BY
  report_month,
  traffic_source_medium
ORDER BY
  report_month DESC,
  purchased_value_usd DESC;
