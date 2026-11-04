## Billing Rulebook - Step 1: Billing Periods, Customer Classification and Billable Activity

**Status:** Working rulebook  
**Scope:** Step 1 of the Billing Assurance Workbench design  
**Purpose:** Establish the business rules that determine which customer activities enter a billing period and how they are organized for review. Pricing calculations, adjustments, validation logic and Gold-field mapping will be completed in subsequent steps.

### Rule status conventions

- **Documented:** Explicitly stated in the SwiftRoute Business Operating Context.
- **Agreed:** Confirmed during the rulebook design discussion.
- **Proposed control:** A practical control recommended for consistent billing, subject to confirmation where indicated.
- **Data validation pending:** The business rule is understood, but the curated Gold data must be inspected to confirm that it can be implemented reliably.

---

## 1. Customer billing arrangements

SwiftRoute uses three primary billing arrangements. The arrangement determines the billing cadence and the commercial basis used to calculate charges.

| Arrangement | Business definition | Billing cadence | Pricing basis | Payment terms |
|---|---|---|---|---|
| Pay-as-you-go (PAYG) | No committed minimum. Typically used by smaller or newer customers during an initial period. | Weekly, Monday to Sunday | Standard list rates | Net 7 |
| Volume contract | Customer commits to a monthly delivery minimum in exchange for a negotiated per-delivery rate. | Monthly | Negotiated rate, subject to the contract's terms | Net 30 |
| Fixed-fee contract | Customer pays a flat monthly fee for an agreed delivery volume within a defined service/zone scope. Charges may apply to activity above the included volume. | Monthly | Monthly fee plus eligible overage | Net 30 |

### 1.1 Classification rules

1. Use the applicable Salesforce account/contract information and the active commercial agreement to determine the billing arrangement.
2. Apply a contract only when its status and effective dates make it applicable to the service date being billed.
3. Use the rate and terms effective on the service date, not simply the most recently loaded rate record.
4. Do not classify a customer as PAYG merely because an active contract record cannot be found. Missing, expired, draft or unmapped contract information must be flagged for review rather than silently assigned standard rates.
5. Use the canonical customer/client identifier to connect Salesforce, Onfleet, Linnworks and QuickBooks records. Similar customer names are not a reliable substitute for an identifier.
6. Customer industry or segment labels, such as e-commerce, retail, healthcare/pharma or B2B, describe the customer but do not override its contractual billing arrangement.

### 1.2 Service scope is separate from billing arrangement

Fulfillment and last-mile delivery describe the services a customer uses. They are not additional contract types. A customer may therefore be:

- Last-mile delivery only.
- Fulfillment and last-mile delivery.
- Fulfillment only.
- Of unknown or unconfirmed service scope.

A customer can also have more than one commercial arrangement or service scope. The billing logic must preserve those distinctions in the supporting charge detail.

### 1.3 Consolidation for the Billing Review worksheet

The Billing Review summary will use **one row per customer per selected billing period**. Where a customer has multiple service arrangements or charge categories within the same period and those charges belong on one consolidated invoice, the expected charges will be aggregated into one customer-period total.

The detail/breakdown view must retain the underlying components, including the relevant arrangement or contract, service type, activity, quantity, rate, pricing basis and calculated charge. Consolidation must not erase the audit trail or cause different rates to be applied as though they were one arrangement.

Where a customer has distinct billing cadences or separate invoice requirements, the records must not be forced into one artificial period. The customer-period summary should follow the actual invoice grouping supported by the commercial terms.

**Reconciliation grain:** customer + billing period, with currency included where a customer can be billed in more than one currency. Expected billing is compared with the actual QuickBooks invoice total at this grain. The workbench must not imply line-level matching between calculated operational charges and QuickBooks invoice lines unless a reliable matching method is established.

---

## 2. Billing periods and invoice timetable

### 2.1 Monthly contracted customers

The documented monthly billing cycle is:

- Billing period closes on the final calendar day of the month.
- Billing preparation begins on the first business day of the following month.
- Invoices are targeted for issue by the 5th of the month.
- Standard payment terms are Net 30 from the invoice date.

### 2.2 PAYG customers

The agreed PAYG billing cycle is:

