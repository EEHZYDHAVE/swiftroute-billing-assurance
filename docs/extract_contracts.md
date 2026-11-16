# Downstream extract contracts

## 1. Billing Review summary

**Grain:** valid `client_id` + Gold `billing_period` (one row per customer-period). The query groups the service-level Finance reconciliation rows before joining independently aggregated AR and billing detail controls. This avoids multiplying expected charges or invoice totals.

**Primary measures:**
- `expected_amount`: sum of `invoice_ready_expected_charge_amount`, preserving all-null groups as null.
- `actual_invoiced_amount`: sum of `actual_invoiced_amount` from reconciliation.
- `actual_invoice_count`: distinct AR `invoice_id` count.
- `ar_invoice_amount_control`: AR invoice amount, populated only where the period has one known currency and no null invoice amounts.
- `assessable_variance_amount`: populated only when all service-level expected components are present, the source exception counters and review-status signals are clear, the AR tie-out passes, and currency is unambiguous.

**Important dimensions and controls:** `billing_period_key`, `currency_code`, currency profile, service types, source cadence, original reconciliation statuses and explanations, expected component counts, review/pricing/chargeability counts, detail-line counts and the derived `billing_review_status`.

## 2. Billing-line detail

**Grain:** one `billing_line_key`. Both ready and non-ready records remain. All pricing/quantity values are copied from Gold without recomputation. Source activity/order arrays are exported as JSON strings to keep them representable in CSV.

**Exception handling:** valid IDs not found in the canonical customer dimension and null/blank/`N/A`/`NULL` identifiers receive explicit mapping statuses. A missing period key is also labelled. Use these flags for the separate unassigned/unmatched activity area; do not filter such rows out of the export.

## 3. Receivables

**Grain:** one `invoice_id`. The query projects invoice and linked-payment fields directly from AR and adds canonical customer context with a left join. It provides normalized `client_id` and `customer_period_key` fields while retaining `source_client_id` for traceability. It does not join payment application rows, infer a billing period from invoice date or recalculate aging.

## 4. Customer lookup

**Grain:** one valid canonical `client_id`. The query does not deduplicate records silently; the validation query should confirm dimension uniqueness before refresh.

## 5. Currency and comparison limitations

`billing_reconciliation` has no currency column. The extract therefore cannot safely assign expected charges to individual currency codes if AR shows more than one currency for the same customer-period. In that case the currency code and AR control amount are withheld, `currency_profile_status` flags the condition, and a conclusive variance is not returned. Revisit this design only if Gold adds a reliable currency dimension to the reconciliation output or an authoritative downstream mapping is supplied.
