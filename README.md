# GA4 with Dataform — Case Study Solution

## Overview

This Dataform project implements a **Bronze → Silver → Gold** medallion architecture over the [public GA4 obfuscated sample e-commerce dataset](https://support.google.com/analytics/answer/7029846) in BigQuery.

The pipeline extracts purchase events, denormalises nested GA4 fields, filters out deleted data, and produces a monthly business report that ranks traffic source mediums by purchase value and volume.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA LINEAGE                                  │
│                                                                      │
│  ┌──────────────────────┐                                            │
│  │      BRONZE           │                                           │
│  │  (declaration)        │                                           │
│  │                       │                                           │
│  │  ga4_events           │  Points to:                               │
│  │  (events_*)           │  bigquery-public-data                     │
│  │                       │  .ga4_obfuscated_sample_ecommerce         │
│  └──────────┬───────────┘  .events_*                                 │
│             │                                                        │
│             ▼                                                        │
│  ┌──────────────────────┐                                            │
│  │      SILVER           │                                           │
│  │  (incremental table)  │                                           │
│  │                       │  • Filters: event_name = 'purchase'       │
│  │  purchase_traffic_    │  • Removes: (data deleted) rows           │
│  │  source_medium        │  • Extracts: ga_session_id, total_items   │
│  │                       │  • Partitioned by: event_date             │
│  └──────────┬───────────┘  • Clustered by: traffic_source_medium     │
│             │                                                        │
│             ▼                                                        │
│  ┌──────────────────────┐                                            │
│  │      GOLD             │                                           │
│  │  (table)              │                                           │
│  │                       │  • Monthly aggregation                    │
│  │  top_traffic_source_  │  • KPIs: value, items, purchases, avg     │
│  │  medium               │  • Clustered by: report_month             │
│  └──────────────────────┘  • Ordered by: month DESC, value DESC      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
ga4-dataform-casestudy/
├── dataform.json                      # Legacy Dataform config (for CLI compatibility)
├── workflow_settings.yaml             # Modern Dataform on GCP configuration
├── package.json                       # NPM dependencies (@dataform/core)
├── .gitignore
│
├── definitions/
│   ├── sources/
│   │   └── ga4_events.sqlx            # BRONZE — declaration of public GA4 dataset
│   │
│   ├── silver/
│   │   └── purchase_traffic_source_medium.sqlx
│   │                                  # SILVER — incremental, denormalised purchases
│   │
│   └── gold/
│       └── top_traffic_source_medium.sqlx
│                                      # GOLD — monthly aggregated business report
│
├── includes/
│   └── constants.js                   # Shared constants (source project/dataset)
│
├── docs/
│   └── ARCHITECTURE.md                # Architecture deep-dive & design decisions
│
├── exports/
│   └── top_traffic_source_medium.csv  # Exported gold-layer output (deliverable)
│
└── README.md                          # This file
```

---

## Layer Details

### Bronze — Source Declaration

| Property   | Value |
|------------|-------|
| **File**   | `definitions/sources/ga4_events.sqlx` |
| **Type**   | `declaration` |
| **Target** | `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` |

No data is materialised. This declaration registers the external dataset in Dataform's dependency graph so downstream actions can reference it with `${ref("events_*")}`.

### Silver — `purchase_traffic_source_medium`

| Property          | Value |
|-------------------|-------|
| **File**          | `definitions/silver/purchase_traffic_source_medium.sqlx` |
| **Type**          | `incremental` |
| **Partitioned by**| `event_date` |
| **Clustered by**  | `traffic_source_medium` |

**Columns:**

| Column                  | Type    | Description |
|-------------------------|---------|-------------|
| `event_date`            | DATE    | Date of the purchase event |
| `traffic_source_medium` | STRING  | Medium from the user's original traffic source (e.g., organic, cpc, referral) |
| `user_pseudo_id`        | STRING  | GA4 anonymous user identifier |
| `ga_session_id`         | INT64   | Session identifier extracted from `event_params` |
| `event_value_in_usd`    | FLOAT64 | Purchase value in USD |
| `event_timestamp`       | INT64   | Event timestamp in microseconds (epoch) |
| `total_items`           | INT64   | Number of items in the purchase (sum of item quantities) |

**Key logic:**
- `event_name = 'purchase'` filter applied at source.
- `traffic_source.medium NOT LIKE '%(data deleted)%'` removes GDPR-deleted rows.
- Incremental: on re-run, only new `event_date` partitions are processed.

### Gold — `top_traffic_source_medium`

| Property        | Value |
|-----------------|-------|
| **File**        | `definitions/gold/top_traffic_source_medium.sqlx` |
| **Type**        | `table` (full rebuild) |
| **Clustered by**| `report_month` |

**Columns:**

| Column                   | Type    | Description |
|--------------------------|---------|-------------|
| `report_month`           | DATE    | First day of the month |
| `traffic_source_medium`  | STRING  | Traffic source medium (NULL coalesced to "(not set)") |
| `purchased_value_usd`    | FLOAT64 | Total purchase value in USD for the month |
| `total_purchased_items`  | INT64   | Total items purchased in the month |
| `total_purchases`        | INT64   | Number of purchase events (transactions) |
| `avg_items_per_purchase` | FLOAT64 | Average items per transaction |

Full table rebuild is chosen over incremental because the gold table is a small aggregation and full rebuild guarantees correct aggregates without merge complexity.

---

## How to Run

### Prerequisites

1. A GCP project with BigQuery and Dataform enabled.
2. The Dataform service account needs `roles/bigquery.dataViewer` on `bigquery-public-data`.
3. The Dataform service account needs `roles/bigquery.dataEditor` on your target dataset.

### Setup

1. **Create a Dataform repository** in the GCP Console under BigQuery → Dataform.
2. **Link this repository** (push this code to the connected Git repo, or paste files via the Dataform web IDE).
3. **Update `workflow_settings.yaml`**: replace `p-ga4-dataform-demo-dev` with your actual GCP project ID.
4. **Update `dataform.json`**: replace `p-ga4-dataform-demo-dev` with your actual GCP project ID.

### Execution

```bash
# Full run (all tags)
dataform run

# Run only the silver layer
dataform run --tags silver

# Run only the gold layer
dataform run --tags gold

# Dry run — compile and validate without executing
dataform compile
```

In the GCP Console, you can trigger runs manually via the Dataform UI or set up scheduled workflow configurations for daily execution.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Incremental silver, full-rebuild gold** | Silver handles large raw data efficiently; gold is a small aggregate where full rebuild is cheap and avoids merge edge cases. |
| **Partitioning by `event_date`** | Aligns with GA4's date-sharded export pattern; enables efficient incremental loads and query pruning. |
| **Clustering by `traffic_source_medium`** | Optimises the GROUP BY in the gold-layer query. |
| **`COALESCE(traffic_source_medium, '(not set)')`** | Prevents NULL dimension keys in the gold report, following GA4 conventions. |
| **`SAFE_DIVIDE` for averages** | Prevents division-by-zero errors in edge cases. |
| **Assertions** | `nonNull` and `rowConditions` provide data quality guardrails that run automatically with each execution. |

---

## Exporting Gold-Layer Data

After running the pipeline, export the gold table to CSV:

```sql
EXPORT DATA OPTIONS(
  uri = 'gs://your-bucket/exports/top_traffic_source_medium_*.csv',
  format = 'CSV',
  overwrite = true,
  header = true
) AS
SELECT * FROM `p-ga4-dataform-demo-dev.ga4_dataform.top_traffic_source_medium`
ORDER BY report_month DESC, purchased_value_usd DESC;
```

Or via the BigQuery Console: open the table → Export → Export to Google Cloud Storage / Download as CSV.

The pre-exported CSV is included in `exports/top_traffic_source_medium.csv`.

---

## Author

Prepared as a case study deliverable for a Data Engineering role requiring Dataform on GCP experience.
