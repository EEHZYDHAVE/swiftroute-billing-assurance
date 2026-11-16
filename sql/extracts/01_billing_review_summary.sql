-- SwiftRoute Billing Assurance Workbench
-- Extract: customer-period Billing Review summary
-- Source objects are read-only Gold models. This query performs downstream aggregation only.
-- Intended grain: one row per valid client_id + Gold billing_period.
-- Currency is sourced from AR because billing_reconciliation has no currency_code.
-- When AR contains multiple/missing currencies, the amount is retained as a source value,
-- but no currency allocation or conclusive variance is produced.

WITH reconciliation_source AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        CAST(billing_month AS DATE) AS billing_month,
        CAST(billing_period AS STRING) AS billing_period,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key,
        service_type,
        billing_cadence,
        source_activity_count,
        candidate_quantity,
        eligible_billable_quantity,
        invoice_ready_expected_charge_amount,
        actual_invoiced_amount,
        review_line_count,
        pricing_exception_line_count,
        chargeability_review_line_count,
        reconciliation_status,
        reconciliation_explanation
    FROM gold_finance.billing_reconciliation
),

reconciliation_by_customer_period AS (
    SELECT
        client_id,
        billing_period_key,
        MAX(billing_period) AS billing_period,
        MIN(billing_month) AS billing_month,
        COUNT(*) AS reconciliation_service_row_count,
        COUNT(invoice_ready_expected_charge_amount) AS expected_amount_component_count,
        COUNT(*) - COUNT(invoice_ready_expected_charge_amount) AS expected_amount_null_component_count,
        SUM(invoice_ready_expected_charge_amount) AS expected_amount,
        SUM(actual_invoiced_amount) AS actual_invoiced_amount,
        SUM(COALESCE(source_activity_count, 0)) AS source_activity_count,
        SUM(COALESCE(candidate_quantity, 0)) AS candidate_quantity,
        SUM(COALESCE(eligible_billable_quantity, 0)) AS eligible_billable_quantity,
        SUM(COALESCE(review_line_count, 0)) AS review_line_count,
        SUM(COALESCE(pricing_exception_line_count, 0)) AS pricing_exception_line_count,
        SUM(COALESCE(chargeability_review_line_count, 0)) AS chargeability_review_line_count,
        SUM(
            CASE
                WHEN UPPER(COALESCE(reconciliation_status, '')) RLIKE 'REVIEW|EXCEPTION|PARTIAL|INCOMPLETE'
                THEN 1 ELSE 0
            END
        ) AS reconciliation_status_review_row_count,
        ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(service_type, '[NULL]'))), ', ') AS source_service_types,
        ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(billing_cadence, '[NULL]'))), ', ') AS source_billing_cadences,
        ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(reconciliation_status, '[NULL]'))), ', ') AS source_reconciliation_statuses,
        ARRAY_JOIN(
            SORT_ARRAY(COLLECT_SET(NULLIF(TRIM(CAST(reconciliation_explanation AS STRING)), ''))),
            ' | '
        ) AS source_reconciliation_explanations
    FROM reconciliation_source
    GROUP BY client_id, billing_period_key
),

billing_detail_source AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(service_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_period_start AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key,
        invoice_ready_amount,
        billing_line_status,
        billing_review_status
    FROM gold_finance.billing_invoice_lines
),

billing_detail_by_customer_period AS (
    SELECT
        client_id,
        billing_period_key,
        COUNT(*) AS billing_detail_line_count,
        SUM(CASE WHEN invoice_ready_amount IS NOT NULL THEN 1 ELSE 0 END)
            AS detail_lines_with_invoice_ready_amount,
        SUM(
            CASE
                WHEN UPPER(COALESCE(billing_review_status, '')) RLIKE 'REVIEW|EXCEPTION|PARTIAL|INCOMPLETE'
                  OR UPPER(COALESCE(billing_line_status, '')) RLIKE 'REVIEW|EXCEPTION|PARTIAL|INCOMPLETE'
                THEN 1 ELSE 0
            END
        ) AS detail_lines_with_review_status,
        ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(billing_line_status, '[NULL]'))), ', ')
            AS detail_billing_line_statuses,
        ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(COALESCE(billing_review_status, '[NULL]'))), ', ')
            AS detail_billing_review_statuses
    FROM billing_detail_source
    WHERE client_id IS NOT NULL
      AND TRIM(client_id) <> ''
      AND UPPER(TRIM(client_id)) NOT IN ('N/A', 'NULL')
      AND billing_period_key IS NOT NULL
    GROUP BY client_id, billing_period_key
),