- **Period start:** Monday.
- **Period end:** Sunday.
- **Close:** End of day Sunday.
- **Invoice preparation:** Monday following the close.
- **Standard payment terms:** Net 7 from the invoice date.

The week is therefore a Monday-to-Sunday calendar week. The billing period must be represented explicitly by its start and end dates, not only by a week number.

### 2.3 Service-date assignment

**Proposed control:** Assign operational activity to a billing period using the date on which the service was performed, rather than the date on which the source record was ingested, processed or exported.

For Onfleet delivery activity, use the relevant completion timestamp for a successfully completed customer-facing delivery. Convert timestamps to the applicable operating location's local time before deriving the service date, where source timestamps are stored in UTC.

For Linnworks fulfillment activity, the exact event that establishes the billable date (for example, pick, pack or dispatch) remains to be confirmed against the operating rule and available source fields.

Storage charges require a period-based measurement. A current stock snapshot alone must not be treated as historical monthly storage utilization.

### 2.4 Payment terms and collection stages

Payment terms and collection escalation are separate concepts:

- Payment due date is derived from the invoice date and the applicable contractual terms.
- Invoice age is the number of days since invoice date.
- Days past due is the number of days after the due date.
- Collection stage is determined by the documented escalation process and must not be substituted for either invoice age or days past due.

The operating context describes collection actions at days 35, 45, 55 and 60. The precise meaning of the reference to a “35th” day should be checked against the invoice due-date calculation before it is implemented as an automated rule.

---

## 3. Billable activity catalogue

The catalogue below defines the activity types that may contribute to expected customer billing. Inclusion in the catalogue does not mean that every source record is automatically billable. Each activity must satisfy the relevant eligibility, customer, contract and pricing checks.

| Activity | Proposed billing unit / basis | Primary source | Rule and control |
|---|---|---|---|
| Same-day delivery | Per eligible completed delivery | Onfleet | Bill a successful customer-facing delivery when customer, service, zone and applicable contract/rate can be identified. |
| Next-day delivery | Per eligible completed delivery | Onfleet | Same eligibility principle as same-day delivery, using the applicable service rate. |
| Scheduled/window delivery | Base delivery charge, plus an applicable surcharge where the contract provides for it | Onfleet and Salesforce | Apply a surcharge only when the relevant service/contract terms support it. Do not add a surcharge when it is already included in the base rate. |
| Returns collection | Per eligible return movement, using the applicable zone rate where supported by the operating context | Onfleet | A return must be distinguishable from an ordinary pickup or delivery task. Identification method is pending Gold-data validation. |
| B2B distribution run | Per distribution run, as the starting business rule | Onfleet and Salesforce | Operating context describes regular box-truck distribution runs on fixed schedules and routes under dedicated account contracts with committed volumes. Validate that Gold data identifies runs and that contract rates support a per-run unit before implementation. |
| Fulfillment pick/pack | Per picked or packed unit, potentially differentiated by complexity tier | Linnworks | Confirm the billable event, unit definition and complexity mapping before calculation. |
| Inventory storage | Per agreed pallet/shelf unit per billing month, or other contract-defined measure | Linnworks | Requires an appropriate monthly or historical utilization measure. A single current stock snapshot is insufficient to reconstruct prior-period usage. |
| Delivery associated with fulfillment | Per eligible delivery, if separately chargeable under the customer agreement | Onfleet, with Linnworks context where available | Check whether delivery is included in a fulfillment package or separately priced. Do not charge twice for a bundled service. |
| Special handling | Contract-defined flat fee or per-movement charge | Operational evidence and Salesforce/approved adjustment record | Charge only where a contract/rate or approved manual amount supports it. Retain reason, evidence and approval. |
| Fixed-fee overage | Per eligible unit above the included contractual volume, using the overage rate | Salesforce and operational activity | Apply only after measuring eligible activity against the contract's included volume and scope. |
| Service-failure credit | Negative adjustment, where approved | Onfleet and finance approval evidence | Credit only when the failure is attributable to SwiftRoute and the adjustment is approved. Not every failed task automatically creates a credit. |
| Warehouse returns processing | No separate charge by default | Linnworks / contract | Charge separately only if the contract or rate card explicitly defines a processing fee. This is distinct from charging for return collection. |
| Other commercial adjustment | Approved amount | Finance-approved record and supporting evidence | Must include customer, billing period, amount, reason/reference and approval evidence. |

