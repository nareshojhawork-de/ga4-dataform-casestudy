-- ============================================================================
-- DDL 02: Silver Layer — purchase_traffic_source_medium
-- ============================================================================
-- Run this AFTER 01_create_datasets.sql.
--
-- NOTE: Dataform will create this table automatically on first run.
--       This DDL is provided for documentation, manual pre-creation,
--       or if you need to recreate the table outside of Dataform.
--
-- Persistence : Incremental (Dataform MERGE)
-- Partitioned : event_date (DAY)
-- Clustered   : traffic_source_medium
-- Grain       : One row per purchase event (user × session × timestamp)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `p-ga4-dataform-demo-dev.ga4_dataform.purchase_traffic_source_medium`
(
  event_date              DATE          NOT NULL    OPTIONS (description = 'Date of the purchase event'),
  traffic_source_medium   STRING                    OPTIONS (description = 'Medium from the users original traffic source (organic, cpc, referral, etc.)'),
  user_pseudo_id          STRING        NOT NULL    OPTIONS (description = 'GA4 anonymous user identifier'),
  ga_session_id           INT64                     OPTIONS (description = 'Session identifier extracted from event_params'),
  event_value_in_usd      FLOAT64                   OPTIONS (description = 'Purchase value in USD'),
  event_timestamp         INT64                     OPTIONS (description = 'Event timestamp in microseconds since epoch'),
  total_items             INT64                     OPTIONS (description = 'Number of items in the purchase (sum of item quantities)')
)
PARTITION BY event_date
CLUSTER BY traffic_source_medium
OPTIONS (
  description = 'Silver layer — denormalised purchase events with traffic source medium. Filters out deleted data and unpacks nested GA4 fields. Each row represents one purchase event.',
  labels = [('layer', 'silver'), ('project', 'ga4_case_study')]
);
