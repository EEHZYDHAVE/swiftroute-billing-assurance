# SwiftRoute Billing Assurance Workbench
## Data Dictionary and Gold Field Mapping

**Version:** 1.0  
**Prepared:** 9 November 2026  
**Status:** Working reference for downstream extract design  
**Project:** `swiftroute-billing-assurance`

---

## 1. Purpose

This document maps the agreed Billing Assurance business rules to the existing Gold datasets and the fields that can support them. It is the field-level reference for the downstream SQL extracts and Excel workbench.

The dictionary is deliberately focused on fields relevant to the Billing Review and Receivables & Collections worksheets. It is not a complete physical catalog of every column in every Gold model. Field names below are taken from the existing model SQL, inspected schema outputs and the supplied validation results. The field tables prioritize business meaning and workbench handling rather than repeating physical data types for every column. Where types were captured during inspection, the inspection output remains the schema reference; re-run `DESCRIBE TABLE` against the active workspace before finalizing extract casts or Excel data types. Do not guess or silently coerce field types.

## 2. Architecture boundary

The existing Gold layer is read-only for this project. No Gold model, schema, transformation, test or source relationship is to be changed as part of the Billing Assurance Workbench.

All downstream work must happen in the separate `swiftroute-billing-assurance` project:

1. Read the existing Gold models.
2. Apply only the aggregation, projection, presentation and validation needed for the workbook.
3. Export controlled files for Excel Power Query or an equivalent refresh process.
4. Preserve source statuses and values. When a field or calculation is unavailable, surface the limitation rather than manufacture a replacement.

The workbook is a review and decision-support workpaper. It does not calculate a second set of prices, issue invoices, post credits, or write changes back to Gold or QuickBooks.

## 3. Gold model inventory and intended role

### 3.1 Primary billing and receivables models

| Gold dataset | Business grain | Workbench role | Use |
|---|---|---|---|
| `gold_finance.billing_invoice_lines` | One row per aggregated billing-line group, uniquely identified by `billing_line_key`. A row can represent multiple source activities sharing the same customer, period, source, service, zone, contract/rate and status context. | Billing detail | Drill-down evidence for activity, period, quantity, contract/rate context, line status and the invoice-ready charge. |
| `gold_finance.billing_reconciliation` | One row per customer, billing month and service type, identified by `reconciliation_key`. `billing_cadence` is an attribute, not part of the generated key. | Billing summary source | Service-level expected and actual billing measures, exception counts and reconciliation status. Must be aggregated downstream to customer + billing period for the main Billing Review queue. |
| `gold_finance.accounts_receivable` | One row per QuickBooks invoice (`invoice_id`). The inspected profile contained 564 rows and 564 distinct invoice IDs. | Receivables and invoice detail | Invoice number, invoice amount, balance, dates, payment terms, linked payment information and aging. |

### 3.2 Supporting and investigative models

| Gold dataset | Business grain / content | Workbench role | Boundary |
|---|---|---|---|
| `gold_finance.financial_transaction_lines` | Mixed record grain: invoice line, payment header, payment application line, expense line, or header fallback where a source transaction has no lines. | Financial audit and investigation only | Amounts have distinct roles. Do not sum all rows or use this model as the primary AR balance calculation. |
| `gold_last_mile.fact_delivery` | One row per delivery task / delivery record. | Operational investigation | Use outcomes and task attributes to explain activity or failures. Do not re-price delivery tasks or replace Finance billing outputs. |
| `gold_last_mile.dim_service` | One row per supported service classification. | Service label lookup | Supplies service groups and flags. The inspected classifications do not provide a dedicated returns service classification. |
| `gold_last_mile.dim_contract_l` | Contract context, including customer, status, type, validity dates, commitment and payment terms. | Contract context only | Supports investigation of the contract context already reflected in Finance Gold. Do not independently select a rate or calculate charges. |
| `gold_last_mile.dim_customer_l` | Last-mile customer dimension. | Supporting customer context | Not the primary customer selector for the workbench. Exclude sentinel values such as `N/A`. |
| `gold_fulfillment.fact_fulfillment_transaction` | One row per Linnworks stock transaction. | Fulfillment operational investigation | `quantity_moved` and stock movement measures describe inventory movements, not billable pick quantities. Do not turn them into invoice amounts. |
| `gold_fulfillment.dim_contract`, `dim_customer`, `dim_product`, `dim_warehouse`, `dim_date` | Fulfillment lookup dimensions. | Supporting descriptions and filtering | Join only when needed to explain a fulfillment transaction. Finance Gold remains authoritative for expected charge. |
| `gold_customer.dim_customer_c` | One row per canonical SwiftRoute client. | Canonical customer selector / display context | Use valid `client_id` values and the customer key/name where a conformed customer list is needed. |
| `gold_customer.fact_customer_economics` | One row per canonical customer and `period_month`. | Optional customer-period context | Can supplement service mix and customer-period context. It does not replace billing reconciliation or invoice-level AR. |
| `gold_finance.financial_reporting_monthly` | One row per accounting month, customer where available, location, financial area and reporting category. | Out of scope for core workbook | Not required for billing assurance or invoice-level collections. Do not use it to recreate billing or AR measures. |

## 4. Business rule to Gold field mapping

