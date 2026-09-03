-- =============================================================
-- Olist E-Commerce Revenue and Order Intelligence
-- Data Quality and Reconciliation Checks
-- =============================================================

\set ON_ERROR_STOP on

SET search_path TO olist, public;


-- =============================================================
-- V1. Reconcile database row counts with source CSV records
-- =============================================================

WITH expected_counts (table_name, expected_rows) AS (
    VALUES
        ('customers', 99441::BIGINT),
        ('orders', 99441::BIGINT),
        ('order_items', 112650::BIGINT),
        ('products', 32951::BIGINT),
        ('payments', 103886::BIGINT),
        ('reviews', 99224::BIGINT),
        ('sellers', 3095::BIGINT),
        ('category_translation', 71::BIGINT),
        ('geolocation', 1000163::BIGINT)
),

actual_counts AS (
    SELECT 'customers' AS table_name, COUNT(*) AS actual_rows
    FROM customers

    UNION ALL
    SELECT 'orders', COUNT(*) FROM orders

    UNION ALL
    SELECT 'order_items', COUNT(*) FROM order_items

    UNION ALL
    SELECT 'products', COUNT(*) FROM products

    UNION ALL
    SELECT 'payments', COUNT(*) FROM payments

    UNION ALL
    SELECT 'reviews', COUNT(*) FROM reviews

    UNION ALL
    SELECT 'sellers', COUNT(*) FROM sellers

    UNION ALL
    SELECT 'category_translation', COUNT(*)
    FROM category_translation

    UNION ALL
    SELECT 'geolocation', COUNT(*) FROM geolocation
)

SELECT
    e.table_name,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows AS variance,
    a.actual_rows = e.expected_rows AS passed
FROM expected_counts e
JOIN actual_counts a
    ON a.table_name = e.table_name
ORDER BY e.table_name;


-- =============================================================
-- V2. Primary-key duplicate checks
-- Every result should equal zero.
-- =============================================================

SELECT
    'customers.customer_id' AS key_test,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_rows
FROM customers

UNION ALL

SELECT
    'orders.order_id',
    COUNT(*) - COUNT(DISTINCT order_id)
FROM orders

UNION ALL

SELECT
    'products.product_id',
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT
    'sellers.seller_id',
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM sellers

UNION ALL

SELECT
    'order_items.(order_id, order_item_id)',
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
FROM order_items

UNION ALL

SELECT
    'payments.(order_id, payment_sequential)',
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential))
FROM payments

UNION ALL

SELECT
    'reviews.(review_id, order_id)',
    COUNT(*) - COUNT(DISTINCT (review_id, order_id))
FROM reviews;


-- =============================================================
-- V3. Foreign-key orphan checks
-- Every result should equal zero.
-- =============================================================

SELECT
    'orders -> customers' AS relationship,
    COUNT(*) AS orphan_rows
FROM orders o
LEFT JOIN customers c
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'order_items -> orders',
    COUNT(*)
FROM order_items oi
LEFT JOIN orders o
    ON o.order_id = oi.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'order_items -> products',
    COUNT(*)
FROM order_items oi
LEFT JOIN products p
    ON p.product_id = oi.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'order_items -> sellers',
    COUNT(*)
FROM order_items oi
LEFT JOIN sellers s
    ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL

UNION ALL

SELECT
    'payments -> orders',
    COUNT(*)
FROM payments p
LEFT JOIN orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'reviews -> orders',
    COUNT(*)
FROM reviews r
LEFT JOIN orders o
    ON o.order_id = r.order_id
WHERE o.order_id IS NULL;


-- =============================================================
-- V4. Validate the one-row-per-order revenue calculation
-- =============================================================

WITH order_item_summary AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
),

joined_orders AS (
    SELECT
        o.order_id,
        o.order_status,
        COALESCE(i.item_revenue, 0) AS item_revenue
    FROM orders o
    LEFT JOIN order_item_summary i
        ON i.order_id = o.order_id
)

SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS multiplied_rows,
    ROUND(
        SUM(item_revenue)
            FILTER (WHERE order_status = 'delivered'),
        2
    ) AS delivered_revenue
FROM joined_orders;


-- =============================================================
-- V5. Reconcile item plus freight value against payments
-- Payments do not always equal merchandise plus freight exactly.
-- =============================================================

WITH item_summary AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_plus_freight
    FROM order_items
    GROUP BY order_id
),

payment_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM payments
    GROUP BY order_id
),

order_reconciliation AS (
    SELECT
        o.order_id,
        COALESCE(i.item_plus_freight, 0)
            AS item_plus_freight,
        COALESCE(p.payment_value, 0)
            AS payment_value,
        COALESCE(p.payment_value, 0)
            - COALESCE(i.item_plus_freight, 0)
            AS variance
    FROM orders o
    LEFT JOIN item_summary i
        ON i.order_id = o.order_id
    LEFT JOIN payment_summary p
        ON p.order_id = o.order_id
)