### 3.1 Successful and unsuccessful delivery tasks

The agreed billing rule is that **unsuccessful deliveries are not billable to the customer**. They are treated as a SwiftRoute operating cost.

For the billing calculation:

- Only eligible, successfully completed customer-facing deliveries may enter standard delivery charges.
- Failed, unsuccessful or incomplete attempts must be excluded from customer-billable delivery quantities.
- Unsuccessful tasks should remain available in supporting operational data for cost and service-performance review. They must not disappear simply because they are excluded from billing.
- A pickup task is not automatically a billable delivery. It must be identified as a separately chargeable activity, such as a qualifying return collection, and supported by the applicable contract/rate.

### 3.2 Returns identification

The business rule distinguishes return collection from ordinary pickup activity, but the exact source-data identification method is **pending validation**.

The Gold layer should be inspected for fields, event types, task metadata or derived classifications that reliably distinguish return movements from normal delivery/pickup work. Until that inspection is complete:

- Do not classify all pickup tasks as returns.
- Do not automatically apply a return charge based only on a generic pickup task type.
- Retain an unresolved/unknown classification for records that cannot be confidently identified.
- Confirm whether the existing Gold model already provides a usable return indicator before proposing a model change.

### 3.3 B2B distribution runs

The operating context describes B2B distribution as regular box-truck runs, operating on fixed schedules and routes, and managed under dedicated account contracts with committed volumes and fixed route structures.

The initial billing interpretation is **per distribution run**, rather than per stop or per individual delivery. This is the business rule to test against the curated data.

Before implementing the charge:

1. Check whether the Gold data can identify a run as a distinct operational unit.
2. Check whether multiple Onfleet tasks/stops can be associated with the same run.
3. Inspect the relevant Salesforce rate records and rate units.
4. Resolve any conflict between a per-run commercial description and a technical rate record expressed as `per_delivery`.

If the available data cannot reliably identify runs, do not approximate run counts by counting individual tasks without an agreed rule. Record the limitation and determine whether a reliable source field or mapping is available.

---

## 4. Eligibility and duplicate-charge controls

An operational record should enter expected billing only when the following checks pass, as applicable:

1. It represents a customer-facing service or other contractually chargeable activity.
2. The customer can be identified using the canonical customer/client identifier.
3. The service date falls within the relevant billing period and the applicable contract's effective dates.
4. The service/activity type can be identified sufficiently to select the correct pricing rule.
5. The required pricing dimensions, such as service type and zone, are available.
6. The activity satisfies the agreed completion/eligibility rule.
7. The activity has not already been included in a prior billing period or duplicated through another source record.
8. The contract does not bundle the activity into another charge already being calculated.

### 4.1 No-double-counting principles

- A fulfillment pick/pack charge and a delivery charge may both be valid when the agreement prices them separately.
- A delivery included in a fixed fee or fulfillment bundle must not also be charged as a separate delivery unless the contract explicitly permits it.
- A scheduled-delivery surcharge must not be added when it is already included in the base rate.
- Fixed-fee customers should be charged the monthly fee for the defined included scope, with overage applied only to eligible activity above the commitment.
- A volume commitment must not automatically be treated as a minimum billable quantity unless the contract explicitly states that the minimum is chargeable.
- Return collection and warehouse returns processing are separate activities. Do not assume that one implies the other.
- Multiple operational tasks associated with one service must not automatically be counted as multiple billable deliveries.

---

## 5. Source-system responsibilities

| Source | Primary billing role |
|---|---|
| Salesforce | Customer commercial arrangements, contract status/effective dates, service scope, rate cards, negotiated pricing and contractual terms. |
| Onfleet | Last-mile operational activity, task status, completion timestamps, service/task attributes, route/zone context and delivery evidence. |
| Linnworks | Fulfillment activity, picked/packed/dispatched quantities, inventory and storage-related data. |
| QuickBooks | Actual invoices, invoice dates, invoice totals, balances, due dates and payment/receivables information. |