| Business rule / workbook requirement | Primary dataset and fields | Supporting fields / model | Workbench treatment |
|---|---|---|---|
| Identify the customer consistently across billing, invoices and support detail. | `billing_invoice_lines.client_id`, `billing_reconciliation.client_id`, `accounts_receivable.client_id` | `dim_customer_c.client_id`, `dim_customer_c.customer_key`, `dim_customer_c.customer_name`; supporting `fact_delivery.client_id` and `fact_fulfillment_transaction.customer_key` | Use canonical `client_id` as the business join key. Use the canonical customer dimension for selection/display where appropriate. Do not match customers by name. Exclude null, blank, `N/A` and `null` sentinel IDs from the normal customer list; retain affected rows in an unresolved-mapping exception view. |
| Display the customer name and account context. | `billing_invoice_lines.customer_name`; `accounts_receivable.customer_name` | `dim_customer_c.customer_name`; `account_type`, `account_contract_type`, `account_tier`, `industry`, `primary_city` from billing lines | Prefer the canonical customer dimension for a consistent selector. Preserve source customer names on detail records for traceability. Do not let account segment or tier override commercial terms. |
| Select the billing period. | `billing_reconciliation.billing_month`, `billing_reconciliation.billing_period`; `billing_invoice_lines.service_month`, `billing_period_start`, `billing_period_end`, `billing_period_label`; `accounts_receivable.billing_period` | `fact_customer_economics.period_month`, `billing_period` | Use the period supplied by Gold. Do not create weekly periods in the current workbook because the inspected Finance output contains `MONTHLY` and `UNKNOWN`, not a demonstrated weekly PAYG population. Preserve the documented Monday-to-Sunday PAYG rule as an operating-context note only. |
| Keep service scope distinct from commercial arrangement. | `billing_invoice_lines.activity_source`, `service_type`, `account_contract_type`, `applicable_contract_type` | `dim_customer_c.has_ever_used_fulfillment`, `has_ever_used_last_mile`; `fact_customer_economics.has_fulfillment_activity`, `has_last_mile_activity`, `customer_service_mix` | Show service mix separately from account/contract classification. Do not treat fulfillment as a contract type. |
| Identify service type and service context. | `billing_invoice_lines.service_type`, `activity_source`, `zone_id`, `billing_unit`, `quantity_basis` | `fact_delivery.service_key`, `dim_service.service_type`, `service_name`, `service_group` and service flags | Preserve source service classifications. The inspected set includes `next_day`, `same_day`, `distribution_run`, `scheduled` and an unknown/unmapped category. Do not infer returns from generic pickup activity. |
| Determine whether activity is eligible, billable and ready for review. | `billing_invoice_lines.activity_eligibility_status`, `billing_line_status`, `billing_review_status`, `review_explanation`, `candidate_quantity`, `billable_quantity` | `fact_delivery.is_completed`, `is_successful_delivery`, `delivery_outcome`; `fact_delivery.completion_failure_reason` | Eligibility is not the same as billing readiness. Use the line status and review status as well as the existence of a usable invoice-ready amount. Preserve the Gold exception reason. |
| Identify unresolved chargeability and pricing issues. | `billing_invoice_lines.billing_line_status`, `billing_review_status`, `review_explanation`, `contract_candidate_count`, `contract_status_at_extract` | `billing_reconciliation.review_line_count`, `pricing_exception_line_count`, `chargeability_review_line_count`; operational status fields in `fact_delivery` and `fact_fulfillment_transaction` | Surface unknown cadence, pickup chargeability, failed-task chargeability, unmapped service, missing customer mapping, missing rate and fulfillment matching exceptions. Do not resolve them by guessing in Excel. |
| Show contract and rate context behind a ready line. | `billing_invoice_lines.applicable_contract_id`, `applicable_source_contract_id`, `contract_status_at_extract`, `contract_start_date`, `contract_end_date`, `contract_signed_date`, `applicable_contract_type`, `committed_monthly_volume`, `contract_discount_rate`, `contract_net_payment_terms`, `applicable_contract_rate_id`, `rate_effective_date`, `applicable_rate_zone_id`, `applicable_rate_is_zone_specific`, `rate_unit`, `base_rate`, `applicable_discount_rate`, `source_net_rate`, `calculated_net_rate` | `dim_contract_l.contract_key`, `source_contract_id`, `contract_status`, `contract_type`, `start_date`, `end_date`, `committed_monthly_volume`, `discount_rate`, `net_payment_terms` | These are explanatory and traceability fields. Consume the price already calculated by Finance Gold; do not create a second rate-selection hierarchy in the workbench. Preserve the source class labels such as `Fixed Rate` and `Variable Rate` without translating them into PAYG, volume contract or fixed monthly fee. |
| Show operational activity lineage behind the billing line. | `billing_invoice_lines.first_activity_date`, `last_activity_date`, `service_date_basis`, `source_activity_count`, `source_activity_ids`, `source_order_count`, `source_order_ids` | `fact_delivery.delivery_id`, task dates and outcomes; fulfillment `source_stock_transaction_id`, `source_order_id`, `order_reference`, `tracking_number` | Keep these fields in the detail extract where useful. They support investigation but do not create an independent charge calculation. |
| Show calculated quantities and charge components. | `billing_invoice_lines.candidate_quantity`, `billable_quantity`, `calculated_gross_charge`, `calculated_net_charge`, `invoice_ready_amount` | `billing_reconciliation.candidate_quantity`, `eligible_billable_quantity`, `calculated_expected_charge_amount`, `invoice_ready_expected_charge_amount` | Use `invoice_ready_amount` for a ready billing-line expected charge. Use the reconciliation expected amount for the summary. Do not recalculate amount from rate × quantity in Excel or downstream SQL. |
| Consolidate expected and actual charges to one customer-period row. | `billing_reconciliation.client_id`, `billing_month`, `billing_period`, `service_type`, `invoice_ready_expected_charge_amount`, `actual_invoiced_amount` | `accounts_receivable.client_id`, `billing_period`, `invoice_id`, `invoice_amount`, `currency_code` | Aggregate service-level reconciliation rows by `client_id` + `billing_period`. The sum of `actual_invoiced_amount` at this grain was validated against AR for all 564 matched customer-periods. Keep line/service detail underneath the summary. |
| Show invoice count for a customer-period. | `accounts_receivable.invoice_id`, `client_id`, `billing_period` | `billing_reconciliation.actual_invoice_count` | Count distinct `invoice_id` from AR at customer-period grain. Do not assume summing `actual_invoice_count` across service rows is safe where one invoice can contain multiple service categories. |
| Show a customer-period variance. | `billing_reconciliation.actual_minus_invoice_ready_variance`, `reconciliation_status`, `reconciliation_explanation` | `invoice_ready_expected_charge_amount`, `actual_invoiced_amount`, `review_line_count`, pricing and chargeability exception counts | The sign convention is actual minus expected. Only interpret variance as conclusive when expected coverage is complete enough to assess and material review exceptions are absent. A null expected amount is not zero. Gold's row-level variance uses null-to-zero handling, so the workbench must not rely on a numeric variance alone. |
| Show the invoice and document number. | `accounts_receivable.invoice_id`, `document_number` | `financial_transaction_lines.transaction_id`, `source_transaction_id`, `source_line_id` | AR is the invoice-level source. Use transaction lines only for drill-through or audit where required. |
| Show invoice amount and currency. | `accounts_receivable.invoice_amount`, `currency_code` | `financial_transaction_lines.amount`, `amount_role`, `currency_code` | Use invoice amount as the accounting actual. Preserve currency. Do not aggregate different currencies without an explicit conversion rule. The supplied AR profile contained one currency. |
| Show open balance and linked payments. | `accounts_receivable.recorded_current_balance`, `linked_applied_payment_amount`, `linked_payment_count`, `first_linked_payment_date`, `latest_linked_payment_date`, `payment_reconstructed_balance`, `recorded_minus_reconstructed_balance` | `financial_transaction_lines.amount`, `amount_role`, `record_level`, `linked_invoice_id`, `application_link_status`, `unapplied_amount` | Use `recorded_current_balance` as the displayed AR balance and keep reconstruction fields as a validation control. Do not add payment headers to payment application lines. Do not use `cash_received_amount` as revenue. |
| Show due date, terms and aging. | `accounts_receivable.invoice_date`, `due_date`, `payment_terms`, `days_past_due`, `aging_bucket`, `receivable_review_status` | `account_net_payment_terms` and `contract_net_payment_terms` from billing lines are context only | Use invoice-level terms and due date. `days_past_due` is calculated in the Gold AR model from `CURRENT_DATE()` and `due_date` for open balances; the workbook should display the supplied value and Last Refreshed timestamp rather than recalculate with Excel `TODAY()`. |
| Apply the collections escalation policy. | `accounts_receivable.days_past_due`, `due_date`, `invoice_date`, `recorded_current_balance` | Business operating context milestones: Day 35, Day 45, Day 55 and Day 60 | Display source aging. Do not automatically assign the escalation stage until the business confirms whether the milestone count starts from invoice date or due date. |
| Investigate failed and unsuccessful deliveries. | `fact_delivery.delivery_id`, `client_id`, `task_status`, `delivery_outcome`, `is_completed`, `is_successful_delivery`, `completion_failure_reason` | `dim_service.service_type`, `service_group` | Unsuccessful deliveries are not billable under the agreed workbench rule and are retained as SwiftRoute operating-cost/service evidence. Do not apply customer rates to failed tasks or allocate general expenses to them. |
| Investigate distribution service basis. | `billing_invoice_lines.billing_unit`, `quantity_basis`, `invoice_ready_amount` | `fact_delivery.delivery_id`, `task_vehicle_type`, `delivery_count`; `dim_service.is_distribution_service` | Gold represents the observed distribution billing unit as `per_delivery`. No distinct physical run identifier was identified. Do not calculate a run count or per-run charge. |
| Investigate fulfillment activity. | `billing_invoice_lines` fields for `activity_source`, `service_type`, quantity, status and `invoice_ready_amount` | `fact_fulfillment_transaction.fulfillment_transaction_id`, `source_stock_transaction_id`, `transaction_date`, `activity_month`, `fulfillment_transaction_type`, `inventory_movement_direction`, `quantity_change`, `quantity_moved`, `order_reference`, `order_dispatched_at_utc`, `fulfillment_rate_context_status`, `fulfillment_pick_rate_id`, `fulfillment_pick_service_type`, `fulfillment_pick_rate_unit`, `fulfillment_pick_rate_effective_date`, `has_fulfillment_pick_invoice_for_client_month` | Finance Gold is the expected-charge source. Fulfillment stock movements and quantities are not automatically equivalent to billable pick quantities. Use fact rows to investigate matches or operational context only. |
| Show actual returns/storage invoicing where expected charge is unavailable. | `billing_reconciliation.service_type`, `actual_invoiced_amount`, `invoice_ready_expected_charge_amount`, `reconciliation_status`, `reconciliation_explanation` | `billing_invoice_lines` was inspected for matching ready lines; none were returned for returns or storage in the supplied validation | Show actual amounts if present, but label expected coverage unavailable/not calculated. Do not derive expected rates or quantities from actual invoice amounts. Do not treat pickup as a return. |
| Add broader customer-period context if useful. | Not a primary billing control source. | `fact_customer_economics.customer_period_key`, `customer_key`, `client_id`, `period_month`, `billing_period`, `customer_service_mix`, `has_fulfillment_activity`, `has_last_mile_activity`, `invoice_count`, `invoiced_amount`, `current_outstanding_balance_for_billing_period`, service-specific invoiced amounts, payment counts, `cash_received_amount`, `collections_applied_to_period_invoices_amount` | Optional supplementary context only. Its outstanding balance is the current balance of invoices assigned to that period, not historical month-end AR. Its cash received amount belongs to the payment transaction month, not necessarily the invoice month. |

