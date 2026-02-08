-- Drop tables if they exist to ensure a clean run
DROP TABLE IF EXISTS fact_sales_natural;
DROP TABLE IF EXISTS dim_product_natural;

--======== DIMENSION TABLE USING A NATURAL KEY ========--
-- The product_sku is the business key and also the primary key.
CREATE TABLE dim_product_natural (
    product_sku VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    supplier VARCHAR(50)
);

--======== FACT TABLE LINKED TO THE NATURAL KEY ========--
CREATE TABLE fact_sales_natural (
    sale_id SERIAL PRIMARY KEY,
    sale_date DATE,
    product_sku VARCHAR(20) REFERENCES dim_product_natural(product_sku),
    quantity_sold INT,
    total_amount NUMERIC(10, 2)
);

--======== POPULATE WITH INITIAL DATA ========--
INSERT INTO dim_product_natural (product_sku, product_name, category, supplier) VALUES
('LAP-DEL-123', 'Dell XPS 15', 'Laptop', 'Dell Inc.'),
('MON-SAM-456', 'Samsung Odyssey G7', 'Monitor', 'Samsung Electronics');

INSERT INTO fact_sales_natural (sale_date, product_sku, quantity_sold, total_amount) VALUES
('2025-09-10', 'LAP-DEL-123', 1, 1500.00),
('2025-09-15', 'MON-SAM-456', 2, 1200.00);

-- Let's check the sales report
SELECT
    s.sale_date,
    p.product_name,
    p.supplier,
    s.quantity_sold
FROM
    fact_sales_natural s
JOIN
    dim_product_natural p ON s.product_sku = p.product_sku;
