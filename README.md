# SwiftRoute Billing Assurance

## Project Overview

The SwiftRoute Billing Assurance project develops a reusable Finance
workbench to support billing preparation, invoice validation,
reconciliation and accounts receivable follow-up.

It consumes curated datasets from the existing SwiftRoute data
warehouse. It does not recreate or manage the original data
infrastructure.

## Data Source Architecture

Curated Gold datasets are extracted from Databricks into controlled
files and consumed by the Excel workbench.

The project follows an export-based data consumption approach.

## Main Deliverable

Billing Assurance Workbench (Excel)

- Billing Review
- Receivables & Collections

## Project Documentation

See the `docs/` directory for the business requirements, billing
rulebook, data dictionary and workbook design.

## Project Separation

This repository is independent of the original SwiftRoute data
infrastructure repository. Changes to the upstream warehouse can be
incorporated through updated data extracts.