SELECT
    COUNT(*) AS orders,
    ROUND(SUM(item_plus_freight), 2)
        AS total_item_plus_freight,
    ROUND(SUM(payment_value), 2)
        AS total_payment_value,
    ROUND(SUM(variance), 2)
        AS net_variance,
    ROUND(
        100.0 * SUM(variance)
        / NULLIF(SUM(item_plus_freight), 0),
        2
    ) AS net_variance_pct,
    COUNT(*) FILTER (
        WHERE ABS(variance) <= 0.01
    ) AS reconciled_orders,
    COUNT(*) FILTER (
        WHERE ABS(variance) > 0.01
    ) AS non_reconciled_orders
FROM order_reconciliation;


-- =============================================================
-- V6. Missing-value and valid-range profile
-- Some missing values are expected source limitations.
-- =============================================================

SELECT
    'products missing category' AS quality_check,
    COUNT(*) AS affected_rows
FROM products
WHERE product_category_name IS NULL

UNION ALL

SELECT
    'orders missing approval timestamp',
    COUNT(*)
FROM orders
WHERE order_approved_at IS NULL

UNION ALL

SELECT
    'orders missing delivered timestamp',
    COUNT(*)
FROM orders
WHERE order_delivered_customer_date IS NULL

UNION ALL

SELECT
    'delivered orders missing delivered timestamp',
    COUNT(*)
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL

UNION ALL

SELECT
    'reviews missing title',
    COUNT(*)
FROM reviews
WHERE NULLIF(BTRIM(review_comment_title), '') IS NULL

UNION ALL

SELECT
    'reviews missing message',
    COUNT(*)
FROM reviews
WHERE NULLIF(BTRIM(review_comment_message), '') IS NULL

UNION ALL

SELECT
    'review scores outside 1-5',
    COUNT(*)
FROM reviews
WHERE review_score NOT BETWEEN 1 AND 5

UNION ALL

SELECT
    'negative product prices',
    COUNT(*)
FROM order_items
WHERE price < 0

UNION ALL

SELECT
    'negative freight values',
    COUNT(*)
FROM order_items
WHERE freight_value < 0;


-- =============================================================
-- V7. Product-category translation coverage
-- =============================================================

SELECT
    p.product_category_name,
    COUNT(*) AS affected_products
FROM products p
LEFT JOIN category_translation t
    ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY affected_products DESC;


-- =============================================================
-- V8. Transactional date coverage
-- =============================================================

SELECT
    MIN(order_purchase_timestamp) AS first_purchase,
    MAX(order_purchase_timestamp) AS last_purchase,
    MIN(order_delivered_customer_date) AS first_delivery,
    MAX(order_delivered_customer_date) AS last_delivery
FROM orders;

-- =============================================================
-- V9. Diagnose payment reconciliation differences
-- =============================================================

WITH item_summary AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_plus_freight
    FROM order_items
    GROUP BY order_id
),

payment_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM payments
    GROUP BY order_id
),

reconciliation AS (
    SELECT
        o.order_id,
        o.order_status,
        i.order_id IS NULL AS missing_item_rows,
        p.order_id IS NULL AS missing_payment_rows,
        COALESCE(i.item_plus_freight, 0)
            AS item_plus_freight,
        COALESCE(p.payment_value, 0)
            AS payment_value,
        COALESCE(p.payment_value, 0)
            - COALESCE(i.item_plus_freight, 0)
            AS variance
    FROM orders o
    LEFT JOIN item_summary i
        ON i.order_id = o.order_id
    LEFT JOIN payment_summary p
        ON p.order_id = o.order_id
),

classified AS (
    SELECT
        *,
        CASE
            WHEN missing_item_rows
                 AND NOT missing_payment_rows
                THEN 'Payment present, no item rows'
            WHEN missing_payment_rows
                 AND NOT missing_item_rows
                THEN 'Item rows present, no payment'
            WHEN missing_item_rows
                 AND missing_payment_rows
                THEN 'No item or payment rows'
            WHEN ABS(variance) <= 0.01
                THEN 'Exact reconciliation'
            ELSE 'Amount mismatch'
        END AS reconciliation_type
    FROM reconciliation
)

SELECT
    reconciliation_type,
    order_status,
    COUNT(*) AS orders,
    ROUND(SUM(item_plus_freight), 2)
        AS item_plus_freight,
    ROUND(SUM(payment_value), 2)
        AS payment_value,
    ROUND(SUM(variance), 2)
        AS net_variance
FROM classified
GROUP BY
    reconciliation_type,
    order_status
ORDER BY
    reconciliation_type,
    orders DESC;
