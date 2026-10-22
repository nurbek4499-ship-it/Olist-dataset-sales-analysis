
-- ============================================
-- ПОЛНЫЙ СБРОС И СОЗДАНИЕ ЗАНОВО
-- ============================================

DROP TABLE IF EXISTS 
    customers, 
    geolocation, 
    payment, 
    order_review, 
    orders, 
    products, 
    sellers, 
    category_name, 
    order_items 
CASCADE;

-- Клиенты
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2)
);

-- Геолокация
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat DECIMAL(10,8),
    geolocation_lng DECIMAL(11,8),
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2)
);

-- Платежи
CREATE TABLE payment (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(20),
    payment_installments INTEGER,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);


-- Заказы
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- Товары (ИСПРАВЛЕНО: category VARCHAR(100))
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

-- Продавцы
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);

-- Перевод категорий
CREATE TABLE category_name (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);


-- ТОВАРЫ В ЗАКАЗАХ (НОВАЯ ТАБЛИЦА!)
CREATE TABLE order_review (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id) -- Теперь ключ составной
);
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INTEGER,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

COPY customers FROM 'C:\Users\Admin\Desktop\e-commerse\olist_customers_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY geolocation FROM 'C:\Users\Admin\Desktop\e-commerse\olist_geolocation_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY payment FROM 'C:\Users\Admin\Desktop\e-commerse\olist_order_payments_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY order_review FROM 'C:\Users\Admin\Desktop\e-commerse\olist_order_reviews_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY orders FROM 'C:\Users\Admin\Desktop\e-commerse\olist_orders_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY products FROM 'C:\Users\Admin\Desktop\e-commerse\olist_products_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY sellers FROM 'C:\Users\Admin\Desktop\e-commerse\olist_sellers_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');
COPY order_items FROM 'C:\Users\Admin\Desktop\e-commerse\olist_order_items_dataset.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');


SELECT o.order_id,
SUM(oi.price) AS Order_total
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY o.order_id;

SELECT
DATE_TRUNC('month',o.order_purchase_timestamp) AS month,
SUM(oi.price) as revenue
FROM ORDERS O
inner join  order_items oi
ON o.order_id = oi.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
order BY month;



SELECT p.product_category_name,
SUM(oi.price) AS revenue,
COUNT(DISTINCT o.order_id) as orders_count
FROM orders o 
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC;

SELECT p.product_category_name,
SUM(oi.price) AS revenue,
COUNT(DISTINCT o.order_id) as orders_count,
ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id),2) as aov
FROM orders o 
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC;


---- aveage product & average price
SELECT 
AVG(order_total) AS avg_order_value,
AVG(items_count) AS avg_item_per_order
FROM(
SELECT O.order_id,
SUM(oi.price) AS order_total,
COUNT(oi.order_item_id) AS items_count
FRoM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id
) t;

SELECT COUNT(*) FROM orders;
SELECT current_database();