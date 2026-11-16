# SwiftRoute Billing Assurance Workbench

## Billing Rulebook

**Version:** 1.0  
**Prepared:** 8 November 2026  
**Purpose:** Define the business rules, source-of-truth decisions, calculation boundaries, exception treatment and validation controls for the downstream Excel Billing Assurance Workbench.

---

## 1. Purpose and scope

The Billing Assurance Workbench helps Finance review billing completeness and accuracy for SwiftRoute business customers. It brings together the expected billing outputs already calculated in the existing Gold Finance models, actual QuickBooks invoice values, and invoice-level receivables information. It is a review and decision-support workpaper, not a replacement billing engine or accounting system.

The workbench has two primary views:

1. **Billing Review:** a customer-and-billing-period review queue comparing Gold's invoice-ready expected charges with actual invoiced amounts, while exposing the underlying service and charge detail and any unresolved exceptions.
2. **Receivables & Collections:** an invoice-level view of invoice amount, outstanding balance, due date, payment terms, aging and collection review information.

The workbench covers both last-mile delivery and fulfillment billing where the existing Gold Finance outputs provide usable billing information.

### 1.1 Non-negotiable architecture boundary

The existing Gold layer is the source to be consumed. It must not be modified, rebuilt, extended or repurposed as part of this workbench project. All downstream shaping, extracts, workbook logic, presentation labels and validation must take place outside Gold in the separate Billing Assurance project workspace.

Where a source field, classification or calculation is missing, the workbench must expose the limitation and handle it as a review item. It must not silently create a substitute business rule or alter Gold outputs to make the workbook appear complete.

---

## 2. Source-of-truth models and their roles

| Existing Gold model | Workbench role | Primary use |
|---|---|---|
| `gold_finance.billing_invoice_lines` | Billing detail and charge evidence | Detailed activity, service, quantity, contract/rate context, review status and `invoice_ready_amount` |
| `gold_finance.billing_reconciliation` | Billing-period summary and reconciliation | Expected invoice-ready amount, actual invoiced amount, invoice count, exception counts and reconciliation status by customer/service/cadence/period |
| `gold_finance.accounts_receivable` | Receivables and collections | One row per invoice, due date, terms, invoice amount, outstanding balance, applied payments and aging fields |
| `gold_finance.financial_transaction_lines` | Supporting financial audit only | Inspect transaction types and amounts; do not use as the primary receivables calculation or infer credits from expenses |
| `gold_last_mile.fact_delivery` and its dimensions | Operational context where needed | Investigate delivery outcomes, service, contract and zone context; do not independently re-price delivery activity |
| `gold_fulfillment.fact_fulfillment_transaction` and its dimensions | Fulfillment activity context where needed | Investigate stock/dispatch activity; do not independently calculate billing charges |
| `gold_customer.fact_customer_economics` | Supplementary customer-period context | Customer service mix and financial context; not a replacement for the Finance billing and AR models |

### 2.1 Primary model responsibilities

- Use `billing_invoice_lines` for line-level charge evidence and drill-down.
- Use `billing_reconciliation` for the customer-period review summary and its precomputed variance and exception measures.
- Use `accounts_receivable` for invoice-level balances and aging.
- Use the other Gold models only to explain or investigate source activity when required. They must not be used to recreate a price or overwrite a Finance Gold result.

---

## 3. Step 1: Billing periods, customer classification and billable activity

### 3.1 Billing review grain

The primary Billing Review grain is **one customer for one billing period**. All relevant service and charge components belonging to that customer-period are consolidated into the summary amount. This allows Finance to review the total amount expected and the total amount actually invoiced without splitting a customer's invoice into separate summary rows for each service or commercial arrangement.

The detailed breakdown remains available beneath the summary. It should retain the source billing line and, where populated, the activity source, service type, billing unit, quantity basis, quantity, contract/rate context, line status, review explanation and invoice-ready amount.

The summary should also retain service-level and exception counts so that a consolidated amount does not conceal incomplete billing coverage.

### 3.2 Billing-period definition

Use the billing-period identifiers and boundaries supplied by Gold, including the available billing period label, start/end dates, service month and reconciliation period fields. The workbook must not create alternative billing periods that are not represented by the source billing outputs.

