create database shopping_db;
use shopping_db;
Select * from shopping_behavior;
Describe shopping_behavior;

CREATE TABLE shopping_behavior_clean (
    customer_id INT NOT NULL,
    age INT,
    gender VARCHAR(10),
    item_purchased VARCHAR(100),
    category VARCHAR(50),
    purchase_amount_usd DECIMAL(10,2),
    location VARCHAR(100),
    size VARCHAR(10),
    color VARCHAR(50),
    season VARCHAR(20),
    review_rating DECIMAL(3,1),
    subscription_status ENUM('Yes','No'),
    shipping_type VARCHAR(50),
    discount_applied ENUM('Yes','No'),
    promo_code_used ENUM('Yes','No'),
    previous_purchases INT,
    payment_method VARCHAR(50),
    frequency_of_purchases VARCHAR(50),
    PRIMARY KEY (customer_id, item_purchased) -- composite if needed
);

INSERT INTO shopping_behavior_clean
SELECT 
    `ï»¿Customer ID`,
    Age,
    Gender,
    `Item Purchased`,
    Category,
    CAST(`Purchase Amount (USD)` AS DECIMAL(10,2)),
    Location,
    Size,
    Color,
    Season,
    CAST(`Review Rating` AS DECIMAL(3,1)),
    `Subscription Status`,
    `Shipping Type`,
    `Discount Applied`,
    `Promo Code Used`,
    `Previous Purchases`,
    `Payment Method`,
    `Frequency of Purchases`
FROM shopping_behavior;

Select * from shopping_behavior_clean;
Describe shopping_behavior_clean;

-- Count rows
SELECT COUNT(*) FROM shopping_behavior_clean;

-- Check ranges
SELECT MIN(age), MAX(age) FROM shopping_behavior_clean;
SELECT MIN(purchase_amount_usd), MAX(purchase_amount_usd) FROM shopping_behavior_clean;
SELECT MIN(review_rating), MAX(review_rating) FROM shopping_behavior_clean;

-- Check distinct values for flags
SELECT DISTINCT subscription_status FROM shopping_behavior_clean;
SELECT DISTINCT discount_applied FROM shopping_behavior_clean;
SELECT DISTINCT promo_code_used FROM shopping_behavior_clean;

-- 1. Drop old version if it exists
DROP TABLE IF EXISTS shopping_facts;

-- 2. Create shopping_facts table
CREATE TABLE shopping_facts AS
SELECT
    customer_id,
    age,
    
    -- Derived: Age group
    CASE 
        WHEN age < 25 THEN '<25'
        WHEN age BETWEEN 25 AND 40 THEN '25-40'
        ELSE '40+'
    END AS age_group,
    
    gender,
    item_purchased,
    category,
    purchase_amount_usd,
    location,
    size,
    color,
    season,
    
    review_rating,
    
    -- Convert subscription flag to boolean
    CASE WHEN subscription_status = 'Yes' THEN 1 ELSE 0 END AS is_subscribed,
    
    shipping_type,
    
    -- Convert discount and promo flags
    CASE WHEN discount_applied = 'Yes' THEN 1 ELSE 0 END AS is_discounted,
    CASE WHEN promo_code_used = 'Yes' THEN 1 ELSE 0 END AS is_promo_used,
    
    previous_purchases,
    
    -- Derived: repeat customer flag
    CASE WHEN previous_purchases > 0 THEN 1 ELSE 0 END AS is_repeat_customer,
    
    payment_method,
    frequency_of_purchases,
    
    -- Derived: revenue metric (can adjust later)
    purchase_amount_usd AS total_value
    
FROM shopping_behavior_clean;

-- Count rows (should equal original table)
SELECT COUNT(*) FROM shopping_facts;

-- Check age groups distribution
SELECT age_group, COUNT(*) 
FROM shopping_facts 
GROUP BY age_group;

-- Check discount/promo flags
SELECT is_discounted, COUNT(*) FROM shopping_facts GROUP BY is_discounted;
SELECT is_promo_used, COUNT(*) FROM shopping_facts GROUP BY is_promo_used;

-- Check subscription vs repeat customers
SELECT is_subscribed, is_repeat_customer, COUNT(*) 
FROM shopping_facts 
GROUP BY is_subscribed, is_repeat_customer;

-- Check revenue sanity
SELECT SUM(total_value) AS total_revenue FROM shopping_facts;

-- 1. Category performance
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
    category,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_purchase_amount,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_discounted)/COUNT(*),2) AS discount_rate_pct,
    ROUND(100.0 * SUM(is_promo_used)/COUNT(*),2) AS promo_use_pct
FROM shopping_facts
GROUP BY category
ORDER BY total_revenue DESC;


