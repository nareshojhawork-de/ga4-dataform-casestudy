-- ============================================================================
-- DDL 06: Validation & Export Queries
-- ============================================================================
-- Run these AFTER the pipeline has completed to verify data quality
-- and export the gold table for the case study deliverable.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. VERIFY SOURCE DATA ACCESS
--    Confirms you can read the public GA4 dataset.
-- ────────────────────────────────────────────────────────────────────────────
SELECT *
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
LIMIT 5;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. COUNT SOURCE PURCHASES
--    Baseline count of purchase events in the raw data.
-- ────────────────────────────────────────────────────────────────────────────
SELECT
  COUNT(*)                                                    AS total_purchase_events,
  COUNT(DISTINCT user_pseudo_id)                              AS distinct_users,
  MIN(event_date)                                             AS earliest_date,
  MAX(event_date)                                             AS latest_date
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  event_name = 'purchase';


-- ────────────────────────────────────────────────────────────────────────────
-- 3. VERIFY SILVER TABLE
--    Row count and date range should match source (minus deleted rows).
-- ────────────────────────────────────────────────────────────────────────────
SELECT
  COUNT(*)                                                    AS row_count,
  COUNT(DISTINCT user_pseudo_id)                              AS distinct_users,
  MIN(event_date)                                             AS earliest_date,
  MAX(event_date)                                             AS latest_date,
  COUNTIF(event_value_in_usd IS NULL)                         AS null_value_count,
  COUNTIF(traffic_source_medium LIKE '%(data deleted)%')      AS deleted_rows_leaked  -- Should be 0
FROM
  `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. VERIFY GOLD TABLE
--    Check monthly aggregation correctness.
-- ────────────────────────────────────────────────────────────────────────────
SELECT
  COUNT(*)                                                    AS total_rows,
  COUNT(DISTINCT report_month)                                AS distinct_months,
  COUNT(DISTINCT traffic_source_medium)                       AS distinct_mediums,
  ROUND(SUM(purchased_value_usd), 2)                          AS grand_total_usd,
  SUM(total_purchases)                                        AS grand_total_purchases
FROM
  `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`;


-- ────────────────────────────────────────────────────────────────────────────
-- 5. CROSS-CHECK: Gold total_purchases should equal Silver row count
-- ────────────────────────────────────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`)
    AS silver_row_count,
  (SELECT SUM(total_purchases) FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`)
    AS gold_total_purchases,
  (SELECT COUNT(*) FROM `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`)
    = (SELECT SUM(total_purchases) FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`)
    AS counts_match;  -- Should be TRUE


-- ────────────────────────────────────────────────────────────────────────────
-- 6. PREVIEW GOLD TABLE (final report)
-- ────────────────────────────────────────────────────────────────────────────
SELECT *
FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
ORDER BY report_month DESC, purchased_value_usd DESC;


-- ────────────────────────────────────────────────────────────────────────────
-- 7. EXPORT GOLD TABLE TO CSV (via GCS)
--    Option A: Use the BigQuery Console "Save Results" → CSV download.
--    Option B: Export to GCS bucket (uncomment below).
-- ────────────────────────────────────────────────────────────────────────────
/*
EXPORT DATA OPTIONS (
  uri = 'gs://gcs-ga4-dataform-demo-dev/exports/top_traffic_source_medium_*.csv',
  format = 'CSV',
  overwrite = true,
  header = true
) AS
SELECT *
FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
ORDER BY report_month DESC, purchased_value_usd DESC;
*/