The business operating context describes PAYG billing as a Monday-to-Sunday weekly cycle. That is the stated operating rule, but the inspected Gold billing outputs do not currently demonstrate a weekly PAYG cadence. The observed cadence values are `MONTHLY` and `UNKNOWN`, and the billing-period outputs are monthly in the supplied data.

Therefore:

- Preserve Monday-to-Sunday as the documented PAYG operating rule.
- Do not generate weekly customer-periods in the workbook from the current Gold data.
- Use the billing periods actually supplied by Gold for the present workbench.
- Treat `UNKNOWN` cadence as unresolved. Do not assume it means weekly PAYG or monthly contracted billing.

### 3.3 Customer and contract classification

The inspected billing data contains `Fixed Rate` and `Variable Rate` contract/account classifications. These are source classifications, not sufficient evidence to map a customer to a specific commercial arrangement such as PAYG, committed-volume contract or fixed monthly fee.

The workbench must:

- Preserve the source contract/account classification as supplied.
- Keep service scope (last-mile, fulfillment or both) separate from commercial arrangement.
- Avoid translating `Fixed Rate` directly into “fixed monthly fee”.
- Avoid translating `Variable Rate` directly into “PAYG”.
- Show unknown or unavailable commercial terms as requiring review rather than inferring an arrangement.

The current curated AR data shows Net 30 and Net 60 payment terms. The operating context describes Net 7 for PAYG, but Net 7 is not demonstrated in the supplied Gold AR records. The workbook must use the payment terms attached to each actual invoice and must not assign Net 7 based only on an assumed PAYG classification.

### 3.4 Last-mile service activity

The inspected Gold service categories include `next_day`, `same_day`, `distribution_run`, `scheduled` and an unknown/unmapped category. The workbench should use the service classifications provided by Gold and retain the source service label for investigation.

The following activity rules apply to the workbench:

| Activity condition | Workbench treatment |
|---|---|
| Successful, completed delivery with a supported service/rate and a ready billing line | Include the Gold-produced invoice-ready charge |
| Unsuccessful delivery | Not billable under the agreed workbench rule; treat as SwiftRoute operating cost, not customer revenue |
| Pickup task | Do not charge automatically. Keep under review until contractual billability is established |
| Task not completed | Exclude from billable quantity under the current rule |
| Unknown or unmapped service type | Hold for review; do not assign a rate-card service by guesswork |
| Missing customer mapping | Hold outside the customer-level billing comparison until the canonical customer mapping is resolved |
| Missing applicable rate | Hold as a pricing exception; do not calculate an expected charge in Excel |
| Unknown billing cadence | Hold as a billing-period/commercial classification exception |

Gold may label failed-task activity `REVIEW_FAILED_TASK_CHARGEABILITY`. Preserve that source status. The workbench should separately make the agreed business treatment clear: unsuccessful deliveries are not billable and are a SwiftRoute operating cost. Do not modify the Gold status or include failed activity in customer expected revenue. This is not a cost-allocation rule: the current extracts do not establish a reliable cost per failed task, so do not multiply failed-task counts by a customer rate or allocate general operating expenses to individual failed deliveries.

### 3.5 Distribution service basis

The operating context describes distribution work in terms of scheduled routes/runs, sometimes using box trucks and dedicated arrangements. However, the inspected Gold billing output prices the available `distribution_run` activity on a `per_delivery` basis. The relevant billing output contains 49 lines for 2 customers, 66 billable units and $8,442.62 in invoice-ready charges. The inspected delivery model does not expose a distinct run identifier that would support a reliable count of physical runs.

For this workbench:

- Consume the Gold `per_delivery` unit and its `invoice_ready_amount`.
- Do not reinterpret each task or delivery as a distinct physical run.
- Do not calculate a per-run charge or a distinct run count.
- Retain the distinction between the operational description of distribution runs and the per-delivery billing basis represented in Gold.

### 3.6 Fulfillment, returns and storage

Fulfillment pick/pack billing is represented in the Finance billing lines with a `per_unit` basis and an invoice-ready amount. The inspected dataset contains 41 fulfillment-pick billing lines totalling $201,016.05. Use the Finance billing output for the expected amount; the fulfillment transaction model is supporting operational evidence only.

The inspected returns and storage reconciliation records contain actual invoiced amounts but no corresponding ready billing-line calculation:

- Returns: $286,768.43 across 178 reconciliation rows and 84 customers.
- Storage: $719,404.71 across 66 reconciliation rows and 11 customers.

