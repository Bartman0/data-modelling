-- ====================================================================
--  Snowflake Dimension & Conformed Facts Example
--
--  Demonstrates how two fact tables can conform to different
--  levels of a single snowflake dimension hierarchy.
-- ====================================================================

-- Clean up previous tables if they exist
DROP TABLE IF EXISTS FactStoreSales, FactRegionalMarketingSpend, DimCity, DimState, DimCountry CASCADE;

----------------------------------------------------------------------
-- ## 1. Create the Snowflake Dimension Tables (Geography)
----------------------------------------------------------------------
-- The hierarchy is Country -> State -> City.
-- This normalized structure is characteristic of a snowflake schema.

-- Highest level of the hierarchy
CREATE TABLE DimCountry (
    country_key SERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL
);

-- Middle level, links to Country
CREATE TABLE DimState (
    state_key SERIAL PRIMARY KEY,
    state_name VARCHAR(100) NOT NULL,
    country_key INT REFERENCES DimCountry(country_key)
);

-- Lowest level, links to State
CREATE TABLE DimCity (
    city_key SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    state_key INT REFERENCES DimState(state_key)
);

----------------------------------------------------------------------
-- ## 2. Create the Fact Tables
----------------------------------------------------------------------
-- These two tables model different business events and therefore have
-- different grains (levels of detail).

-- FACT TABLE 1: Conformed at the LOWEST level (City)
-- This table records daily sales, a process that occurs in a specific city.
CREATE TABLE FactStoreSales (
    sales_id SERIAL PRIMARY KEY,
    sale_date DATE NOT NULL,
    city_key INT REFERENCES DimCity(city_key), -- Foreign key to the City dimension
    sales_amount NUMERIC(10, 2) NOT NULL
);

-- FACT TABLE 2: Conformed at a HIGHER level (State)
-- This table records monthly marketing spend, which is budgeted at a state/regional level.
CREATE TABLE FactRegionalMarketingSpend (
    spend_id SERIAL PRIMARY KEY,
    spend_month DATE NOT NULL,
    state_key INT REFERENCES DimState(state_key), -- Foreign key to the State dimension
    spend_amount NUMERIC(12, 2) NOT NULL
);


----------------------------------------------------------------------
-- ## 3. Populate Tables with Sample Data
----------------------------------------------------------------------

-- Populate Dimensions
INSERT INTO DimCountry (country_name) VALUES ('United States'), ('Canada');

INSERT INTO DimState (state_name, country_key) VALUES
('California', 1),
('Texas', 1),
('Ontario', 2);

INSERT INTO DimCity (city_name, state_key) VALUES
('Los Angeles', 1),
('San Francisco', 1),
('Houston', 2),
('Dallas', 2),
('Toronto', 3);

-- Populate Fact Tables
-- Note how the foreign keys link to different levels of the same dimension.
INSERT INTO FactStoreSales (sale_date, city_key, sales_amount) VALUES
('2025-09-01', 1, 1200.50), -- Los Angeles
('2025-09-01', 2, 2500.00), -- San Francisco
('2025-09-01', 3, 950.75),  -- Houston
('2025-09-02', 1, 1800.25), -- Los Angeles
('2025-09-02', 4, 1100.00), -- Dallas
('2025-09-02', 5, 3200.00); -- Toronto

INSERT INTO FactRegionalMarketingSpend (spend_month, state_key, spend_amount) VALUES
('2025-09-01', 1, 50000.00), -- California
('2025-09-01', 2, 35000.00), -- Texas
('2025-09-01', 3, 40000.00); -- Ontario


----------------------------------------------------------------------
-- ## 4. Analytical Query: The Benefit in Action
----------------------------------------------------------------------
-- This query demonstrates the primary benefit: analyzing metrics from
-- different grains together. We can roll up the low-grain sales data
-- to the state level to compare it against the high-grain marketing spend.

WITH StateSales AS (
    -- 1. Aggregate the low-grain sales data (city level) up to the state level.
    --    This requires joining through the snowflake dimension hierarchy.
    SELECT
        s.state_key,
        SUM(fss.sales_amount) AS total_sales
    FROM
        FactStoreSales fss
    JOIN
        DimCity c ON fss.city_key = c.city_key
    JOIN
        DimState s ON c.state_key = s.state_key
    GROUP BY
        s.state_key
)
-- 2. Join the aggregated sales data with the marketing spend data at the common 'State' grain.
SELECT
    ds.state_name,
    dc.country_name,
    frms.spend_amount,
    ss.total_sales,
    -- We can now create powerful new metrics, like marketing ROI
    (ss.total_sales / frms.spend_amount) * 100 AS sales_per_dollar_spent
FROM
    FactRegionalMarketingSpend frms
JOIN
    DimState ds ON frms.state_key = ds.state_key
JOIN
    DimCountry dc ON ds.country_key = dc.country_key
LEFT JOIN
    StateSales ss ON frms.state_key = ss.state_key
ORDER BY
    ds.state_name;

-- ====================================================================
-- Final thoughts: Every real-life dimensional model with multiple
-- star schemas will contain snowflakes.
-- ====================================================================
