-- The supplier for the Dell laptop is updated in the source system.
UPDATE dim_product_natural
SET supplier = 'Dell Corp Global'
WHERE product_sku = 'LAP-DEL-123';

-- Now, run the same sales report again for historical data.
SELECT
    s.sale_date,
    p.product_name,
    p.supplier,
    s.quantity_sold
FROM
    fact_sales_natural s
JOIN
    dim_product_natural p ON s.product_sku = p.product_sku;
