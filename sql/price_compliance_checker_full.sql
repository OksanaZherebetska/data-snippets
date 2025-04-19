-- 🧠 PRICE COMPLIANCE CHECKER
-- Core goal: track how long products stay discounted, compare it to regular price periods, and flag non-compliant behavior.
-- Translation: are we respecting RRP, or is this another permanent "campaign"?

-- 📆 STEP 0: Define time range (last 16 days) & purge existing records
DECLARE start_date DATE;
DECLARE end_date DATE;

SET start_date = CURRENT_DATE() - 16;
SET end_date = CURRENT_DATE();

DELETE FROM `project.dataset.Base_Table`
WHERE Date BETWEEN start_date AND end_date;

-- 🧹 STEP 1: Fix brand key mapping inconsistencies (because data governance is a lie)
CREATE TEMP TABLE correct_brand_key_name AS (
  SELECT 
    wrong_brand_key, 
    correct_brand_key, 
    bd.brand_name AS correct_brand_name
  FROM `project.dataset.correct_brand_key` cb
  JOIN `project.dataset.Brand_D` bd
    ON cb.correct_brand_key = bd.brand_key
);

-- 🧾 STEP 2: Generate product x date base with all relevant metadata
CREATE TEMP TABLE cross_table AS (
  SELECT DISTINCT
    A.Product_Id,
    A.product_key,
    A.Product_Title,
    A.Site_Key,
    A.Site,
    A.Locale_Key,
    A.Locale,
    COALESCE(CBD.correct_brand_key, P.Brand_Key) AS Brand_key,
    COALESCE(CBD.correct_brand_name, B.Brand_Name) AS Brand_Name,
    IFNULL(BA.Brand_Submarket, '') AS Brand_Submarket,
    IFNULL(BA.Main_Category, '') AS Brand_Category,
    COALESCE(PA.Category, A.Category) AS Category,
    IFNULL(PA.Subcategory, '') AS Subcategory,
    D.Date,
    PD.Currency_Key
  FROM `project.dataset.Active_Displayable_SKUs` A
  INNER JOIN `project.dataset.Product_D` P ON A.product_id = P.product_id
  LEFT JOIN `project.dataset.Brand_D` B ON P.Brand_Key = B.Brand_Key
  LEFT JOIN correct_brand_key_name CBD ON P.Brand_Key = CBD.wrong_brand_key
  LEFT JOIN `project.dataset.Brand_Attribution` BA ON COALESCE(CBD.correct_brand_key, P.Brand_Key) = BA.Brand_key
  LEFT JOIN `project.dataset.product_attribution` PA ON A.product_id = PA.product_id
  CROSS JOIN (
    SELECT CAST(full_date AS DATE) AS Date
    FROM `project.dataset.Date_D`
    WHERE full_date BETWEEN start_date AND end_date
  ) D
  LEFT JOIN `project.dataset.Price_D` PD
    ON PD.Product_key = A.product_key
    AND PD.Site_Key = A.Site_Key
    AND PD.Locale_Key = A.Locale_Key
  WHERE A.Site_Key IN (37, 231) -- CORE, CULT
    AND A.Locale_Key IN (3, 6, 2, 8, 4) -- UK, FR, DE, NL, IE
  ORDER BY D.Date, A.Product_Id
);

