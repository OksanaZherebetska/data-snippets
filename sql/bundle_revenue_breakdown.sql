-- 🎯 GOAL:
-- Calculate product-level metrics for bundles with cost allocation to child products.
-- Includes corrections for brand keys and mappings for bundle/child/product relationships.

-- 🛠 Parameters
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE start_date_pre DATE;
DECLARE end_date_pre DATE;

SET start_date = DATE_ADD(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY), INTERVAL -1 YEAR);
SET end_date = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY);
SET start_date_pre = DATE_ADD(start_date, INTERVAL -1 YEAR);
SET end_date_pre = DATE_ADD(end_date, INTERVAL -1 YEAR);

-- 🛠 Brand key correction table
CREATE TEMP TABLE correct_brand_key_name AS (
    SELECT wrong_brand_key, correct_brand_key, brand_name AS correct_brand_name
    FROM `project.dataset.correct_brand_key`
    JOIN `project.dataset.brand_reference` USING(correct_brand_key)
);

-- 📊 Main bundle query
SELECT DISTINCT
  c.Year,
  COALESCE(CBD.correct_brand_key, c.Brand_Key) AS Brand_Key,
  COALESCE(BP.Bundle_Brand_Name, CBD.correct_brand_name, c.Brand_Name) AS Bundle_Brand_Name,
  COALESCE(BP.Bundle_Category, c.Category) AS Bundle_Category,
  c.product_id AS Ordered_Product_Id,
  P.Product_Title AS Ordered_Product_Title,
  c.is_bundle AS Is_Bundle,

  COALESCE(BP.Bundle_Product_Id, c.product_id) AS Bundle_Product_Id,
  COALESCE(BP.Bundle_Product_Title, P.Product_Title) AS Bundle_Product_Title,
  COALESCE(BP.Child_Product_Id, c.product_id) AS Child_Product_Id,
  COALESCE(BP.Child_Product_Title, P.Product_Title) AS Child_Product_Title,
  COALESCE(BP.Child_Brand_Name, CBD.correct_brand_name, c.Brand_Name) AS Child_Brand_Name,
  COALESCE(BP.Child_Category, c.Category) AS Child_Category,

  -- Child-level metrics (cost-weighted)
  SUM(c.Units * COALESCE(BP.Qty, 1)) AS Child_Units,
  SUM(c.list_price * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_List_Revenue,
  SUM(c.product_revenue * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Gross_Revenue,
  SUM(c.product_net_revenue * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Net_Revenue,
  SUM(c.rrp * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Rrp_Revenue,
  SUM(c.Shipping_Net_Revenue * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Shipping_Revenue,
  SUM(c.product_cost * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Cogs,
  SUM(c.Total_Discount * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Discount,
  SUM(c.funded * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Funding,
  SUM(c.gp * COALESCE(SAFE_CAST(BP.Cost_Weight AS FLOAT64), 100) / 100) AS Child_Gp,

  -- Bundle-level metrics (raw)
  SUM(c.Units) AS Bundle_Units,
  SUM(c.list_price) AS Bundle_List_Revenue,
  SUM(c.product_revenue) AS Bundle_Gross_Revenue,
  SUM(c.product_net_revenue) AS Bundle_Net_Revenue,
  SUM(c.rrp) AS Bundle_Rrp_Revenue,
  SUM(c.Shipping_Net_Revenue) AS Bundle_Shipping_Revenue,
  SUM(c.product_cost) AS Bundle_Cogs,
  SUM(c.Total_Discount) AS Bundle_Discount,
  SUM(c.funded) AS Bundle_Funding,
  SUM(c.gp) AS Bundle_Gp

FROM `project.dataset.customer_product` c
LEFT JOIN `project.dataset.dates` d
  ON c.order_date = d.full_date
LEFT JOIN correct_brand_key_name CBD
  ON c.Brand_Key = CBD.wrong_brand_key
JOIN `project.dataset.products` P
  ON c.product_id = P.product_id
LEFT JOIN `project.dataset.bundles_mapping` BP
  ON BP.Bundle_Product_Id = c.Product_Id
JOIN `project.dataset.products` P1
  ON COALESCE(BP.Bundle_Product_Key, c.Product_Key) = P1.Product_Key

WHERE 1 = 1
  AND (
    c.Order_Date BETWEEN start_date AND end_date
    OR c.Order_Date BETWEEN start_date_pre AND end_date_pre
  )
  AND (
    c.Business_Unit IN ('A', 'B')
    OR (c.Business_Unit = 'C' AND c.Country_Group NOT IN ('X', 'Y'))
  )
  AND c.Units > 0
  AND c.Is_GWP = 0
  AND c.Order_Payment_Status_Key = 0
  AND c.Is_Bundle = 1

GROUP BY ALL
ORDER BY c.product_id, c.Year;
