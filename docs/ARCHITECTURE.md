# Architecture & Design Documentation

## 1. Medallion Architecture

This project follows a three-layer **medallion (Bronze → Silver → Gold)** architecture, a proven pattern for lakehouse-style data engineering on BigQuery.

### Why Medallion?

- **Separation of concerns**: Each layer has a single responsibility — sourcing, cleaning, aggregating.
- **Debuggability**: When a gold-layer KPI looks wrong, you can inspect the silver layer independently.
- **Reusability**: The silver layer can serve multiple gold-layer reports without re-processing raw data.
- **Incremental processing**: Silver handles the expensive raw-data extraction incrementally; gold rebuilds cheaply from the already-clean intermediate.

---

## 2. Layer Design

### 2.1 Bronze — Declaration

**Pattern:** Dataform `declaration` type.

The bronze layer does not materialise any data. It registers the external public dataset in Dataform's dependency graph. This means:

- Downstream `.sqlx` files can use `${ref("events_*")}` instead of hardcoding the fully qualified table name.
- If the source dataset ever moves (e.g., to a replicated copy in your own project), you change one file — not every query.
- The Dataform compilation graph correctly shows the full lineage from source to gold.

### 2.2 Silver — Incremental Table

**Pattern:** Dataform `incremental` type with date partitioning.

Key design decisions:

| Aspect | Choice | Why |
|--------|--------|-----|
| **Persistence** | Incremental | The GA4 export is date-sharded and append-only by nature. Incremental avoids reprocessing historical data on every run. |
| **Partition key** | `event_date` | Matches the natural grain of GA4 exports. BigQuery can prune partitions efficiently during both writes and reads. |
| **Cluster key** | `traffic_source_medium` | The gold-layer query groups by this column. Clustering reduces bytes scanned and cost. |
| **Unique key** | `[event_date, user_pseudo_id, ga_session_id, event_timestamp]` | Enables Dataform's MERGE strategy for incremental loads, preventing duplicates on re-runs. |
| **Assertions** | `nonNull` on key columns, `rowConditions` for value ranges | Catches data quality issues early — before they propagate to the gold report. |

**Data cleaning rules:**

1. **Purchase filter**: `event_name = 'purchase'` — only purchase events pass through.
2. **Deleted-data exclusion**: `traffic_source_medium NOT LIKE '%(data deleted)%'` — rows flagged as GDPR-deleted in the sample dataset are removed.
3. **Nested field extraction**: `ga_session_id` is pulled from the `event_params` repeated record; `total_items` is aggregated from the `items` repeated record.

### 2.3 Gold — Full-Rebuild Table

**Pattern:** Dataform `table` type (full rebuild on each run).

Why full rebuild instead of incremental for gold?

- The gold table aggregates monthly. An incremental merge on aggregated rows would require complex logic to re-aggregate when late-arriving silver data falls into an already-loaded month.
- The gold table is small (one row per month × medium combination), so a full scan of the silver table and rebuild is fast and cheap.
- Full rebuild guarantees aggregate correctness with zero merge edge cases.

---

## 3. Data Lineage

```
  bigquery-public-data
  .ga4_obfuscated_sample_ecommerce
  .events_*
       │
       │  Dataform declaration
       │  (definitions/sources/ga4_events.sqlx)
       │
       ▼
  ┌─────────────────────────────────────┐
  │  purchase_traffic_source_medium      │  SILVER
  │  (incremental, partitioned by date)  │
  │                                      │
  │  Filters: purchase events only       │
  │  Cleans:  removes (data deleted)     │
  │  Extracts: session ID, item counts   │
  └─────────────────┬───────────────────┘
                    │
                    ▼
  ┌─────────────────────────────────────┐
  │  top_traffic_source_medium           │  GOLD
  │  (table, full rebuild)               │
  │                                      │
  │  Aggregates: monthly by medium       │
  │  KPIs: value, items, avg items       │
  └─────────────────────────────────────┘
```

> **Tip:** In the Dataform web UI, navigate to the "Compiled graph" tab to see the interactive version of this lineage. You can screenshot it from there for presentations.

---

## 4. Scheduling & Operations

### Recommended Schedule

Set up a **Dataform workflow configuration** in the GCP Console:

- **Frequency**: Daily (or weekly, depending on business needs).
- **Tags to run**: `daily` — this tag is applied to both silver and gold layers.
- **Execution order**: Dataform respects the dependency graph automatically. Silver runs first, gold runs after silver completes.

### Handling Full Refreshes

If you need to backfill or rebuild from scratch:

```bash
dataform run --full-refresh
```

This forces the incremental silver table to drop and rebuild entirely, then rebuilds gold.

---

## 5. Assertions & Data Quality

Both silver and gold layers include inline assertions:

| Layer  | Assertion | Purpose |
|--------|-----------|---------|
| Silver | `nonNull: [event_date, user_pseudo_id]` | Ensures critical identifiers are present |
| Silver | `event_value_in_usd >= 0 OR event_value_in_usd IS NULL` | Catches negative purchase values |
| Gold   | `nonNull: [report_month, traffic_source_medium]` | Ensures dimension keys are populated |
| Gold   | `total_purchases > 0` | Validates that every row has at least one purchase |
| Gold   | `avg_items_per_purchase >= 0` | Ensures non-negative averages |

Assertion results are visible in the Dataform execution logs and can trigger alerts via Cloud Monitoring.

---

## 6. Cost & Performance Considerations

- **Partitioning**: Queries against the silver table that filter on `event_date` scan only relevant partitions, reducing cost.
- **Clustering**: The `traffic_source_medium` cluster key on silver and `report_month` on gold improve query performance for GROUP BY operations.
- **Incremental loads**: After the initial backfill, daily runs process only the delta, keeping slot usage and bytes scanned minimal.
- **Public dataset**: Reading from `bigquery-public-data` is free in terms of storage but billed for query bytes scanned under your project's on-demand pricing.
