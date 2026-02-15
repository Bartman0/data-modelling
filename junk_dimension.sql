-- ====================================================================
-- Step 1: Create and populate the source tables
-- These represent the distinct, low-cardinality attributes
-- that we want to combine into our junk dimension.
-- ====================================================================

-- Drop tables if they already exist to make the script re-runnable
DROP TABLE IF EXISTS Dim_Junk_OrderAttributes;
DROP TABLE IF EXISTS Source_OrderStatus;
DROP TABLE IF EXISTS Source_PaymentMethod;

-- Source Table 1: Order Status
CREATE TABLE Source_OrderStatus (
    OrderStatusKey INT PRIMARY KEY,
    OrderStatusDescription VARCHAR(50) NOT NULL
);

INSERT INTO Source_OrderStatus (OrderStatusKey, OrderStatusDescription) VALUES
(1, 'Pending'),
(2, 'Processing'),
(3, 'Shipped'),
(4, 'Delivered'),
(5, 'Cancelled');

-- Source Table 2: Payment Method
CREATE TABLE Source_PaymentMethod (
    PaymentMethodKey INT PRIMARY KEY,
    PaymentMethodDescription VARCHAR(50) NOT NULL
);

INSERT INTO Source_PaymentMethod (PaymentMethodKey, PaymentMethodDescription) VALUES
(101, 'Credit Card'),
(102, 'PayPal'),
(103, 'Bank Transfer'),
(104, 'Gift Card');


-- ====================================================================
-- Step 2: Create the Junk Dimension table
-- This table will hold every possible combination of the source attributes.
-- It includes a surrogate key which will be used in the fact table.
-- ====================================================================

CREATE TABLE Dim_Junk_OrderAttributes (
    -- PostgreSQL uses GENERATED ALWAYS AS IDENTITY for auto-incrementing surrogate keys
    JunkAttributeKey INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,

    -- The descriptive attributes from our sources
    OrderStatusDescription VARCHAR(50) NOT NULL,
    PaymentMethodDescription VARCHAR(50) NOT NULL,

    -- We can also include other simple flags directly
    IsGiftFlag VARCHAR(3) NOT NULL -- e.g., 'Yes' or 'No'
);


-- ====================================================================
-- Step 3: Populate the Junk Dimension using a CROSS JOIN
-- The CROSS JOIN is the key to generating the Cartesian product,
-- which creates a row for every possible combination of the attributes.
-- ====================================================================

INSERT INTO Dim_Junk_OrderAttributes (
    OrderStatusDescription,
    PaymentMethodDescription,
    IsGiftFlag
)
SELECT
    os.OrderStatusDescription,
    pm.PaymentMethodDescription,
    gf.IsGift -- This 'IsGift' column comes from the derived table below
FROM
    Source_OrderStatus AS os
CROSS JOIN
    Source_PaymentMethod AS pm
CROSS JOIN
    -- This VALUES clause for creating a derived table works perfectly in PostgreSQL
    (VALUES ('Yes'), ('No')) AS gf(IsGift);


-- ====================================================================
-- Step 4: Verify the result
-- This query shows the newly created junk dimension.
-- You should see 5 (statuses) * 4 (payment methods) * 2 (gift flags) = 40 rows.
-- ====================================================================

SELECT * FROM Dim_Junk_OrderAttributes;

-- ====================================================================
-- Result: One join is required from facts to this one dimension
-- instead of three separate joins.
-- Natural key: combination of all separate attributs.
-- ====================================================================

-- ====================================================================
-- Think about: what are the consequences and actions to take if
-- the junk dimension is extended with additional attributes?
-- What actions do you envision?
-- ====================================================================
