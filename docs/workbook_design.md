# SwiftRoute Billing Assurance Workbench
## Excel Workbook Design Specification

**Version:** 1.0  
**Prepared:** 9 November 2026  
**Project:** `swiftroute-billing-assurance`  
**Workbook:** `SwiftRoute_Billing_Assurance_Workbench.xlsx`  
**Status:** Design baseline for downstream extract and workbook implementation

---

## 1. Purpose

This document translates the business problem, billing rulebook and Gold data dictionary into the functional design for the Excel Billing Assurance Workbench.

The workbook is a controlled Finance review workpaper. It gives reviewers one place to assess billing at customer-and-period level, investigate the charge detail and exceptions behind a total, and monitor actual invoices and outstanding receivables. It is not a replacement for QuickBooks, a billing engine, a customer portal or a new software application.

The workbook will consume downstream extracts of existing Gold data. It will not connect directly to operational source systems, alter QuickBooks, or modify any existing Gold model. All shaping and presentation transformations will remain in the separate `swiftroute-billing-assurance` project.

## 2. Design principles

1. **Two primary user-facing worksheets.** The workbook has `Billing Review` and `Receivables & Collections`. Supporting import tables and lookup values may be kept on hidden support sheets; they are not additional user workflows.
2. **Respect the business grain.** Billing Review has one row per customer and billing period (with currency retained as an additional key where necessary). Receivables & Collections has one row per QuickBooks invoice.
3. **Gold remains authoritative.** Expected charges, actual invoice amounts, receivables balances, payment linkage and aging are consumed from the existing Gold outputs. Excel does not select rates or recalculate prices.
4. **Exceptions remain visible.** Missing values, unknown classifications, partial coverage and source review statuses must not be hidden by converting nulls to zero or by applying guessed mappings.
5. **Summary and detail remain connected.** A reviewer can move from a customer-period total to the supporting service and billing-line detail without losing the source identifiers and review explanations.
6. **Refresh must be repeatable and controlled.** The workbook uses a documented manual refresh process, records the last successful extract timestamp and provides simple validation checks.
7. **No VBA in the first release.** Use Excel Tables, Power Query, data validation lists, XLOOKUP, FILTER, SUMIFS, conditional formatting and native filters. PivotTable slicers can be added where they improve multi-select filtering, but are not required for the initial build.

## 3. Workbook structure

### 3.1 Visible worksheets

| Worksheet | Purpose | Record grain |
|---|---|---|
| `Billing Review` | Review expected versus actual billing, identify incomplete coverage and investigate line-level evidence. | One customer + billing period (+ currency if applicable) in the queue; billing-line groups in the detail view. |
| `Receivables & Collections` | Monitor QuickBooks invoices, outstanding balances, linked payments and source aging. | One row per invoice. |

### 3.2 Supporting worksheets

These are technical import/control areas, not navigation tabs for Finance users. Hide them after implementation if that suits the workbook's operating model.

| Support sheet | Contents | Source / purpose |
|---|---|---|
| `_Data_Billing` | Loaded customer-period summary table and billing-line detail table. | Downstream extracts from `billing_reconciliation`, `billing_invoice_lines`, `accounts_receivable` and canonical customer dimension. |
| `_Data_AR` | Invoice-level receivables table. | Downstream extract from `gold_finance.accounts_receivable`. |
| `_Control` | Customer and period validation lists, status labels, refresh manifest and workbook control checks. | Derived from the current extracts and controlled static policy labels. |
| `_Review_Log` (optional) | Reviewer-owned notes and disposition records, stored separately from refreshed query tables. | Manual workpaper entries, keyed to customer-period or billing line. |

The first release may combine `_Data_AR` into `_Data_Billing` if Power Query loading and worksheet row limits remain manageable. Keep the two visible worksheets unchanged. The optional review log should only be introduced if Finance needs notes to persist across data refreshes.

### 3.3 Workbook navigation and general layout

Use a consistent restrained layout across both visible worksheets. Place the worksheet title at the top, followed by a compact control/filter area and then the main table. Keep explanatory notes and definitions close to the metrics they qualify. Avoid adding a separate dashboard or a large number of navigation sheets.

