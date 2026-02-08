-- Clean up previous runs if they exist
DROP TABLE IF EXISTS fact_sales_scd2;
DROP TABLE IF EXISTS dim_customer_scd2;

-- 1. Create the SCD Type 2 Dimension Table
-- This table will store a new row for every historical change.
CREATE TABLE dim_customer_scd2 (
    customer_key    SERIAL PRIMARY KEY, -- Surrogate Key
    customer_id     INT NOT NULL,       -- Natural Key
    customer_name   VARCHAR(100),
    -- Attributes that will be tracked for changes:
    income_level    VARCHAR(50),
    marital_status  VARCHAR(50),
    education_level VARCHAR(50),
    -- SCD2 columns to track history:
    start_date      DATE,
    end_date        DATE,
    is_current      BOOLEAN
);

-- 2. Create the Fact Table
CREATE TABLE fact_sales_scd2 (
    sale_id         SERIAL PRIMARY KEY,
    customer_key    INT REFERENCES dim_customer_scd2(customer_key),
    sale_date       DATE,
    sale_amount     DECIMAL(10, 2)
);

-- 3. Populate with data for one customer, "Jane Doe"
-- Initial State: January 1, 2024
INSERT INTO dim_customer_scd2 (customer_id, customer_name, income_level, marital_status, education_level, start_date, end_date, is_current)
VALUES (101, 'Jane Doe', 'Medium', 'Single', 'Bachelors', '2024-01-01', NULL, TRUE); -- Current version (key=1)

-- A sale happens while she is in this state
INSERT INTO fact_sales_scd2 (customer_key, sale_date, sale_amount) VALUES (1, '2024-03-15', 100.00);

-- Change 1: Jane's income level increases on June 1, 2024
-- Expire the old record
UPDATE dim_customer_scd2 SET end_date = '2024-05-31', is_current = FALSE WHERE customer_key = 1;
-- Insert the new record
INSERT INTO dim_customer_scd2 (customer_id, customer_name, income_level, marital_status, education_level, start_date, end_date, is_current)
VALUES (101, 'Jane Doe', 'High', 'Single', 'Bachelors', '2024-06-01', NULL, TRUE); -- New current version (key=2)

-- A sale happens in this new state
INSERT INTO fact_sales_scd2 (customer_key, sale_date, sale_amount) VALUES (2, '2024-08-20', 150.00);

-- Change 2: Jane gets married on December 1, 2024
-- Expire the old record
UPDATE dim_customer_scd2 SET end_date = '2024-11-30', is_current = FALSE WHERE customer_key = 2;
-- Insert the new record
INSERT INTO dim_customer_scd2 (customer_id, customer_name, income_level, marital_status, education_level, start_date, end_date, is_current)
VALUES (101, 'Jane Doe', 'High', 'Married', 'Bachelors', '2024-12-01', NULL, TRUE); -- New current version (key=3)

-- Another sale happens
INSERT INTO fact_sales_scd2 (customer_key, sale_date, sale_amount) VALUES (3, '2025-01-10', 200.00);

-- Imagine millions of customers with dozens of changes. The dim_customer_scd2 table would become enormous.
SELECT * FROM dim_customer_scd2 ORDER BY customer_key;