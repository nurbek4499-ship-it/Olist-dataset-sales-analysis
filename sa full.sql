-- ==============================================================================
-- БЛОК 1. ИНИЦИАЛИЗАЦИЯ И ПРОЕКТИРОВАНИЕ СХЕМЫ БАЗЫ ДАННЫХ (DDL)
-- ==============================================================================

-- Удаляем таблицы, если они существовали ранее, для возможности перезапуска скрипта.
-- CASCADE автоматически удаляет связанные внешние ключи.
DROP TABLE IF EXISTS 
    order_items,
    order_review,
    payment,
    orders,
    products,
    sellers,
    customers,
    geolocation,
    category_name 
CASCADE;

-- Таблица клиентов: содержит информацию о локации покупателей.
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,          -- Временный ID для конкретного заказа
    customer_unique_id VARCHAR(50),               -- Постоянный уникальный ID клиента
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2)                     -- Двухбуквенный код штата (например, SP)
);

-- Таблица геолокации: координаты бразильских индексов (для построения карт).
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat DECIMAL(10,8),
    geolocation_lng DECIMAL(11,8),
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2)
);

-- Таблица транзакций: информация о способах оплаты и стоимости.
CREATE TABLE payment (
    order_id VARCHAR(50),
    payment_sequential INTEGER,                   -- Порядковый номер платежа (если платили несколькими картами)
    payment_type VARCHAR(20),                     -- Тип оплаты (credit_card, voucher, boleto и т.д.)
    payment_installments INTEGER,                 -- Количество долей/рассрочка
    payment_value DECIMAL(10,2),                  -- Итоговая сумма транзакции
    PRIMARY KEY (order_id, payment_sequential)
);

-- Таблица отзывов: оценки клиентов и текстовые комментарии.
CREATE TABLE order_review (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,                         -- Оценка от 1 до 5 звезд
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id)             -- Составной ключ (один клиент может оставить отзыв на разные части заказа)
);

-- Таблица заказов: ключевая таблица фактов с таймстампами жизненного цикла заказа.
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(20),                     -- Статус заказа (delivered, canceled, processing)
    order_purchase_timestamp TIMESTAMP,           -- Дата и время покупки
    order_approved_at TIMESTAMP,                  -- Время подтверждения оплаты
    order_delivered_carrier_date TIMESTAMP,       -- Время передачи в логистическую компанию
    order_delivered_customer_date TIMESTAMP,      -- Фактическое время доставки клиенту
    order_estimated_delivery_date TIMESTAMP       -- Обещанное (плановое) время доставки
);

-- Таблица товаров: физические параметры и категории продуктов.
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

-- Таблица продавцов: данные о зарегистрированных на маркетплейсе мерчантах.
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);

-- Таблица-словарик: перевод португальских категорий товаров на английский язык.
CREATE TABLE category_name (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

-- Содержимое заказов: связующая таблица (чек), фиксирующая цены и стоимость доставки товаров.
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INTEGER,                        -- Порядковый номер товара внутри одного чека (1, 2, 3...)
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2),                          -- Стоимость самого товара
    freight_value DECIMAL(10,2),                  -- Стоимость доставки товара (фрахт)
    PRIMARY KEY (order_id, order_item_id)
);


-- ==============================================================================
-- БЛОК 2. БАЗОВЫЕ МЕТРИКИ И ЭКОНОМИКА ЗАКАЗОВ
-- ==============================================================================

-- 2.1 Расчет полной стоимости каждого заказа (сумма цен всех позиций в чеке)
SELECT 
    o.order_id,
    SUM(oi.price) AS order_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id;

-- 2.2 Первичная динамика выручки маркетплейса, разбитая по месяцам
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    SUM(oi.price) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

-- 2.3 Анализ выручки и объема заказов в разрезе оригинальных португальских категорий
SELECT 
    p.product_category_name,
    SUM(oi.price) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders_count
FROM orders o 
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC;

-- 2.4 Расчет выручки, объема продаж и Среднего Чека (AOV) с переводом категорий на английский.
-- COALESCE подстраховывает от пустых значений, подставляя 'unknown'.
SELECT
    COALESCE(cn.product_category_name_english, p.product_category_name, 'unknown') AS category,
    SUM(oi.price) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders_count,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS aov
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_name cn ON p.product_category_name = cn.product_category_name
GROUP BY COALESCE(cn.product_category_name_english, p.product_category_name, 'unknown')
ORDER BY revenue DESC;

-- 2.5 Комплексный расчет: Средний чек (AOV) и среднее число товаров в одном корзине по всей базе
SELECT 
    ROUND(AVG(order_total), 2) AS avg_order_value,
    ROUND(AVG(items_count), 2) AS avg_items_per_order
FROM (
    SELECT 
        o.order_id,
        SUM(oi.price) AS order_total,
        COUNT(oi.order_item_id) AS items_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id
) t;


-- ==============================================================================
-- БЛОК 3. УГЛУБЛЕННЫЙ АНАЛИЗ ПРОДАЖ И ПОВЕДЕНИЯ КЛИЕНТОВ (SALES ANALYSIS)
-- ==============================================================================

