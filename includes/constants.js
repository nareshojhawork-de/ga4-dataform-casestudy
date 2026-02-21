/**
 * Constants used across the Dataform project.
 * Import in any .sqlx file via:  ${constants.GA4_SOURCE_PROJECT}
 */

const GA4_SOURCE_PROJECT = "bigquery-public-data";
const GA4_SOURCE_DATASET = "ga4_obfuscated_sample_ecommerce";
const DATA_DELETED_MARKER = "(data deleted)";

module.exports = {
  GA4_SOURCE_PROJECT,
  GA4_SOURCE_DATASET,
  DATA_DELETED_MARKER
};
