# SwiftRoute Billing Assurance Workbench

A finance review workbench for improving billing visibility, invoice reconciliation and receivables monitoring at SwiftRoute Logistics.

![SwiftRoute Billing Assurance Workbench](assets/billing-assurance-hero.png)

## Project Overview

SwiftRoute Logistics is a regional logistics business providing last-mile delivery and e-commerce fulfilment services. Its billing activity spans operational workflows, customer agreements, rate information and accounting records held across systems such as Onfleet, Linnworks, Salesforce and QuickBooks.

Preparing invoices and monitoring what customers owe requires Finance to bring these different records together, understand which activities are billable, apply the relevant commercial context and reconcile issued invoices against payment activity. When this work relies heavily on exports, spreadsheets and manual checks, it becomes harder to maintain a consistent view of billing readiness, explain differences and identify invoices that need attention.

The **SwiftRoute Billing Assurance Workbench** addresses this challenge by turning prepared warehouse data into a structured, repeatable Finance review process. It combines downstream SQL extracts with an Excel workbook, giving Finance a clear view of expected versus actual billing, supporting billing-line detail, unresolved customer mappings and invoice-level receivables.

## Business Objectives

The workbench is designed to help Finance:

- Review expected billing against invoices actually issued, at customer and billing-period level.
- Inspect the service activity, quantities, rate context and review explanations behind billing lines.
- Identify unassigned or unmapped billing activity that cannot yet be attributed to a recognised customer.
- Monitor invoice balances, linked payments and aging at individual invoice level.
- Surface incomplete billing information and reconciliation exceptions before they are overlooked in the billing process.

## Solution at a Glance

The solution follows a simple, repeatable flow:

```text
Curated Gold warehouse models
              │
              ▼
       Downstream SQL extracts
              │
              ▼
       Controlled CSV exports
              │
              ▼
       Excel Power Query refresh
              │
              ▼
  Billing Assurance Workbench
              │
       ┌──────┴──────┐
       ▼             ▼
  Billing Review   Receivables &
                   Collections
```

Gold provides the prepared billing, reconciliation and receivables information used by the workbench. SQL shapes the required datasets for Finance, while Power Query loads the extracts into the workbook for filtering, review and investigation.

## Finance Workbench

The Excel workbook contains two primary review areas.

### 1. Billing Review

Billing Review provides a customer-period view of billing activity. Finance selects a billing period and can narrow the review queue using the available customer and review-status controls.

The worksheet includes:

- **Customer-period billing summary:** expected amount, actual invoiced amount, invoice count, assessable variance and review indicators for each customer-period.
- **Selected billing-line detail:** the billing lines associated with the selected customer-period key, including service, activity source, billing unit, quantities, invoice-ready amount, status, explanation and contract/rate references.
- **Unmapped billing activity:** billing lines without a valid canonical customer mapping, presented separately for investigation rather than being attributed to an unrelated customer.

The summary is at customer-period grain, the detail is at billing-line grain, and unmapped activity remains visible as a separate exception population.

### 2. Receivables & Collections

Receivables & Collections provides an invoice-level view of issued invoices, linked payments, outstanding balances and aging information.

The worksheet includes:

- A filterable invoice review queue.
- Invoice amount and recorded outstanding balance.
- Applied payment amounts, linked payment counts and payment dates.
- Gold-provided days past due and aging bucket.
- Receivable review status and payment-link mismatch indicators.
- A KPI strip showing invoice amount, outstanding balance, invoice count, open invoice count and 90+ days past-due balance for the loaded USD extract.

The invoice queue is at one row per invoice. Aging values are supplied by the warehouse and displayed for Finance review.

## Repository Structure

