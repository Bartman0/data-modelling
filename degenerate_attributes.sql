-- ========= SETUP: Clean up previous tables if they exist =========
DROP TABLE IF EXISTS fact_sales_good;
DROP TABLE IF EXISTS fact_sales_bad;
DROP TABLE IF EXISTS dim_order CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;

-- =================================================================
--  PART 1: THE INEFFICIENT APPROACH (AVOIDING DEGENERATE ATTRIBUTES) 👎
-- =================================================================
-- Here, we create a separate dimension table for the order number.
-- This is generally considered bad practice in dimensional modeling.

-- Standard Dimension Tables
CREATE TABLE dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_name VARCHAR(100)
);

CREATE TABLE dim_product (
    product_key SERIAL PRIMARY KEY,
    product_name VARCHAR(100)
);

-- An unnecessary, single-attribute dimension table for the order number
CREATE TABLE dim_order (
    order_key SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL
);

-- Fact table that must link to the unnecessary dim_order table
CREATE TABLE fact_sales_bad (
    customer_key INT REFERENCES dim_customer(customer_key),
    product_key INT REFERENCES dim_product(product_key),
    order_key INT REFERENCES dim_order(order_key), -- Foreign key to dim_order
    quantity_sold INT,
    total_amount NUMERIC(10, 2)
);

-- --- Load Sample Data ---
INSERT INTO dim_customer (customer_key, customer_name) VALUES (1, 'Alice'), (2, 'Bob');
INSERT INTO dim_product (product_key, product_name) VALUES (1, 'Laptop'), (2, 'Mouse'), (3, 'Keyboard');
INSERT INTO dim_order (order_key, order_number) VALUES (1, 'ORD-2025-001'), (2, 'ORD-2025-002');

-- Order 'ORD-2025-001' has two items (Laptop and Mouse)
INSERT INTO fact_sales_bad VALUES (1, 1, 1, 1, 1200.00); -- Alice, Laptop, Order 1
INSERT INTO fact_sales_bad VALUES (1, 2, 1, 1, 25.00);   -- Alice, Mouse, Order 1
-- Order 'ORD-2025-002' has one item (Keyboard)
INSERT INTO fact_sales_bad VALUES (2, 3, 2, 1, 75.00);    -- Bob, Keyboard, Order 2

-- --- Querying the Inefficient Model ---
-- To get details for a specific order, we MUST join the fact table to dim_order.
-- This JOIN is wasteful as dim_order contains nothing but the number itself.
SELECT
    p.product_name,
    fsb.quantity_sold,
    fsb.total_amount
FROM
    fact_sales_bad fsb
JOIN
    dim_order do_ ON fsb.order_key = do_.order_key
JOIN
    dim_product p ON fsb.product_key = p.product_key
WHERE
    do_.order_number = 'ORD-2025-001';

-- =================================================================
--  PART 2: THE EFFICIENT APPROACH (USING A DEGENERATE ATTRIBUTE) 👍
-- =================================================================
-- Here, we place the `order_number` directly into the fact table.

-- The dimension tables for customer and product remain the same.

-- Fact table with the degenerate attribute `order_number`
CREATE TABLE fact_sales_good (
    customer_key INT REFERENCES dim_customer(customer_key),
    product_key INT REFERENCES dim_product(product_key),
    order_number VARCHAR(50), -- DEGENERATE ATTRIBUTE
    quantity_sold INT,
    total_amount NUMERIC(10, 2)
);

-- --- Load Sample Data ---
-- The data is logically the same, but stored more efficiently.
INSERT INTO fact_sales_good VALUES (1, 1, 'ORD-2025-001', 1, 1200.00);
INSERT INTO fact_sales_good VALUES (1, 2, 'ORD-2025-001', 1, 25.00);
INSERT INTO fact_sales_good VALUES (2, 3, 'ORD-2025-002', 1, 75.00);

-- --- Querying the Efficient Model ---
-- The query is simpler and faster because we've eliminated a JOIN.
-- We can filter or group directly on the fact table's `order_number` column.
SELECT
    p.product_name,
    fsg.quantity_sold,
    fsg.total_amount
FROM
    fact_sales_good fsg
JOIN
    dim_product p ON fsg.product_key = p.product_key
WHERE
    fsg.order_number = 'ORD-2025-001';

-- =================================================================
--                      BENEFITS SUMMARY
-- =================================================================
/*
1.  **SIMPLICITY & REDUCED CLUTTER:**
    The 'good' model has one less table (`dim_order`) to create, manage, and load data into.
    The database schema is cleaner and easier to understand.

2.  **PERFORMANCE:**
    The query on `fact_sales_good` is inherently faster. It avoids a JOIN between the
    potentially massive fact table and the (also potentially massive) `dim_order` table.
    The database can directly filter the fact table using a `WHERE` clause on `order_number`.

3.  **USABILITY & DIRECT CONTEXT:**
    Analysts can easily group facts by the transactional identifier. For example, calculating
    the total value of each order is trivial:

    SELECT
        order_number,
        SUM(total_amount) AS order_total
    FROM
        fact_sales_good
    GROUP BY
        order_number
    ORDER BY
        order_total DESC;

    In the 'bad' model, this would have required another JOIN, further slowing down the query.
*/
