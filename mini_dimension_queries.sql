-- Query 1: Using the SCD Type 2 Model
-- This query must join the large fact table with the potentially HUGE, bloated customer dimension.
EXPLAIN ANALYZE
SELECT
    d.income_level,
    SUM(f.sale_amount) AS total_sales
FROM fact_sales_scd2 f
JOIN dim_customer_scd2 d ON f.customer_key = d.customer_key
GROUP BY d.income_level;

/*
SCD Type 2 Query Result:
| income_level | total_sales |
|--------------|-------------|
| Medium       | 100.00      |
| High         | 350.00      |
*/


-- Query 2: Using the Mini-Dimension Model
-- This query joins the large fact table with the TINY profile mini-dimension.
-- The main customer dimension is not even needed for this query!
EXPLAIN ANALYZE
SELECT
    p.income_level,
    SUM(f.sale_amount) AS total_sales
FROM fact_sales_mini f
JOIN dim_customer_profile p ON f.profile_key = p.profile_key
GROUP BY p.income_level;

/*
Mini-Dimension Query Result:
| income_level | total_sales |
|--------------|-------------|
| Medium       | 100.00      |
| High         | 350.00      |
*/