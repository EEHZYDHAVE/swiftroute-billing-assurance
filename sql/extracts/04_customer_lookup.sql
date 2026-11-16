-- SwiftRoute Billing Assurance Workbench
-- Extract: canonical customer selector / lookup
-- Intended grain: one row per valid canonical client_id.
-- Duplicate keys are deliberately not hidden; run the customer-dimension validation query.

SELECT
    TRIM(CAST(client_id AS STRING)) AS client_id,
    customer_key,
    customer_name,
    has_salesforce_account,
    has_ever_used_fulfillment,
    has_ever_used_last_mile
FROM gold_customer.dim_customer_c
WHERE client_id IS NOT NULL
  AND TRIM(CAST(client_id AS STRING)) <> ''
  AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
ORDER BY customer_name, client_id;