A small workbook header should display:

- Workbench name and worksheet title.
- Selected billing period or current view context, where applicable.
- **Last Refreshed** timestamp from the extract manifest.
- A visible reminder that the workbook is a review workpaper and does not post changes to QuickBooks or Gold.

Use clear number formats: currency with two decimal places, quantities with appropriate decimal/integer display, and dates in a consistent unambiguous format. Do not mix currencies in a single total. Keep source field names available in the support tables even where the visible label is more readable.

---

## 4. Worksheet 1: Billing Review

### 4.1 Purpose

The Billing Review worksheet is the main billing assurance queue. It helps Finance identify customer-periods that need attention, see the expected amount supplied by Gold, compare it with actual invoicing, and investigate the detail or exceptions behind the comparison.

The worksheet has three areas:

1. A customer-period review queue.
2. A selected customer-period summary and charge breakdown.
3. A separate unassigned-activity exception area for records that cannot be attributed to a valid customer identifier.

### 4.2 Review queue grain and row inclusion

**Primary grain:** one row per canonical `client_id` and Gold billing period. If more than one currency is present for a customer-period, retain a separate row per currency rather than combining currencies.

The queue should include customer-periods represented in the Finance reconciliation output, including periods with actual invoices but no invoice-ready expected amount and periods with unresolved activity. It should not be restricted to rows with a non-null expected amount.

Exclude null, blank, `N/A` and `null` sentinel customer identifiers from the normal customer selector. Do not discard them from the workbench: expose these records in the unassigned-activity exception area so missing customer mapping remains visible.

### 4.3 Review queue fields

The downstream summary extract should provide at least the following fields. Some are source fields; others are downstream presentation/control fields derived from source records without changing the underlying business calculation.

| Visible column | Meaning / source | Handling |
|---|---|---|
| Customer | Canonical customer name from `gold_customer.dim_customer_c.customer_name`, with source customer name retained for traceability. | Display label; customer ID remains the join key. |
| Customer ID | `client_id`. | Canonical key; do not join by customer name. |
| Billing Period | `billing_period` from reconciliation, with period date/boundaries retained from source where available. | Display the source period. Do not create weekly periods from current monthly/unknown data. |
| Currency | `currency_code` from AR. | Preserve as part of the summary key where required. |
| Service Scope / Mix | Optional customer-period service mix from billing detail or `fact_customer_economics.customer_service_mix`. | Context only; do not use it to infer commercial arrangement. |
| Expected Amount | Sum of `invoice_ready_expected_charge_amount` from reconciliation service rows at customer-period grain. | Leave blank when all source expected amounts are null. Do not convert null expected coverage to zero. |
| Actual Invoiced Amount | Sum of `actual_invoiced_amount` from reconciliation service rows. | This total was validated against AR at customer-period level. Retain AR-side control amount for validation. |
| Actual Invoice Count | Distinct count of `accounts_receivable.invoice_id` by customer-period. | Do not sum service-level `actual_invoice_count` across reconciliation rows. |
| Variance | `Actual Invoiced Amount - Expected Amount`, at customer-period grain. | Show only when expected coverage is assessable and there are no material unresolved coverage exceptions. Otherwise show blank with a review status. |
| Ready Billing Lines | Count of detail rows marked ready by the source billing status/review fields. | A count of aggregated billing-line groups, not necessarily raw tasks or units. |
| Review Lines | Source reconciliation review-line count, supported by detailed source statuses. | Expose as a count; keep reason/status detail available. |
| Pricing Exceptions | Source `pricing_exception_line_count`. | Retain the source count. |
| Chargeability Exceptions | Source `chargeability_review_line_count`. | Retain the source count. |
| Review Status | Downstream presentation status derived from expected coverage, actual invoice presence, source statuses and exception counts. | Must not overwrite source `reconciliation_status`. |
| Review Explanation | Source `reconciliation_explanation` where one exists, supplemented by a concise downstream roll-up explanation. | Preserve original source explanation in detail. |

The queue may also retain `billing_month`, `billing_period` and the underlying source status values in hidden or secondary columns for audit and filtering.

### 4.4 Selected customer-period panel

