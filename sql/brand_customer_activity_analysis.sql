-- 🧠 GOAL:
-- Identify who's loyal, who's ghosting, and who's cheating on us with other brands.
-- Segment brand customers into: Active, Lapsing, Lapsed — and find out where the deserters went.

-- 🛠️ Parameters (set 'em and forget 'em)
DECLARE brand_key INT64;                -- Brand you're spying on
DECLARE brand_category STRING;          -- Optional filter for similar product categories
DECLARE start_date DATE;                
DECLARE end_date DATE;
DECLARE lookback_period INT64;          -- "How long before we call it ghosting?"

SET start_date = DATE_ADD(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY), INTERVAL -1 YEAR);
SET end_date = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY);
SET brand_key = 7206;
SET brand_category = 'Hair';


-- 🧾 Step 1: Who bought our stuff at all?
CREATE TEMP TABLE brand_customers AS
SELECT DISTINCT
  customer_id,
  MAX(order_date) AS last_order_date,
  DATE_DIFF(end_date, MAX(order_date), DAY) AS days_since_last_order,
  COUNT(DISTINCT order_id) AS total_orders
FROM `project.dataset.transactions`
WHERE order_date BETWEEN start_date AND end_date
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')  -- Sorry 🇺🇸🇦🇺, this one’s not about you
  AND units > 0
  AND payment_status = 'Paid'
  AND is_gift = FALSE
  AND brand_id = brand_key
  AND customer_id IS NOT NULL
GROUP BY customer_id;

-- 📉 Step 2: Let's check their order rhythm
WITH order_diffs AS (
  SELECT
    customer_id,
    order_id,
    order_date,
    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date,
    DATE_DIFF(order_date, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date), DAY) AS days_between
  FROM `project.dataset.transactions`
  WHERE brand_id = brand_key
    AND order_date BETWEEN start_date AND end_date
    AND business_unit = 'CORE'
    AND country_group NOT IN ('US', 'Australia')
    AND units > 0
    AND payment_status = 'Paid'
    AND is_gift = FALSE
    AND customer_id IS NOT NULL
),

-- 📊 Step 3: What’s the “normal” behavior anyway?
stats AS (
  SELECT
    AVG(days_between) AS avg_time,
    STDDEV(days_between) AS std_dev
  FROM order_diffs d
  JOIN brand_customers bc ON d.customer_id = bc.customer_id
  WHERE days_between IS NOT NULL AND bc.total_orders > 1 AND days_between > 0
),

-- 📏 Step 4: Determine who's out of rhythm
bounds AS (
  SELECT
    avg_time,
    std_dev,
    (avg_time - 2 * std_dev) AS lower_bound,
    (avg_time + 2 * std_dev) AS upper_bound
  FROM stats
),

-- 🧪 Step 5: Bucket 'em
customer_activity AS (
  SELECT DISTINCT
    d.customer_id,
    CASE 
      WHEN bc.days_since_last_order < b.avg_time THEN 'Active'
      WHEN bc.days_since_last_order BETWEEN b.avg_time AND (b.avg_time + b.std_dev) THEN 'Lapsing'
      WHEN bc.days_since_last_order > (b.avg_time + b.std_dev) THEN 'Lapsed'
      ELSE '¯\\_(ツ)_/¯'
    END AS activity_bucket
  FROM order_diffs d
  CROSS JOIN bounds b
  JOIN brand_customers bc ON d.customer_id = bc.customer_id
),

-- 🕵️‍♀️ Step 6: Betrayers still buying... just not *your* stuff
active_elsewhere AS (
  SELECT
    t.customer_id,
    t.category,
    t.brand_id AS alt_brand_id,
    t.brand_name AS alt_brand_name,
    COUNT(DISTINCT t.order_id) AS alt_orders
  FROM `project.dataset.transactions` t
  JOIN customer_activity ca ON t.customer_id = ca.customer_id
  JOIN brand_customers bc ON t.customer_id = bc.customer_id
  WHERE t.order_date BETWEEN start_date AND end_date
    AND ca.activity_bucket IN ('Lapsed', 'Lapsing')
    AND t.brand_id != brand_key
    AND t.order_date > bc.last_order_date
    AND t.business_unit = 'CORE'
    AND t.country_group NOT IN ('US', 'Australia')
    AND t.units > 0
    AND t.payment_status = 'Paid'
    AND t.is_gift = FALSE
    AND t.customer_id IS NOT NULL
  GROUP BY t.customer_id, t.category, t.brand_id, t.brand_name
)

-- 🎉 Final report: Tell the story with numbers
SELECT 'Total Brand Customers' AS segment, COUNT(DISTINCT customer_id) AS customers, 1 AS sort_order
FROM customer_activity

UNION ALL

SELECT 'Active Customers', COUNT(DISTINCT customer_id), 2
FROM customer_activity
WHERE activity_bucket = 'Active'

UNION ALL

SELECT 'Lapsing Customers', COUNT(DISTINCT customer_id), 3
FROM customer_activity
WHERE activity_bucket = 'Lapsing'

UNION ALL

SELECT 'Lapsed Customers', COUNT(DISTINCT customer_id), 4
FROM customer_activity
WHERE activity_bucket = 'Lapsed'

UNION ALL

SELECT 'Lapsed/Lapsing Active Elsewhere', COUNT(DISTINCT customer_id), 5
FROM active_elsewhere

UNION ALL

SELECT CONCAT('Moved to Brand ', alt_brand_name), COUNT(DISTINCT customer_id), 6
FROM active_elsewhere
WHERE category = brand_category
GROUP BY alt_brand_name

ORDER BY sort_order, customers DESC;