No detailed `billing_invoice_lines` expected-charge rows were returned for these service categories in the supplied validation. As a result:

- Show returns and storage actual invoiced amounts where present.
- Mark their expected-charge coverage as unavailable/not calculated.
- Do not create an expected quantity, rate or charge from the actual invoice amount.
- Do not calculate or present an expected-versus-actual variance for those categories as though the expected amount had been validated.

Do not infer that every pickup is a return. Returns must remain distinct from pickup activity unless a source classification explicitly identifies the return.

---

## 4. Step 2: Pricing hierarchy, charge calculation and expected billing

### 4.1 Gold owns the pricing calculation

The existing Finance Gold billing model already provides the applicable billing and pricing outputs, including contract/rate context, rate unit, base rate, applicable discount, source/calculated net rate, candidate/billable quantities, calculated gross/net charge and `invoice_ready_amount`.

The workbench must consume these calculated outputs. It must not independently implement a second pricing hierarchy or recalculate charges from quantities and rates in Excel or in downstream SQL.

In particular:

- Use `invoice_ready_amount` as the line-level expected charge when the line is ready to bill.
- Use `invoice_ready_expected_charge_amount` in `billing_reconciliation` for the customer/service/cadence-period expected amount.
- Retain rate and quantity fields for reviewer traceability, not to create a competing calculation.
- Do not silently substitute a standard rate when the applicable Gold rate is missing.
- Do not derive an unsupported contract method, surcharge, overage or discount in the workbook.

### 4.2 Billing readiness is distinct from activity eligibility

An activity can be eligible for consideration but still not be ready to bill. The validation profile demonstrates this distinction. For example, activity with `activity_eligibility_status = ELIGIBLE` can still carry `REVIEW_BILLING_CADENCE_UNKNOWN`, `MISSING_APPLICABLE_RATE` or `UNMAPPED_SERVICE_TYPE` and have no `invoice_ready_amount`.

Therefore, `ELIGIBLE` must not be interpreted as “ready to invoice”. The workbench must consider the billing-line status, review status and presence of a valid invoice-ready amount.

### 4.3 Null expected amounts are not zero

A null `invoice_ready_amount` or `invoice_ready_expected_charge_amount` means that Gold has not supplied a calculated invoice-ready amount for that line or group. It must not be converted to zero for display or variance calculation.

The workbook should distinguish at least these conditions:

- **Calculated:** an invoice-ready expected amount is present.
- **Partially covered / review required:** an expected amount is present, but one or more billing, pricing or chargeability exceptions remain in the same customer-period.
- **Not calculated:** no invoice-ready expected amount is present.
- **Actual only:** an actual invoice amount exists but there is no corresponding expected-charge calculation, as seen for returns and storage.

Where unresolved exception counts exist in a customer-period, the ready amount may represent only the chargeable portion that Gold could calculate. It must not be presented as a complete expected invoice total. Use the reconciliation exception counts and statuses to qualify the comparison.

### 4.4 Expected-versus-actual calculation

For customer-periods with a usable expected amount and no unresolved billing-coverage exceptions, the variance convention is:

`Variance = Actual invoiced amount - Invoice-ready expected amount`

A negative variance means the actual invoice amount is below the expected amount. A positive variance means the actual invoice amount is above the expected amount.

Use the variance already supplied by `billing_reconciliation` where it matches this convention. The workbook should not calculate a conclusive variance when expected coverage is incomplete or unavailable. In those cases, show the amount/status and the outstanding exception count, and label the comparison as provisional or not assessable.

### 4.5 Charge detail and traceability

For each ready billing line, retain enough detail to let a reviewer trace the amount back to the Gold output. Where available this includes:

- `billing_line_key` and customer identifiers;
- billing period start/end and label;
- activity source and service type;
- billing unit and quantity basis;
- candidate and billable quantity;
- applicable contract and rate identifiers;
- rate effective date, rate unit, base rate and discount context;
- source/calculated net rate and calculated gross/net charge;
- `invoice_ready_amount`;
- billing line status, review status and review explanation.

The detail is explanatory evidence. The workbench is not an invoice-line generator and does not replace QuickBooks entry.

---

## 5. Step 3: Actual invoices, payments, exceptions and review controls

### 5.1 Actual invoice amount

