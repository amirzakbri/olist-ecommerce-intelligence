# Power BI Reporting Layer

This directory contains the validated reporting extracts used to build the
completed three-page report in Power BI Web (Power BI Service). The [saved screenshots](../README.md#power-bi-report) provide a viewable portfolio artifact without requiring workspace access.

## Generate the extracts

From the repository root, run:

```bash
chmod +x scripts/export_powerbi_data.sh
./scripts/export_powerbi_data.sh
```

The script queries the local PostgreSQL database and refreshes the files in
`powerbi/data/`.

It defaults to localhost:5432, database `olist_revenue_intelligence`, and the Postgres.app `psql` binary. Set `DB_NAME` and `PSQL_BIN` when needed. A successful export replaces the local CSV snapshots; it does not update the Power BI Service model automatically.

## Reporting extracts

| File | Grain | Intended use |
| --- | --- | --- |
| `kpi_summary.csv` | One project-level summary row | Executive KPI cards |
| `monthly_revenue.csv` | One row per purchase month | Revenue and order trends |
| `category_performance.csv` | One row per translated product category | Category ranking |
| `state_performance.csv` | One row per customer state | Geographic performance |
| `delivery_review.csv` | One row per delivery-timing group | Delivery and review comparison |
| `customer_segments.csv` | One row per customer segment | One-time versus repeat customers |

The extracts are already aggregated to the grain required by their visuals.
They should not be joined together on row-level keys. Dashboard totals must
reconcile to the SQL results and metric definitions documented elsewhere in
the repository.

## Completed Power BI report

### Page 1: Executive Overview

- Delivered orders
- Realized revenue
- Average order value
- Gross order value (merchandise revenue plus freight)
- Late-delivery rate
- Average review score
- Monthly revenue and delivered-order trend on separately labeled axes

### Page 2: Revenue Drivers

- Top-ten product-category revenue ranking
- Top-ten customer-state revenue ranking
- Supporting order counts and state average order value in report tooltips

### Page 3: Customer and Delivery Quality

- One-time versus repeat customer mix and revenue per customer
- Delivery timing versus review score
- Low-review rate comparison
- State late-delivery performance

The saved state-ranking screenshot shows the visible portion of the visual. It does not prove the complete Top N configuration or minimum-order filter; inspect those settings in the live report when reproducing it. SQL Q10 independently applies a minimum of 100 delivered orders with valid delivery timestamps.

## Model, data types, and measure rules

- Keep the six tables disconnected. They summarize different dimensions and do not contain the keys for a shared interactive star schema. A date, customer-type, or state filter on one table does not automatically affect the other tables.
- Import `order_month` as Date, count fields as whole numbers, amounts and scores as decimal numbers, and category/state/group labels as text. CSV files do not retain Power BI data types or formatting.
- Format monetary measures in Brazilian reais (BRL, `R$`), order/customer counts as `#,##0`, scores as `0.00`, and rates as percentages.
- CSV columns ending in `_pct` contain percentage points, such as `8.11`. Divide them by 100 before applying percentage formatting; otherwise Power BI would show `811%`.
- Sum revenue and counts only at an additive grain. Compute combined average order value from revenue divided by orders, and revenue per customer from revenue divided by customers.
- Category delivered-order counts overlap across categories and must not be summed into marketplace delivered orders.
- Do not average state late rates or review averages into an overall KPI: the CSVs do not include all necessary eligible-order and reviewed-order denominators. Use `kpi_summary` for overall cards.
- Delivery-group comparison measures should return the selected group's score/rate, not an unweighted average of the two rows. Use the [reference DAX measures](MEASURES.md).
- `delivery_review` includes only delivered orders with known delivery timing and an observed order-level mean review score: 7,661 late and 88,163 on-time/early reviewed orders. This is a different population from all delivered orders.
- The monthly export contains 23 observed purchase months from September 2016 through August 2018; it omits November 2016, which has no delivered orders. The SQL growth analysis, not this CSV, supplies a complete calendar.

## Snapshot checks

| Check | Expected value |
| --- | ---: |
| Delivered orders | 96,478 |
| Delivered merchandise revenue | R$13,221,498.11 |
| Freight | R$2,198,275.64 |
| Gross order value | R$15,419,773.75 |
| Average order value | R$137.04 |
| Late delivery rate | 8.11% |
| Average review score | 4.16 |
| Purchasing customers | 93,358 |
| Repeat customers | 2,801 (3.00%) |
| Repeat / one-time revenue per customer | R$260.05 / R$137.96 |
| Late / on-time average review score | 2.57 / 4.29 |
| Late / on-time low-review rate | 53.99% / 9.19% |

The revenue sums from monthly, category, state, and customer-segment extracts each reconcile to `kpi_summary`. State, monthly, and customer-segment order counts also reconcile. The [validation report](../documentation/VALIDATION_REPORT.md) distinguishes raw-source checks from previously recorded database validation.

## Source and refresh notes

- Source database: PostgreSQL database `olist_revenue_intelligence`
- Database schema: `olist`
- Report destination: Power BI Web
- Data scope: historical Olist marketplace transactions
- Refresh method: rerun `scripts/export_powerbi_data.sh`, then refresh or replace
  the corresponding Power BI Web source files

This repository does not contain a PBIX/PBIP export or a public Power BI embed link. The live report requires appropriate workspace access. The screenshots and documented measures support review and manual reconstruction, but are not a one-click backup of the report's layout, relationships, formatting, or service settings.

The screenshots' service update date describes model refresh timing, not the age of the underlying historical transactions. Review/customer comparisons are observational, not evidence of a causal effect or a measured retention intervention.
