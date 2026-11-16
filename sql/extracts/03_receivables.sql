-- SwiftRoute Billing Assurance Workbench
-- Extract: invoice-level Receivables & Collections
-- Intended grain: one row per invoice_id.
-- Uses Gold's linked payment and aging fields. No raw payment rows are joined here.
-- days_past_due is consumed as supplied; it is not recalculated in this query or Excel.

WITH customer_dimension AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        customer_key,
        customer_name
    FROM gold_customer.dim_customer_c
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
)

SELECT
    ar.invoice_id,
    ar.source_sync_token,
    ar.document_number,
    CAST(ar.client_id AS STRING) AS source_client_id,
    TRIM(CAST(ar.client_id AS STRING)) AS client_id,
    ar.source_customer_id,
    ar.customer_name AS invoice_customer_name,
    d.customer_name AS canonical_customer_name,
    d.customer_key,
    CASE
        WHEN ar.client_id IS NULL OR TRIM(CAST(ar.client_id AS STRING)) = ''
          OR UPPER(TRIM(CAST(ar.client_id AS STRING))) IN ('N/A', 'NULL')
            THEN 'UNASSIGNED_CUSTOMER_REVIEW'
        WHEN d.client_id IS NULL
            THEN 'CUSTOMER_ID_NOT_FOUND_IN_CANONICAL_DIMENSION'
        ELSE 'MAPPED'
    END AS customer_mapping_status,
    ar.primary_city,
    ar.billing_period,
    NULLIF(REGEXP_EXTRACT(CAST(ar.billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        AS billing_period_key,
    CASE
        WHEN ar.client_id IS NOT NULL
         AND TRIM(CAST(ar.client_id AS STRING)) <> ''
         AND UPPER(TRIM(CAST(ar.client_id AS STRING))) NOT IN ('N/A', 'NULL')
         AND NULLIF(REGEXP_EXTRACT(CAST(ar.billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '') IS NOT NULL
        THEN CONCAT(
            TRIM(CAST(ar.client_id AS STRING)),
            '|',
            NULLIF(REGEXP_EXTRACT(CAST(ar.billing_period AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        )
        ELSE NULL
    END AS customer_period_key,
    ar.invoice_date,
    ar.due_date,
    ar.payment_terms,
    ar.currency_code,
    ar.invoice_amount,
    ar.recorded_current_balance,
    ar.linked_applied_payment_amount,
    ar.linked_payment_count,
    ar.first_linked_payment_date,
    ar.latest_linked_payment_date,
    ar.payment_reconstructed_balance,
    ar.recorded_minus_reconstructed_balance,
    ar.aging_bucket,
    ar.days_past_due,
    ar.receivable_review_status,
    ar.linked_payment_client_mismatch_count
FROM gold_finance.accounts_receivable ar
LEFT JOIN customer_dimension d
    ON TRIM(CAST(ar.client_id AS STRING)) = d.client_id
ORDER BY ar.invoice_date DESC, ar.document_number, ar.invoice_id;