## 5. Detailed field dictionary

### 5.1 `gold_finance.billing_invoice_lines`

**Purpose:** Primary source for expected billing detail and traceability.  
**Grain:** One row per aggregated billing-line group, uniquely identified by `billing_line_key`. A line is not necessarily one raw delivery task or one raw stock transaction.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `billing_line_key` | Stable unique identifier for the aggregated billing line. | Detail row key; validate uniqueness in each refresh. |
| `client_id` | Canonical SwiftRoute customer ID. | Join key to customer, reconciliation and AR. Exclude invalid sentinels from customer dropdowns. |
| `customer_name` | Customer name carried into the billing line. | Detail display and traceability. |
| `account_type` | Account classification from customer context. | Descriptive only. |
| `account_contract_type` | Account-level contract classification. | Preserve source label; do not infer a specific commercial arrangement from `Fixed Rate` / `Variable Rate`. |
| `account_tier` | Customer tier. | Optional reviewer context. |
| `industry` | Customer industry classification. | Optional reviewer context. |
| `primary_city` | Customer's primary city. | Optional filter/context; not a billing key. |
| `account_net_payment_terms` | Account-level payment terms. | Context only; invoice-level AR terms govern collection display. |
| `billing_cadence` | Cadence supplied by Finance Gold. | Observed values are `MONTHLY` and `UNKNOWN`. Preserve `UNKNOWN`; do not assume PAYG. |
| `service_month` | Month associated with the service activity. | Period filtering and month alignment. |
| `billing_period_start`, `billing_period_end` | Start and end dates supplied for the billing period. | Display exact period boundary from Gold. |
| `billing_period_label` | Display label derived from the billing period start date. | Period label in the detail and workbook. |
| `activity_source` | Origin of the billing activity, such as Onfleet or fulfillment source. | Detail classification and drill-down context. |
| `service_type` | Business service classification, for example `next_day`, `same_day`, `distribution_run` or `fulfillment_pick`. | Service breakdown. Preserve unmapped/null values as exceptions. |
| `zone_id` | Delivery zone context where relevant. | Detail only; do not derive a rate from it. |
| `billing_unit` | Unit attached to the expected rate, such as `per_delivery` or `per_unit`. | Displayed pricing context. Do not transform one unit into another. |
| `quantity_basis` | Description of the activity quantity used by Finance Gold. | Explains quantity semantics. |
| `activity_eligibility_status` | Status of the source activity's eligibility. | Does not alone establish invoice readiness. |
| `billing_line_status` | Gold's line-level billing status, including ready or review states. | Primary source status for billing detail. Preserve exactly. |
| `billing_review_status` | Workbench-readable review classification supplied by Gold. | Use to filter ready, not billable and review-required lines. |
| `review_explanation` | Explanation for the billing-line status. | Show to reviewer without rewriting the underlying source reason. |
| `contract_candidate_count` | Number of candidate contracts considered for the activity. | Helps explain ambiguous or missing contract selection. |
| `applicable_contract_id` | Contract identifier selected by Gold for the billing line. | Contract traceability only. |
| `applicable_source_contract_id` | Source contract identifier associated with the selected contract. | Source lineage. |
| `contract_status_at_extract` | Contract status when the billing line was produced. | Context for review. |
| `contract_start_date`, `contract_end_date`, `contract_signed_date` | Relevant contract dates. | Contract validity context. |
| `applicable_contract_type` | Contract type selected by Gold. | Preserve as source classification; not a substitute for an independently agreed customer arrangement label. |
| `committed_monthly_volume` | Monthly volume commitment associated with the contract, where available. | Context only. Do not recompute overage. |
| `contract_discount_rate` | Contract discount context. | Traceability only. |
| `contract_net_payment_terms` | Contract-level payment terms. | Context only; AR invoice terms remain authoritative for collections. |
| `applicable_contract_rate_id` | Rate record associated with the billing line. | Rate traceability. |
| `rate_effective_date` | Effective date of the selected rate. | Confirm rate timing during investigation. |
| `applicable_rate_zone_id` | Zone associated with the selected rate. | Rate traceability. |
| `applicable_rate_is_zone_specific` | Indicates whether the applicable rate is zone-specific. | Context only. |
| `rate_unit` | Pricing unit defined by the rate. | Traceability; not a formula instruction for Excel. |
| `base_rate` | Base unit rate used by Finance Gold. | Display for audit only; do not multiply it by quantity again. |
| `applicable_discount_rate` | Discount applied in the Finance Gold pricing calculation. | Display for audit only. |
| `source_net_rate` | Net rate from the source rate context. | Display for audit only. |
| `calculated_net_rate` | Net rate calculated by Finance Gold. | Display for audit only. |
| `first_activity_date`, `last_activity_date` | First and last activity dates represented by the aggregated line. | Detail context and period investigation. |
| `service_date_basis` | Date basis used to place source activity in the service period. | Explains service-month attribution. |
| `source_activity_count`, `source_activity_ids` | Count and identifiers of source activities represented. | Lineage and investigation. IDs may be an array. |
| `source_order_count`, `source_order_ids` | Count and identifiers of source orders represented. | Fulfillment/order lineage where applicable. IDs may be an array. |
| `candidate_quantity` | Candidate volume considered by the billing model. | Context only; not automatically billable. |
| `billable_quantity` | Quantity accepted by the billing logic before final readiness checks. | Context only; line may still require review. |
| `calculated_gross_charge` | Gross charge calculated by Finance Gold. | Supporting pricing trace. |
| `calculated_net_charge` | Net charge calculated by Finance Gold. | Supporting pricing trace. |
| `invoice_ready_amount` | Charge amount Finance Gold exposes as ready for invoicing. | Use as the line-level expected amount only when the line is ready. Null means not calculated/ready, not zero. |

