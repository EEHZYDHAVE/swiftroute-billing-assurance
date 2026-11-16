# SwiftRoute Billing Assurance Workbench
## Business Problem and Project Definition

**Version:** 1.0  
**Prepared:** 9 November 2026  
**Project:** `swiftroute-billing-assurance`  
**Business domain:** Finance, billing assurance and receivables

---

## 1. Business context

SwiftRoute Logistics is a case-study regional logistics business providing last-mile delivery and e-commerce fulfillment services across Denver, Salt Lake City and Albuquerque. Its operating environment spans delivery management, warehouse and inventory operations, customer and contract management, and accounting. Different parts of this activity are recorded in systems such as Onfleet, Linnworks, Salesforce and QuickBooks Online.

The Business Operating Context describes a recurring billing process covering approximately 94 business accounts. At the end of a billing period, Finance assembles operational activity, applies the relevant customer rates, calculates fulfillment charges and adjustments, enters invoice lines into QuickBooks, and submits the invoice for Finance Director review. The documented process takes approximately 3-5 business days across the account portfolio.

Although SwiftRoute's data platform now provides curated Gold models for finance, last-mile delivery, fulfillment and customer economics, Finance still needs a practical review workpaper that brings the relevant outputs together in a controlled way. The gap addressed by this project is therefore not the absence of a data warehouse or the need to build another billing engine. It is the need to make the existing, governed data usable for repeatable billing review and receivables monitoring.

## 2. The business problem

SwiftRoute's billing assurance process depends on assembling information from several operational and financial systems and manually checking that activity, contracted pricing and QuickBooks invoices agree. Delivery activity is exported from Onfleet by customer. Customer rate cards and contract terms are referenced in Salesforce and applied through a Finance-maintained mapping spreadsheet. Fulfillment customers require separate Linnworks activity reports for picked, packed and dispatched units and storage utilization. Finance then identifies relevant credits, service failures, special handling and returns charges, prepares invoice lines, and enters them into QuickBooks for review.

This process creates a fragmented path between what happened operationally, what should be charged commercially, what Finance actually invoiced and what remains unpaid. The most exposed steps are the manual application of rates and the transcription of calculated amounts into QuickBooks. The process also requires Finance to investigate whether delivery and fulfillment activity has been classified correctly, whether all charge components have been considered, and whether any exceptions or adjustments have been missed.

Receivables follow-up is a separate but related control. Finance runs an AR aging report weekly and escalates overdue accounts through a defined sequence of reminders and management intervention. Without an accessible invoice-level view of due dates, balances, payment applications and aging, collections review continues to depend on separate accounting reports and manual follow-up.

**Core problem statement:** SwiftRoute does not have a single, repeatable Finance workpaper that connects invoice-ready expected charges, actual QuickBooks invoices, unresolved billing exceptions and invoice-level receivables in one review process. As a result, billing review is time-consuming, susceptible to manual handling errors and harder to monitor consistently across customers and periods.

## 3. Why this matters

### 3.1 Time spent assembling and checking billing information

The documented 3-5 business day billing process requires Finance to gather reports, apply rates, consolidate service charges, identify adjustments and manually create invoice lines across approximately 94 accounts. Time spent reconstructing the same information limits the time available for exception investigation and financial review.

### 3.2 Exposure to rate and transcription errors

The operating context identifies the manual rate-application step as particularly exposed to transcription errors. Separate source exports and mapping spreadsheets increase the need to recheck customer, service, zone, quantity and rate combinations before invoices are finalized.

### 3.3 Incomplete visibility of billing exceptions

A customer may have eligible operational activity that is not ready to bill because the billing cadence, customer mapping, service classification, contract or rate context is unresolved. Pickup and failed-task chargeability also require deliberate treatment. If the Finance review focuses only on totals, these issues can be hidden inside an apparently complete invoice amount.

### 3.4 Limited connection between billing and collections review

Billing review asks whether expected service charges were invoiced. Collections review asks whether issued invoices have been paid and what balances remain overdue. Both are part of Finance's control process, but they require different levels of detail: customer + billing period for billing assurance, and one row per invoice for receivables.

## 4. Business objective

Create a controlled, refreshable Excel Billing Assurance Workbench that allows Finance to review billing completeness and accuracy using the existing Gold Finance outputs, investigate material exceptions through supporting detail, and monitor receivables at invoice level.

The workbench will reduce the need to repeatedly assemble and reconcile separate exports during review. It will provide a consistent view of expected billing, actual invoiced amounts, exception coverage, invoice balances and aging while preserving traceability to the curated data.

## 5. Decisions the workbench should support

### 5.1 Billing Review

For each customer and billing period, Finance should be able to determine:

