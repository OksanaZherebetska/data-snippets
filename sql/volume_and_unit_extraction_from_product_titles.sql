-- 🎯 GOAL:
-- Extract volume value and unit of measure from product titles in the Hair category.

-- 📦 STEP 1: Extract numeric volume (first number found in title)
WITH volume_extracted AS (
  SELECT DISTINCT
    product_id,
    product_title,
    REGEXP_EXTRACT(product_title, r'(\d+)\s?') AS volume_raw
  FROM `project.dataset.products` p
  JOIN `project.dataset.product_attributes` pa ON p.product_id = pa.product_id
  WHERE pa.category = 'Hair'
),

-- 📦 STEP 2: Extract unit of measurement from title
volume_unit AS (
  SELECT DISTINCT
    product_id,
    LOWER(
      CASE
        WHEN REGEXP_CONTAINS(product_title, r'(ml|oz|fl\.oz|g|cm|inch|mm|gallons)') 
          THEN REGEXP_EXTRACT(product_title, r'(ml|oz|fl\.oz|g|cm|inch|mm|gallons)')
        ELSE NULL
      END
    ) AS volume_unit
  FROM `project.dataset.products` p
  JOIN `project.dataset.product_attributes` pa ON p.product_id = pa.product_id
  WHERE pa.category = 'Hair'
)

-- 🧾 FINAL: Join extracted value and unit
SELECT
  ve.product_id,
  ve.product_title,
  SAFE_CAST(ve.volume_raw AS INT64) AS volume,
  vu.volume_unit
FROM volume_extracted ve
JOIN volume_unit vu USING(product_id);