### 5.2 `gold_finance.billing_reconciliation`

**Purpose:** Service-level expected-versus-actual billing control.  
**Grain:** One row per `client_id` + `billing_month` + `service_type`, identified by `reconciliation_key`.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `reconciliation_key` | Deterministic key for the customer-month-service row. | Source row key; use to detect duplicates. |
| `client_id` | Canonical customer ID. | Customer-period aggregation key. |
| `billing_month` | Monthly date field for the reconciliation row. | Month-level alignment key. |
| `billing_period` | Formatted billing period, observed as `YYYY-MM`. | User-facing period label and AR join context. |
| `service_type` | Service represented by the row. | Service-level breakdown. |
| `billing_cadence` | Cadence attached to the service-period row. | Preserve `UNKNOWN`; not a reliable PAYG classifier. |
| `source_activity_count` | Count of source activity represented. | Activity coverage context. |
| `candidate_quantity` | Candidate quantity considered. | Diagnostic measure. |
| `eligible_billable_quantity` | Quantity classified as eligible billable activity. | Not proof of a ready charge; check exceptions and expected amount. |
| `calculated_expected_charge_amount` | Calculated expected charge before invoice-readiness restriction. | Supporting calculation evidence; not the primary expected amount. |
| `invoice_ready_expected_charge_amount` | Expected amount that passed Finance Gold's invoice-readiness rules. | Primary service-level expected amount for summary aggregation. Preserve nulls. |
| `actual_invoiced_amount` | Actual QuickBooks invoice amount assigned to the service/month row. | Sum across service rows to customer + billing period; roll-up was validated against AR for all 564 overlapping customer-periods. |
| `actual_invoice_count` | Invoice count associated with the service/month row. | Diagnostic only. Use distinct `accounts_receivable.invoice_id` for customer-period invoice count to avoid double counting across services. |
| `review_line_count` | Count of billing lines requiring review. | Coverage and status indicator. |
| `pricing_exception_line_count` | Count of pricing exception lines. | Coverage indicator. |
| `chargeability_review_line_count` | Count of chargeability review lines. | Coverage indicator. |
| `actual_minus_invoice_ready_variance` | Gold row-level actual less invoice-ready expected amount, with null handling in the model. | Do not treat as conclusive by itself. The workbench should qualify a customer-period variance using coverage and exception counts. |
| `reconciliation_status` | Gold's service-level reconciliation status. | Preserve as source evidence; customer-period summary status must account for all service rows and exceptions. |
| `reconciliation_explanation` | Gold's service-level explanation. | Show during drill-down or exception review. |

