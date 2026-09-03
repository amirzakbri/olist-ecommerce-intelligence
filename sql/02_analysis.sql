-- =============================================================
-- Olist E-Commerce Revenue and Order Intelligence
-- Analysis Queries
-- =============================================================

\set ON_ERROR_STOP on

SET search_path TO olist, public;

-- =============================================================
-- Q1. Order status distribution
-- Business question:
-- How many orders reached each stage of the order lifecycle?
-- =============================================================

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_orders_pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- =============================================================
-- Q2. Executive KPI snapshot
-- Revenue excludes freight and includes delivered orders only.
-- Order items are aggregated before joining to orders.
-- =============================================================

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS gross_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(COALESCE(v.item_revenue, 0)), 2)
        AS realized_revenue,
    ROUND(
        SUM(COALESCE(v.item_revenue, 0)) / NULLIF(COUNT(*), 0),
        2
    ) AS average_order_value,
    ROUND(SUM(COALESCE(v.freight_value, 0)), 2)
        AS freight_value,
    ROUND(SUM(COALESCE(v.gross_order_value, 0)), 2)
        AS gross_order_value
FROM orders o
LEFT JOIN order_values v
    ON v.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- =============================================================
-- Q3. Monthly delivered-order revenue trend
-- The result is maintained at one row per month.
-- =============================================================

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
)

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS order_month,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(COALESCE(v.item_revenue, 0)), 2)
        AS realized_revenue,
    ROUND(
        SUM(COALESCE(v.item_revenue, 0)) / NULLIF(COUNT(*), 0),
        2
    ) AS average_order_value
FROM orders o
LEFT JOIN order_values v
    ON v.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

-- =============================================================
-- Q4. Top 15 product categories by delivered revenue
-- Category names use the English translation when available.
-- =============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS realized_revenue,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS revenue_per_category_order
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
JOIN products p
    ON p.product_id = oi.product_id
LEFT JOIN category_translation t
    ON t.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
ORDER BY realized_revenue DESC
LIMIT 15;

-- =============================================================
-- Q5. Month-over-month revenue growth and running revenue
-- A calendar series preserves months with zero delivered orders.
-- Growth is undefined when the previous month's revenue is zero.
-- =============================================================


WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
),

monthly AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        COUNT(*) AS delivered_orders,
        SUM(COALESCE(v.item_revenue, 0)) AS realized_revenue
    FROM orders o
    LEFT JOIN order_values v
        ON v.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
),

month_boundaries AS (
    SELECT
        MIN(order_month) AS first_month,
        MAX(order_month) AS last_month
    FROM monthly
),

calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS order_month
    FROM month_boundaries
),

filled_months AS (
    SELECT
        c.order_month,
        COALESCE(m.delivered_orders, 0) AS delivered_orders,
        COALESCE(m.realized_revenue, 0) AS realized_revenue
    FROM calendar c
    LEFT JOIN monthly m
        ON m.order_month = c.order_month
),

