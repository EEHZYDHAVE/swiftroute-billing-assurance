-- SwiftRoute Billing Assurance Workbench
-- Gold data reconnaissance: inventory, schema and small row samples
-- READ-ONLY inspection. No tables or views are created or modified.
-- Run in Databricks SQL using the catalog that contains the SwiftRoute Gold schemas.

-- ============================================================================
-- 1. Confirm the active Databricks context
-- ============================================================================
SELECT
    current_catalog() AS active_catalog,
    current_schema()  AS active_schema,
    current_timestamp() AS inspection_timestamp;

-- List schemas in the active catalog. Confirm the Gold schemas are present.
SHOW SCHEMAS;

-- ============================================================================
-- 2. Inventory the expected Gold schemas
-- If a schema is not found, use SHOW SCHEMAS output and correct the name.
-- ============================================================================
SHOW TABLES IN gold_finance;
SHOW TABLES IN gold_last_mile;
SHOW TABLES IN gold_fulfillment;
SHOW TABLES IN gold_customer;

-- ============================================================================
-- 3. Inspect table definitions
-- Run only after confirming the table exists in the inventory above.
-- If any table name differs, replace it with the actual name returned by SHOW.
-- ============================================================================

-- Finance
DESCRIBE TABLE gold_finance.billing_invoice_lines;
DESCRIBE TABLE gold_finance.billing_reconciliation;
DESCRIBE TABLE gold_finance.financial_transaction_lines;
DESCRIBE TABLE gold_finance.accounts_receivable;
DESCRIBE TABLE gold_finance.financial_reporting_monthly;

-- Last-mile delivery
DESCRIBE TABLE gold_last_mile.fact_delivery;
DESCRIBE TABLE gold_last_mile.dim_contract_l;
DESCRIBE TABLE gold_last_mile.dim_customer_l;
DESCRIBE TABLE gold_last_mile.dim_service;
DESCRIBE TABLE gold_last_mile.dim_zone;
DESCRIBE TABLE gold_last_mile.dim_city;
DESCRIBE TABLE gold_last_mile.dim_driver;
DESCRIBE TABLE gold_last_mile.dim_date_l;

-- Fulfillment
DESCRIBE TABLE gold_fulfillment.fact_fulfillment_transaction;
DESCRIBE TABLE gold_fulfillment.dim_contract;
DESCRIBE TABLE gold_fulfillment.dim_customer;
DESCRIBE TABLE gold_fulfillment.dim_date;
DESCRIBE TABLE gold_fulfillment.dim_product;
DESCRIBE TABLE gold_fulfillment.dim_warehouse;

-- Customer economics
DESCRIBE TABLE gold_customer.fact_customer_economics;
DESCRIBE TABLE gold_customer.dim_customer_c;

-- ============================================================================
-- 4. Inspect a small sample from the core billing tables
-- LIMIT 20 is for column/value inspection only. Do not use these samples as
-- complete extracts or as evidence of full-table coverage.
-- ============================================================================

SELECT * FROM gold_finance.billing_invoice_lines LIMIT 20;
SELECT * FROM gold_finance.billing_reconciliation LIMIT 20;
SELECT * FROM gold_finance.accounts_receivable LIMIT 20;

SELECT * FROM gold_last_mile.fact_delivery LIMIT 20;
SELECT * FROM gold_last_mile.dim_contract_l LIMIT 20;
SELECT * FROM gold_last_mile.dim_customer_l LIMIT 20;
SELECT * FROM gold_last_mile.dim_service LIMIT 20;
SELECT * FROM gold_last_mile.dim_zone LIMIT 20;

SELECT * FROM gold_fulfillment.fact_fulfillment_transaction LIMIT 20;
SELECT * FROM gold_fulfillment.dim_contract LIMIT 20;
SELECT * FROM gold_fulfillment.dim_customer LIMIT 20;

SELECT * FROM gold_customer.fact_customer_economics LIMIT 20;
SELECT * FROM gold_customer.dim_customer_c LIMIT 20;

-- ============================================================================
-- 5. Optional: inspect detailed metadata for a table
-- Use if DESCRIBE TABLE does not provide enough context.
-- ============================================================================
DESCRIBE TABLE EXTENDED gold_last_mile.fact_delivery;
DESCRIBE TABLE EXTENDED gold_finance.billing_invoice_lines;
