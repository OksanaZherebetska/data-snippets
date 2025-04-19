-- 🎯 GOAL:
-- Analyze customer orders before and after their first luxury order.
-- Classify orders by brand submarket type (Mass, Prestige, Lux) relative to that luxury event.

-- 🧮 PARAMETERS
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE brand_keys ARRAY<INT64>;
DECLARE luxury_category STRING;

-- Analyze data from 3 years ago up to last year
SET start_date = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 3, 1, 1);
SET end_date   = DATE(EXTRACT(YEAR FROM CURRENT_DATE()) - 1, 12, 31);

-- Define luxury brands and the luxury category (e.g., Fragrance)
SET brand_keys = [101, 102, 103];  -- replace with anonymized brand keys
SET luxury_category = 'Fragrance';

-- 📦 STEP 1: Filter orders using core business rules
WITH base_orders AS (
  SELECT 
    customer_id,
    order_id,
    order_date,
    order_sequence,
    brand_id,
    category,
    EXTRACT(YEAR FROM order_date) AS order_year
  FROM `project.dataset.transactions`
  WHERE order_date BETWEEN start_date AND end_date
    AND site_id = 37
    AND country_group NOT IN ('US', 'Australia')
    AND units > 0
    AND is_gift = FALSE
    AND payment_status = 'Paid'
    AND gross_revenue > 0
),

-- 💎 STEP 2: Identify first luxury order per customer
lux_orders AS (
  SELECT
    customer_id,
    MIN(order_sequence) AS lux_seq,
    MIN(order_date) AS lux_date
  FROM base_orders
  WHERE brand_id IN UNNEST(brand_keys)
    AND category = luxury_category
  GROUP BY customer_id
),

-- 📑 STEP 3: Roll up order history with sequence info
customer_orders AS (
  SELECT
    customer_id,
    order_id,
    MIN(order_date) AS order_date,
    MIN(order_sequence) AS order_sequence,
    ARRAY_AGG(DISTINCT brand_id) AS brand_ids,
    EXTRACT(YEAR FROM MIN(order_date)) AS order_year
  FROM base_orders
  WHERE customer_id IN (SELECT customer_id FROM lux_orders)
  GROUP BY customer_id, order_id
),

orders_with_rn AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_sequence) AS rn
  FROM customer_orders
),

-- 🔁 STEP 4: Tag each order relative to luxury order (before/after)
lux_index AS (
  SELECT o.customer_id, MIN(o.rn) AS lux_rn
  FROM orders_with_rn o
  JOIN lux_orders l ON o.customer_id = l.customer_id AND o.order_date = l.lux_date AND o.order_sequence = l.lux_seq
  GROUP BY o.customer_id
),

orders_relative AS (
  SELECT
    o.customer_id,
    o.order_id,
    o.order_date,
    o.order_sequence,
    o.brand_ids,
    o.order_year,
    (o.rn - l.lux_rn) AS order_from_lux
  FROM orders_with_rn o
  JOIN lux_index l ON o.customer_id = l.customer_id
),

-- 🧠 STEP 5: Classify each order by brand submarket
orders_with_type AS (
  SELECT 
    o.customer_id,
    o.order_id,
    o.order_date,
    o.order_sequence,
    o.order_year,
    o.order_from_lux,
    SUM(CASE WHEN ba.brand_submarket IN ('Mass','Masstige') THEN 1 ELSE 0 END) AS mass,
    SUM(CASE WHEN ba.brand_submarket = 'Prestige' THEN 1 ELSE 0 END) AS prestige,
    SUM(CASE WHEN ba.brand_submarket = 'Prestige-Lux' THEN 1 ELSE 0 END) AS prestige_lux,
    SUM(CASE WHEN ba.brand_submarket NOT IN ('Mass','Masstige','Prestige','Prestige-Lux') THEN 1 ELSE 0 END) AS na
  FROM orders_relative o,
       UNNEST(o.brand_ids) AS brand_id
  LEFT JOIN `project.dataset.brand_metadata` ba ON ba.brand_id = brand_id
  GROUP BY 
    o.customer_id, o.order_id, o.order_date, o.order_sequence, o.order_year, o.order_from_lux
),

final_classified_orders AS (
  SELECT 
    customer_id,
    order_id,
    order_date,
    order_sequence,
    order_year,
    order_from_lux,
    mass,
    prestige,
    prestige_lux,
    CASE 
      WHEN mass = 1 AND prestige = 0 AND prestige_lux = 0 AND na = 0 THEN 'Mass_Only'
      WHEN mass = 1 AND prestige = 1 AND prestige_lux = 0 THEN 'Mass_Prestige_Combo'
      WHEN mass = 1 AND prestige = 0 AND prestige_lux = 1 THEN 'Mass_Lux_Combo'
      WHEN mass = 0 AND prestige = 1 AND prestige_lux = 0 THEN 'Prestige_Only'
      WHEN mass = 0 AND prestige = 0 AND prestige_lux = 1 THEN 'Lux_Only'
      WHEN mass = 0 AND prestige = 1 AND prestige_lux = 1 THEN 'Lux_Prestige_Combo'
    END AS order_type
  FROM orders_with_type
)

-- 📊 FINAL AGGREGATION: Orders grouped by relative position and type
SELECT
  order_year,
  order_from_lux,
  order_type,
  COUNT(*) AS orders_count,
  SUM(mass) AS total_mass,
  SUM(prestige) AS total_prestige,
  SUM(prestige_lux) AS total_prestige_lux
FROM final_classified_orders
WHERE order_from_lux BETWEEN -5 AND 5
GROUP BY order_year, order_from_lux, order_type
ORDER BY order_year, order_from_lux;