A reviewer should be able to select a customer and billing period from native Excel data-validation dropdowns. The selection panel should display:

- Customer name and ID.
- Billing period and period boundaries, if provided.
- Expected invoice-ready amount.
- Actual invoiced amount and distinct invoice count.
- Assessable variance, or a clear reason why a variance is not assessable.
- Service mix and the number of ready, review and pricing/chargeability exception lines.
- A concise review status and reviewer note/disposition, if the optional review log is implemented.

The selected panel is a convenience view of the selected row in the queue, not a second source of financial measures. Use the summary extract as the authoritative source for the displayed customer-period values.

### 4.5 Billing-line breakdown

The detail table should filter to the selected customer and period. It must include both ready and exception lines so reviewers can see what was included in the expected amount and what remains unresolved.

Recommended visible columns:

| Column | Gold field / source | Use |
|---|---|---|
| Billing Line ID | `billing_line_key` | Unique source detail reference. |
| Customer ID / Name | `client_id`, `customer_name` | Traceability. |
| Service Month / Period | `service_month`, `billing_period_start`, `billing_period_end`, `billing_period_label` | Identify the source activity period. |
| Activity Source | `activity_source` | Distinguish Onfleet and fulfillment-derived lines. |
| Service Type | `service_type` | Service category, including unknown/unmapped values. |
| Zone | `zone_id` | Pricing and operational context. |
| Billing Unit | `billing_unit` and `rate_unit` | Retain the unit selected in Gold. |
| Quantity Basis | `quantity_basis` | Explain how the source quantity was determined. |
| Candidate Quantity | `candidate_quantity` | Activity quantity considered by Gold. |
| Billable Quantity | `billable_quantity` | Quantity accepted by Gold's billing logic. |
| Activity Eligibility | `activity_eligibility_status` | Operational eligibility result. |
| Billing Line Status | `billing_line_status` | Primary Gold line-level outcome. |
| Review Status | `billing_review_status` | Ready, not billable under the current rule or review required. |
| Review Explanation | `review_explanation` | Reason a line is held or excluded. |
| Contract / Rate Reference | `applicable_contract_id`, `applicable_contract_rate_id`, `applicable_contract_type` | Traceability only. |
| Rate Context | `rate_effective_date`, `rate_unit`, `base_rate`, `applicable_discount_rate`, `calculated_net_rate` | Explain the Gold-selected rate context; never recalculate the charge. |
| Invoice-Ready Amount | `invoice_ready_amount` | Gold-produced expected amount. Blank where no invoice-ready amount was calculated. |
| Activity Count / Order Count | `source_activity_count`, `source_order_count` | Show how many source activities/orders are represented in the aggregated line. |
| First / Last Activity | `first_activity_date`, `last_activity_date` | Support investigation of the line's date coverage. |

Keep `source_activity_ids` and `source_order_ids` in the downstream detail extract if practical for audit. They may be hidden from the normal view or made available through a drill-through column because arrays can be lengthy and are not suitable as primary display fields.

### 4.6 Exception visibility and treatment

The detail area must preserve the Gold statuses and review explanations. At minimum, reviewers should be able to filter or group the following categories:

| Source status / condition | Workbench treatment |
|---|---|
| `REVIEW_BILLING_CADENCE_UNKNOWN` | Review required. Do not assume PAYG or invent a weekly period. |
| `REVIEW_PICKUP_CHARGEABILITY` | Review required. Pickup is not automatically a billable delivery or a return. |
| `UNMAPPED_SERVICE_TYPE` | Review required. Do not map to a supported service by guesswork. |
| `REVIEW_FAILED_TASK_CHARGEABILITY` | Preserve the source status. Under the agreed business rule, unsuccessful deliveries are not billable and remain operating-cost/service evidence, not customer revenue. |
| `MISSING_APPLICABLE_RATE` / `MISSING_RATE_AMOUNT` | Review required. Do not apply a fallback price in Excel. |
| `MISSING_CUSTOMER_MAPPING` | Keep out of normal customer-level comparison and show in the unassigned-activity area. |
| `NOT_COMPLETED` | Exclude from billable quantity under the current rule; retain for operational evidence. |
| Fulfillment order/stock matching exceptions | Retain as investigative statuses. Do not convert stock movement quantities into invoice charges. |

