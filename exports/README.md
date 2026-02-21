# Exports

This directory contains CSV exports of the gold-layer tables.

## `top_traffic_source_medium.csv`

**Important**: The included CSV contains **representative sample data** showing the expected schema and format. After running the Dataform pipeline against the actual public GA4 dataset, replace this file with the real export.

### How to export the real data

**Option A — BigQuery Console:**
1. Open the table `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium` in BigQuery.
2. Click **Export** → **Export to local file (CSV)**.

**Option B — SQL export to GCS:**
```sql
EXPORT DATA OPTIONS(
  uri = 'gs://gcs-ga4-dataform-demo-dev/exports/top_traffic_source_medium_*.csv',
  format = 'CSV',
  overwrite = true,
  header = true
) AS
SELECT * FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
ORDER BY report_month DESC, purchased_value_usd DESC;
```

**Option C — bq CLI:**
```bash
bq extract \
  --destination_format=CSV \
  'your-project:ga4_dataform.top_traffic_source_medium' \
  gs://your-bucket/exports/top_traffic_source_medium.csv
```
