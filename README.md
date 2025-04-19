# 🧠 Data Snippets: SQL for Real-World Analytics

A collection of SQL scripts from real-life projects — from customer behavior deep dives to KPI tracking and monthly loops.  
No fluff, no fake data, just clean queries that worked in production.

---

## 📊 Categories

### 📦 KPI & Aggregation

- `add_monthly_kpi_loop_aggregation.sql`  
  Monthly TY/LY/LY_AL KPI aggregation using a WHILE loop. Tracks revenue, units, GP, discounts, new customers — all by category and brand.

- `add_brand_category_reorder_interval.sql`  
  Calculates average reorder interval for a specific brand and product category.

- `add_luxury_order_frequency_distribution.sql`  
  Groups luxury customers by number of orders placed over the past year.

---

### 🧍‍♀️ Customer Behavior

- `add_three_year_retention_by_brand.sql`  
  Cohort-based retention across 3 years for a single brand.

- `add_top_products_by_customer_type.sql`  
  Compare top-selling products for new vs returning customers.

- `add_customer_type_by_year_analysis.sql`  
  Segments customers into one-time, consistent_once, and other. Yearly aggregation.

- `add_order_type_relative_to_luxury_entry.sql`  
  Classifies orders -5 to +5 from a customer’s first luxury order by brand submarket (mass, prestige, lux).

---

### 🧠 Product Data Enrichment

- `add_volume_and_unit_extraction_from_product_titles.sql`  
  Regex-based volume and unit extraction from product titles (ml, oz, g, etc.).

---

### 🧪 Product / Category Analysis

- `add_order_category_mix_analysis.sql`  
  Analyzes which product categories are purchased together (e.g., Hair + Skin, Fragrance only, etc.).

---

## 🧷 Script Format

Each script is:
- anonymized,
- well-commented in a sharp but friendly tone,
- written for reuse and clarity.

---

## 🚀 Stack

- Google BigQuery (Standard SQL)
- CTEs, TEMP TABLEs, arrays, windows, WHILE loops — yes, used them all
- Python / Tableau / Power BI / Notion (on the side)

---

## ⚙️ Who made this?

[Oksana aka Niekta](https://www.linkedin.com/in/oksana-zherebetska-174021ab/)  
Data analyst with experience in e-commerce, media, customer journey mapping, and building analytics from scratch.  
Loves clean logic, sarcastic comments, and when stuff just works.