An activity status of `ELIGIBLE` does not by itself mean that the line is ready to bill. Billing-line status, review status and the presence of an invoice-ready amount must all be considered.

### 4.7 Customer-period review status logic

The review status is a downstream presentation label, not a replacement for the source reconciliation status. The downstream summary query should apply a controlled precedence similar to the following:

| Condition | Suggested workbench status | Variance treatment |
|---|---|---|
| Invalid/missing customer identifier | `UNASSIGNED_CUSTOMER_REVIEW` | No customer-level variance. |
| Actual invoice exists but no invoice-ready expected amount is available | `ACTUAL_ONLY_EXPECTED_NOT_CALCULATED` | Not assessable. |
| Expected amount exists but one or more material billing/chargeability exceptions affect coverage | `PARTIAL_COVERAGE_REVIEW` | Do not present as conclusive. |
| Expected amount exists and no matching AR invoice exists | `READY_BILLING_NO_ACTUAL_INVOICE` | Do not calculate a normal variance against an absent invoice. |
| Expected and actual amounts exist, expected coverage is complete, and the customer-period amounts match within the source reconciliation tolerance | `MATCHED` | Display actual minus expected. |
| Expected and actual amounts exist, expected coverage is complete, but the amounts differ beyond the source reconciliation tolerance | `VARIANCE_REVIEW` | Display actual minus expected for investigation. |
| No expected amount, no actual invoice and unresolved activity or coverage | `NOT_CALCULATED_REVIEW` | Not assessable. |

The implementation should use the source exception counts/statuses and actual invoice presence to decide whether coverage is complete. It must not infer completeness from a populated expected amount alone. Use the source reconciliation tolerance (one cent in the inspected model) rather than introduce a competing tolerance in Excel.

The downstream aggregation must also preserve the distinction between **zero** and **null**. A zero actual amount with no AR invoice is not the same as an invoice of zero dollars; show an explicit invoice-presence indicator or invoice count.

### 4.8 Unassigned activity area

A customer with a missing/invalid canonical `client_id` cannot be included in the normal customer-period queue or selected via the customer dropdown. To prevent these records from disappearing, include a compact exception table on `Billing Review` filtered to invalid IDs such as null, blank or `N/A`.

Show at least the source billing line key, source customer name if available, period, service type, activity eligibility, billing status, review explanation, candidate quantity and billable quantity. This area is an exception worklist, not a customer invoice comparison.

---

## 5. Worksheet 2: Receivables & Collections

### 5.1 Purpose and grain

This worksheet provides an invoice-level view of amounts issued, payments linked to invoices, balances outstanding and the aging classification supplied by Gold.

**Grain:** one row per `invoice_id`. Do not consolidate invoices into a customer-period row on this worksheet.

### 5.2 Recommended columns

| Visible column | Gold field | Meaning / handling |
|---|---|---|
| Invoice Number | `document_number` | Human-readable QuickBooks invoice reference. |
| Invoice ID | `invoice_id` | Unique invoice key; retain even if hidden from the main view. |
| Customer | `customer_name` | Invoice customer display. |
| Customer ID | `client_id` | Canonical SwiftRoute customer key. |
| City | `primary_city` | Supporting account context. |
| Billing Period | `billing_period` | Period assigned to the invoice in Gold. |
| Invoice Date | `invoice_date` | QuickBooks invoice date. |
| Due Date | `due_date` | Invoice due date. |
| Payment Terms | `payment_terms` | Invoice-level terms. Do not infer Net 7 from customer type. |
| Currency | `currency_code` | Preserve invoice currency. |
| Invoice Amount | `invoice_amount` | Total issued invoice amount. |
| Outstanding Balance | `recorded_current_balance` | Displayed AR balance from Gold. |
| Applied Payments | `linked_applied_payment_amount` | Sum of supported payment applications linked to the invoice. |
| Linked Payment Count | `linked_payment_count` | Number of linked payment transactions. |
| First Payment Date | `first_linked_payment_date` | Earliest linked payment date. |
| Latest Payment Date | `latest_linked_payment_date` | Latest linked payment date. |
| Days Past Due | `days_past_due` | Gold-calculated value based on due date and the view's current date logic. Do not recalculate using Excel `TODAY()`. |
| Aging Bucket | `aging_bucket` | Source aging category. |
| Receivable Review Status | `receivable_review_status` | Source control status for balance/due-date reconstruction. |
| Balance Check Difference | `recorded_minus_reconstructed_balance` | Validation difference between recorded balance and reconstructed balance. |
| Payment Link Mismatch Count | `linked_payment_client_mismatch_count` | Control for linked payments whose customer context does not agree. |

