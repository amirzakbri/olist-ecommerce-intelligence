# Olist E-Commerce Data Dictionary

## Dataset overview

**Source:** Olist Brazilian E-Commerce Public Dataset
**Publisher:** Olist
**Distribution:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
**Database:** PostgreSQL
**Schema:** `olist`
**Purchase coverage:** September 2016 through October 2018

The dataset contains historical, anonymized marketplace transactions from Brazil. Identifiers are pseudonymous keys rather than customer, seller, or product names; the raw records still include geographic attributes and free-text review content and are excluded from Git.

## customers

**Grain:** One customer record attached to one order
**Primary key:** `customer_id`
**Row count:** 99,441

| Column | Type | Description |
|---|---|---|
| customer_id | CHAR(32) | Customer record identifier used by the orders table |
| customer_unique_id | CHAR(32) | Stable shopper identifier across multiple orders |
| customer_zip_code_prefix | INTEGER | First five digits of the customer’s postal code |
| customer_city | TEXT | Customer delivery city |
| customer_state | CHAR(2) | Brazilian state abbreviation |

Use `customer_unique_id`, rather than `customer_id`, for repeat-customer and lifetime-value analysis.

## orders

**Grain:** One row per order
**Primary key:** `order_id`
**Foreign key:** `customer_id → customers.customer_id`
**Row count:** 99,441

| Column | Type | Description |
|---|---|---|
| order_id | CHAR(32) | Unique order identifier |
| customer_id | CHAR(32) | Customer record associated with the order |
| order_status | TEXT | Current or final order status |
| order_purchase_timestamp | TIMESTAMP | Time the customer placed the order |
| order_approved_at | TIMESTAMP | Time payment was approved |
| order_delivered_carrier_date | TIMESTAMP | Time the order was transferred to the carrier |
| order_delivered_customer_date | TIMESTAMP | Time the order reached the customer |
| order_estimated_delivery_date | TIMESTAMP | Estimated delivery deadline |

Observed statuses include `delivered`, `shipped`, `canceled`, `unavailable`, `invoiced`, `processing`, `created`, and `approved`.

## order_items

**Grain:** One product line within one order
**Primary key:** `(order_id, order_item_id)`
**Row count:** 112,650

| Column | Type | Description |
|---|---|---|
| order_id | CHAR(32) | Parent order identifier |
| order_item_id | INTEGER | Sequential item number within the order |
| product_id | CHAR(32) | Purchased product identifier |
| seller_id | CHAR(32) | Seller fulfilling the item |
| shipping_limit_date | TIMESTAMP | Seller’s shipping deadline |
| price | NUMERIC(12,2) | Merchandise price, excluding freight |
| freight_value | NUMERIC(12,2) | Freight charged for the item |

Foreign keys:

- `order_id → orders.order_id`
- `product_id → products.product_id`
- `seller_id → sellers.seller_id`

Realized revenue is calculated from `price` for delivered orders. Freight is reported separately.

## products

**Grain:** One row per product
**Primary key:** `product_id`
**Row count:** 32,951

| Column | Type | Description |
|---|---|---|
| product_id | CHAR(32) | Unique anonymized product identifier |
| product_category_name | TEXT | Product category in Portuguese |
| product_name_length | INTEGER | Character count of the product name |
| product_description_length | INTEGER | Character count of the product description |
| product_photos_qty | INTEGER | Number of product photographs |
| product_weight_g | NUMERIC(10,2) | Product weight in grams |
| product_length_cm | NUMERIC(10,2) | Product length in centimetres |
| product_height_cm | NUMERIC(10,2) | Product height in centimetres |
| product_width_cm | NUMERIC(10,2) | Product width in centimetres |

There are 610 products without a category. These are reported as `Unknown`.

## payments

**Grain:** One payment sequence within one order
**Primary key:** `(order_id, payment_sequential)`
**Foreign key:** `order_id → orders.order_id`
**Row count:** 103,886

| Column | Type | Description |
|---|---|---|
| order_id | CHAR(32) | Parent order identifier |
| payment_sequential | INTEGER | Sequence number for split or multiple payments |
| payment_type | TEXT | Payment method, such as credit card, boleto, voucher, or debit card |
| payment_installments | INTEGER | Number of payment installments |
| payment_value | NUMERIC(12,2) | Recorded payment amount |

One order can contain multiple payment rows. Payments must be aggregated by `order_id` before joining them to other order-level datasets.

## reviews

