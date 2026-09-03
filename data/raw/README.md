# Raw Olist Data

Download the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the following unmodified files in this directory:

- `olist_customers_dataset.csv`
- `olist_geolocation_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_orders_dataset.csv`
- `olist_products_dataset.csv`
- `olist_sellers_dataset.csv`
- `product_category_name_translation.csv`

The CSV files are excluded from Git to keep the repository lightweight. The data loader reads them directly from this directory.

Do not manually edit the raw source files. Any cleaning, transformations, or metric logic should be implemented in SQL or the reporting layer.

The compact, derived reporting snapshots are stored separately in [powerbi/data](../../powerbi/data/). Those extracts are not substitutes for the nine raw files when rebuilding the PostgreSQL database. See the [main reproduction instructions](../../README.md#reproducing-the-project) for server setup, schema creation, and loading order.