**Customer-period aggregation:** Group by `client_id` + `billing_period` (or the equivalent `billing_month` key). Sum the expected and actual service-level amounts. The actual amount roll-up is validated against AR totals at this grain. Preserve null expected amounts; do not coalesce them to zero for display or coverage assessment. Keep service-level detail available.

### 5.3 `gold_finance.accounts_receivable`

**Purpose:** Invoice-level actuals, receivable balances and collections monitoring.  
**Grain:** One row per QuickBooks invoice.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `invoice_id` | Unique QuickBooks invoice identifier. | Invoice-level primary key; use distinct count at customer-period level. |
| `source_sync_token` | QuickBooks source version token. | Audit/lineage only. |
| `document_number` | Human-readable invoice number. | Primary invoice display field. |
| `client_id` | Canonical SwiftRoute customer ID. | Customer join key. |
| `source_customer_id` | QuickBooks internal customer reference. | Source lineage only; do not substitute for canonical `client_id`. |
| `customer_name` | Customer name from the invoice source. | Invoice display and cross-check. |
| `primary_city` | Mapped primary customer city. | Optional filter/context. |
| `billing_period` | Billing period assigned to the invoice. | Customer-period actual roll-up. |
| `invoice_date` | Invoice transaction date. | Invoice age and invoice timing context. |
| `due_date` | Invoice due date. | Days past due and collection review. |
| `payment_terms` | Payment terms carried by the invoice. | Use invoice-specific terms, not assumed account terms. |
| `currency_code` | Invoice currency. | Preserve currency on display and aggregation. |
| `invoice_amount` | Total invoice value. | Actual invoiced amount and invoice totals. |
| `recorded_current_balance` | Current balance recorded on the invoice. | Primary displayed outstanding balance. |
| `linked_applied_payment_amount` | Valid payment applications linked to the invoice. | Payment context and balance reconstruction. |
| `linked_payment_count` | Count of linked payments. | Invoice payment history context. |
| `first_linked_payment_date` | First linked payment date. | Collections context. |
| `latest_linked_payment_date` | Most recent linked payment date. | Collections context. |
| `payment_reconstructed_balance` | Invoice amount less linked applied payments. | Validation of the recorded balance. |
| `recorded_minus_reconstructed_balance` | Difference between recorded and reconstructed balances. | Review control; investigate when outside tolerance. |
| `aging_bucket` | Gold's aging classification. | Display source bucket; do not manufacture missing buckets. |
| `days_past_due` | Days after due date for an open balance, supplied by Gold. | Use as delivered. Gold calculates using `CURRENT_DATE()` and `due_date`; refresh timestamp is the workbench's visible as-of reference. |
| `receivable_review_status` | Gold's review status for the receivable. | Surface missing due date, missing balance or payment reconstruction exceptions. |
| `linked_payment_client_mismatch_count` | Count of linked payment applications with a customer/client mismatch. | Receivables investigation flag. |

### 5.4 `gold_finance.financial_transaction_lines`

**Purpose:** Unified audit representation of QuickBooks invoice lines, payment receipts/applications and expense lines.  
**Grain:** Mixed by design. A row can represent an invoice line, payment header, payment application line, expense line or a header fallback.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `transaction_line_key` | Unique identifier for the normalized financial record. | Source row key. |
| `transaction_type` | Transaction family, such as `invoice`, `payment` or `expense`. | Filter and classify. |
| `record_level` | Record level, such as `transaction_line`, `transaction_header` or `application_line`. | Prevent double counting across representations. |
| `amount_role` | Economic role of the amount, such as `billed_revenue`, `cash_received`, `payment_application`, `unresolved_payment_line` or `operating_expense`. | Required classification before any amount aggregation. |
| `transaction_id`, `source_transaction_id`, `source_line_id` | Normalized and source transaction/line identifiers. | Financial lineage. |
| `transaction_date`, `accounting_month`, `service_date`, `source_billing_period`, `due_date` | Transaction, accounting and service dates/periods. | Time context only; choose the relevant date based on the business question. |
| `client_id`, `customer_name`, `primary_city` | Canonical customer and location context where resolved. | Customer context; expense rows may have no customer ID. |
| `vendor_name`, `vendor_id` | Vendor context for expenses. | Expense investigation only. |
| `accounting_account_id`, `accounting_account_name`, `transaction_account_id`, `transaction_account_name` | Accounting and transaction account references. | Expense and cash-account investigation. |
| `source_category_label`, `service_type`, `expense_category`, `source_detail_type` | Source description and classification fields. | Audit classification. Do not infer a credit from an expense category. |
| `linked_transaction_id`, `linked_transaction_type`, `linked_invoice_id` | Payment/application link identifiers. | Trace applied payments to invoices where the link is valid. |
| `application_link_status` | Status explaining whether a payment line is linked to an invoice or unresolved. | Investigate unresolved or ambiguous payment links. |
| `unapplied_amount` | Payment amount not applied to an invoice. | Cash application context. |
| `amount`, `currency_code` | Signed transaction-line/header amount and currency. | Aggregate only within the same `amount_role` and intended record level. |
| `source_record_type`, `source_sync_token` | Source record classification and synchronization token. | Audit/lineage. |
| `uses_header_amount_fallback` | Indicates a header amount was used because no source lines were available. | Audit context. |

**Critical aggregation rule:** Payment headers (`amount_role = cash_received`) and payment application lines (`amount_role = payment_application`) are separate representations of the same payment flow. In the supplied profile, 407 payment-header records and 407 application records each totalled $4,370,507.71. Never add these totals together. Use `accounts_receivable` for invoice balance reporting.

The supplied sign check found positive invoice lines and negative expense lines, but no negative invoice/revenue rows. The 28 negative transactions were operating expenses, not customer credits. This model therefore does not currently support a customer-credit workflow based on the inspected records.