```text
swiftroute-billing-assurance/
│
├── assets/
│   └── billing-assurance-hero.png       # README hero image
│
├── data/
│   └── exports/
│       ├── 01_billing_review_summary.csv
│       ├── 02_billing_detail.csv
│       ├── 03_receivables.csv
│       └── 04_customer_lookup.csv
│
├── docs/
│   ├── billing_rulebook.md              # Billing and review rules
│   ├── business_problem.md              # Business context and problem definition
│   ├── data_dictionary.md               # Source fields and data definitions
│   ├── extract_contracts.md             # Extract grains, schemas and field contracts
│   └── workbook_design.md               # Workbook layout and interaction design
│
├── sql/
│   ├── extracts/
│   │   ├── 01_billing_review_summary.sql
│   │   ├── 02_billing_detail.sql
│   │   ├── 03_receivables.sql
│   │   ├── 04_customer_lookup.sql
│   │   └── SQL_EXTRACTS_README.md
│   │
│   ├── inspection/
│   │   └── 00_profile_source_values.sql
│   │
│   └── validation/
│       ├── 01_validate_source_keys.sql
│       ├── 02_validate_period_alignment.sql
│       ├── 03_validate_reconciliation_to_ar.sql
│       └── 04_validate_currency_and_customer_mapping.sql
│
├── workbook/
│   ├── SwiftRoute_Billing_Assurance_Workbench_v1_1.xlsx
│   └── workbook_setup_guide.md
│
├── .gitignore
├── .python-version
├── main.py
├── pyproject.toml
├── uv.lock
└── README.md
```

The `.venv/` directory is a local Python environment and is not part of the project deliverables. The `assets/` directory is used for the README hero image.

> **Before publishing publicly:** Review the CSV files in `data/exports/` for customer names, identifiers, invoice details and other commercially sensitive information. Use approved, anonymised or synthetic extracts in a public repository, or keep working exports out of the public release.

## Key Deliverables

| Deliverable | Description |
|---|---|
| Excel Billing Assurance Workbench | Finance-facing workbook for billing review and receivables monitoring. |
| Four SQL extracts | Customer-period billing summary, billing-line detail, receivables and customer lookup. |
| SQL validation queries | Checks for key uniqueness, period alignment, reconciliation to AR, currency and customer mapping. |
| Source inspection query | Profiles source values used to understand the available billing and review categories. |
| Business and data documentation | Business problem, billing rulebook, data dictionary, extract contracts and workbook design. |
| Power Query setup guide | Instructions for connecting the extracts and refreshing the workbook. |

## Technology

- **Databricks SQL** – downstream extraction, aggregation and validation against the curated warehouse models.
- **Microsoft Excel 2021** – Finance review interface and formula-driven review views.
- **Power Query** – import and refresh of the controlled CSV extracts.
- **CSV** – portable hand-off format between SQL extracts and the workbook.
- **Git** – project version control and documentation.

## Refresh Workflow

The workbench is refreshed as a controlled batch:

1. Profile source values when needed and run the four SQL extracts.
2. Export the results using the filenames in `data/exports/`.
3. Run the SQL validation queries and review any exceptions or differences.
4. Open the workbook and use **Data → Refresh All** to refresh the Power Query imports.
5. Confirm that all four imports refreshed successfully and review the key counts, totals and exception populations.
6. Record the successful refresh details in the workbook's control area.

For detailed setup instructions, see [`workbook/workbook_setup_guide.md`](workbook/workbook_setup_guide.md). The SQL extract definitions and output expectations are documented in [`sql/extracts/SQL_EXTRACTS_README.md`](sql/extracts/SQL_EXTRACTS_README.md).

## Business and Data Principles

The workbench is designed around a small set of important review principles:

- **Preserve the distinction between zero and unavailable.** A missing expected amount is not treated as a zero-value expected charge.
- **Use warehouse-prepared billing values.** Finance reviews Gold-provided quantities, rates, invoice-ready amounts and aging rather than independently recreating those calculations in Excel.
- **Keep review levels distinct.** Billing is reviewed at customer-period and billing-line levels; receivables are reviewed at invoice level.
- **Make exceptions visible.** Unmapped customers, missing rates, unclear activity chargeability and incomplete billing coverage remain identifiable for review.
- **Retain operational context.** Billing-line source references, statuses and explanations help Finance understand why a line is ready, requires review or has no calculated expected amount.

## Scope

The workbench supports Finance review, reconciliation and receivables monitoring. It does not create or post invoices, replace the accounting system, or make automated collections or service-continuation decisions. It is a structured review layer that helps Finance investigate billing information and make better-informed decisions.

---

**Project:** SwiftRoute Billing Assurance Workbench  
**Primary users:** Finance and operations stakeholders  
**Workbook:** `workbook/SwiftRoute_Billing_Assurance_Workbench.xlsx`
