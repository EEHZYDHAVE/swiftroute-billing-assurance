-- SwiftRoute Billing Assurance Workbench
-- Stage 02: Profile the existing Gold billing models and validate their behavior.
-- Run in Databricks SQL, section by section. All statements are read-only.
-- This is an inspection script. It does not create or modify warehouse objects.

-- 0. Confirm active catalog and complete remaining inventory
SELECT current_catalog() AS active_catalog,
       current_schema() AS active_schema,
       current_timestamp() AS inspection_timestamp;
SHOW TABLES IN gold_customer;
SHOW TABLES IN gold_fulfillment;

-- 1. Billing invoice-line model: grain and key coverage
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT billing_line_key) AS distinct_billing_line_keys,
    COUNT(DISTINCT client_id) AS distinct_customers,
    COUNT(DISTINCT CONCAT_WS('|', client_id,
        CAST(billing_period_start AS STRING),
        CAST(billing_period_end AS STRING),
        COALESCE(billing_cadence, ''))) AS distinct_customer_periods,
    SUM(CASE WHEN billing_line_key IS NULL THEN 1 ELSE 0 END) AS missing_line_keys,
    SUM(CASE WHEN client_id IS NULL THEN 1 ELSE 0 END) AS missing_client_ids
FROM gold_finance.billing_invoice_lines;

-- 1B. Billing line composition and calculation outcomes
SELECT
    billing_cadence, billing_period_label, activity_source, service_type,
    billing_unit, quantity_basis, account_contract_type, applicable_contract_type,
    rate_unit, activity_eligibility_status, billing_line_status, billing_review_status,
    COUNT(*) AS line_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(candidate_quantity) AS candidate_quantity,
    SUM(billable_quantity) AS billable_quantity,
    SUM(invoice_ready_amount) AS invoice_ready_amount,
    SUM(CASE WHEN applicable_contract_rate_id IS NULL THEN 1 ELSE 0 END) AS lines_without_rate_id,
    SUM(CASE WHEN calculated_net_rate IS NULL THEN 1 ELSE 0 END) AS lines_without_net_rate
FROM gold_finance.billing_invoice_lines
GROUP BY billing_cadence, billing_period_label, activity_source, service_type,
    billing_unit, quantity_basis, account_contract_type, applicable_contract_type,
    rate_unit, activity_eligibility_status, billing_line_status, billing_review_status
ORDER BY billing_period_label, billing_cadence, service_type,
    activity_eligibility_status, billing_review_status;

-- 1C. Rate and contract matching coverage
SELECT
    applicable_contract_type, contract_status_at_extract, rate_unit,
    applicable_rate_is_zone_specific, billing_line_status, billing_review_status,
    COUNT(*) AS line_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(CASE WHEN contract_candidate_count = 0 THEN 1 ELSE 0 END) AS no_contract_candidates,
    SUM(CASE WHEN contract_candidate_count > 1 THEN 1 ELSE 0 END) AS multiple_contract_candidates,
    SUM(CASE WHEN applicable_contract_id IS NULL THEN 1 ELSE 0 END) AS missing_contract,
    SUM(CASE WHEN applicable_contract_rate_id IS NULL THEN 1 ELSE 0 END) AS missing_rate,
    SUM(CASE WHEN base_rate IS NULL THEN 1 ELSE 0 END) AS missing_base_rate,
    SUM(CASE WHEN calculated_net_rate IS NULL THEN 1 ELSE 0 END) AS missing_net_rate,
    SUM(invoice_ready_amount) AS invoice_ready_amount
FROM gold_finance.billing_invoice_lines
GROUP BY applicable_contract_type, contract_status_at_extract, rate_unit,
    applicable_rate_is_zone_specific, billing_line_status, billing_review_status
ORDER BY applicable_contract_type, rate_unit, billing_line_status;

-- 1D. Representative expected-charge detail
SELECT *
FROM gold_finance.billing_invoice_lines
ORDER BY service_month DESC, client_id, service_type
LIMIT 100;

-- 2. Reconciliation grain and aggregation behavior
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT reconciliation_key) AS distinct_reconciliation_keys,
    COUNT(DISTINCT client_id) AS distinct_customers,
    COUNT(DISTINCT CONCAT_WS('|', client_id, CAST(billing_month AS STRING),
        COALESCE(billing_period, ''), COALESCE(billing_cadence, ''))) AS customer_period_groups
FROM gold_finance.billing_reconciliation;

-- 2B. Multiple rows per customer-period-cadence, likely due to service_type
SELECT
    client_id, billing_month, billing_period, billing_cadence,
    COUNT(*) AS row_count,
    COUNT(DISTINCT service_type) AS service_type_count,
    COLLECT_SET(service_type) AS service_types
FROM gold_finance.billing_reconciliation
GROUP BY client_id, billing_month, billing_period, billing_cadence
HAVING COUNT(*) > 1
ORDER BY billing_month DESC, client_id
LIMIT 200;

