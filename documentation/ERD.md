# Olist E-Commerce Database ERD

This entity relationship diagram represents the PostgreSQL data model used for the Olist revenue and order intelligence analysis.

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--o{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : includes
    SELLERS ||--o{ ORDER_ITEMS : fulfills
    ORDERS ||--o{ PAYMENTS : receives
    ORDERS ||--o{ REVIEWS : receives
    CATEGORY_TRANSLATION |o--o{ PRODUCTS : translates

    CUSTOMERS {
        char customer_id PK
        char customer_unique_id
        int customer_zip_code_prefix
        text customer_city
        char customer_state
    }

    ORDERS {
        char order_id PK
        char customer_id FK
        text order_status
        timestamp order_purchase_timestamp
        timestamp order_approved_at
        timestamp order_delivered_carrier_date
        timestamp order_delivered_customer_date
        timestamp order_estimated_delivery_date
    }

    ORDER_ITEMS {
        char order_id PK, FK
        int order_item_id PK
        char product_id FK
        char seller_id FK
        timestamp shipping_limit_date
        numeric price
        numeric freight_value
    }

    PRODUCTS {
        char product_id PK
        text product_category_name
        int product_name_length
        int product_description_length
        int product_photos_qty
        numeric product_weight_g
        numeric product_length_cm
        numeric product_height_cm
        numeric product_width_cm
    }

    SELLERS {
        char seller_id PK
        int seller_zip_code_prefix
        text seller_city
        char seller_state
    }

    PAYMENTS {
        char order_id PK, FK
        int payment_sequential PK
        text payment_type
        int payment_installments
        numeric payment_value
    }

    REVIEWS {
        char review_id PK
        char order_id PK, FK
        int review_score
        text review_comment_title
        text review_comment_message
        timestamp review_creation_date
        timestamp review_answer_timestamp
    }

    CATEGORY_TRANSLATION {
        text product_category_name PK
        text product_category_name_english
    }
```

## Modeling notes

- `customer_id` identifies the customer record attached to one order.
- `customer_unique_id` identifies the same shopper across multiple orders and should be used for lifetime-customer analysis.
- `order_items`, `payments`, and `reviews` are one-to-many children of `orders`.
- `order_items` uses the composite primary key `(order_id, order_item_id)`.
- `payments` uses `(order_id, payment_sequential)`.
- `reviews` uses `(review_id, order_id)` because `review_id` is not globally unique in the source.
- Product categories are connected to the translation table logically rather than through an enforced foreign key because two source categories lack English translations.
- `geolocation` is excluded from the transactional ERD because ZIP prefixes repeat. It contains multiple coordinate observations per ZIP prefix and does not have a safe direct one-to-one relationship with customers or sellers.

## Power BI model boundary

This ERD describes PostgreSQL, not the Power BI model. The reporting exporter creates six pre-aggregated CSV tables for the three-page report. They are kept independent because their grains differ and they do not supply shared row-level relationship keys. See the [reporting guide](../powerbi/README.md) for the snapshot and filter limitations.