-- 💰 STEP 3: Pull actual prices (only if valid for the date)
CREATE TEMP TABLE actual AS (
  SELECT DISTINCT
    C.Date,
    C.Product_Id,
    C.product_key,
    C.Product_Title,
    C.Site_Key,
    C.Site,
    C.Locale_Key,
    C.Locale,
    C.Brand_key,
    C.Brand_Name,
    C.Brand_Submarket,
    C.Brand_Category,
    C.Category,
    C.Subcategory,
    C.Currency_Key,
    CASE WHEN C.Currency_Key = 2 THEN 'GBP' ELSE 'EURO' END AS Currency,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN CAST(P.Valid_From AS DATE) 
    END AS Valid_From,
    CASE 
      WHEN CAST(P.Valid_To AS DATE) > end_date THEN end_date
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN CAST(P.Valid_To AS DATE) 
    END AS Valid_To,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN P.RRP 
    END AS RRP,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN P.Price 
    END AS Price,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN 'A' 
    END AS Price_Check
  FROM cross_table C
  LEFT JOIN `project.dataset.Price_D` P
    ON P.Product_key = C.product_key
    AND P.Site_Key = C.Site_Key
    AND P.Locale_Key = C.Locale_Key
    AND CAST(P.Valid_From AS DATE) <= C.Date
    AND P.Currency_Key = C.Currency_Key
  WHERE C.Locale_Key = 3 AND C.Currency_Key = 2

  UNION ALL

  SELECT DISTINCT
    C.Date,
    C.Product_Id,
    C.product_key,
    C.Product_Title,
    C.Site_Key,
    C.Site,
    C.Locale_Key,
    C.Locale,
    C.Brand_key,
    C.Brand_Name,
    C.Brand_Submarket,
    C.Brand_Category,
    C.Category,
    C.Subcategory,
    C.Currency_Key,
    CASE WHEN C.Currency_Key = 2 THEN 'GBP' ELSE 'EURO' END AS Currency,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN CAST(P.Valid_From AS DATE) 
    END AS Valid_From,
    CASE 
      WHEN CAST(P.Valid_To AS DATE) > end_date THEN end_date
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN CAST(P.Valid_To AS DATE) 
    END AS Valid_To,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN P.RRP 
    END AS RRP,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN P.Price 
    END AS Price,
    CASE 
      WHEN C.Date BETWEEN CAST(P.Valid_From AS DATE) AND DATE_SUB(CAST(P.Valid_To AS DATE), INTERVAL 1 DAY)
      THEN 'A' 
    END AS Price_Check
  FROM cross_table C
  LEFT JOIN `project.dataset.Price_D` P
    ON P.Product_key = C.product_key
    AND P.Site_Key = C.Site_Key
    AND P.Locale_Key = C.Locale_Key
    AND CAST(P.Valid_From AS DATE) <= C.Date
    AND P.Currency_Key = C.Currency_Key
  WHERE C.Locale_Key <> 3 AND C.Currency_Key = 1
);

-- 🗿 STEP 4: Add historical price data where current prices are missing
CREATE TEMP TABLE base AS (
  SELECT DISTINCT
    C.Date,
    C.Product_Id,
    C.product_key,
    C.Product_Title,
    C.Site_Key,
    C.Site,
    C.Locale_Key,
    C.Locale,
    C.Brand_key,
    C.Brand_Name,
    C.Brand_Submarket,
    C.Brand_Category,
    C.Category,
    C.Subcategory,
    C.Currency_Key,
    C.Currency,
    COALESCE(
      C.Valid_From,
      CASE 
        WHEN C.Date BETWEEN CAST(PH.Valid_From AS DATE) AND DATE_SUB(CAST(PH.Valid_To AS DATE), INTERVAL 1 DAY)
        THEN CAST(PH.Valid_From AS DATE) 
      END
    ) AS Valid_From,
    COALESCE(
      C.Valid_To,
      CASE 
        WHEN C.Date BETWEEN CAST(PH.Valid_From AS DATE) AND DATE_SUB(CAST(PH.Valid_To AS DATE), INTERVAL 1 DAY)
        THEN CAST(PH.Valid_To AS DATE) 
      END
    ) AS Valid_To,
    COALESCE(
      C.RRP,
      CASE 
        WHEN C.Date BETWEEN CAST(PH.Valid_From AS DATE) AND DATE_SUB(CAST(PH.Valid_To AS DATE), INTERVAL 1 DAY)
        THEN PH.RRP 
      END
    ) AS RRP,
    COALESCE(
      C.Price,
      CASE 
        WHEN C.Date BETWEEN CAST(PH.Valid_From AS DATE) AND DATE_SUB(CAST(PH.Valid_To AS DATE), INTERVAL 1 DAY)
        THEN PH.Price 
      END
    ) AS Price,
    COALESCE(C.Price_Check, 'H') AS Price_Check  -- 'H' = from historical data
  FROM actual C
  LEFT JOIN `project.dataset.Price_D_Historic` PH
    ON PH.Product_key = C.product_key
    AND PH.Site_Key = C.Site_Key
    AND PH.Locale_Key = C.Locale_Key
    AND CAST(PH.Valid_From AS DATE) <= C.Date
    AND CAST(PH.Valid_To AS DATE) > C.Date
    AND PH.Currency_Key = C.Currency_Key
);
-- 🧾 STEP 5: Finalize daily record with campaign flag
CREATE TEMP TABLE final AS (
  SELECT DISTINCT
    b.Date,
    b.Product_Id,
    b.product_key,
    b.Product_Title,
    b.Site_Key,
    b.Site,
    b.Locale_Key,
    b.Locale,
    b.Brand_key,
    b.Brand_Name,
    b.Brand_Submarket,
    b.Brand_Category,
    IFNULL(b.Category, '') AS Category,
    b.Subcategory,
    b.Valid_From,
    b.Valid_To,
    b.Currency,
    b.RRP,
    b.Price,
    b.Price_Check,
    -- 🚩 If price is lower than RRP, flag it as part of a campaign
    CASE 
      WHEN b.RRP > b.Price THEN 1 
      ELSE 0 
    END AS Campaign_Flag
  FROM base b
);

