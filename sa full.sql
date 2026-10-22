


DROP TABLE IF EXISTS customers,geolocation,payment,orders,order_review,products,sellers ,category_name
DROP TABLE IF EXISTS order_review
-- Creating tables


--customers
CREATE TABLE IF NOT EXISTS customers (
customer_id VARCHAR(50) PRIMARY KEY,
customer_unique_id VARCHAR(50),
customer_zip_code_prefix INTEGER,
customer_city VARCHAR (100),
customer_state VARCHAR(2)
);

--geolocation
CREATE TABLE geolocation (
geolocation_zip_code_prefix INTEGER,
geolocation_lat DECIMAL(10,8),
geolocation_lng DECIMAL (11,8),
geolocation_city VARCHAR (100),
geolocation_state CHAR(2)
);

--payment
CREATE TABLE payment (
order_id	VARCHAR(50),
payment_sequential	INTEGER,
payment_type	VARCHAR(20),
payment_installments	INTEGER,
payment_value	DECIMAL(10,2),
PRIMARY KEY(order_id,payment_sequential)
);

--REVIEW
CREATE TABLE order_review (
review_id	VARCHAR(50) PRIMARY KEY,
order_id	VARCHAR(50),
review_score	INTEGER,
review_comment_title TEXT,
review_comment_message	TEXT,
review_creation_date	TIMESTAMP,
review_answer_timestamp TIMESTAMP
);


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

CREATE TABLE products (
product_id  VARCHAR(50) PRIMARY KEY,
product_category_name VARCHAR(20),
product_name_lenght	INTEGER,
product_description_lenght INTEGER,
product_photos_qty	INTEGER,
product_weight_g	INTEGER,
product_length_cm	INTEGER,
product_height_cm	INTEGER,
product_width_cm INTEGER
);


CREATE TABLE sellers (
seller_id VARCHAR(50) PRIMARY KEY,
seller_zip_code_prefix INTEGER,
seller_city VARCHAR(100),
seller_state CHAR(2)
);



CREATE TABLE category_name (
product_category_name VARCHAR(50),
product_category_name_english VARCHAR(50)  
)

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





SELECT
AVG(order_total) AS avg_order_value,
AVG(items_count) AS avg_items_per_order
FROM(SELECT
o.order_id,
SUM(oi.price)AS oder_total)
count(oi.order_item_id) AS items_count
FROM orders o
INNER JOIN order_ite

SELECT
COALESCE(cn.product_category_name_english,p.product_category_name,'unknown')
AS category_english,

SUM(oi.price) AS revenue,
COUNT(DISTINCT o.order_id) AS orders_count,
ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id),2) AS aov
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_name cn
ON p.product_category_name = cn.product_category_name

GROUP BY COALESCE(cn.product_category_name_english,
p.product_category_name,
'unknown')
ORDER BY revenue DESC;

SELECT 
    c.customer_state AS state,
    COUNT(o.order_id) AS total_delivered_orders,
    -- Исправлено: добавлено _customer_
    ROUND(AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)))::numeric, 1) AS avg_delivery_days,
    ROUND(
        (COUNT(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 END) * 100.0 / COUNT(o.order_id)), 2
    ) AS delayed_orders_percentage
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id
-- Исправлено: одинарные кавычки для текста 'delivered'
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY delayed_orders_percentage DESC;



WITH customer_first_purchase AS (
    -- Находим месяц первой покупки для каждого клиента
    SELECT 
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM orders o 
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id -- Исправлено: c.customer_unique_id
),

orders_month AS (
    -- Находим все месяцы заказов клиентов
    SELECT 
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, DATE_TRUNC('month', o.order_purchase_timestamp) -- Исправлено: c.customer_unique_id
),

cohort_sizes AS (
    -- Считаем изначальный размер каждой когорты
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),

retention_table AS (
    -- Вычисляем номер месяца жизни когорты и количество активных клиентов
    SELECT 
        f.cohort_month,
        s.cohort_size,
        -- Исправлено: добавлен расчет разницы месяцев, ключевое слово FROM и алиас AS month_number
        ((EXTRACT(YEAR FROM o.order_month) - EXTRACT(YEAR FROM f.cohort_month)) * 12 +
         (EXTRACT(MONTH FROM o.order_month) - EXTRACT(MONTH FROM f.cohort_month))) AS month_number,
        COUNT(DISTINCT o.customer_unique_id) AS active_customers
    -- Исправлено: здесь везде правильные названия таблиц из блоков выше
    FROM orders_month o
    JOIN customer_first_purchase f ON o.customer_unique_id = f.customer_unique_id
    JOIN cohort_sizes s ON f.cohort_month = s.cohort_month
    GROUP BY f.cohort_month, s.cohort_size, month_number -- Исправлено: убрана лишняя скобка
)

-- Финальный вывод с расчетом Retention Rate в процентах
SELECT 
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort,
    cohort_size AS original_users,
    month_number,
    active_customers,
    ROUND((active_customers::numeric / cohort_size) * 100, 2) AS retention_percentage -- Исправлено: active_customers
FROM retention_table
WHERE month_number BETWEEN 0 AND 12
ORDER BY cohort, month_number;


SELECT 
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Опоздал'
        ELSE 'Вовремя'
    END AS delivery_status,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(*) AS orders_count
FROM orders o
JOIN order_review r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY avg_review_score DESC;

SELECT inet_server_addr(), inet_server_port();
