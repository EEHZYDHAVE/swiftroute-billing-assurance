-- Validation 1: source keys and canonical customer dimension uniqueness.
-- Expected: each query returns zero rows, except the final duplicate-dimension query if a defect exists.

-- Billing detail key must be populated and unique.
SELECT billing_line_key, COUNT(*) AS row_count
FROM gold_finance.billing_invoice_lines
GROUP BY billing_line_key
HAVING billing_line_key IS NULL OR COUNT(*) > 1;

-- Reconciliation source key must be populated and unique.
SELECT reconciliation_key, COUNT(*) AS row_count
FROM gold_finance.billing_reconciliation
GROUP BY reconciliation_key
HAVING reconciliation_key IS NULL OR COUNT(*) > 1;

-- AR invoice key must be populated and unique.
SELECT invoice_id, COUNT(*) AS row_count
FROM gold_finance.accounts_receivable
GROUP BY invoice_id
HAVING invoice_id IS NULL OR COUNT(*) > 1;

-- Canonical customer key should be unique after sentinel/null rows are excluded.
SELECT TRIM(CAST(client_id AS STRING)) AS client_id, COUNT(*) AS row_count
FROM gold_customer.dim_customer_c
WHERE client_id IS NOT NULL
  AND TRIM(CAST(client_id AS STRING)) <> ''
  AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
GROUP BY TRIM(CAST(client_id AS STRING))
HAVING COUNT(*) > 1;