-- 💾 STEP 6: Insert into main compliance table (partitioned by date if needed)
INSERT INTO `project.dataset.Base_Table` (
  SELECT DISTINCT
    Date,
    Product_Id,
    product_key,
    Product_Title,
    Site_Key,
    Site,
    Locale_Key,
    Locale,
    Brand_key,
    Brand_Name,
    Brand_Submarket,
    Brand_Category,
    Category,
    Subcategory,
    Valid_From,
    Valid_To,
    Currency,
    RRP,
    Price,
    Price_Check,
    Campaign_Flag
  FROM final
);

-- 🔁 STEP 7: Detect changes in campaign flag over time (yes, we’re tracking your discount rollercoaster)
CREATE TEMP TABLE Campaign_Changes AS (
  SELECT
    Brand_key,
    Brand_Name,
    Category,
    Product_id,
    Product_Title,
    Site_Key,
    Locale_Key,
    Valid_From,
    Valid_To,
    Campaign_Flag,
    LAG(Campaign_Flag) OVER (PARTITION BY Product_id, Site_Key, Locale_Key ORDER BY Valid_From) AS Prev_Campaign_Flag,
    ROW_NUMBER() OVER (PARTITION BY Product_id, Site_Key, Locale_Key ORDER BY Valid_From) AS row_num
  FROM `project.dataset.Base_Table`
);

-- 🧩 STEP 8: Assign campaign periods to groups
CREATE TEMP TABLE Identified_Groups AS (
  SELECT
    *,
    SUM(CASE WHEN Campaign_Flag != Prev_Campaign_Flag THEN 1 ELSE 0 END)
      OVER (PARTITION BY Product_id, Site_Key, Locale_Key ORDER BY row_num) AS Change_Group
  FROM Campaign_Changes
);

-- 🗓️ STEP 9: Collapse campaign periods to one row per group, and calculate duration
CREATE TEMP TABLE Compliant_Groups AS (
  SELECT
    Brand_key,
    Brand_Name,
    Category,
    Product_id,
    Product_Title,
    Site_Key,
    Locale_Key,
    Campaign_Flag,
    Change_Group,
    -- Normalize campaign start to Jan 1 if it started earlier (new year, new you)
    CASE 
      WHEN MIN(Valid_From) < DATE_TRUNC(MAX(Valid_To), YEAR) THEN DATE_TRUNC(MAX(Valid_To), YEAR)
      ELSE MIN(Valid_From)
    END AS Valid_From,
    MAX(Valid_To) AS Valid_To,
    DATE_DIFF(
      MAX(Valid_To), 
      CASE 
        WHEN MIN(Valid_From) < DATE_TRUNC(MAX(Valid_To), YEAR) THEN DATE_TRUNC(MAX(Valid_To), YEAR)
        ELSE MIN(Valid_From)
      END,
      DAY
    ) AS Day_diff
  FROM Identified_Groups
  GROUP BY Brand_key, Brand_Name, Category, Product_id, Product_Title, Site_Key, Locale_Key, Campaign_Flag, Change_Group
);

