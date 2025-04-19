-- 🎯 GOAL:
-- Segment customers by type based on their order frequency across years.
-- Distinguish between one-time buyers, consistently infrequent buyers, and everyone else.

-- 🧮 PARAMETERS
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE brand_keys ARRAY<INT64>;
DECLARE category_filter STRING;

-- Analyze two past years (adjustable)
SET start_date = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 3, 1, 1);
SET end_date   = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 1, 12, 31);

-- Define brand filter
SET brand_keys = [101, 102, 103];  -- replace with anonymized keys
SET category_filter = 'Fragrance';

--------------------------------------------------------------------------------
-- STEP 1: Count number of orders per customer, per year
--------------------------------------------------------------------------------
WITH per_year_orders AS (
  SELECT
    customer_id,
    EXTRACT(YEAR FROM order_date) AS order_year,
    COUNT(DISTINCT order_id) AS orders_per_year
  FROM `project.dataset.transactions`
  WHERE order_date BETWEEN start_date AND end_date
    AND brand_id IN UNNEST(brand_keys)
    AND site_id = 37
    AND country_group NOT IN ('US','Australia')
    AND units > 0
    AND is_gift = FALSE
    AND payment_status = 'Paid'
    AND gross_revenue > 0
    AND category = category_filter
  GROUP BY customer_id, order_year
),

--------------------------------------------------------------------------------
-- STEP 2: Summarize per customer across all years
--------------------------------------------------------------------------------
customer_summary AS (
  SELECT
    customer_id,
    SUM(orders_per_year) AS total_orders,
    COUNT(DISTINCT order_year) AS years_bought,
    COUNTIF(orders_per_year = 1) AS years_with_exactly_one
  FROM per_year_orders
  GROUP BY customer_id
),

--------------------------------------------------------------------------------
-- STEP 3: Classify customers into types
--------------------------------------------------------------------------------
customer_classification AS (
  SELECT
    customer_id,
    total_orders,
    years_bought,
    CASE
      WHEN total_orders = 1 THEN 'one_time'
      WHEN years_bought > 1 AND years_bought = years_with_exactly_one THEN 'consistent_once'
      ELSE 'other'
    END AS buyer_type
  FROM customer_summary
)

--------------------------------------------------------------------------------
-- STEP 4: Aggregate classification results by year
--------------------------------------------------------------------------------
SELECT
  pyo.order_year,
  SUM(CASE WHEN cc.buyer_type = 'one_time' THEN 1 ELSE 0 END) AS one_time_buyers,
  SUM(CASE WHEN cc.buyer_type = 'consistent_once' THEN 1 ELSE 0 END) AS consistent_once_buyers,
  SUM(CASE WHEN cc.buyer_type = 'other' THEN 1 ELSE 0 END) AS other_buyers,
  COUNT(DISTINCT pyo.customer_id) AS total_customers
FROM per_year_orders pyo
JOIN customer_classification cc ON pyo.customer_id = cc.customer_id
GROUP BY pyo.order_year
ORDER BY pyo.order_year;