-- 2. Customer segmentation
CREATE OR REPLACE VIEW v_customer_segments AS
SELECT
    age_group,
    is_subscribed,
    frequency_of_purchases,
    COUNT(DISTINCT customer_id) AS customers,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_order_value,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_repeat_customer)/COUNT(*),2) AS repeat_rate_pct
FROM shopping_facts
GROUP BY age_group, is_subscribed, frequency_of_purchases
ORDER BY total_revenue DESC;


-- 3. Shipping & CX analysis
CREATE OR REPLACE VIEW v_shipping_cx AS
SELECT
    shipping_type,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_purchase_amount,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_discounted)/COUNT(*),2) AS discount_rate_pct
FROM shopping_facts
GROUP BY shipping_type;




-- 4. Payment method analysis
CREATE OR REPLACE VIEW v_payment_stats AS
SELECT
    payment_method,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_order_value,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_repeat_customer)/COUNT(*),2) AS repeat_rate_pct
FROM shopping_facts
GROUP BY payment_method;




-- 5. Promo effectiveness
CREATE OR REPLACE VIEW v_promo_effects AS
SELECT
    is_promo_used,
    is_discounted,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_order_value,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_repeat_customer)/COUNT(*),2) AS repeat_rate_pct
FROM shopping_facts
GROUP BY is_promo_used, is_discounted;




-- 6. Hotspots (Category × Location)
CREATE OR REPLACE VIEW v_hotspots AS
SELECT
    category,
    location,
    COUNT(*) AS orders,
    SUM(total_value) AS total_revenue,
    ROUND(AVG(total_value),2) AS avg_purchase_amount,
    ROUND(AVG(review_rating),2) AS avg_review_rating,
    ROUND(100.0 * SUM(is_discounted)/COUNT(*),2) AS discount_rate_pct
FROM shopping_facts
GROUP BY category, location
HAVING COUNT(*) >= 20;



-- Total rows match?
SELECT COUNT(*) FROM shopping_behavior_clean;
SELECT COUNT(*) FROM shopping_facts;

-- Total revenue matches across tables
SELECT SUM(CAST(`Purchase Amount (USD)` AS DECIMAL(10,2))) FROM shopping_behavior;
SELECT SUM(total_value) FROM shopping_facts;

-- Ratings are within 1–5
SELECT MIN(review_rating), MAX(review_rating) FROM shopping_facts;

-- Distinct age groups
SELECT age_group, COUNT(*) FROM shopping_facts GROUP BY age_group;


-- Total rows (should equal ~3900, same as original CSV)
SELECT COUNT(*) FROM shopping_facts;

-- Preview first 10 rows
SELECT * FROM shopping_facts LIMIT 10;

-- Revenue sanity check
SELECT SUM(total_value) AS total_revenue FROM shopping_facts;

-- Age group distribution
SELECT age_group, COUNT(*) AS customers FROM shopping_facts GROUP BY age_group;

SELECT * FROM v_category_performance ORDER BY total_revenue DESC LIMIT 10;

SELECT * FROM v_customer_segments ORDER BY total_revenue DESC LIMIT 10;

SELECT * FROM v_shipping_cx ORDER BY avg_review_rating DESC;

SELECT * FROM v_payment_stats ORDER BY total_revenue DESC;

SELECT * FROM v_promo_effects ORDER BY total_revenue DESC;

SELECT * FROM v_hotspots ORDER BY total_revenue DESC LIMIT 10;


-- Basic sanity checks:
-- Orders in facts = sum of all views?
SELECT COUNT(*) FROM shopping_facts;

-- Total revenue across everything
SELECT SUM(total_value) FROM shopping_facts;

-- Spot anomalies:
-- Any negative or zero purchase amounts?
SELECT * FROM shopping_facts WHERE total_value <= 0;

-- Ratings outside 1–5 range?
SELECT * FROM shopping_facts WHERE review_rating < 1 OR review_rating > 5;

-- Customers with weird ages
SELECT * FROM shopping_facts WHERE age < 10 OR age > 100;

-- 1. Category Performance
SELECT * FROM v_category_performance ORDER BY total_revenue DESC LIMIT 5;

-- 2. Customer Segments
SELECT * FROM v_customer_segments ORDER BY total_revenue DESC LIMIT 5;

-- 3. Shipping & CX
SELECT * FROM v_shipping_cx ORDER BY avg_review_rating DESC;

-- 4. Payment Method
SELECT * FROM v_payment_stats ORDER BY total_revenue DESC;

-- 5. Promo Effectiveness
SELECT * FROM v_promo_effects;

-- 6. Hotspots
SELECT * FROM v_hotspots ORDER BY total_revenue DESC LIMIT 10;


