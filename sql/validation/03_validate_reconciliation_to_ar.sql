-- Validation 3: customer-period reconciliation actuals against invoice-level AR.
-- This is the recurring control for the summary extract.
-- Comparisons are made only where AR has one known currency and no null invoice amounts.

WITH reconciliation_period AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key,
        SUM(actual_invoiced_amount) AS reconciliation_actual_amount
    FROM gold_finance.billing_reconciliation
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
    GROUP BY
        TRIM(CAST(client_id AS STRING)),
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        )
),
ar_period AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
            AS billing_period_key,
        COUNT(DISTINCT invoice_id) AS invoice_count,
        COUNT(DISTINCT currency_code) AS distinct_currency_count,
        SUM(CASE WHEN currency_code IS NULL THEN 1 ELSE 0 END) AS null_currency_invoice_count,
        SUM(CASE WHEN invoice_amount IS NULL THEN 1 ELSE 0 END) AS null_invoice_amount_count,
        SUM(invoice_amount) AS ar_invoice_amount
    FROM gold_finance.accounts_receivable
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
    GROUP BY
        TRIM(CAST(client_id AS STRING)),
        NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
)
SELECT
    r.client_id,
    r.billing_period_key,
    r.reconciliation_actual_amount,
    a.ar_invoice_amount,
    a.invoice_count,
    a.distinct_currency_count,
    a.null_currency_invoice_count,
    a.null_invoice_amount_count,
    CASE
        WHEN a.client_id IS NULL THEN 'RECONCILIATION_ONLY_NO_AR_INVOICE'
        WHEN a.distinct_currency_count > 1 THEN 'MULTIPLE_CURRENCIES_REQUIRES_REVIEW'
        WHEN a.null_currency_invoice_count > 0 THEN 'MISSING_CURRENCY_CODE_REVIEW'
        WHEN a.null_invoice_amount_count > 0 THEN 'AR_INVOICE_AMOUNT_MISSING_REVIEW'
        WHEN r.reconciliation_actual_amount IS NULL THEN 'RECONCILIATION_AMOUNT_NULL'
        WHEN ABS(r.reconciliation_actual_amount - a.ar_invoice_amount) <= 0.01 THEN 'MATCHED'
        ELSE 'MISMATCH_REVIEW'
    END AS validation_status,
    CASE
        WHEN a.distinct_currency_count = 1
         AND a.null_currency_invoice_count = 0
         AND a.null_invoice_amount_count = 0
         AND r.reconciliation_actual_amount IS NOT NULL
        THEN r.reconciliation_actual_amount - a.ar_invoice_amount
        ELSE NULL
    END AS difference_amount
FROM reconciliation_period r
LEFT JOIN ar_period a
    ON r.client_id = a.client_id
   AND r.billing_period_key = a.billing_period_key
WHERE a.client_id IS NULL
   OR a.distinct_currency_count <> 1
   OR a.null_currency_invoice_count > 0
   OR a.null_invoice_amount_count > 0
   OR r.reconciliation_actual_amount IS NULL
   OR ABS(r.reconciliation_actual_amount - a.ar_invoice_amount) > 0.01
ORDER BY r.billing_period_key, r.client_id;

-- AR-only customer-periods. Expected: zero rows based on the inspected baseline.
WITH reconciliation_periods AS (
    SELECT DISTINCT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key
    FROM gold_finance.billing_reconciliation
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
),
ar_periods AS (
    SELECT DISTINCT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
            AS billing_period_key
    FROM gold_finance.accounts_receivable
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
)
SELECT a.client_id, a.billing_period_key
FROM ar_periods a
LEFT JOIN reconciliation_periods r
    ON a.client_id = r.client_id
   AND a.billing_period_key = r.billing_period_key
WHERE r.client_id IS NULL
ORDER BY a.billing_period_key, a.client_id;