`source_sync_token` and `source_customer_id` may be retained in the support table for audit but do not need prominent display. The QuickBooks source customer identifier is not the canonical SwiftRoute `client_id`.

### 5.3 Filters and review controls

Provide standard Excel Table filters for:

- Customer / customer ID.
- Billing period.
- Invoice date and due date.
- Payment terms.
- Aging bucket.
- Receivable review status.
- Outstanding balance (for example, filter to balances greater than zero).

Use a visible summary strip above the invoice table for total invoice amount, total outstanding balance, number of invoices, number of open invoices and number of invoices requiring review. These values must be calculated from the currently filtered invoice table or a controlled PivotTable, not from an unrelated overall total.

### 5.4 Collection escalation policy

The operating context identifies the following actions:

| Policy milestone | Business action |
|---|---|
| Day 35 | Automated QuickBooks reminder. |
| Day 45 | Finance Director sends a personal email. |
| Day 55 | Escalate to the Account Manager. |
| Day 60 | Finance Director and VP of Operations review whether service should continue or be suspended. |

The available business instruction does not conclusively establish whether these milestones are measured from invoice date or due date. Therefore, the first workbook release should show the source `days_past_due`, due date, balance and a static reference to the policy milestones, but **must not automatically assign a collection stage or next action**. Once Finance confirms the day-count basis, the status/action mapping can be added downstream or in a controlled workbook lookup table. The workbook must not send emails or make service decisions.

### 5.5 Aging as-of context

The inspected `accounts_receivable` model computes `days_past_due` using `CURRENT_DATE()` and the invoice due date for open balances. The workbook should display the Last Refreshed timestamp prominently and describe aging as the value supplied by the latest Gold extract. Do not let an Excel formula silently advance days-past-due after the extract has become stale.

---

## 6. Data model and relationships inside the workbook

### 6.1 Data tables

The first build should load the following controlled tables through Power Query:

| Excel table name | Origin | Intended grain |
|---|---|---|
| `tblBillingSummary` | Downstream aggregation of `gold_finance.billing_reconciliation`, joined to AR invoice controls and canonical customer display. | Customer + billing period (+ currency where applicable). |
| `tblBillingDetail` | Projection of `gold_finance.billing_invoice_lines`, with canonical customer display where matched. | Billing-line group (`billing_line_key`). |
| `tblReceivables` | Projection of `gold_finance.accounts_receivable`. | Invoice (`invoice_id`). |
| `tblCustomers` | `gold_customer.dim_customer_c`, filtered to valid canonical IDs. | Customer (`client_id`). |
| `tblRefreshManifest` | Batch extract metadata created by the downstream export process. | One row per export batch (or per file if generated separately). |

If the reviewer log is implemented, keep it separate from Power Query output tables so a refresh cannot overwrite reviewer-authored notes.

### 6.2 Relationships and keys

- `tblCustomers.client_id` is the canonical customer key for display and customer filtering.
- `tblBillingSummary` is keyed by `client_id` + normalized Gold billing period + currency where relevant.
- `tblBillingDetail` is connected to the selected customer-period by `client_id` plus a normalized period key derived from the source period fields (`service_month` / period boundaries). Confirm the period alignment in the extract validation; do not join on customer name or a formatted label alone.
- `tblReceivables` is keyed by `invoice_id`. Its customer-period view uses `client_id` + `billing_period` and currency.
- `tblRefreshManifest` provides the common successful batch timestamp displayed by both worksheets.