-- 2C. Reconciliation measures at the existing row dimensions
SELECT
    billing_month, billing_period, billing_cadence, service_type,
    reconciliation_status,
    COUNT(*) AS row_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(source_activity_count) AS source_activity_count,
    SUM(eligible_billable_quantity) AS eligible_billable_quantity,
    SUM(invoice_ready_expected_charge_amount) AS expected_amount,
    SUM(actual_invoiced_amount) AS actual_invoiced_amount,
    SUM(actual_invoice_count) AS actual_invoice_count,
    SUM(pricing_exception_line_count) AS pricing_exception_lines,
    SUM(chargeability_review_line_count) AS chargeability_review_lines
FROM gold_finance.billing_reconciliation
GROUP BY billing_month, billing_period, billing_cadence, service_type, reconciliation_status
ORDER BY billing_month DESC, billing_period, billing_cadence, service_type;

-- 2D. Diagnostic customer-period rollup.
-- CAUTION: Do not treat SUM(actual_invoiced_amount) as final customer-period
-- actual billing until compared with accounts_receivable. It may be repeated
-- or allocated across service-type rows.
SELECT
    client_id, billing_month, billing_period, billing_cadence,
    COUNT(*) AS reconciliation_rows,
    COUNT(DISTINCT service_type) AS service_type_count,
    SUM(invoice_ready_expected_charge_amount) AS summed_expected_amount,
    SUM(actual_invoiced_amount) AS diagnostic_summed_actual_amount,
    SUM(actual_minus_invoice_ready_variance) AS diagnostic_summed_variance,
    SUM(actual_invoice_count) AS diagnostic_summed_invoice_count
FROM gold_finance.billing_reconciliation
GROUP BY client_id, billing_month, billing_period, billing_cadence
ORDER BY billing_month DESC, client_id
LIMIT 200;

SELECT *
FROM gold_finance.billing_reconciliation
ORDER BY billing_month DESC, client_id, service_type
LIMIT 100;

-- 3. Actual invoices and receivables
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT invoice_id) AS distinct_invoice_ids,
    COUNT(DISTINCT client_id) AS distinct_customers,
    SUM(invoice_amount) AS total_invoice_amount,
    SUM(recorded_current_balance) AS total_recorded_balance,
    SUM(payment_reconstructed_balance) AS total_reconstructed_balance,
    SUM(recorded_minus_reconstructed_balance) AS total_balance_difference,
    SUM(CASE WHEN invoice_id IS NULL THEN 1 ELSE 0 END) AS missing_invoice_ids,
    SUM(CASE WHEN client_id IS NULL THEN 1 ELSE 0 END) AS missing_client_ids
FROM gold_finance.accounts_receivable;

-- 3B. Independent actual invoice control total by customer-period-currency
SELECT
    client_id, billing_period, currency_code,
    COUNT(DISTINCT invoice_id) AS invoice_count,
    SUM(invoice_amount) AS actual_invoice_amount,
    SUM(recorded_current_balance) AS current_receivable_balance,
    MIN(invoice_date) AS first_invoice_date,
    MAX(invoice_date) AS last_invoice_date,
    MIN(due_date) AS earliest_due_date,
    MAX(due_date) AS latest_due_date
FROM gold_finance.accounts_receivable
GROUP BY client_id, billing_period, currency_code
ORDER BY last_invoice_date DESC, client_id
LIMIT 300;

-- 3C. Receivables aging/review profile
SELECT
    aging_bucket, receivable_review_status, payment_terms, currency_code,
    COUNT(*) AS invoice_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(invoice_amount) AS invoice_amount,
    SUM(recorded_current_balance) AS current_balance,
    SUM(payment_reconstructed_balance) AS reconstructed_balance,
    SUM(recorded_minus_reconstructed_balance) AS balance_difference,
    AVG(days_past_due) AS average_days_past_due,
    MAX(days_past_due) AS maximum_days_past_due
FROM gold_finance.accounts_receivable
GROUP BY aging_bucket, receivable_review_status, payment_terms, currency_code
ORDER BY aging_bucket, receivable_review_status;

SELECT *
FROM gold_finance.accounts_receivable
ORDER BY invoice_date DESC, client_id
LIMIT 100;

-- 4. Last-mile service classification, delivery outcomes and rate matching
-- 4A. Service dimension: check whether return services appear in labels/groups
SELECT *
FROM gold_last_mile.dim_service
ORDER BY service_group, service_type;

-- 4B. Delivery outcome and match-status distribution
SELECT
    task_status, task_state_code, delivery_outcome,
    is_completed, is_successful_delivery,
    account_match_status, contract_match_status,
    rate_match_status, billing_context_match_status,
    COUNT(*) AS task_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(delivery_count) AS delivery_count,
    SUM(task_quantity) AS task_quantity
FROM gold_last_mile.fact_delivery
GROUP BY task_status, task_state_code, delivery_outcome,
    is_completed, is_successful_delivery, account_match_status,
    contract_match_status, rate_match_status, billing_context_match_status