- What invoice-ready amount does the existing Gold model provide?
- What amount was actually invoiced in QuickBooks for that customer and period?
- Is the expected-versus-actual comparison assessable, or is it partial because unresolved billing exceptions remain?
- Which service types and charge components contribute to the customer-period total?
- Are there eligible activities that remain unpriced, unmapped, unclassified or under review?
- Is there an actual invoice amount for a service category for which Gold has no corresponding expected-charge calculation?
- Which detailed source activities, orders, contract references or rate attributes should be investigated?

The summary must show **one row per customer per billing period**. Where multiple services or charge components belong to the same customer-period invoice, they should be consolidated into the summary amount while preserving the service and billing-line breakdown for review.

### 5.2 Receivables & Collections

For each QuickBooks invoice, Finance should be able to determine:

- Which customer does the invoice belong to?
- What is the invoice amount, invoice date, due date and payment term?
- What balance remains outstanding?
- What payment amount has been linked to the invoice, and when was the first or latest linked payment recorded?
- How many days past due does the Gold receivables model report, and what aging bucket does it assign?
- Does the invoice have a balance, due-date or payment-linkage review issue?
- What collection action is due under the business escalation policy, once the day-count basis has been confirmed?

The receivables view must retain **one row per invoice**. It must not be consolidated to customer-period grain.

## 6. Target users and responsibilities

| User | Primary use |
|---|---|
| Finance analyst / billing team | Review customer-period billing, investigate exceptions, compare expected and actual amounts, and prepare the supporting evidence for invoice review. |
| Finance Director | Review billing exceptions and material variances, oversee invoice approval, and monitor aged receivables. |
| Account Manager | Receive escalations for overdue customer accounts and support the customer relationship follow-up. |
| VP of Operations | Participate in service continuation or suspension review at the defined collection escalation point. |

The workbench supports these roles by presenting information and review evidence. It does not itself approve invoices, contact customers or decide to suspend service.

## 7. Scope

### In scope

1. **Billing Review customer-period queue:** customer, period, expected billing, actual invoiced amount, variance where assessable, exception counts and review status.
2. **Billing detail breakdown:** service, activity source, billing unit, quantity basis, candidate/billable quantities, contract and rate context, invoice-ready amount, line status and review explanation.
3. **Billing coverage exceptions:** missing customer mapping, unknown cadence, unmapped service, missing applicable rate, pickup chargeability, failed-task chargeability and other source-provided review statuses.
4. **Receivables & Collections:** invoice number, customer, invoice date, due date, payment terms, invoice amount, outstanding balance, linked payments, days past due, aging bucket and receivables review status.
5. **Refresh controls:** controlled data extracts, a Last Refreshed timestamp, documented refresh steps and validation checks.
6. **Reviewer workpaper fields:** where useful, controlled reviewer notes or dispositions kept outside Gold and clearly distinguished from source values.

### Out of scope

- Creating or sending QuickBooks invoices.
- Posting payments, journal entries, credits, refunds or other accounting adjustments.
- Replacing QuickBooks as the accounting system of record.
- Building a new application or a customer-facing billing portal.
- Modifying, rebuilding or extending any existing Gold model or schema.
- Reimplementing contract selection, rate selection or charge calculations in Excel.
- Inferring missing customer, service, contract, rate, return or distribution-run classifications.
- Allocating general operating expenses to individual failed deliveries without a defensible cost attribution method.
- Automating collection emails, customer contact or service suspension decisions.

## 8. Data and solution boundary

The workbench will consume existing Gold datasets from the established SwiftRoute analytics environment. The core sources are:

| Gold model | Workbench purpose |
|---|---|
| `gold_finance.billing_reconciliation` | Customer/service/month expected and actual billing measures, reconciliation status and exception counts. Downstream aggregation produces the customer-period summary. |
| `gold_finance.billing_invoice_lines` | Expected-charge detail, quantities, contract/rate context, billing statuses and invoice-ready line amounts. |
| `gold_finance.accounts_receivable` | Invoice-level actuals, outstanding balances, payment applications, due dates and aging. |
| `gold_finance.financial_transaction_lines` | Supporting transaction audit only. Record types and amount roles must remain separate to avoid double counting. |
| `gold_last_mile.fact_delivery` and dimensions | Supporting delivery outcome, service, zone and contract investigation. |
| `gold_fulfillment.fact_fulfillment_transaction` and dimensions | Supporting fulfillment stock transaction, order and dispatch investigation. |
| `gold_customer.dim_customer_c` and `fact_customer_economics` | Canonical customer display and optional customer-period context. |

The separate Billing Assurance project will own downstream SQL projections, aggregation, controlled extracts, validation, workbook design and documentation. Existing Gold objects remain untouched.

## 9. Known source-data limitations that affect the workbench

The workbook must reflect the available data rather than imply a level of assurance that the source models do not support.

