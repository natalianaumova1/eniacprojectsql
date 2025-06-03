USE magist123;

-- 4. How many products are there in the products table?
-- 32951

SELECT COUNT(DISTINCT product_id) AS products_count
FROM products;

-- 5. Which are the categories with the most products? 

SELECT t.product_category_name_english AS product_category,
COUNT(*) AS products_total
FROM products p
LEFT JOIN product_category_name_translation t 
ON p.product_category_name = t.product_category_name
GROUP BY p.product_category_name
ORDER BY products_total DESC;

-- 6. How many of those products were present in actual transactions? 
-- The products table is a “reference” of all the available products. 
-- Have all these products been involved in orders? Check out the order_items table to find out!

SELECT COUNT(DISTINCT product_id) AS distinct_produts_sold
FROM order_items;

-- 7. What’s the price for the most expensive and cheapest products?
-- 0.85 , 6735

SELECT MIN(price) AS cheapest, MAX(price) AS most_expensive
FROM order_items;

-- 8. What are the highest and lowest payment values?

SELECT MAX(payment_value) as highest, MIN(payment_value) as lowest
FROM order_payments;

-- Maximum someone has paid for an order - 13664:

SELECT SUM(payment_value) AS highest_order
FROM order_payments
GROUP BY order_id
ORDER BY highest_order DESC
LIMIT 1;

-- 2.1. In relation to the products:
-- What categories of tech products does Magist have?

CREATE TABLE product_categories_tech_type AS
SELECT product_id, t.product_category_name_english AS product_category,
  CASE
    WHEN t.product_category_name_english IN ('tablets_printing_image', 'signaling_and_security', 'portable_kitchen_food_processors', 'small_appliances_home_oven_and_coffee', 'housewares', 'security_and_services', 'computers', 'pc_gamer', 'computers_accessories', 'electronics', 'small_appliances', 'home_appliances_2', 'home_appliances', 'consoles_games') THEN 'tech_products'
    ELSE 'non_tech_products'
  END AS category_type
FROM products p
LEFT JOIN product_category_name_translation t 
ON p.product_category_name = t.product_category_name;

-- DROP TABLE IF EXISTS product_categories_tech_type;

-- How many products of these tech categories have been sold (within the time window of the database snapshot)? 

SELECT COUNT(*) AS tech_products_sold
FROM product_categories_tech_type tech
LEFT JOIN order_items 
ON tech.product_id = order_items.product_id
WHERE tech.category_type = 'tech_products';

-- What percentage does that represent from the overall number of products sold?

SELECT
  ROUND(
    100.0 * SUM(CASE WHEN tech.category_type = 'tech_products' THEN 1 ELSE 0 END) / COUNT(*),
    2
  ) AS tech_product_percentage
FROM product_categories_tech_type tech
JOIN order_items
  ON tech.product_id = order_items.product_id;

-- Tech product items 18.62%

-- What’s the average price of the products being sold?

SELECT ROUND(AVG(price), 2) AS average_price
FROM order_items;

-- Average price is 120.65

-- Are expensive tech products popular?

SELECT tech.product_category,
  COUNT(*) AS total_sales,
  AVG(order_items.price) AS avg_price
FROM product_categories_tech_type tech
JOIN order_items ON tech.product_id = order_items.product_id
WHERE tech.category_type = 'tech_products'
GROUP BY tech.product_category
ORDER BY total_sales DESC;

-- 2.2. In relation to the sellers:
-- How many months of data are included in the magist database?

SELECT
  MIN(DATE_FORMAT(order_purchase_timestamp, '%Y-%m')) AS first_month,
  MAX(DATE_FORMAT(order_purchase_timestamp, '%Y-%m')) AS last_month,
  TIMESTAMPDIFF(
    MONTH,
    MIN(order_purchase_timestamp),
    MAX(order_purchase_timestamp)
  ) + 1 AS total_months
FROM orders;

-- How many sellers are there? How many Tech sellers are there? What percentage of overall sellers are Tech sellers?

SELECT COUNT(seller_id) AS seller_count
FROM sellers;

SELECT COUNT(DISTINCT i.seller_id) AS seller_count
FROM order_items AS i
LEFT JOIN products AS p ON i.product_id = p.product_id
LEFT JOIN product_categories_tech_type AS t ON p.product_id = t.product_id
WHERE category_type = 'tech_products';

-- What is the total amount earned by all sellers? 

SELECT ROUND(
	SUM(oi.price), 2) AS total_profit
FROM order_items AS oi
LEFT JOIN product_categories_tech_type AS t ON oi.product_id = t.product_id;

-- What is the total amount earned by all Tech sellers?

SELECT category_type, ROUND(
	SUM(oi.price), 2) AS total_profit_by_sellers
FROM order_items AS oi
LEFT JOIN product_categories_tech_type AS t ON oi.product_id = t.product_id
GROUP BY category_type;

-- Can you work out the average monthly income of all sellers? 
-- 424628.72
-- Can you work out the average monthly income of Tech sellers? 
-- 98126.81

SELECT category_type, ROUND(
	SUM(oi.price) / 26, 2) AS avg_monthly_profit_by_sellers
FROM order_items AS oi
LEFT JOIN product_categories_tech_type AS t ON oi.product_id = t.product_id
GROUP BY category_type;

-- Profit tech sellers by month

SELECT 
  DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
  ROUND(SUM(oi.price), 2) AS monthly_tech_profit
FROM order_items AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN product_categories_tech_type AS t 
  ON oi.product_id = t.product_id
WHERE t.category_type = 'tech_products'
GROUP BY order_month
ORDER BY order_month;

-- Profit all sellers by month

SELECT 
  DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
  ROUND(SUM(oi.price), 2) AS monthly_profit
FROM order_items AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN product_categories_tech_type AS t 
  ON oi.product_id = t.product_id
GROUP BY order_month
ORDER BY order_month;

-- 2.3. In relation to the delivery time:
-- What’s the average time between the order being placed and the product being delivered?
-- 12.5 days

SELECT ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

-- How many orders are delivered on time vs orders delivered with a delay?
-- On time 88649 / delayed 7827

CREATE TABLE delayed_orders AS
SELECT order_id, customer_id,
  CASE 
    WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'on_time'
    ELSE 'delayed'
  END AS delivery_status
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- Is there any pattern for delayed orders, e.g. big products being delayed more often?

SELECT
  CASE 
    WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'on_time'
    ELSE 'delayed'
  END AS delivery_status,
  ROUND(AVG(oi.freight_value), 2) AS avg_freight_value,
  COUNT(*) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status;







