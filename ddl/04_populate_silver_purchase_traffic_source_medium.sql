-- ============================================================================
-- DDL 04: Populate Silver — purchase_traffic_source_medium
-- ============================================================================
-- Standalone BigQuery SQL equivalent of the Dataform incremental action.
-- Use this for manual backfill or ad-hoc execution outside of Dataform.
--
-- This is a FULL LOAD (INSERT OVERWRITE). For incremental logic, add
-- the WHERE clause at the bottom to filter by date.
-- ============================================================================

-- Option A: Full load (truncate + reload)
CREATE OR REPLACE TABLE `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`
PARTITION BY event_date
CLUSTER BY traffic_source_medium
OPTIONS (
  description = 'Silver layer — denormalised purchase events with traffic source medium.',
  labels = [('layer', 'silver'), ('project', 'ga4_case_study')]
)
AS
WITH source AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)                         AS event_date,
    traffic_source.medium                                     AS traffic_source_medium,
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
    )                                                         AS ga_session_id,
    event_value_in_usd,
    event_timestamp,
    (
      SELECT COALESCE(SUM(item.quantity), COUNT(*))
      FROM UNNEST(items) AS item
    )                                                         AS total_items
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    event_name = 'purchase'
)
SELECT
  event_date,
  traffic_source_medium,
  user_pseudo_id,
  ga_session_id,
  event_value_in_usd,
  event_timestamp,
  total_items
FROM
  source
WHERE
  (traffic_source_medium IS NULL OR traffic_source_medium NOT LIKE '%(data deleted)%');


-- ============================================================================
-- Option B: Incremental append (run daily after initial load)
-- Uncomment and use this instead of Option A for incremental loads.
-- ============================================================================
/*
INSERT INTO `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`
  (event_date, traffic_source_medium, user_pseudo_id, ga_session_id,
   event_value_in_usd, event_timestamp, total_items)
WITH source AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)                         AS event_date,
    traffic_source.medium                                     AS traffic_source_medium,
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
    )                                                         AS ga_session_id,
    event_value_in_usd,
    event_timestamp,
    (
      SELECT COALESCE(SUM(item.quantity), COUNT(*))
      FROM UNNEST(items) AS item
    )                                                         AS total_items
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    event_name = 'purchase'
)
SELECT
  event_date,
  traffic_source_medium,
  user_pseudo_id,
  ga_session_id,
  event_value_in_usd,
  event_timestamp,
  total_items
FROM
  source
WHERE
  (traffic_source_medium IS NULL OR traffic_source_medium NOT LIKE '%(data deleted)%')
  AND event_date > (
    SELECT COALESCE(MAX(event_date), DATE '1970-01-01')
    FROM `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`
  );
*/