ORDER BY task_count DESC;

-- 4C. Service/outcome profile using the service dimension
SELECT
    s.service_type, s.service_name, s.service_group,
    s.is_same_day_service, s.is_next_day_service,
    s.is_scheduled_service, s.is_distribution_service, s.is_unknown_service,
    f.task_status, f.delivery_outcome, f.is_successful_delivery,
    COUNT(*) AS task_count,
    COUNT(DISTINCT f.client_id) AS customer_count
FROM gold_last_mile.fact_delivery f
LEFT JOIN gold_last_mile.dim_service s ON f.service_key = s.service_key
GROUP BY s.service_type, s.service_name, s.service_group,
    s.is_same_day_service, s.is_next_day_service, s.is_scheduled_service,
    s.is_distribution_service, s.is_unknown_service,
    f.task_status, f.delivery_outcome, f.is_successful_delivery
ORDER BY s.service_group, s.service_type, task_count DESC;

-- 4D. Rate-match coverage
SELECT
    matched_contract_rate_unit, rate_match_status, contract_match_status,
    billing_context_match_status,
    COUNT(*) AS task_count,
    SUM(CASE WHEN contract_rate_id IS NULL THEN 1 ELSE 0 END) AS missing_rate_id,
    SUM(CASE WHEN matched_contract_base_rate IS NULL THEN 1 ELSE 0 END) AS missing_base_rate,
    SUM(CASE WHEN matched_contract_net_rate IS NULL THEN 1 ELSE 0 END) AS missing_net_rate
FROM gold_last_mile.fact_delivery
GROUP BY matched_contract_rate_unit, rate_match_status,
    contract_match_status, billing_context_match_status
ORDER BY task_count DESC;

-- 4E. Distribution service examples. The supplied fact schema has no obvious
-- dedicated run_id column. Inspect records for a reliable source run key.
SELECT
    f.delivery_id, f.client_id, f.delivery_event_date_key, f.completion_date_key,
    f.driver_key, f.city_key, f.zone_key, s.service_type, s.service_name,
    f.contract_key, f.task_status, f.delivery_outcome, f.is_successful_delivery,
    f.task_created_at_utc, f.completion_time_utc, f.task_vehicle_type,
    f.delivery_count, f.task_quantity, f.contract_rate_id,
    f.matched_contract_rate_unit, f.matched_contract_base_rate, f.matched_contract_net_rate
FROM gold_last_mile.fact_delivery f
LEFT JOIN gold_last_mile.dim_service s ON f.service_key = s.service_key
WHERE s.is_distribution_service = TRUE
ORDER BY f.task_created_at_utc DESC
LIMIT 200;

-- 4F. Contract population and attributes
SELECT
    contract_type, contract_status,
    COUNT(*) AS contract_count,
    COUNT(DISTINCT client_id) AS customer_count,
    SUM(CASE WHEN committed_monthly_volume IS NULL THEN 1 ELSE 0 END) AS missing_commitment,
    SUM(CASE WHEN discount_rate IS NULL THEN 1 ELSE 0 END) AS missing_discount,
    SUM(CASE WHEN is_orphaned_contract THEN 1 ELSE 0 END) AS orphaned_contracts,
    SUM(CASE WHEN is_unknown_contract THEN 1 ELSE 0 END) AS unknown_contracts
FROM gold_last_mile.dim_contract_l
GROUP BY contract_type, contract_status
ORDER BY contract_type, contract_status;

-- 5. Fulfillment and customer schema inspection
DESCRIBE TABLE gold_fulfillment.fact_fulfillment_transaction;
DESCRIBE TABLE gold_fulfillment.dim_contract;
DESCRIBE TABLE gold_fulfillment.dim_customer;
DESCRIBE TABLE gold_fulfillment.dim_product;
DESCRIBE TABLE gold_fulfillment.dim_warehouse;
DESCRIBE TABLE gold_fulfillment.dim_date;
DESCRIBE TABLE gold_customer.dim_customer_c;
DESCRIBE TABLE gold_customer.fact_customer_economics;

SELECT *
FROM gold_fulfillment.fact_fulfillment_transaction
LIMIT 100;

-- 6. Cross-domain customer coverage
-- Run this first for the models whose client_id columns are confirmed.
SELECT 'billing_invoice_lines' AS source_model, COUNT(DISTINCT client_id) AS customer_count
FROM gold_finance.billing_invoice_lines
UNION ALL
SELECT 'accounts_receivable', COUNT(DISTINCT client_id)
FROM gold_finance.accounts_receivable
UNION ALL
SELECT 'fact_delivery', COUNT(DISTINCT client_id)
FROM gold_last_mile.fact_delivery;

-- After inspecting DESCRIBE TABLE gold_fulfillment.fact_fulfillment_transaction,
-- add its confirmed customer/client key to a separate comparison query.
