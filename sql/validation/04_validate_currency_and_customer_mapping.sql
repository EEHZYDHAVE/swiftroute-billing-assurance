-- Validation 4: currency consistency and canonical customer mapping.

-- Customer-periods with more than one AR currency must not be combined into a single monetary total.
SELECT
    TRIM(CAST(client_id AS STRING)) AS client_id,
    billing_period,
    COUNT(DISTINCT currency_code) AS distinct_currency_count,
    ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(currency_code, '[NULL]'))), ', ') AS observed_currencies,
    COUNT(DISTINCT invoice_id) AS invoice_count,
    SUM(CASE WHEN currency_code IS NULL THEN 1 ELSE 0 END) AS missing_currency_invoice_count
FROM gold_finance.accounts_receivable
GROUP BY TRIM(CAST(client_id AS STRING)), billing_period
HAVING COUNT(DISTINCT currency_code) > 1
    OR SUM(CASE WHEN currency_code IS NULL THEN 1 ELSE 0 END) > 0
ORDER BY billing_period, client_id;

-- Billing-detail rows whose valid-looking client ID does not exist in the canonical dimension.
SELECT
    TRIM(CAST(b.client_id AS STRING)) AS client_id,
    COUNT(*) AS billing_line_count,
    COUNT(DISTINCT b.billing_line_key) AS distinct_billing_line_count,
    ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(b.customer_name, '[NULL]'))), ', ') AS source_customer_names
FROM gold_finance.billing_invoice_lines b
LEFT JOIN gold_customer.dim_customer_c d
    ON TRIM(CAST(b.client_id AS STRING)) = TRIM(CAST(d.client_id AS STRING))
WHERE b.client_id IS NOT NULL
  AND TRIM(CAST(b.client_id AS STRING)) <> ''
  AND UPPER(TRIM(CAST(b.client_id AS STRING))) NOT IN ('N/A', 'NULL')
  AND d.client_id IS NULL
GROUP BY TRIM(CAST(b.client_id AS STRING))
ORDER BY billing_line_count DESC, client_id;

-- Invalid/sentinel customer identifiers on billing detail are retained by 02_billing_detail.sql
-- and can feed the workbook's unassigned activity area.
SELECT
    client_id,
    COUNT(*) AS billing_line_count,
    COUNT(DISTINCT billing_line_key) AS distinct_billing_line_count,
    ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(customer_name, '[NULL]'))), ', ') AS source_customer_names
FROM gold_finance.billing_invoice_lines
WHERE client_id IS NULL
   OR TRIM(CAST(client_id AS STRING)) = ''
   OR UPPER(TRIM(CAST(client_id AS STRING))) IN ('N/A', 'NULL')
GROUP BY client_id
ORDER BY billing_line_count DESC;
