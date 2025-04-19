-- 🎯 GOAL:
-- Monthly aggregation of category and brand KPIs: TY vs LY vs LY_AL (aligned dates).
-- Includes revenue, units, GP, COGS, discounts, and customer counts.

-- 🧮 PARAMETERS
DECLARE start_date DATE;
DECLARE end_date DATE;
DECLARE start_date_ly DATE;
DECLARE end_date_ly DATE;
DECLARE start_date_ly_al DATE;
DECLARE end_date_ly_al DATE;
DECLARE yearmonth STRING;
DECLARE eom_date DATE;

-- 📅 Set rolling monthly period
SET start_date = DATE_ADD(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), MONTH), INTERVAL -1 MONTH);
SET end_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 🌀 Monthly loop
WHILE start_date <= end_date DO
  SET eom_date = CASE 
                   WHEN DATE_SUB(DATE_TRUNC(DATE_ADD(start_date, INTERVAL 1 MONTH), MONTH), INTERVAL 1 DAY) < CURRENT_DATE()
                   THEN DATE_SUB(DATE_TRUNC(DATE_ADD(start_date, INTERVAL 1 MONTH), MONTH), INTERVAL 1 DAY)
                   ELSE DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
                 END;

  SET start_date_ly = DATE_ADD(start_date, INTERVAL -1 YEAR);
  SET end_date_ly = DATE_ADD(eom_date, INTERVAL -1 YEAR);

  SET start_date_ly_al = (SELECT CAST(last_year_day_aligned AS DATE)
                          FROM `project.dataset.date_reference`
                          WHERE full_date = start_date);

  SET end_date_ly_al = (SELECT CAST(last_year_day_aligned AS DATE)
                        FROM `project.dataset.date_reference`
                        WHERE full_date = eom_date);

  SET yearmonth = (SELECT CAST(calendar_year_month AS STRING)
                   FROM `project.dataset.date_reference`
                   WHERE full_date = start_date);

  -- 🗑 Clean previous data for this month
  DELETE FROM `project.dataset.monthly_category_brand_agg`
  WHERE calendar_year_month = yearmonth;

  -- 📦 Build raw data table
  CREATE TEMP TABLE rawdata AS (
    SELECT
      CASE WHEN order_date BETWEEN start_date AND end_date THEN 'TY' END AS period_ty,
      CASE WHEN order_date BETWEEN start_date_ly AND end_date_ly THEN 'LY' END AS period_ly,
      CASE WHEN order_date BETWEEN start_date_ly_al AND end_date_ly_al THEN 'LY_AL' END AS period_ly_al,
      FORMAT_DATE("%Y%m", start_date) AS calendar_year_month,
      business_unit,
      country_group,
      region,
      site,
      brand_submarket,
      category,
      subcategory,
      brand_name,
      brand_category,
      partnership_flag,
      warehouse_name,
      external_reporting_flag,
      is_gwp,
      us_category,
      us_subcategory,
      COUNT(DISTINCT order_id) AS orders,
      SUM(rrp_revenue) AS rrp_revenue,
      SUM(list_revenue) AS list_revenue,
      SUM(gross_revenue) AS gross_revenue,
      SUM(net_revenue) AS net_revenue,
      SUM(shipping_revenue) AS shipping_revenue,
      SUM(gp) AS gp,
      SUM(cogs) AS cogs,
      SUM(funding) AS funding,
      SUM(discount) AS discount,
      SUM(units) AS units,
      COUNT(DISTINCT customer_id) AS total_customers,
      COUNT(DISTINCT CASE WHEN new_category = 1 THEN customer_id END) AS new_to_category_customers
    FROM `project.dataset.daily_base`
    JOIN `project.dataset.date_reference` USING (date_key)
    LEFT JOIN `project.dataset.brand_attribution` USING (brand_id)
    WHERE order_date BETWEEN start_date AND eom_date
       OR order_date BETWEEN start_date_ly AND end_date_ly
       OR order_date BETWEEN start_date_ly_al AND end_date_ly_al
  GROUP BY ALL
  );

  -- 🚀 Insert aggregated data
  INSERT INTO `project.dataset.monthly_category_brand_agg`
  SELECT
    calendar_year_month,
    business_unit,
    country_group,
    region,
    site,
    brand_submarket,
    category,
    subcategory,
    brand_name,
    brand_category,
    warehouse_name,
    external_reporting_flag,
    is_gwp,
    us_category,
    us_subcategory,

    -- KPIs for TY, LY, LY_AL
    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN orders END), 0) AS orders_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN orders END), 0) AS orders_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN orders END), 0) AS orders_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN rrp_revenue END), 0) AS rrp_revenue_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN rrp_revenue END), 0) AS rrp_revenue_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN rrp_revenue END), 0) AS rrp_revenue_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN list_revenue END), 0) AS list_revenue_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN list_revenue END), 0) AS list_revenue_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN list_revenue END), 0) AS list_revenue_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN gross_revenue END), 0) AS gross_revenue_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN gross_revenue END), 0) AS gross_revenue_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN gross_revenue END), 0) AS gross_revenue_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN net_revenue END), 0) AS net_revenue_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN net_revenue END), 0) AS net_revenue_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN net_revenue END), 0) AS net_revenue_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN shipping_revenue END), 0) AS shipping_revenue_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN shipping_revenue END), 0) AS shipping_revenue_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN shipping_revenue END), 0) AS shipping_revenue_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN gp END), 0) AS gp_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN gp END), 0) AS gp_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN gp END), 0) AS gp_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN cogs END), 0) AS cogs_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN cogs END), 0) AS cogs_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN cogs END), 0) AS cogs_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN funding END), 0) AS funding_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN funding END), 0) AS funding_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN funding END), 0) AS funding_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN discount END), 0) AS discount_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN discount END), 0) AS discount_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN discount END), 0) AS discount_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN units END), 0) AS units_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN units END), 0) AS units_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN units END), 0) AS units_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN total_customers END), 0) AS total_customers_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN total_customers END), 0) AS total_customers_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN total_customers END), 0) AS total_customers_ly_al,

    IFNULL(SUM(CASE WHEN period_ty = 'TY' THEN new_to_category_customers END), 0) AS new_to_category_customers_ty,
    IFNULL(SUM(CASE WHEN period_ly = 'LY' THEN new_to_category_customers END), 0) AS new_to_category_customers_ly,
    IFNULL(SUM(CASE WHEN period_ly_al = 'LY_AL' THEN new_to_category_customers END), 0) AS new_to_category_customers_ly_al,

    country_name,
    partnership_flag
  FROM rawdata
  GROUP BY ALL;

  DROP TABLE rawdata;

  -- ⏭ Move to next month
  SET start_date = DATE_ADD(start_date, INTERVAL 1 MONTH);
END WHILE;
