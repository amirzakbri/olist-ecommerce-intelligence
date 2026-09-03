# Metric Definitions

## Measurement scope

This project analyzes the Olist Brazilian e-commerce dataset. Unless explicitly stated otherwise, revenue and operational KPIs include only orders where `order_status = 'delivered'`.

Dates use the original timestamps provided by Olist, stored without a timezone conversion. Monetary values are Brazilian reais (R$). Revenue is attributed to the purchase month of orders whose final status is delivered, not to the month of delivery.

## Primary KPIs

| Metric | Definition | Calculation | Grain |
|---|---|---|---|
| Delivered Orders | Successfully delivered marketplace orders | `COUNT(DISTINCT order_id)` where status is delivered | Order |
| Realized Revenue | Merchandise revenue from delivered products, excluding freight | `SUM(order_items.price)` for delivered orders | Order item |
| Average Order Value | Average merchandise revenue per delivered order | Realized Revenue ÷ Delivered Orders | Order |
| Gross Order Value | Merchandise plus freight for delivered orders | `SUM(price + freight_value)` | Order item |

## Customer and product drivers

| Metric | Definition | Calculation |
|---|---|---|
| Customer Lifetime Revenue | Delivered merchandise revenue associated with one shopper | `SUM(price)` grouped by `customer_unique_id` |
| Repeat Customer Rate | Share of purchasing customers with at least two delivered orders | Customers with 2+ delivered orders ÷ customers with 1+ delivered orders |
| Revenue per Customer | Observed delivered merchandise value per purchasing shopper in a segment | Segment merchandise revenue ÷ distinct purchasing shoppers in that segment |
| Category Revenue | Delivered merchandise revenue attributed to a product category | `SUM(price)` grouped by translated product category |
| State Revenue | Delivered merchandise revenue associated with the customer’s state | `SUM(price)` grouped by `customer_state` |

`customer_unique_id` must be used for customer-level analysis because `customer_id` identifies the customer record attached to an individual order.

"Lifetime" and "repeat" refer only to the available observation window. The repeat-customer rate is not a cohort retention rate. Revenue-per-customer comparisons between one-time and repeat shoppers are descriptive: repeat shoppers are defined by having more purchases, so their higher observed revenue is not causal lift from a retention program.

## Operational quality guardrails

| Metric | Definition | Calculation |
|---|---|---|
| Late Delivery Rate | Share of delivered orders whose customer-delivery timestamp exceeds the estimated-delivery timestamp | Late delivered orders ÷ delivered orders with both timestamps available |
| Average Review Score | Mean of order-level mean review scores for reviewed delivered orders | Average review records within each order, then average those order-level scores |
| Low Review Rate | Share of reviewed delivered orders whose order-level mean review score is at most 2 | Orders with mean score ≤2 ÷ reviewed delivered orders in the selected population |

`vw_review_summary` rounds each order's mean score to two decimals before the export layer aggregates it. Multiple reviews can therefore produce a fractional order-level score. The low-review rule is a threshold on that mean, not a count of individual review rows rated 1 or 2.

For delivery-timing comparisons, both review metrics exclude orders without known delivery timing. The groups contain 7,661 late and 88,163 on-time/early reviewed delivered orders. The overall review-score KPI uses all reviewed delivered orders, including those without delivery timing. The overall late-rate denominator is 96,470 delivered orders with known timing, of which 7,826 are late.

The implemented delay rule compares full timestamps, not just calendar dates. An arrival later on an estimated date stored at midnight counts as late under this rule.

Olist does not provide a dedicated returns or refunds field. Late delivery and low review scores are therefore treated as operational-quality indicators, not as actual return rates.

## Payment metrics

| Metric | Definition | Calculation |
|---|---|---|
| Payment Value | Total value recorded in the payments table | `SUM(payment_value)` |
| Payment Value Share | Percentage of payment value associated with each payment method | Method payment value ÷ total payment value |
| Average Installments | Mean number of installments by payment method | `AVG(payment_installments)` |

Payment rows must be aggregated to one row per order before joining them to order items.

## Data-grain guardrail

`order_items`, `payments`, and `reviews` can each contain multiple rows for one order. Joining these tables directly can multiply records and inflate revenue.

The safe approach is:

1. Aggregate order items to one row per order.
2. Aggregate payments to one row per order.
3. Aggregate reviews to one row per order.
4. Join the resulting summaries to the orders table.

## Power BI aggregation guardrails

The six reporting CSVs are independent aggregate tables, not transactional fact/dimension tables. No cross-table filtering should be implied by their side-by-side visuals.

- Revenue is additive across the complete monthly, state, category, and customer-segment extracts separately; do not add totals from different extracts together.
- An order can contain multiple categories, so category order counts are not additive across categories.
- Recompute combined averages from their numerators and denominators. Do not sum averages, average rates, or reconstruct exact counts from rounded percentages.
- Use `kpi_summary` for global review and delay KPIs, since grouped CSVs do not retain all eligible denominators.
- Divide exported `_pct` values by 100 before percentage formatting in Power BI.

## Interpretation limitations

- The dataset does not contain a verified returns field.
- Item revenue excludes freight unless explicitly labeled as gross order value.
- Review metrics only represent orders with submitted reviews.
- The dataset is historical and anonymized, so it should not be presented as current Olist performance.
- Revenue analysis describes marketplace transaction value, not accounting profit or net revenue.