-- 3.1 Детальный помесячный аудит продаж: выручка, заказы, средний чек и штуки проданных товаров.
-- Фильтрация по статусу 'delivered' гарантирует, что мы считаем только реальные, чистые деньги.
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS orders_count,
    SUM(oi.price) AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS aov,
    COUNT(oi.order_item_id) AS items_sold
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

-- 3.2 Географический анализ продаж: определение ключевых рынков сбыта по штатам Бразилии
SELECT 
    c.customer_state AS state,
    COUNT(DISTINCT o.order_id) AS orders_count,
    SUM(oi.price) AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS aov
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- 3.3 Выявление Топ-20 самых прибыльных продавцов (мерчантов) маркетплейса Olist
SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS orders_count,
    SUM(oi.price) AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS aov
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY revenue DESC
LIMIT 20;

-- 3.4 Расчет Repeat Purchase Rate: процент клиентов, совершивших более 1 покупки.
-- Показывает уровень лояльности аудитории маркетплейса.
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN orders_count > 1 THEN 1 END) AS repeat_customers,
    ROUND(COUNT(CASE WHEN orders_count > 1 THEN 1 END) * 100.0 / COUNT(*), 2) AS repeat_rate_pct
FROM customer_orders;


-- ==============================================================================
-- БЛОК 4. ОПЕРАЦИОННЫЙ АНАЛИЗ ЛОГИСТИКИ И КЛИЕНТСКОЙ УДОВЛЕТВОРЕННОСТИ
-- ==============================================================================

-- 4.1 Логистический аудит: расчет среднего времени доставки до двери клиента 
-- и доли посылок, приехавших позже обещанного дедлайна, в разрезе штатов.
SELECT 
    c.customer_state AS state,
    COUNT(o.order_id) AS total_delivered_orders,
    ROUND(AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)))::numeric, 1) AS avg_delivery_days,
    ROUND(
        (COUNT(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 END) * 100.0 / COUNT(o.order_id)), 2
    ) AS delayed_orders_percentage
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY delayed_orders_percentage DESC;
-- 4.2 Корреляционный анализ: влияние качества работы службы доставки на отзывы покупателей.
-- Доказывает прямую зависимость между задержкой посылки и обрушением рейтинга (review_score).
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
GROUP BY
CASE
WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Опоздал'
ELSE 'Вовремя'
END
ORDER BY avg_review_score DESC;



-- 3.5 ABC-анализ категорий

WITH category_revenue AS (
SELECT 
COALESCE(cn.product_category_name_english,p.product_category_name,'unknown') AS category,
SUM(oi.price) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN  products p on oi.product_id = p.product_id
LEFT JOIN category_name cn ON p.product_category_name =cn.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1
),
total AS (
SELECT SUM(revenue) as total_revenue FROM category_revenue
),
ranked AS (
	SELECT
		category,
		revenue,
		SUM(revenue) OVER (ORDER BY revenue DESC) AS cumulative_revenue,
		(SELECT total_revenue FROM total) as total_revenue
	FROM category_revenue
)
SELECT 
	category,
	revenue,
	ROUND(revenue / total_revenue * 100 , 2) AS revenue_share_pct,
	ROUND(cumulative_revenue / total_revenue * 100 , 2) AS cumulative_pct,
	CASE
		WHEN cumulative_revenue / total_revenue <= 0.80 THEN 'A'
		WHEN cumulative_revenue / total_revenue <= 0.95 THEN 'B'
		ELSE 'C'
	END AS abc_group
FROM ranked
ORDER BY revenue DESC;

-- 3.6 Доля выручки, которую дают Топ-10% продавцов
WITH seller_revenue AS (
	SELECT 
		s.seller_id,
		SUM(oi.price) AS revenue
	FROM orders o
	JOIN order_items oi ON o.order_id = oi.order_id
	JOIN sellers s ON oi.seller_id = s.seller_id
	WHERE o.order_status = 'delivered'
	GROUP BY s.seller_id
),
ranked AS (
	SELECT 
		seller_id,
		revenue,
		NTILE(10) OVER (ORDER BY revenue DESC) as decile
	FROM seller_revenue
)
SELECT 
	ROUND(SUM(CASE WHEN decile = 1 THEN revenue ELSE 0 END) * 100.0 / SUM(revenue), 2) AS top_10_pct_sellers_share
	FROM ranked;
	
-- 5.1 RFM-сегментация клиентов
WITH rfm_base AS (
	SELECT 
		c.customer_unique_id,
		MAX(o.order_purchase_timestamp) :: date AS last_purchase_date,
		COUNT(DISTINCT o.order_id) AS frequency,
		SUM(oi.price) AS monetary
	FROM orders o
	JOIN order_items oi ON o.order_id = oi.order_id
	JOIN customers c  ON o.customer_id = c.customer_id
	WHERE o.order_status = 'delivered'
	GROUP BY c.customer_unique_id
),
rfm_calc AS (
	SELECT 
		customer_unique_id,
		CURRENT_DATE -last_purchase_date as recency_days,
		frequency,
		monetary,
		NTILE(5) OVER (ORDER BY CURRENT_DATE - last_purchase_date DESC) AS r_score,
		NTILE(5) OVER (ORDER BY frequency) as f_score,
		NTILE(5) OVER (ORDER BY monetary) as m_score
	FROM rfm_base
)
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total_score
FROM rfm_calc
ORDER BY rfm_total_score DESC;