-- Validation 2: period-key coverage between billing detail and reconciliation.
-- Expected: the unmatched detail query should return zero rows or only explainable exceptions.

WITH detail_periods AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(service_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_period_start AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key,
        COUNT(*) AS billing_line_count
    FROM gold_finance.billing_invoice_lines
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
    GROUP BY
        TRIM(CAST(client_id AS STRING)),
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(service_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_period_start AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        )
),
reconciliation_periods AS (
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
)
SELECT
    d.client_id,
    d.billing_period_key,
    d.billing_line_count,
    CASE WHEN d.billing_period_key IS NULL THEN 'DETAIL_PERIOD_KEY_MISSING'
         ELSE 'NO_MATCHING_RECONCILIATION_CUSTOMER_PERIOD'
    END AS validation_issue
FROM detail_periods d
LEFT JOIN reconciliation_periods r
    ON d.client_id = r.client_id
   AND d.billing_period_key = r.billing_period_key
WHERE d.billing_period_key IS NULL
   OR r.client_id IS NULL
ORDER BY d.client_id, d.billing_period_key;

-- Reconciliation rows with no usable customer-period key must be reviewed separately.
SELECT
    reconciliation_key,
    client_id,
    billing_month,
    billing_period,
    service_type,
    invoice_ready_expected_charge_amount,
    actual_invoiced_amount,
    reconciliation_status,
    reconciliation_explanation
FROM gold_finance.billing_reconciliation
WHERE client_id IS NULL
   OR TRIM(CAST(client_id AS STRING)) = ''
   OR UPPER(TRIM(CAST(client_id AS STRING))) IN ('N/A', 'NULL')
   OR COALESCE(
        NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
        NULLIF(REGEXP_EXTRACT(CAST(billing_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
      ) IS NULL
ORDER BY billing_month, client_id, service_type;

-- AR invoices with no usable billing period key are not joinable to the customer-period summary.
SELECT
    invoice_id,
    document_number,
    client_id,
    billing_period,
    invoice_date,
    invoice_amount,
    currency_code
FROM gold_finance.accounts_receivable
WHERE billing_period IS NULL
   OR NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '') IS NULL
ORDER BY invoice_date DESC, document_number;