A downstream `customer_period_key` may be created as a technical convenience for Excel lookups, for example by combining the canonical client ID, normalized period and currency. It is a workbench key only; it does not replace the Gold source keys.

### 6.3 Billing summary construction

The downstream query for `tblBillingSummary` should:

1. Read the existing `gold_finance.billing_reconciliation` rows.
2. Normalize the supplied period fields into a consistent comparison key while retaining the original `billing_month` and `billing_period` values.
3. Group service-level rows by canonical `client_id`, billing period and currency where applicable.
4. Sum `invoice_ready_expected_charge_amount` without coalescing nulls to zero. If all contributing expected amounts are null, the grouped expected amount must remain null.
5. Sum `actual_invoiced_amount` and retain source service-level status and explanation evidence.
6. Aggregate `review_line_count`, `pricing_exception_line_count` and `chargeability_review_line_count` as source counts. Do not lose which service types generated the exceptions.
7. Separately aggregate `accounts_receivable` by client, billing period and currency to obtain distinct invoice count, AR control total and invoice presence.
8. Join canonical customer display using `client_id`.
9. Compare the reconciliation actual total with the AR control total. Flag a mismatch rather than silently choosing one value if the validation ever fails.
10. Derive the downstream workbench review status using the precedence in Section 4.7, while preserving all original Gold status fields in the support data.

The supplied validation showed exact reconciliation-to-AR actual amount agreement for all 564 overlapping customer-periods, totalling $5,714,696.41. The downstream extract must retain this as a recurring validation control, not assume that future refreshes will always match.

### 6.4 Billing detail construction

`tblBillingDetail` should be a projection of `billing_invoice_lines`. It may add a normalized period key and canonical customer display, but must not recalculate rates, quantities or charges. Preserve all line statuses, explanations and source keys.

The extract should include both ready and non-ready lines. Ready lines contribute their Gold `invoice_ready_amount`; review lines remain visible and must not be assigned a substitute amount. Where source IDs are arrays, export them in a predictable representation (for example, delimited text or JSON string) and validate that the chosen CSV encoding does not corrupt delimiters or quotes.

### 6.5 Receivables construction

`tblReceivables` should be a direct, clearly named projection of `accounts_receivable`, retaining one row per `invoice_id`. Do not join invoice rows directly to payment application detail in a way that duplicates invoices. The Gold model already provides linked payment amounts, counts, dates and reconstructed balances.

### 6.6 Avoid unsafe joins and double counting

- Do not join service-level reconciliation rows directly to raw invoice lines and then sum both sides; this can multiply amounts.
- Do not add `financial_transaction_lines` payment headers to payment application lines. They are two representations of the same payment flow.
- Do not count service-level `actual_invoice_count` values by summing them across services; count distinct AR invoice IDs instead.
- Do not use fulfillment stock movement quantity as a proxy for billable pick/pack quantity.
- Do not use `fact_delivery` to recalculate customer charges.
- Do not aggregate different currencies into one amount.

---

## 7. Excel interaction and formula design

### 7.1 Preferred native Excel features

| Feature | Intended use |
|---|---|
| Excel Tables | Structured source/output tables with built-in filters and expanding ranges. |
| Power Query | Import controlled CSV/Parquet extracts and apply only necessary type/presentation steps. |
| Data Validation lists | Customer and billing-period selectors on Billing Review. |
| `XLOOKUP` | Retrieve selected customer-period summary values or canonical customer display. |
| `FILTER` | Display the billing-line breakdown for the selected customer-period. |
| `SUMIFS` / `COUNTIFS` | Small supporting summaries and counts where the source extract does not already provide the measure. Do not recreate Gold billing calculations. |
| Conditional Formatting | Highlight review statuses, missing invoice presence, outstanding balances and source exceptions. |
| PivotTable slicers (optional) | Multi-select filtering of queue/detail views if Finance prefers slicer controls. |

Use structured table references rather than hard-coded cell ranges where possible. Formula cells should be visually distinct from imported source values, and imported source values should not be manually edited.

### 7.2 Suggested Billing Review interaction

