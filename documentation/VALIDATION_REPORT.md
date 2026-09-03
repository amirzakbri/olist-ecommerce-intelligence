# Data Validation and Reconciliation Report

## Overall assessment

**Status: Ready for analysis with documented caveats**

The PostgreSQL database reproduces the supplied Olist CSV records, enforces the expected entity relationships, and supports order-level revenue analysis without row multiplication.

The validation SQL is available in `sql/03_validation.sql`.

## Source reconciliation

All nine database tables match their corresponding source CSV row counts.

| Table | Expected rows | Loaded rows | Result |
|---|---:|---:|---|
| category_translation | 71 | 71 | Pass |
| customers | 99,441 | 99,441 | Pass |
| geolocation | 1,000,163 | 1,000,163 | Pass |
| order_items | 112,650 | 112,650 | Pass |
| orders | 99,441 | 99,441 | Pass |
| payments | 103,886 | 103,886 | Pass |
| products | 32,951 | 32,951 | Pass |
| reviews | 99,224 | 99,224 | Pass |
| sellers | 3,095 | 3,095 | Pass |

## Key and relationship integrity

All tested primary and composite keys contain zero duplicates.

Validated keys include:

- `customers.customer_id`
- `orders.order_id`
- `products.product_id`
- `sellers.seller_id`
- `order_items (order_id, order_item_id)`
- `payments (order_id, payment_sequential)`
- `reviews (review_id, order_id)`

All tested foreign-key relationships contain zero orphan records:

- orders to customers
- order items to orders
- order items to products
- order items to sellers
- payments to orders
- reviews to orders

## Join-grain validation

The order-level analytical model contains:

- 99,441 rows
- 99,441 distinct orders
- zero multiplied order rows
- R$13,221,498.11 in delivered merchandise revenue

This confirms that order items are aggregated before they are joined to other one-to-many tables.

## Payment reconciliation

Across all order statuses:

| Measure | Value |
|---|---:|
| Item value plus freight | R$15,843,553.24 |
| Payment value | R$16,008,872.12 |
| Net variance | R$165,318.88 |
| Net variance rate | 1.04% |
| Orders reconciling within R$0.01 | 98,365 |
| Non-reconciled orders | 1,076 |

The majority of the variance is structural rather than an arithmetic error:

- 775 orders contain payments but no order-item rows.
- These orders account for R$162,591.95, approximately 98.4% of the total net variance.
- Most payment-without-item cases have `unavailable` or `canceled` status.
- 303 orders have item and payment rows with different amounts, producing a net variance of R$2,871.06.
- One delivered order contains R$143.46 in item and freight value but no payment record.
- Minor differences within R$0.01 are treated as reconciled rounding differences.

The 98,365 tolerance-based matches and the structural classification answer different questions: three payment-without-item orders have variances within R$0.01 and are counted as matches by V5, but remain payment-without-item cases in V9. Thus V9 has 98,362 orders with both sides present and within tolerance. Its label `Exact reconciliation` means within R$0.01, not necessarily zero difference. The categories contribute R$162,591.95 + R$2,871.06 - R$143.46 - R$0.67 = R$165,318.88 in net variance.

Payment totals should therefore not be substituted for delivered merchandise revenue. Revenue reporting uses delivered order-item prices, while payment totals are analyzed separately.

## Completeness findings

| Finding | Affected rows | Treatment |
|---|---:|---|
| Products missing category | 610 | Report as `Unknown` |
| Orders missing approval timestamp | 160 | Preserve as source null |
| Orders missing delivery timestamp | 2,965 | Expected across incomplete statuses |
| Delivered orders missing delivery timestamp | 8 | Exclude from delay-rate denominator |
| Reviews missing title | 87,658 | Treat as optional text |
| Reviews missing message | 58,256 | Treat as optional text |
| Invalid review scores | 0 | Pass |
| Negative product prices | 0 | Pass |
| Negative freight values | 0 | Pass |

Review titles and messages are optional fields. Review-quality metrics use `review_score` and do not require written comments.

## Category translation coverage

Two populated Portuguese categories do not have English translation records:

| Category | Affected products |
|---|---:|
| portateis_cozinha_e_preparadores_de_alimentos | 10 |
| pc_gamer | 3 |

Analysis retains the original Portuguese category when an English translation is unavailable. These products are not dropped.

## Date coverage

| Field | Earliest value | Latest value |
|---|---|---|
| Purchase timestamp | 2016-09-04 | 2018-10-17 |
| Customer delivery timestamp | 2016-10-11 | 2018-10-17 |

Delivered-order revenue trends end in August 2018 because later purchase records do not satisfy the delivered-order filter. The earliest months contain very low volumes and should not be used for headline month-over-month comparisons.

## Analytical limitations

- The dataset contains no verified returns or refunds field.
- Delivery delay and review scores are operational-quality indicators, not return rates.
- The relationship between late delivery and low review scores is observational and must not be presented as causal.
- Revenue represents delivered merchandise value before freight, not accounting revenue or profit.
- Review analysis represents orders with submitted reviews.
- The dataset is historical and should not be described as current Olist performance.

## Final conclusion

The database is suitable for the project’s revenue, customer, product, geographic, payment, delivery, and review analysis. No critical key, relationship, loading, or join-grain defects were found. The identified source limitations are documented and handled explicitly in the analysis.

## Final local reporting-package review

**Assessment: Ready to share with the documented historical-data and snapshot limitations.**

The checks below were rerun against the local source CSVs and saved reporting extracts. They do not represent a fresh PostgreSQL restore, a live Power BI model audit, or verification of every tooltip and filter setting. The earlier database results above remain the recorded SQL validation results.

- Counted all nine raw CSV files with a CSV parser; every count matched the table above, including multiline review text.
- Independently recomputed delivered revenue, freight, gross order value, order count, average order value, delay rate, and overall review score from raw records. All matched `kpi_summary.csv`.
- Recomputed every exported monthly revenue and order count from raw records.
- Recomputed both customer segments and their revenue per customer: 90,557 one-time shoppers, 2,801 repeat shoppers, and 93,358 shoppers in total.
- Recomputed delivery/review group sizes, average scores, and low-review rates using the order-level review grain and rounding in the reporting views.
- Reconciled revenue totals in the monthly, category, state, and customer-segment extracts independently to R$13,221,498.11. Reconciled monthly, state, and customer-segment order counts to 96,478; category counts are intentionally non-additive.
- Independently reproduced the payment reconciliation totals and the three structural cases described above using exact decimal arithmetic.
- Inspected all three saved PNGs. They contain readable report pages without overlapping visual containers. Visible headline values and rankings agree with the extracts at their displayed precision.
- Checked both shell scripts with `bash -n`. This validates shell syntax, not a new database load or service refresh.
- Confirmed that raw CSV files, `.env`, and `.DS_Store` are ignored by Git and that raw CSVs are not tracked.

### Presentation and reproduction caveats

- The monthly chart uses two axes: BRL revenue on the left and order counts on the right. Their heights are not directly comparable units.
- November 2016 is absent from the monthly CSV and categorical chart. Use SQL Q5's calendar series when calculating consecutive-month growth.
- The screenshots round large values (for example, R$13.22M and 93.36K); the exact values are available in the CSVs and documentation.
- The customer donut does not print the two percentage shares, and the customer/state comparison charts do not print every exact value. These are minor presentation limitations, not discrepancies; the source rows remain available for inspection.
- Static screenshots cannot establish live tooltip behavior, all visual filters, or hidden/scrollable ranking rows. The source state extract contains all 27 states; SQL Q10 uses a minimum of 100 delivered orders with known timing. A different live-report filter should be disclosed separately.
- No PBIX/PBIP backup or public report URL is included. The saved PNGs, source extracts, and reference measures support portfolio review and manual reconstruction.

Evidence: [screenshots](../README.md#power-bi-report), [reporting extracts](../powerbi/data/), [export SQL](../scripts/export_powerbi_data.sh), [analysis SQL](../sql/02_analysis.sql), and [validation SQL](../sql/03_validation.sql).