### 5.5 `gold_last_mile.fact_delivery` and dimensions

**Purpose:** Operational evidence for delivery completion, success/failure, service and contract context.  
**Grain:** One row per delivery task / delivery record.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `delivery_id` | Delivery/task identifier. | Operational drill-through key. |
| `client_id` | Canonical customer ID where resolved. | Join using the canonical client ID. |
| `delivery_event_date_key`, `task_created_date_key`, `completion_date_key` | Date dimension keys for relevant task dates. | Date context only. |
| `driver_key`, `city_key`, `zone_key`, `service_key`, `contract_key` | Dimension keys for operational context. | Join to matching Gold dimensions only when needed. |
| `task_status`, `task_state_code` | Task lifecycle status. | Operational state context; do not equate `completed` with successful. |
| `delivery_outcome`, `is_completed`, `is_successful_delivery` | Delivery result and completion/success indicators. | Use outcome/success indicator to distinguish successful and failed completed tasks. |
| `is_within_completion_window` | Indicates whether the task completed within its window. | Optional service-quality investigation. |
| `task_created_at_utc`, `completion_time_utc`, `complete_after_utc`, `complete_before_utc`, `estimated_arrival_time_utc`, `estimated_completion_time_utc` | Task and delivery timing. | Operational evidence only. |
| `completion_failure_reason` | Failure reason when present. | Investigate unsuccessful activity. |
| `delivery_count`, `task_quantity`, `service_time`, `reported_order_value`, `completion_distance`, `failed_scan_count` | Delivery-level measures. | Do not substitute for Finance billing quantities without a rule explicitly supported by Gold. |
| `task_vehicle_type`, `destination_postal_code` | Vehicle and destination attributes. | Operational context. Vehicle field does not identify a physical distribution run. |
| `contract_rate_id`, `matched_contract_rate_unit`, `matched_contract_base_rate`, `matched_contract_net_rate`, `matched_contract_rate_effective_date` | Matched contract rate context. | Context only; Finance `invoice_ready_amount` remains authoritative for billed expected amounts. |

`gold_last_mile.dim_service` provides `service_key`, `service_type`, `service_name`, `service_group`, and flags including `is_same_day_service`, `is_next_day_service`, `is_scheduled_service`, `is_distribution_service` and `is_unknown_service`. The inspected service dimension does not provide a dedicated returns classification. Do not infer returns from pickup status alone.

`gold_last_mile.dim_contract_l` provides contract/customer context through `contract_key`, `source_contract_id`, `client_id`, `contract_status`, `contract_type`, `start_date`, `end_date`, `committed_monthly_volume`, `discount_rate` and `net_payment_terms`, along with orphaned/unknown contract indicators. Use for investigation only, not downstream re-pricing.

### 5.6 `gold_fulfillment.fact_fulfillment_transaction` and dimensions

**Purpose:** Operational context for Linnworks fulfillment stock transactions and dispatch/order matching.  
**Grain:** One row per Silver Business fulfillment transaction, representing one Linnworks stock transaction.

| Field | Business meaning | Workbench use / handling |
|---|---|---|
| `fulfillment_transaction_id` | Gold fulfillment transaction identifier. | Operational row key. |
| `source_stock_transaction_id`, `source_stock_item_id` | Source stock transaction and item identifiers. | Source lineage. |
| `date_key`, `customer_key`, `product_key`, `warehouse_key`, `contract_key` | Keys to fulfillment dimensions. | Dimension joins for operational context. `customer_key` represents the shared client ID or `N/A`. |
| `transaction_at_utc`, `transaction_date`, `activity_month` | Transaction timestamp/date and activity month. | Period context for investigation. |
| `source_transaction_type`, `fulfillment_transaction_type`, `inventory_movement_direction` | Source and standardized stock movement types/directions. | Explain inventory movement; do not interpret as billable service without Finance billing line evidence. |
| `quantity_change`, `quantity_moved`, `source_stock_value` | Stock movement quantities and source stock value. | Inventory measures, not the Finance billable pick quantity or invoice value. |
| `transaction_note`, `warehouse_location`, `bin_rack` | Transaction and inventory location context. | Operational investigation. |
| `order_id`, `source_order_id`, `source_order_reference`, `order_reference`, `order_reference_num`, `order_external_reference`, `order_secondary_reference` | Source and normalized order identifiers/references. | Trace dispatch/order matching. Preserve identifier types and source references. |
| `order_channel`, `order_sales_source`, `order_sub_source`, `order_site_code`, `order_fulfillment_location` | Order channel and fulfillment location context. | Operational context. |
| `order_received_at_utc`, `order_processed_at_utc`, `order_dispatched_at_utc`, `order_status_code`, `order_locked_for_shipping` | Order lifecycle and dispatch details. | Investigate fulfillment progression. |
| `postal_service_name`, `tracking_number`, `shipping_vendor`, `pick_duration_mins` | Shipping and pick-operation attributes. | Detail and operational context. |
| `client_attribution_method`, `client_attribution_mismatch`, `stock_item_match_status`, `order_match_status`, `order_item_match_status`, `contract_match_status`, `fulfillment_rate_context_status` | Attribution, matching and rate-context quality flags. | Surface matching exceptions; do not create expected charges from unmatched records. |
| `fulfillment_pick_rate_id`, `fulfillment_pick_service_type`, `fulfillment_pick_rate_unit`, `fulfillment_pick_rate_effective_date` | Fulfillment pick rate context. | Supporting evidence only. Use Finance billing line amount for expected charge. |
| `has_fulfillment_pick_invoice_for_client_month` | Indicates a fulfillment-pick invoice presence for the customer/month. | Context flag only; not an amount or proof that every stock transaction was billed. |
| `customer_profile_conflict`, `is_deleted_order_reference` | Customer/order quality indicators. | Review context. |
| `processed_at_utc` | Processing timestamp. | Audit/refresh context. |

The fulfillment fact explicitly represents stock movements. A `quantity_moved` value must not be treated as billable pick/pack units. For the workbench, use the `per_unit` and invoice-ready charge already present in Finance billing lines. The fulfillment fact is available to investigate order, dispatch and rate-context issues.

### 5.7 `gold_customer.dim_customer_c` and `gold_customer.fact_customer_economics`

`dim_customer_c` contains one row per canonical client. Relevant fields are:

| Field | Business meaning | Workbench use |
|---|---|---|
| `customer_key` | Deterministic customer dimension key. | Dimension relationship key where needed. |
| `client_id` | Canonical SwiftRoute business customer ID. | Customer join and selector key. |
| `customer_name` | Best available integrated customer name. | Standard display name. |
| `has_salesforce_account` | Indicates a matched Salesforce account. | Customer data completeness context. |
| `has_ever_used_fulfillment` | Indicates fulfillment activity in available history. | Service-scope context. |
| `has_ever_used_last_mile` | Indicates last-mile activity in available history. | Service-scope context. |

`fact_customer_economics` contains one row per canonical `client_id` and `period_month`. It may provide supplementary service mix, contract context, operational measures, invoice measures and payment measures. Relevant fields include:

- Keys and periods: `customer_period_key`, `customer_key`, `client_id`, `period_month`, `billing_period`, `period_year`, `period_number`.
- Service scope: `has_fulfillment_activity`, `has_last_mile_activity`, `customer_service_mix`.
- Contract context: `contract_candidate_count`, `has_contract_in_force_for_period`, `contract_match_is_ambiguous`, `applicable_contract_id`, `applicable_source_contract_id`, `contract_status_at_extract`, `contract_start_date`, `contract_end_date`, `contract_signed_date`, `applicable_contract_type`, `contracted_monthly_volume`, `contract_discount_rate`, `contract_net_payment_terms_days`, `contract_auto_renewal`, `contract_termination_notice_days`.
- Fulfillment measures: `fulfillment_orders_received_count`, `fulfillment_units_ordered`, `fulfillment_orders_dispatched_count`, `fulfillment_pick_duration_observation_count`, `average_fulfillment_pick_duration_mins`, `fulfillment_stock_transaction_count`, `fulfillment_stock_dispatch_units`, `fulfillment_stock_receipt_units`, `fulfillment_stock_adjustment_net_quantity`.
- Last-mile measures: `last_mile_tasks_created_count`, `last_mile_delivery_tasks_created_count`, `last_mile_pickup_tasks_created_count`, `last_mile_completed_delivery_count`, `last_mile_successful_delivery_count`, `last_mile_failed_delivery_count`, `last_mile_completed_pickup_count`, `last_mile_completed_tasks_missing_completion_time_count`, `last_mile_success_rate`, `last_mile_failure_rate`.
- Invoice measures: `invoice_count`, `invoiced_amount`, `current_outstanding_balance_for_billing_period`, `invoice_payment_terms`, `next_day_invoiced_amount`, `same_day_invoiced_amount`, `returns_invoiced_amount`, `distribution_run_invoiced_amount`, `fulfillment_pick_invoiced_amount`, `storage_invoiced_amount`, `last_mile_invoiced_amount`, `fulfillment_invoiced_amount`, `unclassified_invoice_line_amount`.
- Payment measures: `payments_received_count`, `cash_received_amount`, `payments_applied_to_period_invoices_count`, `collections_applied_to_period_invoices_amount`.

This model is optional context, not the source of truth for the two workbook worksheets. In particular, `current_outstanding_balance_for_billing_period` represents the current balance of invoices assigned to the period, not a historical month-end balance. `cash_received_amount` is aligned to the payment transaction month; `collections_applied_to_period_invoices_amount` is attributed to invoice billing periods where links permit. Do not combine these measures with invoice revenue as though they are the same event.

## 6. Derived downstream fields

The following may be created in the separate project SQL extracts or Excel model. They are not Gold fields and must be labelled as workbench-derived.

| Derived field | Derivation | Rule |
|---|---|---|
| `customer_period_key` | A deterministic key or composite of `client_id` + `billing_period`. | One Billing Review row per canonical customer and billing period. Do not use the service-level reconciliation key as the customer-period key. |
| `expected_invoice_amount` | Sum of `invoice_ready_expected_charge_amount` across reconciliation service rows for the customer-period, subject to coverage checks. | If all expected components are null, display Not Calculated. If unresolved review lines exist, label the amount Partial / Review Required rather than complete. |
| `actual_invoice_amount` | Sum of `actual_invoiced_amount` across reconciliation service rows for the customer-period. | Validated against grouped `accounts_receivable.invoice_amount` for the 564 overlapping customer-periods. Keep AR as the independent invoice-level control. |
| `actual_invoice_count` | Count distinct `accounts_receivable.invoice_id` by `client_id` + `billing_period`. | Do not sum service-level `actual_invoice_count`. |
| `customer_period_variance` | `actual_invoice_amount - expected_invoice_amount`. | Calculate/display only when the expected amount is assessable and the same customer-period is compared. Otherwise show Not Assessable / Partial Coverage. |
| `coverage_status` | Derived from expected/actual amount presence, Gold reconciliation statuses and counts of review, pricing and chargeability exceptions. | Use explicit labels such as Complete, Partial / Review Required, Not Calculated, Actual Only and No Actual Invoice. Do not convert nulls to zero. |
| `invoice_age_days` | Refresh as-of date minus `invoice_date`, if needed. | Use the file's controlled refresh date rather than `TODAY()` so all rows in a refresh share the same as-of basis. |
| `last_refreshed_at` | Timestamp recorded by the downstream export/refresh process. | Required workbook metadata. It is not a substitute for a Gold business date field. |

## 7. Known data conditions and interpretation controls

