-- 🎯 GOAL:
-- Calculate the average number of days between orders for customers of a given brand and category.
-- Focus: last month of previous year.

-- 🧮 PARAMETERS
DECLARE brand_key INT64;
DECLARE brand_category STRING;
DECLARE start_date DATE;
DECLARE end_date DATE;

SET start_date = DATE_ADD(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY), INTERVAL -1 YEAR);
SET end_date = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY);
SET brand_key = 1234;         -- Brand to analyze
SET brand_category = 'Body';  -- Product category

-- 🧾 STEP 1: Get customer-level aggregates for the selected brand + category
CREATE TEMP TABLE brand_customers AS
SELECT DISTINCT
  customer_id,
  MAX(order_date) AS last_order_date,
  DATE_DIFF(end_date, MAX(order_date), DAY) AS days_since_last_order,
  COUNT(DISTINCT order_id) AS total_orders
FROM `project.dataset.transactions`
WHERE order_date BETWEEN start_date AND end_date
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND is_gift = FALSE
  AND brand_id = brand_key
  AND category = brand_category
  AND customer_id IS NOT NULL
GROUP BY customer_id;

-- 📊 STEP 2: Calculate days between each customer's orders
WITH order_diffs AS (
  SELECT
    customer_id,
    order_id,
    order_date,
    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date,
    DATE_DIFF(order_date, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date), DAY) AS days_between
  FROM `project.dataset.transactions`
  WHERE brand_id = brand_key
    AND category = brand_category
    AND order_date BETWEEN start_date AND end_date
    AND business_unit = 'CORE'
    AND country_group NOT IN ('US', 'Australia')
    AND units > 0
    AND payment_status = 'Paid'
    AND is_gift = FALSE
    AND customer_id IS NOT NULL
)

-- 🧠 STEP 3: Get average reorder time (excluding single-order users & nulls)
SELECT
  AVG(days_between) AS avg_days_between_orders,
  STDDEV(days_between) AS std_dev_between_orders
FROM order_diffs d
JOIN brand_customers c USING(customer_id)
WHERE days_between IS NOT NULL
  AND c.total_orders > 1
  AND days_between > 0;
