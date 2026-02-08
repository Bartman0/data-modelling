-- Clean up previous tables if they exist
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;

------------------------------------------------------------------
-- 1. CREATE THE DATE DIMENSION WITH A NATURAL KEY
------------------------------------------------------------------
-- Here, 'date_actual' is our natural key. It's of type DATE.
-- It is universally understood, stable, and will never change.
CREATE TABLE dim_date (
    date_actual         DATE NOT NULL PRIMARY KEY,
    year                INT NOT NULL,
    quarter             INT NOT NULL,
    month               INT NOT NULL,
    month_name          TEXT NOT NULL,
    day_of_week         INT NOT NULL,
    day_name            TEXT NOT NULL,
    is_weekend          BOOLEAN NOT NULL
);

-- Comments on the design:
-- PRIMARY KEY: The 'date_actual' column uniquely identifies each row.
-- No surrogate key (like 'date_key SERIAL') is needed.

------------------------------------------------------------------
-- 2. POPULATE THE DATE DIMENSION
------------------------------------------------------------------
-- This query uses generate_series() to quickly populate the table
-- for a range of dates, from 2024 to 2026.
INSERT INTO dim_date (
    date_actual,
    year,
    quarter,
    month,
    month_name,
    day_of_week,
    day_name,
    is_weekend
)
SELECT
    d::date,
    EXTRACT(YEAR FROM d),
    EXTRACT(QUARTER FROM d),
    EXTRACT(MONTH FROM d),
    TO_CHAR(d, 'Month'),
    EXTRACT(ISODOW FROM d), -- Monday (1) to Sunday (7)
    TO_CHAR(d, 'Day'),
    (EXTRACT(ISODOW FROM d) >= 6) -- True for Saturday/Sunday
FROM generate_series('2024-01-01'::date, '2026-12-31'::date, '1 day'::interval) AS d;

-- Let's check our populated dimension
SELECT * FROM dim_date ORDER BY date_actual LIMIT 5;

------------------------------------------------------------------
-- 3. CREATE THE FACT TABLE
------------------------------------------------------------------
-- The 'order_date' column is of type DATE and directly references
-- the primary key of the dim_date table.
CREATE TABLE fact_sales (
    sale_id             SERIAL PRIMARY KEY,
    product_id          INT NOT NULL,
    amount              NUMERIC(10, 2) NOT NULL,
    order_date          DATE NOT NULL,
    CONSTRAINT fk_date
        FOREIGN KEY(order_date)
        REFERENCES dim_date(date_actual)
);

-- Comments on the design:
-- The FOREIGN KEY relationship is clear: fact_sales.order_date -> dim_date.date_actual.
-- The data type (DATE) matches, and the intent is obvious.

-- Populate with some sample data
INSERT INTO fact_sales (product_id, amount, order_date) VALUES
(101, 29.99, '2025-01-15'),
(102, 150.50, '2025-01-16'),
(101, 32.50, '2025-02-20'),
(103, 500.00, '2025-02-22'), -- A weekend sale
(102, 145.00, '2025-03-05');


------------------------------------------------------------------
-- 4. EXAMPLE QUERIES SHOWING THE BENEFITS
------------------------------------------------------------------

-- ## BENEFIT 1: SIMPLIFIED QUERIES & IMPROVED READABILITY ##

-- Goal: Get total sales for February 2025.

-- The query is incredibly simple. You can filter DIRECTLY on the fact table.
-- No JOIN is required for date-based filtering.
SELECT
    SUM(amount) AS total_sales_feb_2025
FROM
    fact_sales
WHERE
    order_date >= '2025-02-01' AND order_date < '2025-03-01';

-- With a surrogate key, the query would be more complex:
-- SELECT SUM(s.amount)
-- FROM fact_sales s
-- JOIN dim_date d ON s.order_date_key = d.date_key
-- WHERE d.date_actual >= '2025-02-01' AND d.date_actual < '2025-03-01';


-- ## BENEFIT 2: INTUITIVE JOINS WHEN NEEDED ##

-- Goal: Get total sales amount on weekends vs. weekdays.

-- When you DO need attributes from the date dimension (like 'is_weekend'),
-- the JOIN condition is self-explanatory and easy to write.
SELECT
    d.is_weekend,
    SUM(s.amount) AS total_sales
FROM
    fact_sales s
JOIN
    dim_date d ON s.order_date = d.date_actual
GROUP BY
    d.is_weekend;


-- ## BENEFIT 3: SIMPLIFIED ETL ##

-- When loading data into fact_sales, you don't need a lookup step.
-- If your source data has a date, you can insert it directly.
-- With a surrogate key, you would first have to look up the integer 'date_key'
-- from 'dim_date' that corresponds to your source date before inserting.

-- Example of a simple insert (no lookup needed):
INSERT INTO fact_sales (product_id, amount, order_date)
VALUES (104, 99.99, CURRENT_DATE); -- 'CURRENT_DATE' can be used directly.

-- ## Final thoughts ##

-- This approach is ideal for dimensions with stable, universal, and simple natural keys. Dates are the perfect example. 
-- Other candidates could include ISO country codes or currency codes.

-- However, for most other dimensions like Customers, Products, or Employees, you should absolutely continue to use surrogate keys. 
-- This is because their natural keys (like an employee ID or product SKU) can change, be reassigned, or you might need to track 
-- historical changes using Slowly Changing Dimensions (SCDs), which is managed far more effectively with meaningless, 
-- integer surrogate keys.
