--
-- PostgreSQL database dump
--

\restrict 6NK7003OBdccM2zvjzowrfHe4dAI1cclgYQt9v8qmVhx64YUioqBP9Vr9oOtVQD

-- Dumped from database version 18.6 (Postgres.app)
-- Dumped by pg_dump version 18.6 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: olist; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA olist;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: category_translation; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.category_translation (
    product_category_name text NOT NULL,
    product_category_name_english text NOT NULL
);


--
-- Name: customers; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.customers (
    customer_id character(32) NOT NULL,
    customer_unique_id character(32) NOT NULL,
    customer_zip_code_prefix integer NOT NULL,
    customer_city text NOT NULL,
    customer_state character(2) NOT NULL
);


--
-- Name: geolocation; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.geolocation (
    geolocation_id bigint NOT NULL,
    geolocation_zip_code_prefix integer NOT NULL,
    geolocation_lat numeric(11,8) NOT NULL,
    geolocation_lng numeric(11,8) NOT NULL,
    geolocation_city text NOT NULL,
    geolocation_state character(2) NOT NULL
);


--
-- Name: geolocation_geolocation_id_seq; Type: SEQUENCE; Schema: olist; Owner: -
--

CREATE SEQUENCE olist.geolocation_geolocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geolocation_geolocation_id_seq; Type: SEQUENCE OWNED BY; Schema: olist; Owner: -
--

ALTER SEQUENCE olist.geolocation_geolocation_id_seq OWNED BY olist.geolocation.geolocation_id;


--
-- Name: order_items; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.order_items (
    order_id character(32) NOT NULL,
    order_item_id integer NOT NULL,
    product_id character(32) NOT NULL,
    seller_id character(32) NOT NULL,
    shipping_limit_date timestamp without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL,
    CONSTRAINT order_items_freight_value_check CHECK ((freight_value >= (0)::numeric)),
    CONSTRAINT order_items_order_item_id_check CHECK ((order_item_id > 0)),
    CONSTRAINT order_items_price_check CHECK ((price >= (0)::numeric))
);


--
-- Name: orders; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.orders (
    order_id character(32) NOT NULL,
    customer_id character(32) NOT NULL,
    order_status text NOT NULL,
    order_purchase_timestamp timestamp without time zone NOT NULL,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone NOT NULL,
    CONSTRAINT orders_order_status_check CHECK ((order_status = ANY (ARRAY['approved'::text, 'canceled'::text, 'created'::text, 'delivered'::text, 'invoiced'::text, 'processing'::text, 'shipped'::text, 'unavailable'::text])))
);


--
-- Name: payments; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.payments (
    order_id character(32) NOT NULL,
    payment_sequential integer NOT NULL,
    payment_type text NOT NULL,
    payment_installments integer NOT NULL,
    payment_value numeric(12,2) NOT NULL,
    CONSTRAINT payments_payment_installments_check CHECK ((payment_installments >= 0)),
    CONSTRAINT payments_payment_sequential_check CHECK ((payment_sequential > 0))
);


--
-- Name: products; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.products (
    product_id character(32) NOT NULL,
    product_category_name text,
    product_name_length integer,
    product_description_length integer,
    product_photos_qty integer,
    product_weight_g numeric(10,2),
    product_length_cm numeric(10,2),
    product_height_cm numeric(10,2),
    product_width_cm numeric(10,2)
);


--
-- Name: reviews; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.reviews (
    review_id character(32) NOT NULL,
    order_id character(32) NOT NULL,
    review_score smallint NOT NULL,
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp without time zone NOT NULL,
    review_answer_timestamp timestamp without time zone NOT NULL,
    CONSTRAINT reviews_review_score_check CHECK (((review_score >= 1) AND (review_score <= 5)))
);


--
-- Name: sellers; Type: TABLE; Schema: olist; Owner: -
--

CREATE TABLE olist.sellers (
    seller_id character(32) NOT NULL,
    seller_zip_code_prefix integer NOT NULL,
    seller_city text NOT NULL,
    seller_state character(2) NOT NULL
);


--
-- Name: vw_order_item_summary; Type: VIEW; Schema: olist; Owner: -
--

CREATE VIEW olist.vw_order_item_summary AS
 SELECT order_id,
    count(*) AS item_rows,
    (sum(price))::numeric(14,2) AS item_revenue,
    (sum(freight_value))::numeric(14,2) AS freight_value,
    (sum((price + freight_value)))::numeric(14,2) AS merchandise_plus_freight
   FROM olist.order_items
  GROUP BY order_id;


--
-- Name: vw_payment_summary; Type: VIEW; Schema: olist; Owner: -
--

CREATE VIEW olist.vw_payment_summary AS
 SELECT order_id,
    count(*) AS payment_rows,
    (sum(payment_value))::numeric(14,2) AS payment_value,
    string_agg(DISTINCT payment_type, ' + '::text ORDER BY payment_type) AS payment_types,
    max(payment_installments) AS max_installments
   FROM olist.payments
  GROUP BY order_id;


