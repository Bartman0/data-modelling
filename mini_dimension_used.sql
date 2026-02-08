-- Clean up previous runs if they exist
DROP TABLE IF EXISTS fact_sales_mini;
DROP TABLE IF EXISTS dim_customer_profile;
DROP TABLE IF EXISTS dim_customer;

-- 1. Create the main, lean Customer Dimension
-- This table is now much more stable and won't grow from profile changes.
CREATE TABLE dim_customer (
    customer_key    SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL,
    customer_name   VARCHAR(100)
);

-- 2. Create the Mini-Dimension for the rapidly changing attributes
-- It holds only the unique combinations of these attributes.
CREATE TABLE dim_customer_profile (
    profile_key     SERIAL PRIMARY KEY,
    income_level    VARCHAR(50),
    marital_status  VARCHAR(50),
    education_level VARCHAR(50)
);

-- 3. Create the Fact Table, linking to both dimensions
CREATE TABLE fact_sales_mini (
    sale_id         SERIAL PRIMARY KEY,
    customer_key    INT REFERENCES dim_customer(customer_key),
    profile_key     INT REFERENCES dim_customer_profile(profile_key),
    sale_date       DATE,
    sale_amount     DECIMAL(10, 2)
);

-- 4. Populate the dimensions
-- Only one record ever for Jane Doe in the main dimension
INSERT INTO dim_customer (customer_id, customer_name) VALUES (101, 'Jane Doe'); -- (key=1)

-- Populate the mini-dimension with the unique profiles that occurred
INSERT INTO dim_customer_profile (income_level, marital_status, education_level)
VALUES
    ('Medium', 'Single', 'Bachelors'), -- (key=1)
    ('High', 'Single', 'Bachelors'),   -- (key=2)
    ('High', 'Married', 'Bachelors');  -- (key=3)

-- 5. Populate the fact table, pointing to the correct customer and profile at the time of sale
-- Sale 1: customer_key=1, profile_key=1 ('Medium', 'Single')
INSERT INTO fact_sales_mini (customer_key, profile_key, sale_date, sale_amount) VALUES (1, 1, '2024-03-15', 100.00);
-- Sale 2: customer_key=1, profile_key=2 ('High', 'Single')
INSERT INTO fact_sales_mini (customer_key, profile_key, sale_date, sale_amount) VALUES (1, 2, '2024-08-20', 150.00);
-- Sale 3: customer_key=1, profile_key=3 ('High', 'Married')
INSERT INTO fact_sales_mini (customer_key, profile_key, sale_date, sale_amount) VALUES (1, 3, '2025-01-10', 200.00);

SELECT * FROM dim_customer;
SELECT * FROM dim_customer_profile;


-- ## Final thoughts ##

-- Result of Mini-Dimension Tables:
-- The dim_customer table has only one row. The dim_customer_profile is very small and only contains 
-- the 3 unique profiles that have existed across all customers.