1. **Customer sentinels:** The billing model contains the literal `N/A` sentinel among client identifiers. Exclude it from customer selection and retain it as a mapping exception.
2. **Billing cadence:** The inspected Finance data contains `MONTHLY` and `UNKNOWN`; no weekly cadence is demonstrated. The business-context PAYG Monday-to-Sunday rule is not implemented by inventing periods in the workbook.
3. **Account classification:** `Fixed Rate` and `Variable Rate` are source classifications. They do not prove a fixed-monthly, volume-contract or PAYG arrangement.
4. **Eligibility versus readiness:** `activity_eligibility_status = ELIGIBLE` does not prove that a line is ready to invoice. Check billing status, review status and `invoice_ready_amount`.
5. **Null amounts:** Null invoice-ready amounts mean not calculated/not ready, not a zero charge. Some service-period reconciliation rows may show actual billing without a corresponding ready expected calculation.
6. **Exception populations:** The validation profile includes pickup chargeability, unknown cadence, unmapped service, failed-task chargeability, missing customer mapping and missing applicable rate. Preserve the source statuses and explanations.
7. **Failed deliveries:** The agreed business rule excludes unsuccessful delivery tasks from customer charges. Preserve them as operational evidence; no per-failed-task cost allocation is supported.
8. **Distribution:** The observed Gold billing unit is `per_delivery`. No distinct physical run key was found in the inspected delivery model. Do not calculate per-run quantities or charges.
9. **Returns and storage:** The supplied data contains actual invoiced amounts for these categories but no matching ready expected-charge lines. Show actual-only and flag expected coverage as unavailable.
10. **Payments:** Payment headers and payment application lines are different record levels with the same total in the validation profile. Do not double-count them.
11. **Credits:** The inspected sign check found positive invoice revenue lines and negative expense lines. It did not identify customer credit/revenue adjustment records. Do not interpret negative expenses as credits.
12. **Aging:** Gold calculates `days_past_due` using `CURRENT_DATE()` and `due_date` for positive balances. The workbook should not calculate a second aging value using its own `TODAY()` function.
13. **Collection milestone basis:** The business context specifies day 35, 45, 55 and 60 escalation actions, but it has not established whether those thresholds are measured from invoice date or due date. Do not automate stage assignment until confirmed.
14. **Currency:** Preserve `currency_code` and check currency consistency before aggregation. The inspected AR profile was single-currency, but the extract should not assume this remains true forever.
15. **Historical balances:** Customer-period economics contains current outstanding balances assigned to an invoice period, not historical month-end balances. Use invoice-level AR for the current receivables worksheet.

## 8. Join and aggregation guidance for downstream extracts

### 8.1 Customer key

Use canonical `client_id` for cross-domain business joins. Use `gold_customer.dim_customer_c` for the conformed customer list and display attributes where helpful. Validate that the key is not null, blank or a sentinel before exposing a customer as a normal workbench selection.

### 8.2 Billing Review

1. Start from `gold_finance.billing_reconciliation`.
2. Aggregate service rows to `client_id` + `billing_period`.
3. Sum `invoice_ready_expected_charge_amount` while preserving the difference between a genuine zero and no calculated amount.
4. Sum `actual_invoiced_amount`; the customer-period total was validated against AR for all 564 matched periods.
5. Aggregate review, pricing and chargeability counts to describe coverage.
6. Count distinct invoice IDs from AR for the invoice count.
7. Join the customer dimension for stable display attributes.
8. Keep `billing_invoice_lines` as the supporting detail dataset. Join or filter using canonical customer and period fields, not customer name.

### 8.3 Receivables & Collections

1. Start from `gold_finance.accounts_receivable` at invoice grain.
2. Preserve one row per `invoice_id`.
3. Use the recorded balance, due date, invoice-level terms and Gold aging fields.
4. Retain payment reconstruction and mismatch indicators for review.
5. Do not join raw payment application rows in a way that multiplies invoice rows. If financial transaction lines are added for drill-through, aggregate or filter them to the intended invoice/record level first.

### 8.4 Supporting operational context

Join delivery or fulfillment facts only for a defined investigation or supporting breakdown. These joins must not change the billing model's grain, expected amounts, invoice totals or receivables balances. If a join can multiply detail rows, keep it in a separate diagnostic extract or aggregate it to the billing-line or customer-period grain before joining.

## 9. Validation evidence carried into the dictionary

The following validation outcomes were used to define the mappings and safeguards:

| Control | Observed result | Consequence |
|---|---|---|
| Billing line keys | 27,432 rows and 27,432 distinct `billing_line_key` values. | Use the key as the detail identifier. |
| Customer identifiers | 95 distinct billing-line client identifiers including `N/A`; 94 customers in the AR profile. | Exclude `N/A` from customer selection and treat as unresolved. |
| Cadence and account classes | `MONTHLY` and `UNKNOWN`; `Fixed Rate` and `Variable Rate`. | Do not infer PAYG or contract arrangement from these labels. |
| Detail-to-reconciliation expected amounts | 291 populated customer-period amounts matched; 367 customer-period groups had no expected amount on either side. | The detail and reconciliation expected outputs agree where populated; null remains Not Calculated. |
| Reconciliation actuals to AR | 564 customer-periods matched exactly; zero mismatches; both totals were $5,714,696.41. | Customer-period actual amount roll-up is supported. |
| AR payment reconstruction | Recorded and reconstructed balance totals matched, with zero aggregate difference. | Retain reconstruction as a receivables control. |
| Payment representations | 407 payment headers and 407 application rows each totalled $4,370,507.71. | Do not add headers and applications. |
| Returns / storage | Returns actual $286,768.43; storage actual $719,404.71; no ready expected line calculation was returned for either category. | Display actual-only; expected coverage unavailable. |
| Distribution | 49 ready lines across 2 customers, 66 units and $8,442.62, using `per_delivery`. | Do not derive physical run count. |
| Fulfillment pick | 41 ready lines totalling $201,016.05, using `per_unit`. | Consume Finance Gold expected amount; fulfillment fact is supporting evidence. |
| Transaction sign profile | 974 invoice lines were positive billed revenue; 28 negative expense rows totalled -$86,109.71. | No credit workflow can be inferred from the negative rows. |

---

## 10. Implementation checklist

Before building the downstream extracts:

- [ ] Run `DESCRIBE TABLE` against each Gold object in the active Databricks workspace and confirm physical types and nullability.
- [ ] Confirm the exact available columns in the current Gold views without altering them.
- [ ] Use `client_id` as the canonical customer key and filter invalid sentinel IDs from customer selection.
- [ ] Roll reconciliation service rows to customer + billing period for Billing Review.
- [ ] Use AR distinct invoice IDs for invoice counts.
- [ ] Preserve null expected amounts and exception statuses.
- [ ] Keep invoice-level AR at one row per `invoice_id`.
- [ ] Preserve currency and the workbook refresh timestamp.
- [ ] Keep financial transaction roles and record levels separate.
- [ ] Keep operational delivery and fulfillment joins outside the core amount calculations.

**Next project step:** Use this dictionary to define the downstream extract SQL and the data contract for the Excel workbook. No Gold changes are required or permitted for this deliverable.
