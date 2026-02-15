-- Ensure a clean slate
DROP TABLE IF EXISTS dim_employee;

-- Create the SCD Type 2 dimension for employees
CREATE TABLE dim_employee (
    -- SCD2 Key: Unique for each version of the record
    employee_sk BIGSERIAL PRIMARY KEY,
    
    -- SCD1 Pointer Key: Stores the 'employee_sk' of the *current* record
    -- for this employee. All versions (historical and current)
    -- for the same employee will share this value.
    current_employee_sk BIGINT,
    
    -- Natural Key: The business identifier (e.g., Employee ID)
    employee_nk INT NOT NULL,
    
    -- Tracked Attributes
    employee_name VARCHAR(100),
    department VARCHAR(50),
    
    -- Versioning Columns
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN NOT NULL
);

-- Indexes are crucial for performance
CREATE INDEX idx_employee_nk ON dim_employee (employee_nk);
CREATE INDEX idx_current_employee_sk ON dim_employee (current_employee_sk);

-- TRANSACTION 1: Initial Load (2023-01-15)
-- Jane Doe is hired. Her SK is 1. Her 'current_employee_sk' points to herself (1).
INSERT INTO dim_employee (
    current_employee_sk, employee_nk, employee_name, department, 
    start_date, end_date, is_current
)
VALUES (1, 101, 'Jane Doe', 'Sales', '2023-01-15', NULL, TRUE);

-- John Smith is hired. His SK is 2. His 'current_employee_sk' points to himself (2).
INSERT INTO dim_employee (
    current_employee_sk, employee_nk, employee_name, department, 
    start_date, end_date, is_current
)
VALUES (2, 102, 'John Smith', 'Engineering', '2023-03-01', NULL, TRUE);


-- TRANSACTION 2: Department Change (2024-05-20)
-- Jane Doe moves from Sales to Marketing.

-- Step 2.1: Expire the old record (SK=1)
UPDATE dim_employee
SET 
    end_date = '2024-05-19',
    is_current = FALSE
WHERE employee_nk = 101 AND is_current = TRUE;

-- Step 2.2: Insert the new current record. Its new SK will be 3.
-- It initially points to itself as the current record.
INSERT INTO dim_employee (
    current_employee_sk, employee_nk, employee_name, department, 
    start_date, end_date, is_current
)
VALUES (3, 101, 'Jane Doe', 'Marketing', '2024-05-20', NULL, TRUE);

-- Step 2.3: IMPORTANT - Update all records for employee 101
-- to point to the new current SK (3).
UPDATE dim_employee
SET current_employee_sk = 3
WHERE employee_nk = 101;

-- ====================================================================
-- Challenge: think of other ways to make the distinction between
-- historical records and current ones.
-- ====================================================================


-- TRANSACTION 3: Promotion & Name Change (2025-09-01)
-- Jane Doe gets married and promoted (now Jane Smith, Senior Marketing).

-- Step 3.1: Expire the old record (SK=3)
UPDATE dim_employee
SET 
    end_date = '2025-08-31',
    is_current = FALSE
WHERE employee_nk = 101 AND is_current = TRUE;

-- Step 3.2: Insert the new current record. Its new SK will be 4.
INSERT INTO dim_employee (
    current_employee_sk, employee_nk, employee_name, department, 
    start_date, end_date, is_current
)
VALUES (4, 101, 'Jane Smith', 'Senior Marketing', '2025-09-01', NULL, TRUE);

-- Step 3.3: Update ALL records for employee 101 to point to the
-- newest current SK (4).
UPDATE dim_employee
SET current_employee_sk = 4
WHERE employee_nk = 101;

SELECT
    employee_sk,
    current_employee_sk,
    employee_nk,
    employee_name,
    department,
    start_date,
    end_date,
    is_current
FROM
    dim_employee
ORDER BY
    employee_nk, start_date;

SELECT
    -- We select from the 'current' side of the join
    curr.current_employee_sk AS employee_sk, -- This is the SCD1 key
    curr.employee_nk,
    curr.employee_name,
    curr.department
FROM
    dim_employee AS curr
WHERE
    -- The 'is_current' flag is the fastest way to get the current state
    curr.is_current = TRUE
ORDER BY
    curr.employee_nk;

SELECT
    hist.employee_sk     AS historical_sk,
    hist.employee_name   AS name_at_the_time,
    hist.department      AS dept_at_the_time,
    hist.start_date      AS valid_from,
    hist.end_date        AS valid_to,
    '-->'                AS " ",   -- Separator
    -- Attributes from the self-joined CURRENT record
    curr.employee_sk     AS current_sk,
    curr.employee_name   AS current_name,
    curr.department      AS current_dept
FROM
    dim_employee AS hist
JOIN
    -- The self-join uses the pointer key
    dim_employee AS curr ON hist.current_employee_sk = curr.employee_sk
WHERE
    -- Ensure the 'curr' side of the join is actually the current one.
    -- This is efficient as 'curr.employee_sk' is a PK.
    curr.is_current = TRUE 
ORDER BY
    hist.employee_nk, hist.start_date;

-- ====================================================================
-- Exercise: how would you report facts against the employee state as of 2024-05-20?
-- Create as fact table something similar to this:
-- CREATE TABLE fact_sales (
--     sale_id         SERIAL PRIMARY KEY,
--     customer_key    INT REFERENCES dim_customer(customer_key),
--     sale_date       DATE,
--     sale_amount     DECIMAL(10, 2)
-- );
-- INSERT INTO fact_sales (customer_key, sale_date, sale_amount) VALUES (1, '2024-03-15', 100.00);
-- ====================================================================

-- ====================================================================
-- Final thoughts: valid_from and valid_to are most of the times based
-- on the load times of data; you may also use datetimes for these
-- attributes, so for example "2023-01-15 02:03:04" and use 
-- identical values for valid_to of a previous record as for the valid_from
-- in the current/next record.
--
-- If functional from/to timestamps are available you may want to use those instead.
--
-- But beware, for 100% reproducability you need both validity periods:
-- 1. the technical from/to to report what you 'saw' at which point in time (as-seen)
-- 2. the functioxnal from/to to report on what functionally was the truth (as-is)
-- If functional information is arriving late ('terugwerkende kracht (TWK)' or 'retroactive effect')
-- you may temporarily be reporting as-was, because you are not able to report as-is temporarily,
-- but this will ensure 100% reproducability.
-- ====================================================================
