-- 🎯 GOAL:
-- Find out what product categories are ordered together — is Hair flying solo or hanging out with Skin?
-- Categorize orders by their category mix to analyze bundling behavior at order level.

-- 🧮 PARAMETERS
DECLARE brand_keys ARRAY<INT64>;  -- Brand(s) to analyze
DECLARE business_unit STRING;     -- Business unit (e.g., 'CORE', 'US')
DECLARE start_date DATE;
DECLARE end_date DATE;

-- Analyze from Jan 1st to yesterday
SET start_date = DATE_TRUNC(CURRENT_DATE(), YEAR);
SET end_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
SET brand_keys = [1234];  -- Replace with your brand keys
SET business_unit = 'CORE';

--------------------------------------------------------------------------------
-- 🧱 STEP 1: Tag categories per order line (Hair, Skin, Body, etc.)
--------------------------------------------------------------------------------
WITH order_cat AS (
  SELECT
    customer_id,
    order_id,
    CASE WHEN category = 'Hair'       THEN 1 ELSE 0 END AS Hair,
    CASE WHEN category = 'Cosmetics'  THEN 1 ELSE 0 END AS Cosmetics,
    CASE WHEN category = 'Skin'       THEN 1 ELSE 0 END AS Skin,
    CASE WHEN category = 'Fragrance'  THEN 1 ELSE 0 END AS Fragrance,
    CASE WHEN category = 'Body'       THEN 1 ELSE 0 END AS Body,
    CASE WHEN category NOT IN ('Body','Hair','Cosmetics','Skin','Fragrance') 
         THEN 1 ELSE 0 END AS Other
  FROM `project.dataset.transactions`
  WHERE order_date BETWEEN start_date AND end_date
    AND country_group NOT IN ('US','Australia')
    AND units > 0
    AND is_gift = FALSE
    AND payment_status = 'Paid'
    AND business_unit = business_unit
    AND brand_id IN UNNEST(brand_keys)
    AND customer_id IS NOT NULL
),

--------------------------------------------------------------------------------
-- 📦 STEP 2: Aggregate categories at order level
--------------------------------------------------------------------------------
cat_mix AS (
  SELECT
    customer_id,
    order_id,
    MAX(Hair)       AS Hair,
    MAX(Cosmetics)  AS Cosmetics,
    MAX(Skin)       AS Skin,
    MAX(Fragrance)  AS Fragrance,
    MAX(Body)       AS Body,
    MAX(Other)      AS Other
  FROM order_cat
  GROUP BY customer_id, order_id
),

--------------------------------------------------------------------------------
-- 🧩 STEP 3: Determine specific category combinations
--------------------------------------------------------------------------------
cat_final AS (
  SELECT
    customer_id,
    order_id,

    -- Solo category purchases
    CASE WHEN Hair = 1 AND Cosmetics + Skin + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Hair_Only,
    CASE WHEN Cosmetics = 1 AND Hair + Skin + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Cosmetics_Only,
    CASE WHEN Skin = 1 AND Hair + Cosmetics + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Skin_Only,
    CASE WHEN Fragrance = 1 AND Hair + Cosmetics + Skin + Body + Other = 0 THEN 1 ELSE 0 END AS Fragrance_Only,
    CASE WHEN Body = 1 AND Hair + Cosmetics + Skin + Fragrance + Other = 0 THEN 1 ELSE 0 END AS Body_Only,
    CASE WHEN Other = 1 AND Hair + Cosmetics + Skin + Fragrance + Body = 0 THEN 1 ELSE 0 END AS Other_Only,

    -- Duos: high-drama combos
    CASE WHEN Hair = 1 AND Cosmetics = 1 AND Skin + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Hair_Cosmetics,
    CASE WHEN Hair = 1 AND Skin = 1 AND Cosmetics + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Hair_Skin,
    CASE WHEN Hair = 1 AND Fragrance = 1 AND Cosmetics + Skin + Body + Other = 0 THEN 1 ELSE 0 END AS Hair_Fragrance,
    CASE WHEN Hair = 1 AND Body = 1 AND Cosmetics + Skin + Fragrance + Other = 0 THEN 1 ELSE 0 END AS Hair_Body,
    CASE WHEN Cosmetics = 1 AND Skin = 1 AND Hair + Fragrance + Body + Other = 0 THEN 1 ELSE 0 END AS Cosmetics_Skin,
    CASE WHEN Cosmetics = 1 AND Fragrance = 1 AND Hair + Skin + Body + Other = 0 THEN 1 ELSE 0 END AS Cosmetics_Fragrance,
    CASE WHEN Cosmetics = 1 AND Body = 1 AND Hair + Skin + Fragrance + Other = 0 THEN 1 ELSE 0 END AS Cosmetics_Body,
    CASE WHEN Skin = 1 AND Fragrance = 1 AND Hair + Cosmetics + Body + Other = 0 THEN 1 ELSE 0 END AS Skin_Fragrance,
    CASE WHEN Skin = 1 AND Body = 1 AND Hair + Cosmetics + Fragrance + Other = 0 THEN 1 ELSE 0 END AS Skin_Body,
    CASE WHEN Fragrance = 1 AND Body = 1 AND Hair + Cosmetics + Skin + Other = 0 THEN 1 ELSE 0 END AS Fragrance_Body,

    -- 🎭 Wildcards
    CASE WHEN Other = 1 AND (Hair + Cosmetics + Skin + Fragrance + Body) > 0 THEN 1 ELSE 0 END AS Other_with_Category
  FROM cat_mix
)

--------------------------------------------------------------------------------
-- 📊 FINAL OUTPUT: Who's bundling what?
--------------------------------------------------------------------------------
SELECT
  COUNT(DISTINCT order_id) AS Orders,
  SUM(Hair_Only)            AS Hair_Only,
  SUM(Cosmetics_Only)       AS Cosmetics_Only,
  SUM(Skin_Only)            AS Skin_Only,
  SUM(Fragrance_Only)       AS Fragrance_Only,
  SUM(Body_Only)            AS Body_Only,
  SUM(Other_Only)           AS Other_Only,

  SUM(Hair_Cosmetics)       AS Hair_Cosmetics,
  SUM(Hair_Skin)            AS Hair_Skin,
  SUM(Hair_Fragrance)       AS Hair_Fragrance,
  SUM(Hair_Body)            AS Hair_Body,
  SUM(Cosmetics_Skin)       AS Cosmetics_Skin,
  SUM(Cosmetics_Fragrance)  AS Cosmetics_Fragrance,
  SUM(Cosmetics_Body)       AS Cosmetics_Body,
  SUM(Skin_Fragrance)       AS Skin_Fragrance,
  SUM(Skin_Body)            AS Skin_Body,
  SUM(Fragrance_Body)       AS Fragrance_Body,
  SUM(Other_with_Category)  AS Other_with_Category
FROM cat_final;