The source system responsible for a business fact should remain authoritative for that fact. The billing workbench may combine sources for review, but should not silently replace missing commercial terms with operational assumptions.

---

## 6. Known data considerations to validate during implementation

The following are implementation checks, not reasons to invent missing business rules:

- The reviewed QuickBooks monthly sample showed 94 invoices per month and 94 distinct valid client identifiers per month, with no missing client IDs in that sample. This is evidence for the reviewed monthly sample, not proof that all weekly PAYG billing cases are covered.
- The Onfleet diagnostic identified 6,595 tasks without `client_id`. These cannot be assigned to a customer automatically without a reliable mapping.
- Onfleet task counts include task types that are not equivalent to billable completed deliveries. Task-level records must be classified before billing.
- The available contract-rate diagnostics include categories such as `same_day`, `next_day`, `scheduled`, `distribution_run`, `returns`, `fulfillment_pick` and `storage`, but coverage and rate units require validation.
- A technical rate record for `distribution_run` was observed with a `per_delivery` unit, while the operating description supports charging per run. This conflict must be resolved before applying the rate.
- Linnworks stock data currently available as a snapshot does not, by itself, establish historical monthly storage utilization.
- A reliable direct relationship between Onfleet delivery tasks and Linnworks orders has not yet been established. Do not manufacture a link using customer names, timestamps or approximate amounts.

---

## 7. Items carried forward for confirmation

These are the remaining decisions or data checks. They do not block documenting the rules already agreed.

| Item | Current position | Next action |
|---|---|---|
| Authoritative source for billing arrangement | Salesforce contract/account information is the intended source. | Confirm the exact Gold fields and precedence where account and contract records differ. |
| Mixed arrangements and invoice consolidation | Consolidate charge components at customer + billing period when they belong to one invoice; preserve arrangement-level detail in the breakdown. | Confirm how distinct billing cadences or separate invoice requirements are represented. |
| Returns classification | Must distinguish returns from ordinary pickup tasks. | Inspect Gold fields and source task metadata; retain unknown where ambiguous. |
| B2B distribution run | Per run is the starting rule. | Validate run identifiers/grouping and resolve `per_run` versus `per_delivery` rate-unit conflict. |
| Billable fulfillment event | Not yet decided. | Confirm whether picked, packed or dispatched quantity/event drives billing. |
| Storage measurement | Requires a monthly/historical measure. | Confirm whether contract uses month-end, daily average, peak usage or another basis, and whether data supports it. |
| Failed delivery attempts | Not billable; treated as SwiftRoute operating cost. | Confirm Gold status mapping reliably identifies unsuccessful tasks. |
| Return processing fee | No separate fee by default unless contract explicitly provides one. | Check rate cards and contract terms. |
| Manual adjustments and credits | Require reason, reference and approval evidence. | Define approval source and required evidence fields in Step 3. |
| Due-date calculation | Net 7 / Net 30 from invoice date are the stated terms. | Confirm calendar-day treatment and weekend/holiday handling. Clarify the operating document's “35th day” reference against due-date calculation. |

---

## 8. Step 1 acceptance criteria

Step 1 is ready to close when:

- PAYG is defined as Monday-to-Sunday, with invoice preparation on Monday.
- Monthly contracted billing follows calendar-month close and the documented invoice timetable.
- Customer billing arrangement is distinct from service scope.
- Customer-period summary consolidation is defined, while underlying arrangement and charge detail is retained.
- Service-date assignment is defined for delivery activity.
- Successful delivery is billable only when the other eligibility and contract checks pass.
- Unsuccessful delivery is excluded from customer billing and retained as a SwiftRoute operating cost.
- Returns are not inferred from generic pickup tasks; Gold classification is to be validated.
- B2B distribution is provisionally priced per run, subject to validating run identification and rate-unit compatibility.
- Remaining data-dependent questions are explicitly carried into the Gold mapping and validation steps.

**Next step:** Step 2 will define the pricing hierarchy and calculation formulas using the arrangements and billable activity catalogue established here.
"""

path = Path("/mnt/data/billing_rulebook_step1_revised.md")
path.write_text(content, encoding="utf-8")
print(f"Created: {path}")
print(f"Size: {path.stat().st_size:,} bytes")
