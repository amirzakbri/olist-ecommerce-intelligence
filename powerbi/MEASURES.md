# Reference DAX Measures

These formulas document a reproducible implementation for the six reporting extracts. They are reference definitions, not an export of the live semantic model. A measure's home table does not determine which source table it calculates from. Reuse an existing equivalent measure rather than creating a duplicate with the same name.

Create each definition below as a separate measure. Keep the source tables disconnected as described in the [reporting guide](README.md).

## Executive cards

```DAX
Delivered Orders = SUM ( kpi_summary[delivered_orders] )

Realized Revenue = SUM ( kpi_summary[realized_revenue] )

Freight Value = SUM ( kpi_summary[freight_value] )

Gross Order Value = [Realized Revenue] + [Freight Value]

Average Order Value = DIVIDE ( [Realized Revenue], [Delivered Orders] )

Late Delivery Rate =
DIVIDE ( SELECTEDVALUE ( kpi_summary[late_delivery_rate_pct] ), 100 )

Average Review Score = SELECTEDVALUE ( kpi_summary[average_review_score] )
```

## Monthly trend

```DAX
Revenue by Month = SUM ( monthly_revenue[realized_revenue] )

Orders by Month = SUM ( monthly_revenue[delivered_orders] )

Monthly Average Order Value = DIVIDE ( [Revenue by Month], [Orders by Month] )
```

Use `monthly_revenue[order_month]` as the date axis and sort chronologically. The export omits months without delivered orders; do not compute consecutive-month growth from row adjacency alone.

## Category and state drivers

```DAX
Category Revenue = SUM ( category_performance[realized_revenue] )

Category Delivered Orders = SUM ( category_performance[delivered_orders] )

State Revenue = SUM ( state_performance[realized_revenue] )

State Delivered Orders = SUM ( state_performance[delivered_orders] )

State Average Order Value = DIVIDE ( [State Revenue], [State Delivered Orders] )

State Late Delivery Rate =
DIVIDE ( SELECTEDVALUE ( state_performance[late_delivery_rate_pct] ), 100 )

State Average Review Score =
SELECTEDVALUE ( state_performance[average_review_score] )
```

Category order counts are valid within each category but not as a marketplace total. State rate/score measures intentionally return blank without a single-state context rather than calculate an unweighted overall average. Use executive measures for global rate/score cards.

## Customer segments

```DAX
Customer Count = SUM ( customer_segments[customers] )

Customer Delivered Orders = SUM ( customer_segments[delivered_orders] )

Customer Revenue = SUM ( customer_segments[realized_revenue] )

Customer Revenue per Customer = DIVIDE ( [Customer Revenue], [Customer Count] )

Repeat Customer Rate =
DIVIDE (
    CALCULATE (
        [Customer Count],
        customer_segments[customer_type] = "Repeat customer"
    ),
    CALCULATE (
        [Customer Count],
        REMOVEFILTERS ( customer_segments[customer_type] )
    )
)
```

The donut uses `customer_type` as its legend and `Customer Count` as its value. The repeat-customer rate is a whole-snapshot share, not a cohort retention measure.

## Delivery and review comparisons

```DAX
Reviewed Delivered Orders = SUM ( delivery_review[reviewed_delivered_orders] )

Delivery Review Score = SELECTEDVALUE ( delivery_review[average_review_score] )

Low Review Rate =
DIVIDE ( SELECTEDVALUE ( delivery_review[low_review_rate_pct] ), 100 )
```

Use `delivery_result` as the category axis and `Reviewed Delivered Orders` in the tooltip. The score/rate measures intentionally require a single group. Do not reconstruct an exact global average from rounded group means or a global low-review count from rounded rates.

## Display formats

| Measures | Format |
| --- | --- |
| Order and customer counts | `#,##0` |
| Currency amounts and per-order/per-customer value | Brazilian real, two decimals (`R$`) |
| Review scores | `0.00` |
| Rate measures after division by 100 | `0.00%` |

Use model/visual formatting rather than wrapping numeric measures in `FORMAT`, which would turn their results into text. Abbreviating large values as millions is appropriate for cards if exact values remain available in the source or tooltips.