1. Reviewer chooses a billing period and, optionally, a customer from validation dropdowns.
2. The customer-period queue remains filterable using native table filters or slicers.
3. Selecting a customer-period updates the summary panel.
4. The detail area filters `tblBillingDetail` to that customer and period, showing both ready and exception lines.
5. A separate unassigned-activity area shows detail records with invalid customer identifiers.
6. The reviewer records findings in a separate review log or in a controlled manual annotation area that is not overwritten by Power Query refresh.

### 7.3 Suggested Receivables interaction

The reviewer filters `tblReceivables` using customer, period, due date, payment terms, aging bucket, review status and outstanding balance. Summary figures above the table should respond to those filters. The invoice row remains the unit of review.

### 7.4 Status presentation

Use text labels as well as conditional formatting. Color must never be the only signal. The status should remain understandable when printed or viewed without color:

- `MATCHED`: complete expected coverage and actual invoice amount agree within the source tolerance.
- `VARIANCE_REVIEW`: assessable expected and actual amounts differ beyond the source tolerance.
- `PARTIAL_COVERAGE_REVIEW`: one or more unresolved exceptions affect the completeness of expected billing.
- `READY_BILLING_NO_ACTUAL_INVOICE`: expected billing exists but no matching AR invoice was found.
- `ACTUAL_ONLY_EXPECTED_NOT_CALCULATED`: actual invoice exists without expected-charge coverage.
- `NOT_CALCULATED_REVIEW`: no usable expected amount is available and activity/coverage remains unresolved.
- `UNASSIGNED_CUSTOMER_REVIEW`: activity cannot be tied to a canonical customer.

The exact label wording can be shortened for display, but its underlying meaning and precedence must remain documented in the downstream SQL and control reference.

---

## 8. Refresh and operating procedure

### 8.1 Refresh architecture

Use the agreed downstream export approach:

`Existing Gold models (read-only) -> Databricks SQL extracts -> controlled export files -> Excel Power Query -> workbook tables`

The export process runs from the separate Billing Assurance project. It does not create or modify Gold models, and it does not introduce a new recurring ingestion pipeline. The first release uses controlled manual execution and refresh.

### 8.2 Refresh sequence

1. Run the approved SQL extracts against the current Gold views.
2. Export the billing summary, billing detail, receivables and customer lookup files to their controlled folders.
3. Run extract-level validation checks.
4. Generate/update the batch refresh manifest only after all required exports and validations succeed.
5. Open the workbook and use **Data > Refresh All**.
6. Confirm the visible Last Refreshed timestamp has advanced to the successful batch timestamp.
7. Check record counts, key uniqueness, missing-key counts, null expected-value counts and reconciliation control totals.
8. Confirm the workbook shows expected exceptions and no query refresh errors before using it for Finance review.

### 8.3 Refresh metadata

The refresh manifest should contain at least:

- `extract_batch_id`;
- `extract_generated_at_utc`;
- extract file/model name;
- row count;
- source Gold object;
- export status; and
- validation status.

Use one shared batch timestamp for the workbook's Last Refreshed display. If any required extract fails, do not publish a new successful timestamp; retain or clearly mark the last successful batch so users do not mistake a partial refresh for a complete one.

### 8.4 Refresh validation controls

At minimum, check:

| Control | Expected outcome |
|---|---|
| Billing detail key | `billing_line_key` is populated and unique. |
| Customer identifiers | Valid customer IDs map to the canonical customer dimension; invalid/sentinel IDs are retained in the unassigned exception area. |
| Summary grain | One row per customer-period-currency key in `tblBillingSummary`. |
| Billing detail period join | Every detail row with a valid customer/period maps to the correct summary key or is explicitly retained as an unmatched exception. |
| AR invoice key | `invoice_id` is populated and unique in `tblReceivables`. |
| Currency | No summary total combines multiple currencies. |
| Expected amount nulls | Null remains null; no conversion to zero. |
| Reconciliation to AR | Reconciliation actual totals match AR invoice totals at customer-period-currency grain within the established tolerance. |
| Receivable balance reconstruction | Preserve `recorded_minus_reconstructed_balance` and surface non-zero/review statuses. |
| Extract completeness | All required extracts share the same successful batch ID/timestamp. |

