-- 🧠 Goal: Identify top co-purchased products for selected brands
-- Tracks which other products are commonly found in the same basket
-- as a target brand’s product, based on historical transaction data

-- ⚙️ Parameters
DECLARE target_brands ARRAY<INT64>;
DECLARE start_date DATE;
DECLARE end_date DATE;

SET start_date = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), YEAR);
SET end_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

SET target_brands = [101, 102, 103, 104];  -- example brand keys

-- 🎯 Orders containing target brands
CREATE TEMP TABLE brand_orders AS
SELECT DISTINCT
     o.business_unit,
     o.order_number
FROM `project.dataset.transactions` o
LEFT JOIN `project.dataset.brand_lookup` b
  ON o.brand_key = b.brand_key
JOIN `project.dataset.products` p
  ON o.product_id = p.product_id
WHERE o.order_date BETWEEN start_date AND end_date
  AND o.units > 0
  AND o.payment_status = 'Paid'
  AND o.is_gwp = FALSE
  AND o.brand_key IN UNNEST(target_brands);

-- 🧺 All orders in scope (for basket joins)
CREATE TEMP TABLE all_orders AS
SELECT DISTINCT
     o.business_unit,
     o.order_number,
     o.brand_key,
     o.brand_name,
     o.product_id,
     p.product_title
FROM `project.dataset.transactions` o
LEFT JOIN `project.dataset.brand_lookup` b
  ON o.brand_key = b.brand_key
JOIN `project.dataset.products` p
  ON o.product_id = p.product_id
WHERE o.order_date BETWEEN start_date AND end_date
  AND o.units > 0
  AND o.payment_status = 'Paid'
  AND o.is_gwp = FALSE;

-- 🔄 Join baskets to see co-occurring products
WITH Basket_Joined AS (
  SELECT
    a.business_unit,
    a.brand_name AS target_brand,
    a.product_id AS target_product_id,
    a.product_title AS target_product_title,
    b.brand_name AS co_brand,
    b.product_id AS co_product_id,
    b.product_title AS co_product_title,
    COUNT(DISTINCT a.order_number) AS orders_together
  FROM all_orders a
  JOIN all_orders b
    ON a.order_number = b.order_number
    AND a.business_unit = b.business_unit
    AND a.product_id != b.product_id
  WHERE a.brand_key IN UNNEST(target_brands)
  GROUP BY 
    a.business_unit,
    a.brand_name,
    a.product_id,
    a.product_title,
    b.brand_name,
    b.product_id,
    b.product_title
),
Ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY target_product_id ORDER BY orders_together DESC) AS rank
  FROM Basket_Joined
)
-- 🏆 Final output: Top 3 co-occurring products per product
SELECT *
FROM Ranked
WHERE rank <= 3
ORDER BY business_unit, target_product_id, orders_together DESC;




