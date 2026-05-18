CREATE DATABASE amazon_report
USE amazon_report

--Overview
SELECT * FROM amazon_df

--Count of total rows
SELECT COUNT(*) FROM amazon_df

--Column wise datatypes
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'amazon_df';

--Null values
SELECT
    SUM(CASE WHEN [Order_ID] IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN [Date] IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN [Status] IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN [Fulfilment] IS NULL THEN 1 ELSE 0 END) AS null_fulfilment,
    SUM(CASE WHEN [Category] IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN [Size] IS NULL THEN 1 ELSE 0 END) AS null_size,
    SUM(CASE WHEN [Qty] IS NULL THEN 1 ELSE 0 END) AS null_qty,
    SUM(CASE WHEN [Amount] IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN [ship_state] IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN [ship_city] IS NULL THEN 1 ELSE 0 END) AS null_city
FROM amazon_df;

--Distinct values in 'Status'
SELECT DISTINCT(Status) FROM amazon_df

--For Fulfilment
SELECT DISTINCT(Fulfilment) FROM amazon_df

--For category
SELECT DISTINCT(Category) FROM amazon_df

--Date range 
SELECT MIN(Date) AS first_date,MAX(Date) AS last_date FROM amazon_df

--Duplicate Order IDs
SELECT [Order_ID], COUNT(*) AS occurrences
FROM amazon_df
GROUP BY [Order_ID]
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

/*QUESTIONS*/

--1.What is the total number of orders, total revenue, and total quantity sold — for completed/delivered orders only?
SELECT 
    COUNT(*) AS total_orders,
    SUM(Amount) AS total_revenue,
    SUM(Qty) AS total_quantity
FROM amazon_df 
WHERE Status IN ('Delivered')

--2.What is the count and percentage of each Status value across all orders? (order status breakdown)
SELECT 
    Status, 
    COUNT(Status) AS total_status_counts,
    ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM amazon_df),2) AS status_wise_percentages
FROM amazon_df
GROUP BY status
ORDER BY total_status_counts DESC

--3.What is the overall cancellation rate % and total revenue lost due to cancellations?
SELECT 
    ROUND(SUM(CASE WHEN [Status]='Cancelled' THEN 1 ELSE 0 END) * 100.0/COUNT(*),2) AS cancellation_rate,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN [Amount] ELSE 0 END) AS total_revenue_lost
FROM amazon_df

--4.Top 5 categories by total revenue — delivered orders only
WITH top_categories AS (
    SELECT  
        [Category] AS category,
        COUNT(*) AS total_orders,
        SUM([Amount]) AS total_amount,
        RANK() OVER(ORDER BY SUM(Amount) DESC) AS rnk
    FROM
        amazon_df
    WHERE [Status] IN ('Delivered', 'Shipped')
    GROUP BY Category
)
SELECT 
    Category
FROM top_categories
WHERE rnk<=5

--5. Category-level cancellation count, rate %, revenue lost
SELECT
    [Category],
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancelled_count,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN [Amount] ELSE 0 END)                                 AS revenue_lost
FROM amazon_df
GROUP BY [Category]
ORDER BY revenue_lost DESC;

--6.FBA vs Merchant — cancellation rate and avg order value
SELECT
    [Fulfilment],
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancelled_count,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct,
    ROUND(AVG(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] END), 2)                 AS avg_order_value
FROM amazon_df
GROUP BY [Fulfilment];

--7.Monthly trend — orders, revenue, cancellations, cancel rate
SELECT
    FORMAT([Date], 'yyyy-MM')                                                                       AS order_month,
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] ELSE 0 END)                    AS total_revenue,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancelled_orders,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct
FROM amazon_df
WHERE [Date] IS NOT NULL
GROUP BY FORMAT([Date], 'yyyy-MM')
ORDER BY order_month ASC;

--8. Worst month for cancellations using CTE
WITH monthly_summary AS (
    SELECT
        FORMAT([Date], 'yyyy-MM')                                                                   AS order_month,
        COUNT(*)                                                                                    AS total_orders,
        SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                    AS cancelled_orders,
        ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)       AS cancel_rate_pct
    FROM amazon_df
    WHERE [Date] IS NOT NULL
    GROUP BY FORMAT([Date], 'yyyy-MM')
)
SELECT TOP 1 *
FROM monthly_summary
ORDER BY cancel_rate_pct DESC;

-- 9. Running cumulative revenue MoM — window function
SELECT
    YEAR([Date])                                                                                    AS order_year,
    MONTH([Date])                                                                                   AS order_month,
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] ELSE 0 END)                    AS total_revenue,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancelled_orders,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct
FROM amazon_df
WHERE [Date] IS NOT NULL
GROUP BY YEAR([Date]), MONTH([Date])
ORDER BY order_year, order_month;


-- 10. Rank statuses by count within each category
WITH category_status AS (
    SELECT
        [Category],
        [Status],
        COUNT(*) AS status_count
    FROM amazon_df
    GROUP BY [Category], [Status]
)
SELECT
    [Category],
    [Status],
    status_count,
    RANK() OVER (PARTITION BY [Category] ORDER BY status_count DESC)                                AS status_rank
FROM category_status
ORDER BY [Category], status_rank;

/* VIEWS FOR POWER BI */
-- View 1: Monthly Summary
CREATE VIEW vw_monthly_summary AS
SELECT
    FORMAT([Date], 'yyyy-MM')                                                                       AS order_month,
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] ELSE 0 END)                    AS total_revenue,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancelled_orders,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN [Amount] ELSE 0 END)                                 AS lost_revenue,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct
FROM amazon_df
WHERE [Date] IS NOT NULL
GROUP BY FORMAT([Date], 'yyyy-MM');


-- View 2: Category Summary
CREATE VIEW vw_category_summary AS
SELECT
    [Category],
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancel_count,
    SUM(CASE WHEN [Status] = 'Returned'  THEN 1 ELSE 0 END)                                        AS return_count,
    SUM(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] ELSE 0 END)                    AS total_revenue,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN [Amount] ELSE 0 END)                                 AS lost_revenue,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct,
    ROUND(AVG(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] END), 2)                 AS avg_order_value
FROM amazon_df
GROUP BY [Category];


-- View 3: Fulfilment Comparison
CREATE VIEW vw_fulfilment_compare AS
SELECT
    [Fulfilment],
    COUNT(*)                                                                                        AS total_orders,
    SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END)                                        AS cancel_count,
    ROUND(SUM(CASE WHEN [Status] = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)           AS cancel_rate_pct,
    ROUND(AVG(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] END), 2)                 AS avg_order_value,
    SUM(CASE WHEN [Status] IN ('Delivered','Shipped') THEN [Amount] ELSE 0 END)                    AS total_revenue
FROM amazon_df
GROUP BY [Fulfilment];