-- 🎯 GOAL:
-- Calculate customer retention over a 3-year period for a given brand.
-- Track how many customers from Year 1 stayed active in Year 2 and Year 3.

-- 🧮 PARAMETERS
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE brand_key INT64;
DECLARE start_year INT64;

-- Set rolling 3-year window
SET start_year = EXTRACT(YEAR FROM CURRENT_DATE()) - 3;
SET start_date = DATE(start_year, 1, 1);
SET end_date = DATE(start_year, 12, 31);
SET brand_key = 1234;  -- replace with desired brand

-- 🗃️ TEMP TABLES for cohort entry points
CREATE TEMP TABLE customers_y1 AS
SELECT DISTINCT customer_id
FROM `project.dataset.transactions`
WHERE order_date BETWEEN start_date AND end_date
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key;

CREATE TEMP TABLE customers_y2 AS
SELECT DISTINCT customer_id
FROM `project.dataset.transactions`
WHERE order_date BETWEEN DATE_ADD(start_date, INTERVAL 1 YEAR) AND DATE_ADD(end_date, INTERVAL 1 YEAR)
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key;

CREATE TEMP TABLE customers_y3 AS
SELECT DISTINCT customer_id
FROM `project.dataset.transactions`
WHERE order_date BETWEEN DATE_ADD(start_date, INTERVAL 2 YEAR) AND DATE_ADD(end_date, INTERVAL 2 YEAR)
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key;

-- 📊 RETENTION LOGIC: measure how many stayed each year
SELECT
  CONCAT(CAST(start_year AS STRING), ' Retention') AS cohort,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN start_date AND end_date THEN customer_id END) AS Year_1,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 1 YEAR) AND DATE_ADD(end_date, INTERVAL 1 YEAR) THEN customer_id END) AS Year_2,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 2 YEAR) AND DATE_ADD(end_date, INTERVAL 2 YEAR) THEN customer_id END) AS Year_3
FROM `project.dataset.transactions`
JOIN customers_y1 cy1 USING(customer_id)
WHERE order_date BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 2 YEAR)
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key

UNION ALL

SELECT
  CONCAT(CAST(start_year + 1 AS STRING), ' Retention') AS cohort,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 1 YEAR) AND DATE_ADD(end_date, INTERVAL 1 YEAR) THEN customer_id END) AS Year_1,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 2 YEAR) AND DATE_ADD(end_date, INTERVAL 2 YEAR) THEN customer_id END) AS Year_2,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 3 YEAR) AND DATE_ADD(end_date, INTERVAL 3 YEAR) THEN customer_id END) AS Year_3
FROM `project.dataset.transactions`
JOIN customers_y2 cy2 USING(customer_id)
WHERE order_date BETWEEN DATE_ADD(start_date, INTERVAL 1 YEAR) AND DATE_ADD(end_date, INTERVAL 3 YEAR)
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key

UNION ALL

SELECT
  CONCAT(CAST(start_year + 2 AS STRING), ' Retention') AS cohort,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 2 YEAR) AND DATE_ADD(end_date, INTERVAL 2 YEAR) THEN customer_id END) AS Year_1,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 3 YEAR) AND DATE_ADD(end_date, INTERVAL 3 YEAR) THEN customer_id END) AS Year_2,
  COUNT(DISTINCT CASE WHEN order_date BETWEEN DATE_ADD(start_date, INTERVAL 4 YEAR) AND DATE_ADD(end_date, INTERVAL 4 YEAR) THEN customer_id END) AS Year_3
FROM `project.dataset.transactions`
JOIN customers_y3 cy3 USING(customer_id)
WHERE order_date BETWEEN DATE_ADD(start_date, INTERVAL 2 YEAR) AND DATE_ADD(end_date, INTERVAL 4 YEAR)
  AND is_gift = FALSE
  AND business_unit = 'CORE'
  AND country_group NOT IN ('US', 'Australia')
  AND units > 0
  AND payment_status = 'Paid'
  AND brand_id = brand_key

ORDER BY cohort;
