#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/powerbi/data"

DB_NAME="${DB_NAME:-olist_revenue_intelligence}"
PSQL_BIN="${PSQL_BIN:-/Applications/Postgres.app/Contents/Versions/latest/bin/psql}"

mkdir -p "$OUTPUT_DIR"

export_query() {
    local filename="$1"
    local query="$2"

    "$PSQL_BIN" \
        -X \
        -h localhost \
        -p 5432 \
        -d "$DB_NAME" \
        -v ON_ERROR_STOP=1 \
        -c "\copy ($query) TO '$OUTPUT_DIR/$filename' WITH (FORMAT csv, HEADER true)"

    echo "Exported $filename"
}

export_query \
    "kpi_summary.csv" \
    "SELECT
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,
        ROUND(
            SUM(item_revenue) FILTER (
                WHERE order_status = 'delivered'
            ),
            2
        ) AS realized_revenue,
        ROUND(
            AVG(item_revenue) FILTER (
                WHERE order_status = 'delivered'
            ),
            2
        ) AS average_order_value,
        ROUND(
            SUM(freight_value) FILTER (
                WHERE order_status = 'delivered'
            ),
            2
        ) AS freight_value,
        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE order_status = 'delivered'
                  AND is_late_delivery
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE order_status = 'delivered'
                      AND is_late_delivery IS NOT NULL
                ),
                0
            ),
            2
        ) AS late_delivery_rate_pct,
        ROUND(
            AVG(avg_review_score) FILTER (
                WHERE order_status = 'delivered'
            ),
            2
        ) AS average_review_score
    FROM olist.vw_order_fact"

export_query \
    "monthly_revenue.csv" \
    "SELECT
        order_month,
        COUNT(*) AS delivered_orders,
        ROUND(SUM(item_revenue), 2) AS realized_revenue,
        ROUND(AVG(item_revenue), 2) AS average_order_value
    FROM olist.vw_order_fact
    WHERE order_status = 'delivered'
      AND item_revenue IS NOT NULL
    GROUP BY order_month
    ORDER BY order_month"

export_query \
    "category_performance.csv" \
    "SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        COUNT(DISTINCT oi.order_id) AS delivered_orders,
        ROUND(SUM(oi.price), 2) AS realized_revenue
    FROM olist.order_items oi
    JOIN olist.orders o
        ON o.order_id = oi.order_id
    JOIN olist.products p
        ON p.product_id = oi.product_id
    LEFT JOIN olist.category_translation t
        ON t.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
    ORDER BY realized_revenue DESC"

export_query \
    "state_performance.csv" \
    "SELECT
        customer_state,
        COUNT(*) AS delivered_orders,
        ROUND(SUM(item_revenue), 2) AS realized_revenue,
        ROUND(AVG(item_revenue), 2) AS average_order_value,
        ROUND(
            100.0
            * COUNT(*) FILTER (WHERE is_late_delivery)
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE is_late_delivery IS NOT NULL
                ),
                0
            ),
            2
        ) AS late_delivery_rate_pct,
        ROUND(AVG(avg_review_score), 2)
            AS average_review_score
    FROM olist.vw_order_fact
    WHERE order_status = 'delivered'
      AND item_revenue IS NOT NULL
    GROUP BY customer_state
    ORDER BY realized_revenue DESC"

export_query \
    "delivery_review.csv" \
    "SELECT
        CASE
            WHEN is_late_delivery
                THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_result,
        COUNT(*) AS reviewed_delivered_orders,
        ROUND(AVG(avg_review_score), 2)
            AS average_review_score,
        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE avg_review_score <= 2
            )
            / COUNT(*),
            2
        ) AS low_review_rate_pct
    FROM olist.vw_order_fact
    WHERE order_status = 'delivered'
      AND is_late_delivery IS NOT NULL
      AND avg_review_score IS NOT NULL
    GROUP BY delivery_result
    ORDER BY delivery_result"

export_query \
    "customer_segments.csv" \
    "WITH customer_summary AS (
        SELECT
            customer_unique_id,
            COUNT(*) AS delivered_orders,
            SUM(item_revenue) AS realized_revenue
        FROM olist.vw_order_fact
        WHERE order_status = 'delivered'
          AND item_revenue IS NOT NULL
        GROUP BY customer_unique_id
    )
    SELECT
        CASE
            WHEN delivered_orders >= 2
                THEN 'Repeat customer'
            ELSE 'One-time customer'
        END AS customer_type,
        COUNT(*) AS customers,
        SUM(delivered_orders) AS delivered_orders,
        ROUND(SUM(realized_revenue), 2)
            AS realized_revenue,
        ROUND(
            100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
            2
        ) AS customer_share_pct,
        ROUND(
            SUM(realized_revenue) / COUNT(*),
            2
        ) AS revenue_per_customer
    FROM customer_summary
    GROUP BY customer_type
    ORDER BY customers DESC"

echo "All Power BI reporting extracts are ready in $OUTPUT_DIR"