**Grain:** One submitted review record for one order
**Primary key:** `(review_id, order_id)`
**Foreign key:** `order_id → orders.order_id`
**Row count:** 99,224

| Column | Type | Description |
|---|---|---|
| review_id | CHAR(32) | Review identifier |
| order_id | CHAR(32) | Reviewed order identifier |
| review_score | SMALLINT | Review score from 1 to 5 |
| review_comment_title | TEXT | Optional review title |
| review_comment_message | TEXT | Optional written review |
| review_creation_date | TIMESTAMP | Date the review request was created |
| review_answer_timestamp | TIMESTAMP | Time the customer submitted the review |

`review_id` is not globally unique in the source, so the database uses the composite key `(review_id, order_id)`.

Written review fields are optional. Score-based analysis does not require a title or message.

## sellers

**Grain:** One row per seller
**Primary key:** `seller_id`
**Row count:** 3,095

| Column | Type | Description |
|---|---|---|
| seller_id | CHAR(32) | Unique anonymized seller identifier |
| seller_zip_code_prefix | INTEGER | First five digits of the seller’s postal code |
| seller_city | TEXT | Seller city |
| seller_state | CHAR(2) | Brazilian state abbreviation |

## category_translation

**Grain:** One translation per Portuguese category
**Primary key:** `product_category_name`
**Row count:** 71

| Column | Type | Description |
|---|---|---|
| product_category_name | TEXT | Original Portuguese category |
| product_category_name_english | TEXT | English category translation |

Two populated categories have no translation row:

- `portateis_cozinha_e_preparadores_de_alimentos`
- `pc_gamer`

Analysis falls back to the Portuguese category rather than removing these products.

## geolocation

**Grain:** One geographic coordinate observation for a postal-code prefix
**Primary key:** `geolocation_id`
**Row count:** 1,000,163

| Column | Type | Description |
|---|---|---|
| geolocation_id | BIGINT | Database-generated row identifier |
| geolocation_zip_code_prefix | INTEGER | First five digits of the postal code |
| geolocation_lat | NUMERIC(11,8) | Latitude |
| geolocation_lng | NUMERIC(11,8) | Longitude |
| geolocation_city | TEXT | City associated with the observation |
| geolocation_state | CHAR(2) | Brazilian state abbreviation |

Postal-code prefixes are not unique. The source contains multiple coordinate observations for the same prefix, so geographic records must be aggregated before being joined to customers or sellers.

## Reporting views

### vw_order_item_summary

**Grain:** One row per order

Aggregates item count, merchandise revenue, freight value, and merchandise-plus-freight value.

### vw_payment_summary

**Grain:** One row per order

Aggregates payment rows, total payment value, payment types, and maximum installment count.

### vw_review_summary

**Grain:** One row per order

Aggregates review count, average review score, minimum and maximum scores, and comment availability.

The average is stored as `NUMERIC(4,2)`, so an order with multiple reviews can have a fractional score. Reporting averages these order-level means rather than joining raw review rows to order items.

### vw_order_fact

**Grain:** One row per order

Combines orders with customer, item, payment, delivery, and review summaries. The child tables are aggregated before joining, preventing row multiplication.

`order_month` is the purchase timestamp truncated to a month. `is_late_delivery` compares the customer-delivery timestamp with the estimated-delivery timestamp and is unknown when delivery timing is missing.

## Power BI reporting extracts

The [Power BI reporting guide](../powerbi/README.md#reporting-extracts) documents the six CSV tables, their grains, measures, and aggregation rules. They are produced by [export_powerbi_data.sh](../scripts/export_powerbi_data.sh), not additional relational database tables.

Count fields are whole numbers; currency fields are BRL decimals; `order_month` is a date; `_pct` fields are percentage points requiring division by 100 before percentage formatting. These independent aggregate tables do not support automatic cross-table slicing.

## Join guidance

Safe analytical joins follow these rules:

1. Join `orders` directly to `customers`.
2. Aggregate `order_items` before combining them with payments or reviews.
3. Aggregate `payments` to one row per order.
4. Aggregate `reviews` to one row per order.
5. Do not join raw geolocation observations directly to transactional tables.
6. Use left joins when missing child records must remain visible.

## Known limitations

- No verified returns or refunds field is available.
- Eight delivered orders lack a customer-delivery timestamp.
- Review comments are optional and highly sparse.
- Product category translation coverage is incomplete.
- Payment value does not reconcile exactly to item value plus freight for every order.
- Postal-code prefixes are geographic approximations, not unique locations.
