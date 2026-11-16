# SwiftRoute Billing Assurance: downstream SQL extracts

This package contains the first downstream SQL extract set for the Excel Billing Assurance Workbench.

## Architecture boundary

These queries read the existing Gold models and return result sets only. They do not create, replace, update or delete tables, views or records. They do not alter the existing Gold layer. Save the files under the matching folders in the `swiftroute-billing-assurance` project.

```text
sql/
├── extracts/
│   ├── 01_billing_review_summary.sql
│   ├── 02_billing_detail.sql
│   ├── 03_receivables.sql
│   └── 04_customer_lookup.sql
├── inspection/
│   └── 00_profile_source_values.sql
└── validation/
    ├── 01_validate_source_keys.sql
    ├── 02_validate_period_alignment.sql
    ├── 03_validate_reconciliation_to_ar.sql
    └── 04_validate_currency_and_customer_mapping.sql
```

## Recommended execution order

1. Run `inspection/00_profile_source_values.sql`. Confirm the actual status labels, period representations and currency values in the current Gold refresh.
2. Run the key checks in `validation/01_validate_source_keys.sql`.
3. Run `validation/02_validate_period_alignment.sql` to identify detail rows that cannot be connected to a customer-period summary.
4. Run `validation/03_validate_reconciliation_to_ar.sql` and resolve or document any differences, missing AR periods or currency-related exclusions.
5. Run `validation/04_validate_currency_and_customer_mapping.sql`.
6. Run the four files in `extracts/` and export each result to its controlled output file.

## Extract contracts

| Extract | Grain | Source | Main purpose |
|---|---|---|---|
| `01_billing_review_summary.sql` | One valid customer + Gold billing period | `gold_finance.billing_reconciliation`, `gold_finance.accounts_receivable`, `gold_finance.billing_invoice_lines`, `gold_customer.dim_customer_c` | Expected vs actual review queue, invoice count, control tie-out and coverage status. |
| `02_billing_detail.sql` | One `billing_line_key` | `gold_finance.billing_invoice_lines`, `gold_customer.dim_customer_c` | Charge breakdown and review evidence. Includes invalid/unmapped customer IDs so the unassigned exception area can filter from this same dataset. |
| `03_receivables.sql` | One `invoice_id` | `gold_finance.accounts_receivable`, `gold_customer.dim_customer_c` | Invoice, due date, terms, payment linkage, balance and Gold aging. |
| `04_customer_lookup.sql` | One valid canonical `client_id` | `gold_customer.dim_customer_c` | Customer selector and canonical name lookup. |

## Important implementation notes

- The reconciliation model does not expose `currency_code`. The summary obtains currency context from AR. If a customer-period contains multiple currencies or missing currency values, the extract does not allocate expected/actual values by currency and suppresses a conclusive variance. Inspect the currency control output.
- The expected amount is `SUM(invoice_ready_expected_charge_amount)`. SQL `SUM` preserves a null result when every contributing component is null. The extract also exposes the number of populated and null service-level components so a partial sum is not mistaken for complete coverage.
- `actual_invoiced_amount` is summed from reconciliation, while `ar_invoice_amount_control` is independently summed from AR only when the customer-period has one known currency and complete invoice amounts. `actual_invoice_count` comes from distinct AR invoice IDs.
- The summary's derived status is a workbench label. Source reconciliation statuses and explanations remain in the output. The keyword-based review-status counters are additional safeguards, not replacements for inspection of the exact source status values.
- The detail extract includes all billing-line groups. In Excel, the unassigned-activity area should filter `customer_mapping_status <> 'MAPPED'` and/or `billing_period_mapping_status = 'PERIOD_KEY_MISSING'`. Do not drop these rows from the source extract.
- `detail_lines_with_invoice_ready_amount` counts populated `invoice_ready_amount` values. It is deliberately not named `ready_billing_lines`, because a populated amount alone should not override Gold's line and review statuses.
- The receivables query does not join payment application records. Gold already provides invoice-level linked payment amounts, counts and dates, avoiding invoice duplication. Its customer-period key is derived only from the supplied AR `billing_period`; invoice date is not used to invent a missing period.
- The queries use Databricks SQL / Spark SQL functions (`REGEXP_EXTRACT`, `TO_JSON`, `ARRAY_JOIN`, `COLLECT_SET`, `SORT_ARRAY`, `RLIKE`).
- There is no refresh-manifest query in this package. The batch ID, generated timestamp, row counts, source object names and validation status belong to the downstream export/refresh process, and a successful manifest should only be written after all required exports and checks pass.

## Current stage boundary

This package provides the SQL query definitions and validation checks. It does not yet implement export automation, file naming, Power Query connections or the Excel workbook. Execute and validate these SQL files against Databricks before treating their result sets as approved workbook inputs.
