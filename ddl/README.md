# DDL Scripts

Standalone BigQuery SQL scripts that create and populate the pipeline tables **outside** of Dataform. Use these for manual setup, validation, or ad-hoc execution in the BigQuery Console.

## Execution Order

| # | File | Purpose |
|---|------|---------|
| 01 | `01_create_datasets.sql` | Creates `ga4_dataform` and `ga4_dataform_assertions` datasets |
| 02 | `02_create_silver_purchase_traffic_source_medium.sql` | Creates the Silver table schema (empty) |
| 03 | `03_create_gold_top_traffic_source_medium.sql` | Creates the Gold table schema (empty) |
| 04 | `04_populate_silver_purchase_traffic_source_medium.sql` | Full-load query to populate Silver from the public GA4 dataset |
| 05 | `05_populate_gold_top_traffic_source_medium.sql` | Full-rebuild query to populate Gold from Silver |
| 06 | `06_validation_and_export.sql` | Validation queries + CSV export |

> **Important:** Replace every occurrence of `p-ga4-dataform-demo-dev` with your actual GCP project ID before running.

## When to Use These

- **With Dataform:** You only need `01_create_datasets.sql`. Dataform handles 02–05 automatically.
- **Without Dataform:** Run all scripts in order (01 → 06) in the BigQuery SQL Workspace.
- **Validation:** Run `06_validation_and_export.sql` after either approach to verify correctness.