windowed AS (
    SELECT
        order_month,
        delivered_orders,
        realized_revenue,
        LAG(realized_revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue,
        SUM(realized_revenue) OVER (
            ORDER BY order_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_revenue
    FROM filled_months
)

SELECT
    order_month,
    delivered_orders,
    ROUND(realized_revenue, 2) AS realized_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    CASE
        WHEN previous_month_revenue > 0
        THEN ROUND(
            100.0
            * (realized_revenue - previous_month_revenue)
            / previous_month_revenue,
            2
        )
    END AS month_over_month_growth_pct,
    ROUND(running_revenue, 2) AS running_revenue
FROM windowed
ORDER BY order_month;

-- =============================================================
-- Q6. Top products with rank and cumulative revenue share
-- ROW_NUMBER provides a deterministic product ranking.
-- =============================================================

WITH product_revenue AS (
    SELECT
        oi.product_id,
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        COUNT(DISTINCT oi.order_id) AS delivered_orders,
        SUM(oi.price) AS realized_revenue
    FROM order_items oi
    JOIN orders o
        ON o.order_id = oi.order_id
    JOIN products p
        ON p.product_id = oi.product_id
    LEFT JOIN category_translation t
        ON t.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        oi.product_id,
        product_category
),

ranked_products AS (
    SELECT
        product_id,
        product_category,
        delivered_orders,
        realized_revenue,
        ROW_NUMBER() OVER (
            ORDER BY realized_revenue DESC, product_id
        ) AS product_rank,
        SUM(realized_revenue) OVER () AS total_revenue,
        SUM(realized_revenue) OVER (
            ORDER BY realized_revenue DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM product_revenue
)

SELECT
    product_rank,
    product_id,
    product_category,
    delivered_orders,
    ROUND(realized_revenue, 2) AS realized_revenue,
    ROUND(
        100.0 * realized_revenue / NULLIF(total_revenue, 0),
        3
    ) AS revenue_share_pct,
    ROUND(
        100.0 * cumulative_revenue / NULLIF(total_revenue, 0),
        3
    ) AS cumulative_revenue_share_pct
FROM ranked_products
WHERE product_rank <= 20
ORDER BY product_rank;

-- =============================================================
-- Q7. Top customers by lifetime delivered revenue
-- customer_unique_id identifies shoppers across multiple orders.
-- =============================================================

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
),

customer_value AS (
    SELECT
        c.customer_unique_id,
        COUNT(*) AS delivered_orders,
        SUM(v.item_revenue) AS lifetime_revenue,
        AVG(v.item_revenue) AS average_order_value,
        MIN(o.order_purchase_timestamp) AS first_purchase,
        MAX(o.order_purchase_timestamp) AS latest_purchase
    FROM orders o
    JOIN customers c
        ON c.customer_id = o.customer_id
    JOIN order_values v
        ON v.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

ranked_customers AS (
    SELECT
        *,
        RANK() OVER (
            ORDER BY lifetime_revenue DESC
        ) AS revenue_rank,
        ROW_NUMBER() OVER (
            ORDER BY lifetime_revenue DESC, customer_unique_id
        ) AS customer_row_number
    FROM customer_value
)

SELECT
    revenue_rank,
    customer_unique_id,
    delivered_orders,
    ROUND(lifetime_revenue, 2) AS lifetime_revenue,
    ROUND(average_order_value, 2) AS average_order_value,
    first_purchase,
    latest_purchase
FROM ranked_customers
WHERE customer_row_number <= 20
ORDER BY customer_row_number;

-- =============================================================
-- Q8. Repeat-customer profile
-- =============================================================

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
),

customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(*) AS delivered_orders,
        SUM(v.item_revenue) AS realized_revenue
    FROM orders o
    JOIN customers c
        ON c.customer_id = o.customer_id
    JOIN order_values v
        ON v.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN delivered_orders >= 2
            THEN 'Repeat customer'
        ELSE 'One-time customer'
    END AS customer_type,
    COUNT(*) AS customers,
    SUM(delivered_orders) AS delivered_orders,
    ROUND(SUM(realized_revenue), 2) AS realized_revenue,
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
ORDER BY customers DESC;

-- =============================================================
-- Q9. Association between delivery timing and review scores
-- This is an association, not proof that delays caused reviews.
-- Reviews are aggregated before joining to orders.
-- =============================================================

WITH review_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM reviews
    GROUP BY order_id
),

delivery_reviews AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
                THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_result,
        r.average_review_score
    FROM orders o
    JOIN review_by_order r
        ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_result,
    COUNT(*) AS reviewed_delivered_orders,
    ROUND(AVG(average_review_score), 2)
        AS average_review_score,
    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE average_review_score <= 2
        )
        / COUNT(*),
        2
    ) AS low_review_rate_pct
FROM delivery_reviews
GROUP BY delivery_result
ORDER BY delivery_result;

-- =============================================================
-- Q10. Late-delivery performance by customer state
-- States require at least 100 delivered orders.
-- =============================================================

WITH review_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM reviews
    GROUP BY order_id
),

state_quality AS (
    SELECT
        c.customer_state,
        COUNT(*) AS delivered_orders,
        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        ) AS late_orders,
        COUNT(r.average_review_score) AS reviewed_orders,
        AVG(r.average_review_score) AS average_review_score
    FROM orders o
    JOIN customers c
        ON c.customer_id = o.customer_id
    LEFT JOIN review_by_order r
        ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY c.customer_state
    HAVING COUNT(*) >= 100
),

ranked_states AS (
    SELECT
        *,
        100.0 * late_orders / delivered_orders
            AS late_delivery_rate_pct,
        RANK() OVER (
            ORDER BY 100.0 * late_orders / delivered_orders DESC
        ) AS late_delivery_rank
    FROM state_quality
)

SELECT
    late_delivery_rank,
    customer_state,
    delivered_orders,
    late_orders,
    ROUND(late_delivery_rate_pct, 2)
        AS late_delivery_rate_pct,
    reviewed_orders,
    ROUND(average_review_score, 2)
        AS average_review_score
FROM ranked_states
ORDER BY late_delivery_rank;