1. **Weekly PAYG periods:** the operating context documents a Monday-to-Sunday PAYG cycle. The inspected Gold billing output contains `MONTHLY` and `UNKNOWN` cadence values, not a demonstrated weekly PAYG population. The current workbook will use the periods Gold provides and will not invent weekly periods.
2. **Commercial arrangement:** source labels such as `Fixed Rate` and `Variable Rate` do not independently establish PAYG, volume-contract or fixed-monthly arrangements. Unknown cadence or contract mapping remains a review issue.
3. **Billing readiness:** eligible activity is not automatically ready to invoice. Unknown cadence, missing rates, unmapped services and chargeability reviews can prevent an expected amount from being produced. A null invoice-ready amount must not be shown as zero.
4. **Failed deliveries and pickups:** unsuccessful deliveries are not billable under the agreed workbench treatment and remain SwiftRoute operating-cost evidence. Pickup activity is not automatically a return or a billable movement.
5. **Distribution runs:** the existing Finance billing output represents the observed distribution service on a `per_delivery` basis. No distinct physical run identifier was identified in the inspected Gold delivery fact. The workbook will use the supplied Finance amount and will not calculate per-run charges.
6. **Returns and storage:** actual invoice amounts are visible in reconciliation, but the supplied validation did not identify corresponding ready expected-charge lines. These categories can be shown as actual-only with expected coverage unavailable; they cannot be treated as fully assured expected-versus-actual comparisons.
7. **Credits and adjustments:** the supplied financial transaction validation did not identify negative customer invoice/revenue lines. Negative records were operating expenses. The workbook will not infer a credit workflow from them.
8. **Collection escalation basis:** the business context defines Day 35, 45, 55 and 60 actions, but the available instruction does not conclusively say whether those days are measured from invoice date or due date. Stage automation remains out of scope until confirmed.
9. **Aging values:** the Gold AR model computes days past due using `CURRENT_DATE()` and due date. The workbook will display the supplied aging value and its refresh timestamp rather than maintain a competing Excel calculation.
10. **Payment representation:** payment headers and payment application lines are separate representations of the same payment flow. They must not be added together.

These limitations are not requests to alter Gold. They define when the workbook should display a review status, partial coverage or unavailable measure.

## 10. Success measures

The project should be evaluated against the existing manual process and the quality of the resulting review controls. Numeric improvement targets should be agreed after recording a baseline; they should not be invented in this design document.

| Measure | How it will be assessed |
|---|---|
| Billing-cycle effort | Compare elapsed Finance effort and time spent assembling/rechecking billing information against the documented 3-5 business day process. |
| Customer-period coverage | Track the number and share of customer-periods with populated expected amounts, actual invoices, and no unresolved coverage exceptions. |
| Reconciliation reliability | Confirm that customer-period actual totals tie to AR and that the downstream expected roll-up ties to the Gold reconciliation source. |
| Exception visibility | Confirm that unresolved activity and pricing/chargeability statuses are visible, categorized and traceable to supporting detail. |
| Receivables reliability | Confirm one row per invoice, correct balances and payment links, preserved invoice terms and source aging. |
| Refresh control | Confirm the extract timestamp is present and refresh validation checks pass before the workbook is used for review. |
| Manual handling reduction | Identify repeated exports, rate reapplication and manual copying that the workbench removes from the review process. |

## 11. Acceptance criteria

The business problem is considered adequately addressed when the workbench:

- Presents one customer-period Billing Review summary with expected amount, actual invoiced amount, assessable variance and exception coverage.
- Preserves an expandable service and billing-line breakdown with traceable source fields.
- Distinguishes complete comparisons from partial, not-calculated and actual-only cases.
- Keeps unsuccessful deliveries out of customer expected charges and retains them as operational evidence.
- Does not infer PAYG, returns, physical distribution runs, missing rates or credit adjustments.
- Presents Receivables & Collections at one row per invoice, with the invoice's own terms, balance, dates and source aging.
- Prevents double counting of payment headers and payment application lines.
- Uses only existing Gold data and downstream transformations in the separate project workspace.
- Records the extract refresh timestamp and provides repeatable validation and refresh instructions.

## 12. Source references

- **SwiftRoute Logistics - Business Operating Context, Internal Reference Document, June 2025:** sections 6 (Commercial Model), 8 (Systems), and 18.1-18.4 (Billing Cycle, Invoice Line Preparation, Expense Tracking and Accounts Receivable Management).
- **SwiftRoute Billing Assurance Workbench - Billing Rulebook, Version 1.0, 8 November 2026:** agreed billing periods, classification boundaries, expected billing rules, exception treatment, reconciliation controls and receivables treatment.
- **Gold schema and profiling validation:** inspection of existing `gold_finance`, `gold_last_mile`, `gold_fulfillment` and `gold_customer` models, with the validation outputs recorded during the project.

---

**Project positioning:** This workbench is a downstream analytical workpaper built on an existing data platform. Its value is a dependable, repeatable Finance review process, not a new billing application or a modification to the warehouse's Gold layer.