The initial profile provides useful baseline controls: 27,432 unique billing lines; 564 unique invoices; $5,714,696.41 total invoice value; and $1,344,188.70 recorded outstanding balance. These are validation baselines from the inspected sample, not hard-coded expectations for every future refresh.

---

## 9. Review ownership and manual annotations

The workbook supports Finance review, but a source-data row should not be overwritten to record a manual decision.

If reviewer notes are required, use a separate `Review Log` table with fields such as:

| Field | Purpose |
|---|---|
| `review_record_id` | Unique workpaper record identifier. |
| `review_grain` | `CUSTOMER_PERIOD` or `BILLING_LINE`. |
| `client_id` | Canonical customer identifier where available. |
| `billing_period` | Gold period reference where applicable. |
| `billing_line_key` | Optional line-level reference. |
| `review_status` | Controlled reviewer disposition, separate from Gold status. |
| `reviewer` | Person recording the note. |
| `reviewed_at` | Date/time of the review. |
| `review_note` | Explanation and follow-up required. |
| `evidence_reference` | Supporting invoice, contract or communication reference. |

The review log is manual workpaper data and must be maintained separately from Power Query output. It does not approve a charge, alter a QuickBooks invoice or change Gold status. If a durable review log is not needed for the first release, omit the table rather than add an unused worksheet.

## 10. Build sequence

Implement the workbook in the following order:

1. **Finalize downstream extract contracts:** agree the exact output columns, grain, types, keys and validation checks for summary, detail, AR, customer lookup and refresh manifest.
2. **Build and validate SQL extracts:** project from existing Gold only; aggregate reconciliation to customer-period; obtain invoice counts from distinct AR invoice IDs; preserve nulls and exceptions.
3. **Load Power Query tables:** connect to controlled export files and load the four main datasets plus refresh metadata.
4. **Build Billing Review:** create queue, selectors, selected summary, line breakdown and unassigned-activity table.
5. **Build Receivables & Collections:** create invoice table, filters and balance/aging summary strip.
6. **Apply usability controls:** formats, conditional formatting, dropdown validation, filters/slicers and refresh metadata display.
7. **Run end-to-end acceptance tests:** compare workbook totals to the extracts and existing Gold validation controls, test null/exception scenarios and verify refresh does not overwrite reviewer annotations.
8. **Document user operation:** complete `refresh_process.md` with exact file locations, refresh steps, validation steps and recovery instructions.

## 11. Acceptance criteria

The workbook design is implemented successfully when:

- Exactly two primary user-facing worksheets are provided: `Billing Review` and `Receivables & Collections`.
- Billing Review presents one consolidated customer-period row, with currency separated where needed.
- Expected amount, actual invoice amount, invoice count and variance follow the aggregation and source-of-truth rules in this document.
- A null expected amount remains blank and is identified as not calculated or actual-only where appropriate.
- The reviewer can filter the queue, select a customer-period and see its supporting billing lines.
- Ready, not billable and review-required lines remain distinguishable.
- Missing customer mappings remain visible in a separate unassigned exception area.
- Receivables & Collections contains one row per invoice with invoice-level terms, amount, balance, linked payment data and Gold aging.
- Collection stage automation is not enabled until the day-count basis is confirmed.
- The workbook does not double-count payment headers and application lines or service-level invoice counts.
- Power Query refresh imports only controlled downstream extracts and exposes a Last Refreshed timestamp.
- Reviewer annotations, if implemented, survive data refresh and remain clearly separate from source data.
- No changes are made to any existing Gold model, schema, transformation or test.

## 12. Design references

- `docs/business_problem.md` - business context, problem statement, objectives, user roles, scope and success measures.
- `docs/billing_rulebook.md` - agreed periods, classification boundaries, chargeability treatment, expected billing logic, reconciliations and receivables rules.
- `docs/data_dictionary.md` - Gold datasets, field mappings, grains, relationships and known data limitations.
- `docs/refresh_process.md` - to be completed with the exact operational procedure after extract and workbook implementation.

---

**Design boundary:** This specification defines a downstream Excel workpaper. Existing Gold datasets remain read-only; all extraction, aggregation, validation and presentation work belongs in the separate Billing Assurance project.