--
-- Name: vw_review_summary; Type: VIEW; Schema: olist; Owner: -
--

CREATE VIEW olist.vw_review_summary AS
 SELECT order_id,
    count(*) AS review_rows,
    (avg(review_score))::numeric(4,2) AS avg_review_score,
    min(review_score) AS min_review_score,
    max(review_score) AS max_review_score,
    bool_or((NULLIF(btrim(review_comment_message), ''::text) IS NOT NULL)) AS has_comment
   FROM olist.reviews
  GROUP BY order_id;


--
-- Name: vw_order_fact; Type: VIEW; Schema: olist; Owner: -
--

CREATE VIEW olist.vw_order_fact AS
 SELECT o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    (date_trunc('month'::text, o.order_purchase_timestamp))::date AS order_month,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
        CASE
            WHEN (o.order_delivered_customer_date IS NULL) THEN NULL::integer
            ELSE ((o.order_delivered_customer_date)::date - (o.order_purchase_timestamp)::date)
        END AS delivery_days,
        CASE
            WHEN (o.order_delivered_customer_date IS NULL) THEN NULL::boolean
            ELSE (o.order_delivered_customer_date > o.order_estimated_delivery_date)
        END AS is_late_delivery,
    COALESCE(i.item_rows, (0)::bigint) AS item_rows,
    i.item_revenue,
    i.freight_value,
    i.merchandise_plus_freight,
    COALESCE(p.payment_rows, (0)::bigint) AS payment_rows,
    p.payment_value,
    p.payment_types,
    p.max_installments,
    COALESCE(r.review_rows, (0)::bigint) AS review_rows,
    r.avg_review_score,
    r.min_review_score,
    r.max_review_score,
    COALESCE(r.has_comment, false) AS has_comment
   FROM ((((olist.orders o
     JOIN olist.customers c ON ((c.customer_id = o.customer_id)))
     LEFT JOIN olist.vw_order_item_summary i ON ((i.order_id = o.order_id)))
     LEFT JOIN olist.vw_payment_summary p ON ((p.order_id = o.order_id)))
     LEFT JOIN olist.vw_review_summary r ON ((r.order_id = o.order_id)));


--
-- Name: VIEW vw_order_fact; Type: COMMENT; Schema: olist; Owner: -
--

COMMENT ON VIEW olist.vw_order_fact IS 'One row per order. Revenue, payment, and review child tables are pre-aggregated before joining.';


--
-- Name: geolocation geolocation_id; Type: DEFAULT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.geolocation ALTER COLUMN geolocation_id SET DEFAULT nextval('olist.geolocation_geolocation_id_seq'::regclass);


--
-- Name: category_translation category_translation_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.category_translation
    ADD CONSTRAINT category_translation_pkey PRIMARY KEY (product_category_name);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- Name: geolocation geolocation_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.geolocation
    ADD CONSTRAINT geolocation_pkey PRIMARY KEY (geolocation_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, order_item_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (order_id, payment_sequential);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id, order_id);


--
-- Name: sellers sellers_pkey; Type: CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.sellers
    ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);


--
-- Name: idx_customers_state; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_customers_state ON olist.customers USING btree (customer_state);


--
-- Name: idx_customers_unique_id; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_customers_unique_id ON olist.customers USING btree (customer_unique_id);


--
-- Name: idx_geolocation_zip; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_geolocation_zip ON olist.geolocation USING btree (geolocation_zip_code_prefix);


--
-- Name: idx_order_items_product; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_order_items_product ON olist.order_items USING btree (product_id);


--
-- Name: idx_order_items_seller; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_order_items_seller ON olist.order_items USING btree (seller_id);


--
-- Name: idx_orders_customer; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_orders_customer ON olist.orders USING btree (customer_id);


--
-- Name: idx_orders_purchase_ts; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_orders_purchase_ts ON olist.orders USING btree (order_purchase_timestamp);


--
-- Name: idx_orders_status; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_orders_status ON olist.orders USING btree (order_status);


--
-- Name: idx_payments_order; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_payments_order ON olist.payments USING btree (order_id);


--
-- Name: idx_reviews_order; Type: INDEX; Schema: olist; Owner: -
--

CREATE INDEX idx_reviews_order ON olist.reviews USING btree (order_id);


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES olist.orders(order_id);


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES olist.products(product_id);


--
-- Name: order_items order_items_seller_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.order_items
    ADD CONSTRAINT order_items_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES olist.sellers(seller_id);


--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES olist.customers(customer_id);


--
-- Name: payments payments_order_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.payments
    ADD CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES olist.orders(order_id);


--
-- Name: reviews reviews_order_id_fkey; Type: FK CONSTRAINT; Schema: olist; Owner: -
--

ALTER TABLE ONLY olist.reviews
    ADD CONSTRAINT reviews_order_id_fkey FOREIGN KEY (order_id) REFERENCES olist.orders(order_id);


--
-- PostgreSQL database dump complete
--

\unrestrict 6NK7003OBdccM2zvjzowrfHe4dAI1cclgYQt9v8qmVhx64YUioqBP9Vr9oOtVQD
