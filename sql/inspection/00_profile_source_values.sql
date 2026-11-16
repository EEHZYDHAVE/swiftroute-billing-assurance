-- Run this inspection script before finalising workbook labels and status filters.
-- It profiles observed source values without changing or materialising Gold objects.

-- 1. Billing-line status values and counts.
SELECT
    billing_line_status,
    billing_review_status,
    activity_eligibility_status,
    COUNT(*) AS billing_line_count,
    SUM(CASE WHEN invoice_ready_amount IS NOT NULL THEN 1 ELSE 0 END)
        AS lines_with_invoice_ready_amount
FROM gold_finance.billing_invoice_lines
GROUP BY billing_line_status, billing_review_status, activity_eligibility_status
ORDER BY billing_line_count DESC;

-- 2. Billing-line periods, cadence and service types.
SELECT
    billing_cadence,
    service_type,
    COUNT(*) AS billing_line_count,
    MIN(service_month) AS min_service_month,
    MAX(service_month) AS max_service_month,
    SUM(CASE WHEN service_month IS NULL THEN 1 ELSE 0 END) AS null_service_month_count,
    SUM(CASE WHEN billing_period_start IS NULL THEN 1 ELSE 0 END) AS null_period_start_count
FROM gold_finance.billing_invoice_lines
GROUP BY billing_cadence, service_type
ORDER BY billing_line_count DESC;

-- 3. Reconciliation statuses, periods and service types.
SELECT
    billing_cadence,
    service_type,
    reconciliation_status,
    COUNT(*) AS reconciliation_row_count,
    SUM(CASE WHEN invoice_ready_expected_charge_amount IS NULL THEN 1 ELSE 0 END)
        AS null_expected_amount_count,
    SUM(COALESCE(review_line_count, 0)) AS review_line_count,
    SUM(COALESCE(pricing_exception_line_count, 0)) AS pricing_exception_line_count,
    SUM(COALESCE(chargeability_review_line_count, 0)) AS chargeability_review_line_count,
    MIN(billing_period) AS min_billing_period,
    MAX(billing_period) AS max_billing_period
FROM gold_finance.billing_reconciliation
GROUP BY billing_cadence, service_type, reconciliation_status
ORDER BY reconciliation_row_count DESC;

-- 4. Currency and period profile on AR.
SELECT
    currency_code,
    COUNT(*) AS invoice_count,
    COUNT(DISTINCT client_id) AS customer_count,
    MIN(billing_period) AS min_billing_period,
    MAX(billing_period) AS max_billing_period,
    SUM(CASE WHEN invoice_amount IS NULL THEN 1 ELSE 0 END) AS null_invoice_amount_count
FROM gold_finance.accounts_receivable
GROUP BY currency_code
ORDER BY invoice_count DESC;

-- 5. Customer dimension key profile.
SELECT
    COUNT(*) AS dimension_row_count,
    COUNT(DISTINCT TRIM(CAST(client_id AS STRING))) AS distinct_client_id_count,
    SUM(CASE WHEN client_id IS NULL OR TRIM(CAST(client_id AS STRING)) = '' THEN 1 ELSE 0 END)
        AS null_or_blank_client_id_count,
    SUM(CASE WHEN UPPER(TRIM(CAST(client_id AS STRING))) IN ('N/A', 'NULL') THEN 1 ELSE 0 END)
        AS sentinel_client_id_count
FROM gold_customer.dim_customer_c;