ar_source AS (
    SELECT
        invoice_id,
        TRIM(CAST(client_id AS STRING)) AS client_id,
        NULLIF(REGEXP_EXTRACT(CAST(billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
            AS billing_period_key,
        currency_code,
        invoice_amount
    FROM gold_finance.accounts_receivable
),

ar_by_customer_period_aggregated AS (
    SELECT
        client_id,
        billing_period_key,
        COUNT(DISTINCT invoice_id) AS actual_invoice_count,
        COUNT(DISTINCT currency_code) AS distinct_currency_count,
        SUM(CASE WHEN currency_code IS NULL THEN 1 ELSE 0 END) AS invoices_missing_currency_count,
        SUM(CASE WHEN invoice_amount IS NULL THEN 1 ELSE 0 END) AS invoices_missing_amount_count,
        MAX(currency_code) AS sole_currency_candidate,
        SUM(invoice_amount) AS ar_invoice_amount_unqualified
    FROM ar_source
    WHERE client_id IS NOT NULL
      AND TRIM(client_id) <> ''
      AND UPPER(TRIM(client_id)) NOT IN ('N/A', 'NULL')
      AND billing_period_key IS NOT NULL
    GROUP BY client_id, billing_period_key
),

ar_by_customer_period AS (
    SELECT
        *,
        CASE
            WHEN distinct_currency_count > 1 THEN 'MULTIPLE_CURRENCIES_REQUIRES_REVIEW'
            WHEN invoices_missing_currency_count > 0 THEN 'MISSING_CURRENCY_CODE_REVIEW'
            WHEN distinct_currency_count = 1 THEN 'SINGLE_CURRENCY'
            ELSE 'NO_AR_CURRENCY_CONTEXT'
        END AS currency_profile_status,
        CASE
            WHEN distinct_currency_count = 1
             AND invoices_missing_currency_count = 0
             AND invoices_missing_amount_count = 0
            THEN ar_invoice_amount_unqualified
            ELSE NULL
        END AS ar_invoice_amount_control,
        CASE
            WHEN distinct_currency_count = 1
             AND invoices_missing_currency_count = 0
            THEN sole_currency_candidate
            ELSE NULL
        END AS currency_code
    FROM ar_by_customer_period_aggregated
),

customer_dimension AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        customer_key,
        customer_name
    FROM gold_customer.dim_customer_c
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
),

summary_base AS (
    SELECT
        r.client_id,
        r.billing_period_key,
        r.billing_period,
        r.billing_month,
        d.customer_name,
        CASE WHEN d.client_id IS NOT NULL THEN 'MATCHED_TO_CANONICAL_CUSTOMER'
             ELSE 'CUSTOMER_ID_NOT_FOUND_IN_CANONICAL_DIMENSION'
        END AS customer_dimension_match_status,
        r.reconciliation_service_row_count,
        r.expected_amount_component_count,
        r.expected_amount_null_component_count,
        r.expected_amount,
        r.actual_invoiced_amount,
        r.source_activity_count,
        r.candidate_quantity,
        r.eligible_billable_quantity,
        r.review_line_count,
        r.pricing_exception_line_count,
        r.chargeability_review_line_count,
        r.reconciliation_status_review_row_count,
        r.source_service_types,
        r.source_billing_cadences,
        r.source_reconciliation_statuses,
        r.source_reconciliation_explanations,
        COALESCE(a.actual_invoice_count, 0) AS actual_invoice_count,
        a.currency_code,
        COALESCE(a.currency_profile_status, 'NO_AR_CURRENCY_CONTEXT') AS currency_profile_status,
        COALESCE(a.distinct_currency_count, 0) AS distinct_currency_count,
        COALESCE(a.invoices_missing_currency_count, 0) AS invoices_missing_currency_count,
        COALESCE(a.invoices_missing_amount_count, 0) AS invoices_missing_amount_count,
        a.ar_invoice_amount_control,
        COALESCE(x.billing_detail_line_count, 0) AS billing_detail_line_count,
        COALESCE(x.detail_lines_with_invoice_ready_amount, 0) AS detail_lines_with_invoice_ready_amount,
        COALESCE(x.detail_lines_with_review_status, 0) AS detail_lines_with_review_status,
        x.detail_billing_line_statuses,
        x.detail_billing_review_statuses
    FROM reconciliation_by_customer_period r
    LEFT JOIN customer_dimension d
        ON r.client_id = d.client_id
    LEFT JOIN ar_by_customer_period a
        ON r.client_id = a.client_id
       AND r.billing_period_key = a.billing_period_key
    LEFT JOIN billing_detail_by_customer_period x
        ON r.client_id = x.client_id
       AND r.billing_period_key = x.billing_period_key
    WHERE r.client_id IS NOT NULL
      AND TRIM(r.client_id) <> ''
      AND UPPER(TRIM(r.client_id)) NOT IN ('N/A', 'NULL')
      AND r.billing_period_key IS NOT NULL
),

summary_with_controls AS (
    SELECT
        *,
        CASE
            WHEN expected_amount_component_count = 0 THEN 'NOT_CALCULATED'
            WHEN expected_amount_null_component_count > 0 THEN 'PARTIAL_EXPECTED_COMPONENT_COVERAGE'
            ELSE 'ALL_RECONCILIATION_SERVICE_ROWS_POPULATED'
        END AS expected_coverage_status,
        CASE
            WHEN actual_invoice_count = 0
             AND actual_invoiced_amount IS NOT NULL
             AND ABS(actual_invoiced_amount) > 0.01
                THEN 'RECONCILIATION_AMOUNT_WITHOUT_AR_INVOICE_REVIEW'
            WHEN actual_invoice_count = 0 THEN 'NO_AR_INVOICE'
            WHEN currency_profile_status <> 'SINGLE_CURRENCY' THEN 'CURRENCY_REVIEW'
            WHEN invoices_missing_amount_count > 0 THEN 'AR_INVOICE_AMOUNT_MISSING_REVIEW'
            WHEN ar_invoice_amount_control IS NULL THEN 'AR_CONTROL_AMOUNT_UNAVAILABLE'
            WHEN actual_invoiced_amount IS NULL THEN 'RECONCILIATION_ACTUAL_AMOUNT_NULL'
            WHEN ABS(actual_invoiced_amount - ar_invoice_amount_control) <= 0.01 THEN 'MATCHED_TO_AR'
            ELSE 'MISMATCH_TO_AR_REVIEW'
        END AS reconciliation_to_ar_status,
        CASE
            WHEN actual_invoice_count = 0 THEN NULL
            WHEN currency_profile_status <> 'SINGLE_CURRENCY' THEN NULL
            WHEN ar_invoice_amount_control IS NULL OR actual_invoiced_amount IS NULL THEN NULL
            ELSE actual_invoiced_amount - ar_invoice_amount_control
        END AS reconciliation_to_ar_difference
    FROM summary_base
),

summary_final AS (
    SELECT
        *,
        CASE
            WHEN actual_invoice_count = 0
             AND actual_invoiced_amount IS NOT NULL
             AND ABS(actual_invoiced_amount) > 0.01
                THEN 'ACTUAL_RECONCILIATION_CONTROL_REVIEW'
            WHEN expected_amount IS NULL AND actual_invoice_count > 0
                THEN 'ACTUAL_ONLY_EXPECTED_NOT_CALCULATED'
            WHEN expected_amount IS NULL AND actual_invoice_count = 0
                THEN 'NOT_CALCULATED_REVIEW'
            WHEN actual_invoice_count > 0 AND currency_profile_status <> 'SINGLE_CURRENCY'
                THEN 'CURRENCY_REVIEW'
            WHEN expected_amount_null_component_count > 0
              OR review_line_count > 0
              OR pricing_exception_line_count > 0
              OR chargeability_review_line_count > 0
              OR reconciliation_status_review_row_count > 0
              OR detail_lines_with_review_status > 0
                THEN 'PARTIAL_COVERAGE_REVIEW'
            WHEN actual_invoice_count = 0
                THEN 'READY_BILLING_NO_ACTUAL_INVOICE'
            WHEN reconciliation_to_ar_status <> 'MATCHED_TO_AR'
                THEN 'ACTUAL_RECONCILIATION_CONTROL_REVIEW'
            WHEN ABS(actual_invoiced_amount - expected_amount) <= 0.01
                THEN 'MATCHED'
            ELSE 'VARIANCE_REVIEW'
        END AS billing_review_status,
        CASE
            WHEN actual_invoice_count = 0
             AND actual_invoiced_amount IS NOT NULL
             AND ABS(actual_invoiced_amount) > 0.01
                THEN 'Reconciliation reports an actual invoiced amount, but no matching invoice exists in AR for this customer-period.'
            WHEN expected_amount IS NULL AND actual_invoice_count > 0
                THEN 'An AR invoice exists, but Gold did not supply an invoice-ready expected amount.'
            WHEN expected_amount IS NULL AND actual_invoice_count = 0
                THEN 'No invoice-ready expected amount is available for this customer-period.'
            WHEN actual_invoice_count > 0 AND currency_profile_status <> 'SINGLE_CURRENCY'
                THEN 'AR currency is missing or contains multiple currencies. Do not compare or total this amount until reviewed.'
            WHEN expected_amount_null_component_count > 0
                THEN 'At least one service-level reconciliation row has no invoice-ready expected amount. The expected total is incomplete.'
            WHEN review_line_count > 0 OR pricing_exception_line_count > 0 OR chargeability_review_line_count > 0
                THEN 'Gold reports billing, pricing or chargeability review lines for this customer-period.'
            WHEN reconciliation_status_review_row_count > 0 OR detail_lines_with_review_status > 0
                THEN 'One or more source status fields indicate review or exception activity. Inspect the service and billing-line detail.'
            WHEN actual_invoice_count = 0
                THEN 'Gold supplied an expected amount, but no matching AR invoice was found for this customer-period.'
            WHEN reconciliation_to_ar_status <> 'MATCHED_TO_AR'
                THEN 'The reconciliation actual amount does not pass the invoice-level AR control.'
            WHEN ABS(actual_invoiced_amount - expected_amount) <= 0.01
                THEN 'Expected and actual amounts agree within the one-cent source tolerance.'
            ELSE 'Expected and actual amounts differ. Review the supporting service and billing-line detail.'
        END AS billing_review_explanation,
        CASE
            WHEN expected_amount_component_count = reconciliation_service_row_count
             AND review_line_count = 0
             AND pricing_exception_line_count = 0
             AND chargeability_review_line_count = 0
             AND reconciliation_status_review_row_count = 0
             AND detail_lines_with_review_status = 0
             AND actual_invoice_count > 0
             AND currency_profile_status = 'SINGLE_CURRENCY'
             AND reconciliation_to_ar_status = 'MATCHED_TO_AR'
            THEN actual_invoiced_amount - expected_amount
            ELSE NULL
        END AS assessable_variance_amount
    FROM summary_with_controls
)

SELECT
    CONCAT(client_id, '|', billing_period_key) AS customer_period_key,
    CASE WHEN currency_code IS NOT NULL
         THEN CONCAT(client_id, '|', billing_period_key, '|', currency_code)
         ELSE NULL
    END AS customer_period_currency_key,
    client_id,
    customer_name,
    customer_dimension_match_status,
    billing_month,
    billing_period,
    billing_period_key,
    currency_code,
    currency_profile_status,
    distinct_currency_count,
    invoices_missing_currency_count,
    reconciliation_service_row_count,
    source_service_types,
    source_billing_cadences,
    source_reconciliation_statuses,
    source_reconciliation_explanations,
    source_activity_count,
    candidate_quantity,
    eligible_billable_quantity,
    expected_amount,
    expected_amount_component_count,
    expected_amount_null_component_count,
    expected_coverage_status,
    actual_invoiced_amount,
    actual_invoice_count,
    CASE WHEN actual_invoice_count > 0 THEN TRUE ELSE FALSE END AS has_actual_invoice,
    ar_invoice_amount_control,
    reconciliation_to_ar_difference,
    reconciliation_to_ar_status,
    assessable_variance_amount,
    billing_review_status,
    billing_review_explanation,
    review_line_count,
    pricing_exception_line_count,
    chargeability_review_line_count,
    reconciliation_status_review_row_count,
    billing_detail_line_count,
    detail_lines_with_invoice_ready_amount,
    detail_lines_with_review_status,
    detail_billing_line_statuses,
    detail_billing_review_statuses
FROM summary_final
ORDER BY billing_period_key, customer_name, client_id;