-- 🧪 STEP 10: Compare with previous campaign duration (if any)
CREATE TEMP TABLE Compliant_Check AS (
  SELECT
    *,
    LAG(Day_diff) OVER (PARTITION BY Product_id, Site_Key, Locale_Key ORDER BY Valid_From) AS Pre_Day_diff
  FROM Compliant_Groups
);

-- 📊 STEP 11: Count how often brand/category was on discount
CREATE TEMP TABLE Brand_Days AS (
  SELECT DISTINCT
    Brand_key,
    Brand_Name,
    Date,
    Site_Key,
    Locale_Key,
    MAX(Campaign_Flag) AS Campaign_Flag
  FROM `project.dataset.Base_Table`
  GROUP BY ALL
);

CREATE TEMP TABLE Brand_Days_Discount AS (
  SELECT
    Brand_key,
    Site_Key,
    Locale_Key,
    SUM(Campaign_Flag) AS Days_on_Discount,
    COUNT(DISTINCT Date) AS Days_on_Site
  FROM Brand_Days
  GROUP BY ALL
);

CREATE TEMP TABLE Brand_Category_Days AS (
  SELECT
    Brand_key,
    Brand_Name,
    Category,
    Date,
    Site_Key,
    Locale_Key,
    MAX(Campaign_Flag) AS Campaign_Flag,
    COUNT(DISTINCT Date) AS Days_on_Site
  FROM `project.dataset.Base_Table`
  GROUP BY ALL
);

CREATE TEMP TABLE Brand_Category_Days_Discount AS (
  SELECT
    Brand_key,
    Category,
    Site_Key,
    Locale_Key,
    SUM(Campaign_Flag) AS Days_on_Discount,
    SUM(Days_on_Site) AS Days_on_Site
  FROM Brand_Category_Days
  GROUP BY ALL
);

-- ✅ FINAL: Flag compliant campaigns based on duration logic
CREATE OR REPLACE TABLE `project.dataset.Compliance_Checker` AS (
  SELECT
    C.Brand_key,
    C.Brand_Name,
    C.Category,
    C.Product_id,
    C.Product_Title,
    C.Site_Key,
    C.Locale_Key,
    C.Valid_From,
    C.Valid_To,
    C.Campaign_Flag,
    C.Day_diff,
    C.Pre_Day_diff,
    -- ⚖️ Main logic: too long on discount = suspicious
    CASE 
      WHEN Campaign_Flag = 1 AND Pre_Day_diff IS NULL AND Day_diff > 14 THEN 1
      WHEN Campaign_Flag = 1 AND Pre_Day_diff IS NOT NULL AND Pre_Day_diff < Day_diff THEN 1
      ELSE 0 
    END AS Compliant_Flag,
    D.Days_on_Discount AS Days_on_Discount_Brand,
    D.Days_on_Site AS Days_on_Site_Brand,
    DD.Days_on_Discount AS Days_on_Discount_Brand_Category,
    DD.Days_on_Site AS Days_on_Site_Brand_Category
  FROM Compliant_Check C
  LEFT JOIN Brand_Days_Discount D
    ON C.Brand_key = D.Brand_key AND C.Site_Key = D.Site_Key AND C.Locale_Key = D.Locale_Key
  LEFT JOIN Brand_Category_Days_Discount DD
    ON C.Brand_key = DD.Brand_key AND C.Category = DD.Category AND C.Site_Key = DD.Site_Key AND C.Locale_Key = DD.Locale_Key
);

