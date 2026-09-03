#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="${RAW_DIR:-$PROJECT_DIR/data/raw}"
DB_NAME="${DB_NAME:-olist_revenue_intelligence}"
PSQL_BIN="${PSQL_BIN:-/Applications/Postgres.app/Contents/Versions/latest/bin/psql}"

required_files=(
    olist_customers_dataset.csv
    olist_geolocation_dataset.csv
    olist_order_items_dataset.csv
    olist_order_payments_dataset.csv
    olist_order_reviews_dataset.csv
    olist_orders_dataset.csv
    olist_products_dataset.csv
    olist_sellers_dataset.csv
    product_category_name_translation.csv
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$RAW_DIR/$file" ]]; then
        echo "Missing required source file: $RAW_DIR/$file" >&2
        exit 1
    fi
done

existing_orders="$(
    "$PSQL_BIN" \
        -X \
        -h localhost \
        -p 5432 \
        -d "$DB_NAME" \
        -Atqc "SELECT COUNT(*) FROM olist.orders;"
)"

if [[ "$existing_orders" != "0" ]]; then
    echo "Database already contains $existing_orders orders."
    echo "Refusing to load duplicate data."
    exit 2
fi

"$PSQL_BIN" \
    -X \
    -h localhost \
    -p 5432 \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 <<SQL

BEGIN;

\copy olist.category_translation (product_category_name, product_category_name_english) FROM '$RAW_DIR/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state) FROM '$RAW_DIR/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state) FROM '$RAW_DIR/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.products (product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm) FROM '$RAW_DIR/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state) FROM '$RAW_DIR/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date) FROM '$RAW_DIR/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value) FROM '$RAW_DIR/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.payments (order_id, payment_sequential, payment_type, payment_installments, payment_value) FROM '$RAW_DIR/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy olist.reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM '$RAW_DIR/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

COMMIT;

ANALYZE olist.customers;
ANALYZE olist.orders;
ANALYZE olist.order_items;
ANALYZE olist.products;
ANALYZE olist.payments;
ANALYZE olist.reviews;

SQL

echo "Olist data loaded successfully into '$DB_NAME'."
