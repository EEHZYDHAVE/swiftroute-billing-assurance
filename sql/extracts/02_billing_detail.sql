-- SwiftRoute Billing Assurance Workbench
-- Extract: billing-line detail and exception evidence
-- Intended grain: one row per billing_line_key.
-- Includes valid, unmapped and sentinel customer identifiers so exceptions are not lost.
-- No rate, quantity or charge is recalculated in this query.

WITH customer_dimension AS (
    SELECT
        TRIM(CAST(client_id AS STRING)) AS client_id,
        customer_key,
        customer_name
    FROM gold_customer.dim_customer_c
    WHERE client_id IS NOT NULL
      AND TRIM(CAST(client_id AS STRING)) <> ''
      AND UPPER(TRIM(CAST(client_id AS STRING))) NOT IN ('N/A', 'NULL')
),

billing_detail AS (
    SELECT
        billing_line_key,
        CAST(client_id AS STRING) AS source_client_id,
        TRIM(CAST(client_id AS STRING)) AS client_id,
        customer_name AS source_customer_name,
        account_type,
        account_contract_type,
        account_tier,
        industry,
        primary_city,
        account_net_payment_terms,
        billing_cadence,
        service_month,
        billing_period_start,
        billing_period_end,
        billing_period_label,
        COALESCE(
            NULLIF(REGEXP_EXTRACT(CAST(service_month AS STRING), '^([0-9]{4}-[0-9]{2})', 1), ''),
            NULLIF(REGEXP_EXTRACT(CAST(billing_period_start AS STRING), '^([0-9]{4}-[0-9]{2})', 1), '')
        ) AS billing_period_key,
        activity_source,
        service_type,
        zone_id,
        billing_unit,
        quantity_basis,
        activity_eligibility_status,
        billing_line_status,
        billing_review_status,
        review_explanation,
        contract_candidate_count,
        applicable_contract_id,
        applicable_source_contract_id,
        contract_status_at_extract,
        contract_start_date,
        contract_end_date,
        contract_signed_date,
        applicable_contract_type,
        committed_monthly_volume,
        contract_discount_rate,
        contract_net_payment_terms,
        applicable_contract_rate_id,
        rate_effective_date,
        applicable_rate_zone_id,
        applicable_rate_is_zone_specific,
        rate_unit,
        base_rate,
        applicable_discount_rate,
        source_net_rate,
        calculated_net_rate,
        first_activity_date,
        last_activity_date,
        service_date_basis,
        source_activity_count,
        TO_JSON(source_activity_ids) AS source_activity_ids_json,
        source_order_count,
        TO_JSON(source_order_ids) AS source_order_ids_json,
        candidate_quantity,
        billable_quantity,
        calculated_gross_charge,
        calculated_net_charge,
        invoice_ready_amount
    FROM gold_finance.billing_invoice_lines
)

SELECT
    b.billing_line_key,
    b.source_client_id,
    b.client_id,
    COALESCE(d.customer_name, b.source_customer_name) AS customer_display_name,
    b.source_customer_name,
    d.customer_key,
    CASE
        WHEN b.client_id IS NULL OR TRIM(b.client_id) = ''
          OR UPPER(TRIM(b.client_id)) IN ('N/A', 'NULL')
            THEN 'UNASSIGNED_CUSTOMER_REVIEW'
        WHEN d.client_id IS NULL
            THEN 'CUSTOMER_ID_NOT_FOUND_IN_CANONICAL_DIMENSION'
        ELSE 'MAPPED'
    END AS customer_mapping_status,
    CASE WHEN b.billing_period_key IS NULL THEN 'PERIOD_KEY_MISSING' ELSE 'PERIOD_KEY_AVAILABLE' END
        AS billing_period_mapping_status,
    CASE
        WHEN b.client_id IS NOT NULL
         AND TRIM(b.client_id) <> ''
         AND UPPER(TRIM(b.client_id)) NOT IN ('N/A', 'NULL')
         AND b.billing_period_key IS NOT NULL
        THEN CONCAT(b.client_id, '|', b.billing_period_key)
        ELSE NULL
    END AS customer_period_key,
    b.account_type,
    b.account_contract_type,
    b.account_tier,
    b.industry,
    b.primary_city,
    b.account_net_payment_terms,
    b.billing_cadence,
    b.service_month,
    b.billing_period_start,
    b.billing_period_end,
    b.billing_period_label,
    b.billing_period_key,
    b.activity_source,
    b.service_type,
    b.zone_id,
    b.billing_unit,
    b.quantity_basis,
    b.activity_eligibility_status,
    b.billing_line_status,
    b.billing_review_status,
    b.review_explanation,
    b.contract_candidate_count,
    b.applicable_contract_id,
    b.applicable_source_contract_id,
    b.contract_status_at_extract,
    b.contract_start_date,
    b.contract_end_date,
    b.contract_signed_date,
    b.applicable_contract_type,
    b.committed_monthly_volume,
    b.contract_discount_rate,
    b.contract_net_payment_terms,
    b.applicable_contract_rate_id,
    b.rate_effective_date,
    b.applicable_rate_zone_id,
    b.applicable_rate_is_zone_specific,
    b.rate_unit,
    b.base_rate,
    b.applicable_discount_rate,
    b.source_net_rate,
    b.calculated_net_rate,
    b.first_activity_date,
    b.last_activity_date,
    b.service_date_basis,
    b.source_activity_count,
    b.source_activity_ids_json,
    b.source_order_count,
    b.source_order_ids_json,
    b.candidate_quantity,
    b.billable_quantity,
    b.calculated_gross_charge,
    b.calculated_net_charge,
    b.invoice_ready_amount,
    CASE WHEN b.invoice_ready_amount IS NOT NULL THEN TRUE ELSE FALSE END
        AS has_invoice_ready_amount
FROM billing_detail b
LEFT JOIN customer_dimension d
    ON b.client_id = d.client_id
ORDER BY b.billing_period_key, customer_display_name, b.billing_line_key;
