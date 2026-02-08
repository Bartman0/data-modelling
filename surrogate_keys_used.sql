-- Drop tables if they exist to ensure a clean run
DROP TABLE IF EXISTS fact_sales_surrogate;
DROP TABLE IF EXISTS dim_product_surrogate;

--======== DIMENSION TABLE USING A SURROGATE KEY ========--
CREATE TABLE dim_product_surrogate (
    product_key SERIAL PRIMARY KEY,         -- Surrogate Key
    product_sku VARCHAR(20),                -- Natural Key (now just an attribute)
    product_name VARCHAR(100),
    category VARCHAR(50),
    supplier VARCHAR(50),
    is_active BOOLEAN,                      -- SCD Type 2: To track the current version
    start_date DATE,
    end_date DATE
);

--======== FACT TABLE LINKED TO THE SURROGATE KEY ========--
-- The fact table is now smaller and joins are faster on an integer key.
CREATE TABLE fact_sales_surrogate (
    sale_id SERIAL PRIMARY KEY,
    sale_date DATE,
    product_key INT REFERENCES dim_product_surrogate(product_key), -- Foreign key is the surrogate key
    quantity_sold INT,
    total_amount NUMERIC(10, 2)
);

--======== POPULATE WITH INITIAL DATA ========--
INSERT INTO dim_product_surrogate (product_sku, product_name, category, supplier, is_active, start_date, end_date) VALUES
('LAP-DEL-123', 'Dell XPS 15', 'Laptop', 'Dell Inc.', TRUE, '2025-01-01', NULL),
('MON-SAM-456', 'Samsung Odyssey G7', 'Monitor', 'Samsung Electronics', TRUE, '2025-01-01', NULL);

-- Sales are linked to the surrogate key (e.g., product_key 1 for the Dell laptop)
INSERT INTO fact_sales_surrogate (sale_date, product_key, quantity_sold, total_amount) VALUES
('2025-09-10', 1, 1, 1500.00),
('2025-09-15', 2, 2, 1200.00);

-- The supplier changes on October 1, 2025.

-- Step 1: Expire the old product version.
UPDATE dim_product_surrogate
SET
    end_date = '2025-09-30',
    is_active = FALSE
WHERE product_key = 1;

-- Step 2: Insert a new version of the product with the updated supplier.
-- This gets a new surrogate key (product_key = 3).
INSERT INTO dim_product_surrogate (product_sku, product_name, category, supplier, is_active, start_date, end_date) VALUES
('LAP-DEL-123', 'Dell XPS 15', 'Laptop', 'Dell Corp Global', TRUE, '2025-10-01', NULL);

-- A new sale occurs with the updated product version.
-- This new sale is linked to the new surrogate key (product_key = 3).
INSERT INTO fact_sales_surrogate (sale_date, product_key, quantity_sold, total_amount) VALUES
('2025-10-02', 3, 1, 1550.00);

-- Now, run the historical report again. The old sale is still linked to product_key = 1.
SELECT
    s.sale_date,
    p.product_name,
    p.supplier,
    s.quantity_sold
FROM
    fact_sales_surrogate s
JOIN
    dim_product_surrogate p ON s.product_key = p.product_key
ORDER BY
    s.sale_date;