The actual invoiced amount in `billing_reconciliation` has been validated against `accounts_receivable` at customer and billing-period level.

The supplied comparison found:

- 564 customer-periods with actual invoice amounts represented on both sides;
- exact agreement for all 564 matching amounts;
- total actual invoiced amount of $5,714,696.41 in both models;
- no mismatched actual amounts;
- 94 reconciliation-only customer-periods with no matching AR invoice amount; and
- no AR-only customer-periods in the comparison.

The reconciliation-only groups had no actual invoiced amount in the supplied profile. They should be shown as **no matching actual invoice recorded in Gold**, not automatically treated as an error or assumed to be an invoice that is overdue. Finance can decide whether the period is awaiting billing, legitimately unbilled or missing an invoice.

### 5.2 Detail-to-summary expected amount validation

The expected-charge detail was tested against the reconciliation summary at customer-period grain:

- 658 customer-period groups were compared;
- 291 groups had populated expected amounts on both sides, and all 291 matched;
- no detail-only or reconciliation-only populated expected-amount groups were found;
- the remaining 367 groups had no invoice-ready expected amount on either side.

This supports using `billing_reconciliation` for the summary and `billing_invoice_lines` for the expandable breakdown. The 367 null groups must remain not calculated, not zero.

### 5.3 Receivables and collections

Use `gold_finance.accounts_receivable` as the source for the Receivables & Collections worksheet. Its intended grain is one row per QuickBooks invoice.

The supplied profile contains 564 unique invoices across 94 customers, with:

- total invoice amount: $5,714,696.41;
- recorded current balance: $1,344,188.70;
- reconstructed payment balance matching the recorded balance, with zero aggregate difference;
- 371 paid/zero-balance invoices; and
- 193 outstanding invoices, all of which are more than 90 days past due in the supplied snapshot.

Use the invoice's own `payment_terms`, `invoice_date`, `due_date`, `recorded_current_balance`, `days_past_due`, `aging_bucket`, payment linkage and receivables review status. Do not assume all customers share the same payment terms.

The supplied records demonstrate Net 30 and Net 60 terms. They do not demonstrate Net 7. Use the actual invoice-level terms from Gold.

The observed aging profile contains paid/zero-balance and greater-than-90-days-past-due records, but no populated intermediate aging buckets. The workbook must display the source aging classification and must not manufacture a historical aging distribution.

The supplied schema does not identify a clearly defined aging as-of date. `days_past_due` should therefore be treated as the value delivered by the Gold snapshot, not recalculated with the Excel `TODAY()` function. Display the workbook's Last Refreshed timestamp and make the snapshot nature of aging clear.

### 5.4 Collection escalation milestones

The business operating context identifies the following collection escalation points:

| Milestone | Action |
|---|---|
| Day 35 | Automated QuickBooks reminder |
| Day 45 | Finance Director email |
| Day 55 | Account Manager escalation |
| Day 60 | Finance Director and VP Operations review of service continuation/suspension |

The available business context does not conclusively establish whether these day counts are measured from invoice date or from due date. Do not automatically derive a collection stage from `days_past_due` until that basis is confirmed. Preserve the milestones as operating policy and keep the day-count basis as an explicit rulebook clarification before automating the stage.

### 5.5 Payment transaction handling

`financial_transaction_lines` contains payment headers and payment application lines. In the supplied profile:

- 407 payment-header records total $4,370,507.71;
- 407 payment-application records also total $4,370,507.71.

These are two representations of the same payment flow at different record levels. Do not add the payment-header total and the payment-application total together when calculating cash received or collections. Use the AR model's linked/applied payment and reconstructed-balance fields for the invoice-level collections view.

The payment header profile also reports unapplied amounts. Retain the relevant Gold unapplied-payment fields for review where useful, but do not allocate unapplied cash to an invoice without a valid application link.

### 5.6 Credits, refunds and adjustments

The supplied financial transaction profile contains 974 positive invoice-line records across 564 invoices, totalling $5,714,696.41. It does not demonstrate negative customer invoice lines or a distinct credit/refund/adjustment transaction type.

The 28 negative transaction lines in the supplied profile are QuickBooks operating-expense lines, not customer invoice credits. They have no linked invoice in the returned profile. They must not be treated as reductions to billed revenue or as customer credits.

Accordingly:

- Do not infer customer credits or invoice adjustments from negative expense entries.
- Do not automatically net operating expenses against customer billing.
- Treat any customer credit, refund or invoice adjustment as unsupported by the inspected transaction extract until an explicit customer-linked source record is available.
- Keep any separately evidenced manual adjustment in a clearly identified reviewer process; do not silently change the Gold expected or actual invoice amounts.

### 5.7 Exception handling

Preserve Gold's `billing_line_status`, `billing_review_status`, `activity_eligibility_status` and `review_explanation`. The workbench may map those source statuses to readable display groupings, but it must not overwrite the source status or create a misleading “ready” classification.

The main exception types observed include:

| Gold status / condition | Workbench treatment |
|---|---|
| `REVIEW_BILLING_CADENCE_UNKNOWN` | Review commercial cadence/period basis; do not assume weekly or monthly from the status alone |
| `REVIEW_PICKUP_CHARGEABILITY` | Hold pickup chargeability for contract review; do not bill automatically |
| `REVIEW_FAILED_TASK_CHARGEABILITY` | Exclude unsuccessful delivery under the agreed workbench rule and flag the source status for visibility |
| `UNMAPPED_SERVICE_TYPE` | Hold until the source service is mapped to a supported service/rate category |
| `MISSING_CUSTOMER_MAPPING` | Hold until canonical customer identification is resolved; do not place under a guessed customer |
| `MISSING_APPLICABLE_RATE` | Hold as a pricing exception; no workbook rate fallback |
| `NOT_COMPLETED` | Exclude from billable quantity under the current rule |
| Fulfillment source/dispatch matching exceptions | Retain as operational review items; do not create a charge without Gold's invoice-ready result |
| Returns/storage with actual invoice but no expected calculation | Show actual amount and mark expected coverage as unavailable/not calculated |

An `ELIGIBLE` activity status does not clear a billing exception. A line remains unresolved if its billing status/review status indicates an issue or it lacks an invoice-ready amount.

The final grouped exception query was intentionally limited to 20 rows. Its returned groups demonstrate the exception categories and their scale, but must not be treated as a complete inventory of every grouped exception combination.

---

## 6. Workbench presentation and decision rules

### 6.1 Billing Review summary

Each customer-period summary should show, at minimum:

- customer identifier and customer name;
- billing period label and period boundaries where available;
- service scope/service mix;
- invoice-ready expected amount from Gold;
- actual invoiced amount from Gold reconciliation, cross-checked to AR;
- variance where expected coverage is complete enough to assess;
- actual invoice count;
- ready-line count and review/exception counts;
- an explicit coverage/review status; and
- Last Refreshed timestamp for the workbook extract.

All applicable service and charge components should roll up into the same customer-period summary. The breakdown should preserve the service and line-level detail needed for investigation.

### 6.2 Variance interpretation

A numerical variance alone is not sufficient to conclude that an invoice is incorrect. Before a reviewer treats it as an actionable billing variance, the reviewer should establish that:

1. the expected amount is populated;
2. there are no material unresolved billing, cadence, rate or chargeability exceptions affecting expected coverage;
3. the actual amount is present and reconciled to AR; and
4. both sides refer to the same customer and billing period.

If any of these conditions is not met, display the relevant review status and avoid presenting the amount difference as a conclusive underbilling or overbilling result.

### 6.3 Receivables & Collections view

The receivables worksheet should have one row per invoice, with invoice number, customer, invoice date, due date, payment terms, invoice amount, current balance, days past due, aging bucket, payment information, receivables review status and collection action/stage where the day-count basis has been confirmed.

Do not aggregate invoices into one row in this worksheet. The customer-period consolidation rule applies to Billing Review, not to the invoice-level receivables view.

### 6.4 Reviewer notes and manual intervention

The workbench may provide controlled reviewer-note or disposition fields for investigating exceptions. Such fields are downstream workpaper annotations only. They must not change source Gold values, overwrite QuickBooks actuals, or silently convert an unresolved line into a ready-to-bill amount.

Any manual resolution should be traceable to a named reviewer, date, explanation and supporting evidence where the workbook design supports those fields.

---

## 7. Validation evidence and control outcomes

The following controls were completed against the supplied Gold outputs:

| Validation | Observed result | Rulebook consequence |
|---|---|---|
| Billing line key uniqueness and customer-period coverage | 27,432 billing lines with unique billing-line keys; 95 client identifiers including the `N/A` sentinel | Use the stable billing-line key for detail; exclude `N/A` from customer selection and retain it as an unresolved mapping condition |
| Billing cadence and account classification | `MONTHLY` and `UNKNOWN` cadences; `Fixed Rate` and `Variable Rate` classifications | Do not infer weekly PAYG or map account class to a commercial arrangement |
| Ready-line arithmetic | No gross, net or invoice-ready arithmetic mismatches in the tested ready-to-bill service groups, using a $0.02 tolerance | Consume Gold's charge values; no separate Excel price calculation |
| Detail-to-reconciliation expected amount | 291 populated customer-period amounts matched; 367 groups had no expected amount on either side | Detail can support the summary; null expected amounts remain not calculated |
| Reconciliation actual amount to AR | 564 matching customer-period actuals; zero mismatches; both totals $5,714,696.41 | Use reconciliation for Billing Review actuals and AR for invoice details/collections |
| Receivables balance reconstruction | Recorded and reconstructed balances matched; aggregate difference zero | Use the existing AR balance fields, while retaining source review flags |
| Distribution billing basis | Gold billing uses `per_delivery`; no run identifier supports physical run count | Use per-delivery basis; do not manufacture run counts |
| Returns and storage | Actual amounts present, expected-charge calculation unavailable | Display actual-only with expected coverage unavailable |
| Transaction signs | Invoice lines all positive; negative rows are operating expenses | No customer credit/adjustment logic can be inferred from the supplied extract |
| Payment record levels | Header and application totals are identical | Do not double-count payments across record levels |

---

## 8. Known limitations and decisions still requiring confirmation

The following are known limitations of the current source outputs. They are not invitations to modify Gold; they define what the downstream workbench must communicate.

1. **Weekly PAYG representation:** the operating rule says Monday-Sunday, but the current billing output does not represent weekly PAYG periods. Use available Gold periods until a source period is present.
2. **Commercial arrangement mapping:** `Fixed Rate` and `Variable Rate` do not independently identify fixed-fee, volume-commitment or PAYG arrangements.
3. **Distribution run count:** the billing output is per delivery and there is no distinct run key in the inspected model.
4. **Returns and storage expected billing:** actual invoiced amounts are visible, but no corresponding expected billing-line calculations were returned.
5. **Customer credits and adjustments:** the inspected financial transaction lines do not demonstrate customer-linked credit or adjustment records.
6. **Collection milestone basis:** confirm whether Day 35/45/55/60 is measured from invoice date or due date before the workbench automatically assigns collection stages.
7. **Aging as-of date:** the supplied AR fields do not expose a clearly defined as-of date. Treat days past due as a value from the Gold snapshot and show Last Refreshed.
8. **Partially covered customer-periods:** a ready amount can coexist with unresolved billing exceptions. Show exception counts and qualify the expected-versus-actual result.

---

## 9. Downstream implementation guardrails

1. Extract from the existing Gold models without changing them.
2. Keep SQL extraction and validation scripts, documentation, reference mappings and workbook files in the separate `swiftroute-billing-assurance` project.
3. Do not commit production data exports to Git; retain only approved non-sensitive sample/fixture data where needed.
4. Preserve source identifiers and Gold status fields in the extracts so that every summary can be traced to its source rows.
5. Include a Last Refreshed timestamp in the workbook and document the manual refresh procedure.
6. Keep reference mappings and reviewer-facing display labels downstream and controlled.
7. Do not use workbook formulas to recreate contract pricing or to override Gold-calculated invoice-ready amounts.
8. Do not use null expected values as zero, double-count payments, treat operating expenses as customer credits, or calculate collection stages before the day-count basis is confirmed.

---

## 10. Completion status

**Step 1 - Billing periods, customer classification and billable activity:** documented against the operating context and current Gold representation.

**Step 2 - Pricing hierarchy and expected charges:** documented with the boundary that Gold owns the pricing calculation and the workbench consumes invoice-ready outputs.

**Step 3 - Actual invoices, payments, exceptions and validation:** documented against the completed validation outputs, with unsupported credit/adjustment treatment explicitly excluded.

The rulebook is ready to serve as the business-rule reference for the next project artifact, `data_dictionary.md`. Any future change should be recorded as a downstream workbench rule or as a documented source limitation.
