-- 🎯 GOAL:
-- Compare the top products for new vs returning customers in a given category.
-- See who’s making the biggest splash and who’s just vibing.

-- 🧮 PARAMETERS
DECLARE brand_key INT64;
DECLARE brand_category STRING;
DECLARE start_date DATE;
DECLARE end_date DATE;

SET brand_key = 1234;               -- Target brand
SET brand_category = 'Fragrance';   -- Choose your arena
SET start_date = DATE_ADD(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY), INTERVAL -1 YEAR);
SET end_date = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY);

-- 🧼 Clean & rank new customers
CREATE TEMP TABLE new_cust_products AS
SELECT
  RANK() OVER (ORDER BY SUM(units) DESC) AS rank_ntb,
  product_id,
  product_title,
  category,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(DISTINCT order_id) AS orders,
  SUM(units) AS total_units,
  SUM(gross_revenue) AS revenue
FROM `project.dataset.transactions` t
JOIN `project.dataset.products` p ON t.product_id = p.product_id
WHERE order_date BETWEEN start_date AND end_date
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US','Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key
  AND customer_id IS NOT NULL
  AND is_new_brand = TRUE
  AND category = brand_category
GROUP BY 2, 3, 4
ORDER BY total_units DESC
LIMIT 10;

-- 🧼 Clean & rank returning customers
CREATE TEMP TABLE returning_cust_products AS
SELECT
  RANK() OVER (ORDER BY SUM(units) DESC) AS rank_rtb,
  product_id,
  product_title,
  category,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(DISTINCT order_id) AS orders,
  SUM(units) AS total_units,
  SUM(gross_revenue) AS revenue
FROM `project.dataset.transactions` t
JOIN `project.dataset.products` p ON t.product_id = p.product_id
WHERE order_date BETWEEN start_date AND end_date
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US','Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key
  AND customer_id IS NOT NULL
  AND is_new_brand = FALSE
  AND category = brand_category
GROUP BY 2, 3, 4
ORDER BY total_units DESC
LIMIT 10;

-- ⚔️ Face-off: Newbies vs Returnees
WITH merged_products AS (
  SELECT 
    ntb.rank_ntb,
    ntb.product_id AS ntb_product_id,
    ntb.product_title AS ntb_product_title,
    ntb.category AS ntb_category,
    ntb.customers AS ntb_customers,
    ntb.orders AS ntb_orders,
    ntb.total_units AS ntb_units,
    ntb.revenue AS ntb_revenue,

    rtb.rank_rtb,
    rtb.product_id AS rtb_product_id,
    rtb.product_title AS rtb_product_title,
    rtb.category AS rtb_category,
    rtb.customers AS rtb_customers,
    rtb.orders AS rtb_orders,
    rtb.total_units AS rtb_units,
    rtb.revenue AS rtb_revenue,

    ntb.rank_ntb - rtb.rank_rtb AS rank_diff_ntb_vs_rtb,
    rtb.rank_rtb - ntb.rank_ntb AS rank_diff_rtb_vs_ntb
  FROM new_cust_products ntb
  FULL OUTER JOIN returning_cust_products rtb
    ON ntb.product_id = rtb.product_id
)

-- 📊 Final Comparison: Who’s hot where?
SELECT
  rank_ntb,
  rank_diff_ntb_vs_rtb,
  ntb_product_id,
  ntb_product_title,
  ntb_category,
  ntb_customers,
  ntb_units,
  ntb_revenue,

  rank_rtb,
  rank_diff_rtb_vs_ntb,
  rtb_product_id,
  rtb_product_title,
  rtb_category,
  rtb_customers,
  rtb_units,
  rtb_revenue
FROM merged_products
ORDER BY rank_ntb NULLS LAST;
