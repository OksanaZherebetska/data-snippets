-- 🎯 GOAL:
-- Count how many customers placed 1, 2, 3, or 4+ luxury orders last year (within a category).
-- Focus on frequency distribution, clean and simple.

-- 🧮 PARAMETERS
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE brand_keys ARRAY<INT64>;
DECLARE brand_category STRING;

-- Analyze previous full calendar year
SET start_date = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 1, 1, 1);
SET end_date   = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 1, 12, 31);

-- Define luxury brand IDs
SET brand_keys = [101, 102, 103];  -- replace with anonymized keys

-- Define focus category (e.g., Fragrance, Skin)
SET brand_category = 'Fragrance';

-- 🛒 STEP 1: Select qualifying orders
CREATE TEMP TABLE qualified_orders AS
SELECT
  business_unit,
  site,
  site_id,
  region,
  customer_id,
  order_id,
  order_sequence,
  EXTRACT(YEAR FROM order_date) AS order_year,
  order_date,
  category,
  1 AS is_lux_order
FROM `project.dataset.transactions`
WHERE order_date BETWEEN start_date AND end_date
  AND site_id = 37
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND is_gift = FALSE
  AND payment_status = 'Paid'
  AND gross_revenue > 0
  AND brand_id IN UNNEST(brand_keys);

-- 📦 STEP 2: Count orders per customer in the target category
CREATE TEMP TABLE order_counts AS
SELECT
  customer_id,
  COUNT(DISTINCT order_id) AS orders
FROM qualified_orders
WHERE category = brand_category
GROUP BY customer_id;

-- 📊 STEP 3: Bucket customers by order count
WITH frequency_buckets AS (
  SELECT
    CASE 
      WHEN o.orders = 1 THEN '1 order'
      WHEN o.orders = 2 THEN '2 orders'
      WHEN o.orders = 3 THEN '3 orders'
      ELSE '4 or more orders'
    END AS order_frequency,
    COUNT(o.customer_id) AS num_customers,
    CASE 
      WHEN o.orders = 1 THEN 1
      WHEN o.orders = 2 THEN 2
      WHEN o.orders = 3 THEN 3
      ELSE 4
    END AS sort_order
  FROM order_counts o
  GROUP BY order_frequency, sort_order
)

-- ✅ FINAL: Sorted frequency distribution
SELECT order_frequency, num_customers
FROM frequency_buckets
ORDER BY sort_order;
