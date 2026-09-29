--Database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'Central_Superstore_DW')
BEGIN
    CREATE DATABASE Central_Superstore_DW;
END;
GO
USE Central_Superstore_DW;
GO
-- Bronze Layer
-- 1. Staging table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Staging_Superstore') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Staging_Superstore (
    RowID           INT             NOT NULL,
    OrderID         VARCHAR(20)     NOT NULL,
    OrderDate       DATE            NOT NULL,
    ShipDate        DATE            NOT NULL,
    ShipMode        VARCHAR(30)     NOT NULL,
    CustomerID      VARCHAR(20)     NOT NULL,
    CustomerName    VARCHAR(100)    NOT NULL,
    Segment         VARCHAR(30)     NOT NULL,
    Country         VARCHAR(50)     NOT NULL,
    City            VARCHAR(50)     NOT NULL,
    State           VARCHAR(50)     NOT NULL,
    PostalCode      VARCHAR(10)     NOT NULL,
    Region          VARCHAR(20)     NOT NULL,
    ProductID       VARCHAR(30)     NOT NULL,
    Category        VARCHAR(30)     NOT NULL,
    SubCategory     VARCHAR(30)     NOT NULL,
    ProductName     VARCHAR(255)    NOT NULL,
    Sales           DECIMAL(10,4)   NOT NULL,
    Quantity        INT             NOT NULL,
    Discount        DECIMAL(4,2)    NOT NULL,
    Profit          DECIMAL(10,4)   NOT NULL,
    CONSTRAINT pk_Staging_Superstore PRIMARY KEY (RowID)
);
END;
GO

TRUNCATE TABLE dbo.Staging_Superstore;
GO
BULK INSERT dbo.Staging_Superstore
FROM 'C:\Users\Active\Downloads\Central_Superstore.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO
-- Silver Layer
-- Step A: Schema Definition

-- Customer dimension
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Dim_Customer') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Dim_Customer (
    CustomerKey     INT IDENTITY(1,1)  PRIMARY KEY,
    CustomerID      VARCHAR(20)        NOT NULL UNIQUE,
    CustomerName    VARCHAR(100)       NOT NULL,
    Segment         VARCHAR(30)        NOT NULL
);
END;
GO

-- Product dimension
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Dim_Product') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Dim_Product (
    ProductKey      INT IDENTITY(1,1)  PRIMARY KEY,
    ProductID       VARCHAR(30)        NOT NULL,
    ProductName     VARCHAR(255)       NOT NULL,
    Category        VARCHAR(30)        NOT NULL,
    SubCategory     VARCHAR(30)        NOT NULL,
    CONSTRAINT uq_Dim_Product UNIQUE (ProductID, ProductName, Category, SubCategory)
);
END;
GO

-- Location dimension
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Dim_Location') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Dim_Location (
    LocationKey     INT IDENTITY(1,1)  PRIMARY KEY,
    City            VARCHAR(50)        NOT NULL,
    State           VARCHAR(50)        NOT NULL,
    PostalCode      VARCHAR(10)        NOT NULL,
    Region          VARCHAR(20)        NOT NULL,
    Country         VARCHAR(50)        NOT NULL,
    CONSTRAINT uq_Dim_Location UNIQUE (City, State, PostalCode, Region, Country)
);
END;
GO

-- Ship mode dimension
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Dim_ShipMode') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Dim_ShipMode (
    ShipModeKey     INT IDENTITY(1,1)  PRIMARY KEY,
    ShipMode        VARCHAR(30)        NOT NULL UNIQUE
);
END;
GO

-- Date dimension
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Dim_Date') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Dim_Date (
    DateKey             INT             PRIMARY KEY,
    FullDate            DATE            NOT NULL UNIQUE,
    DayNum              INT             NOT NULL,
    MonthNum            INT             NOT NULL,
    MonthName           VARCHAR(10)     NOT NULL,
    CalendarQuarter     INT             NOT NULL,
    CalendarYear        INT             NOT NULL
);
END;
GO

-- Fact table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Fact_Sales') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.Fact_Sales (
    SalesKey        INT             PRIMARY KEY, 
    OrderID         VARCHAR(20)     NOT NULL,
    OrderDateKey    INT             NOT NULL,
    ShipDateKey     INT             NOT NULL,
    CustomerKey     INT             NOT NULL,
    ProductKey      INT             NOT NULL,
    LocationKey     INT             NOT NULL,
    ShipModeKey     INT             NOT NULL,
    Sales           DECIMAL(10,4)   NOT NULL,
    Quantity        INT             NOT NULL,
    Discount        DECIMAL(4,2)    NOT NULL,
    Profit          DECIMAL(10,4)   NOT NULL,
    CONSTRAINT fk_Fact_OrderDate FOREIGN KEY (OrderDateKey) REFERENCES dbo.Dim_Date(DateKey),
    CONSTRAINT fk_Fact_ShipDate  FOREIGN KEY (ShipDateKey)  REFERENCES dbo.Dim_Date(DateKey),
    CONSTRAINT fk_Fact_Customer  FOREIGN KEY (CustomerKey)  REFERENCES dbo.Dim_Customer(CustomerKey),
    CONSTRAINT fk_Fact_Product   FOREIGN KEY (ProductKey)   REFERENCES dbo.Dim_Product(ProductKey),
    CONSTRAINT fk_Fact_Location  FOREIGN KEY (LocationKey)  REFERENCES dbo.Dim_Location(LocationKey),
    CONSTRAINT fk_Fact_ShipMode  FOREIGN KEY (ShipModeKey)  REFERENCES dbo.Dim_ShipMode(ShipModeKey)
);
END;
GO

-- Step B: Data Transformation & Population

-- 1. Dim_Customer
INSERT INTO dbo.Dim_Customer (CustomerID, CustomerName, Segment)
SELECT DISTINCT CustomerID, CustomerName, Segment
FROM dbo.Staging_Superstore s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Dim_Customer c WHERE c.CustomerID = s.CustomerID
);
GO
-- 2. Dim_Product
INSERT INTO dbo.Dim_Product (ProductID, ProductName, Category, SubCategory)
SELECT DISTINCT ProductID, ProductName, Category, SubCategory
FROM dbo.Staging_Superstore s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Dim_Product p 
    WHERE p.ProductID = s.ProductID 
      AND p.ProductName = s.ProductName 
      AND p.Category = s.Category 
      AND p.SubCategory = s.SubCategory
);
GO
-- 3. Dim_Location
INSERT INTO dbo.Dim_Location (City, State, PostalCode, Region, Country)
SELECT DISTINCT City, State, PostalCode, Region, Country
FROM dbo.Staging_Superstore s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Dim_Location l 
    WHERE l.City = s.City 
      AND l.State = s.State 
      AND l.PostalCode = s.PostalCode 
      AND l.Region = s.Region 
      AND l.Country = s.Country
);
GO
-- 4. Dim_ShipMod
INSERT INTO dbo.Dim_ShipMode (ShipMode)
SELECT DISTINCT ShipMode
FROM dbo.Staging_Superstore s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Dim_ShipMode sm WHERE sm.ShipMode = s.ShipMode
);
GO
-- 5. Dim_Date
INSERT INTO dbo.Dim_Date (DateKey, FullDate, DayNum, MonthNum, MonthName, CalendarQuarter, CalendarYear)
SELECT DISTINCT
    CAST(FORMAT(d, 'yyyyMMdd') AS INT)  AS DateKey,
    d                                   AS FullDate,
    DAY(d)                              AS DayNum,
    MONTH(d)                            AS MonthNum,
    DATENAME(MONTH, d)                  AS MonthName,
    DATEPART(QUARTER, d)                AS CalendarQuarter,
    YEAR(d)                             AS CalendarYear
FROM (
    SELECT OrderDate AS d FROM dbo.Staging_Superstore
    UNION
    SELECT ShipDate AS d FROM dbo.Staging_Superstore
) AS AllDates
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Dim_Date dt WHERE dt.DateKey = CAST(FORMAT(AllDates.d, 'yyyyMMdd') AS INT)
);
GO
-- 6. Fact_Sales (Mapping keys)
INSERT INTO dbo.Fact_Sales
    (SalesKey, OrderID, OrderDateKey, ShipDateKey, CustomerKey, ProductKey,
     LocationKey, ShipModeKey, Sales, Quantity, Discount, Profit)
SELECT
    s.RowID,
    s.OrderID,
    CAST(FORMAT(s.OrderDate, 'yyyyMMdd') AS INT),
    CAST(FORMAT(s.ShipDate, 'yyyyMMdd') AS INT),
    c.CustomerKey,
    p.ProductKey,
    l.LocationKey,
    sm.ShipModeKey,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit
FROM dbo.Staging_Superstore s
JOIN dbo.Dim_Customer  c  ON s.CustomerID = c.CustomerID
JOIN dbo.Dim_Product   p  ON s.ProductID = p.ProductID
                          AND s.ProductName = p.ProductName
                          AND s.Category = p.Category
                          AND s.SubCategory = p.SubCategory
JOIN dbo.Dim_Location  l  ON s.City = l.City
                          AND s.State = l.State
                          AND s.PostalCode = l.PostalCode
                          AND s.Region = l.Region
                          AND s.Country = l.Country
JOIN dbo.Dim_ShipMode  sm ON s.ShipMode = sm.ShipMode
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Fact_Sales f WHERE f.SalesKey = s.RowID
);
GO

--(before)
SET STATISTICS IO ON;
SELECT l.Region, p.Category, SUM(f.Sales) AS TotalSales
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product  p ON f.ProductKey  = p.ProductKey
JOIN dbo.Dim_Location l ON f.LocationKey = l.LocationKey
GROUP BY l.Region, p.Category;
SET STATISTICS IO OFF;
GO
-- Gold Layer
-- view and stored procedure

IF OBJECT_ID('dbo.vw_KPI_Category_Year', 'V') IS NOT NULL
    DROP VIEW dbo.vw_KPI_Category_Year;
GO

CREATE VIEW dbo.vw_KPI_Category_Year AS
SELECT
    p.Category,
    d.CalendarYear,
    COUNT(DISTINCT f.OrderID)                        AS TotalOrders,
    SUM(f.Quantity)                                   AS TotalUnitsSold,
    SUM(f.Sales)                                     AS TotalSales,
    SUM(f.Profit)                                    AS TotalProfit,
    ROUND(100.0 * SUM(f.Profit) / SUM(f.Sales), 2)  AS ProfitMarginPct,
    ROUND(AVG(f.Discount), 3)                        AS AvgDiscount
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product p ON f.ProductKey  = p.ProductKey
JOIN dbo.Dim_Date    d ON f.OrderDateKey = d.DateKey
GROUP BY p.Category, d.CalendarYear;
GO

-- STORED PROCEDURE
IF OBJECT_ID('dbo.sp_GetKPIByDateRange', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetKPIByDateRange;
GO

CREATE PROCEDURE dbo.sp_GetKPIByDateRange
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @StartDate                                       AS PeriodStart,
        @EndDate                                         AS PeriodEnd,
        COUNT(DISTINCT f.OrderID)                        AS TotalOrders,
        COUNT(DISTINCT f.CustomerKey)                    AS TotalCustomers,
        SUM(f.Sales)                                     AS TotalSales,
        SUM(f.Profit)                                    AS TotalProfit,
        ROUND(100.0 * SUM(f.Profit) / SUM(f.Sales), 2)   AS ProfitMarginPct,
        ROUND(SUM(f.Sales) / COUNT(DISTINCT f.OrderID), 2) AS AvgOrderValue
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Date d ON f.OrderDateKey = d.DateKey
    WHERE d.FullDate BETWEEN @StartDate AND @EndDate;
END;
GO

-- business-analytics areas
-- SECTION A: JOINS

-- Q1. INNER JOIN across the full star
SELECT
    f.SalesKey,
    f.OrderID,
    od.FullDate           AS OrderDate,
    c.CustomerName,
    c.Segment,
    p.ProductName,
    p.Category,
    p.SubCategory,
    l.City,
    l.State,
    sm.ShipMode,
    f.Sales,
    f.Quantity,
    f.Discount,
    f.Profit
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Date     od ON f.OrderDateKey = od.DateKey
JOIN dbo.Dim_Customer c  ON f.CustomerKey  = c.CustomerKey
JOIN dbo.Dim_Product  p  ON f.ProductKey   = p.ProductKey
JOIN dbo.Dim_Location l  ON f.LocationKey  = l.LocationKey
JOIN dbo.Dim_ShipMode sm ON f.ShipModeKey  = sm.ShipModeKey;
GO
-- Confirms every fact row successfully joins to all five dimensions

-- Q2. INNER JOIN + GROUP BY: total sales and profit by Region and Category
SELECT
    l.Region,
    p.Category,
    SUM(f.Sales)   AS TotalSales,
    SUM(f.Profit)  AS TotalProfit
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product  p ON f.ProductKey  = p.ProductKey
JOIN dbo.Dim_Location l ON f.LocationKey = l.LocationKey
GROUP BY l.Region, p.Category
ORDER BY TotalProfit DESC;
GO
-- Observation: Technology is the primary profit engine in the Central region but Furniture operates at a net loss despite high sales volume 
-- Insight: Furniture top-line revenue is comparable to Technology and Office Supplies, 
-- but high cost structures or aggressive discounting are affecting negatively

-- Q3. INNER JOIN + CASE:classify every order line into a profitability tier 
-- and count how many fall into each tier, by Category
SELECT
    p.Category,
    CASE
        WHEN f.Profit < 0                      THEN 'Loss'
        WHEN f.Profit BETWEEN 0 AND 20         THEN 'Low Margin'
        ELSE 'Healthy Margin'
    END AS ProfitTier,
    COUNT(*) AS NumOrderLines
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product p ON f.ProductKey = p.ProductKey
GROUP BY
    p.Category,
    CASE
        WHEN f.Profit < 0                      THEN 'Loss'
        WHEN f.Profit BETWEEN 0 AND 20         THEN 'Low Margin'
        ELSE 'Healthy Margin'
    END
ORDER BY p.Category, ProfitTier;
GO
--Observation: Furniture order lines, 317 operate at a Loss, while only 113 achieve a Healthy Margin. 
--In contrast, Technology shows high operational health with only 49 Loss order lines. 
--Office Supplies is heavily concentrated in the Low Margin tier.  
--Insight: The overall loss in Furniture from Q2 is driven by sheer volume of unprofitable transactions rather than a few isolated outliers. 
--Office Supplies generates steady volume but relies heavily on low-margin items.

-- SECTION B: SUBQUERIES

-- Q4. Non-correlated subquery in WHERE
SELECT f.SalesKey, f.OrderID, f.Sales
FROM dbo.Fact_Sales f
WHERE f.Sales > (SELECT AVG(Sales) FROM dbo.Fact_Sales);
GO
--Observation: Out of the dataset, 550 order lines exceed the global average sales threshold per line item
--Insight: Revenue is heavily right-skewed by a small cluster of high-value transactions, While many transactions fall below the mean

-- Q5. Correlated subquery in WHERE
SELECT
    c.CustomerName,
    c.Segment,
    SUM(f.Profit) AS CustomerProfit
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Customer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, c.CustomerName, c.Segment
HAVING SUM(f.Profit) > (
    SELECT AVG(CustomerTotalProfit)
    FROM (
        SELECT f2.CustomerKey, SUM(f2.Profit) AS CustomerTotalProfit
        FROM dbo.Fact_Sales f2
        JOIN dbo.Dim_Customer c2 ON f2.CustomerKey = c2.CustomerKey
        WHERE c2.Segment = c.Segment
        GROUP BY f2.CustomerKey
    ) AS SegProfit
);
GO
--Observation: Out of the entire customer base, exactly 220 customers generate cumulative profits higher than the average profit of their specific market segment
--Insight: Customer profitability is heavily concentrated within a select group of top performers across each market segment. 
--These high-yield accounts drive overall segment profitability, balancing out low-margin or loss-making customers.

-- Q6. Subquery in FROM (derived/table subquery): top 5 products by total revenue
SELECT TOP 5 ProductName, TotalRevenue
FROM (
    SELECT p.ProductName, SUM(f.Sales) AS TotalRevenue
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Product p ON f.ProductKey = p.ProductKey
    GROUP BY p.ProductName
) AS ProductRevenue
ORDER BY TotalRevenue DESC;
GO
--Observation: The top five revenue drivers are dominated by high-end office technology and binding machines
--Insight: Top-tier top-line revenue is heavily dependent on commercial-grade office hardware and document-binding equipment

-- Q7. Subquery in SELECT (scalar subquery per row): each customer alongside their total number of distinct orders.
SELECT
    c.CustomerName,
    c.Segment,
    (SELECT COUNT(DISTINCT f.OrderID)
     FROM dbo.Fact_Sales f
     WHERE f.CustomerKey = c.CustomerKey) AS OrderCount
FROM dbo.Dim_Customer c
ORDER BY OrderCount DESC;
GO
--Observation: Out of 629 total customers, purchase frequency peaks at 7 distinct orders (Steve Chapman in the Corporate segment), 
--with a small tier of repeat buyers placing 5 to 6 orders
--Insight: Customer transaction engagement is widely spread out across many accounts rather than relying on heavy high-frequency buyers

-- SECTION C: CTEs

-- Q8. Nested CTE: first aggregate sales by month, then rank the months by total sales.
WITH MonthlySales AS (
    SELECT
        d.CalendarYear,
        d.MonthNum,
        d.MonthName,
        SUM(f.Sales) AS TotalSales
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Date d ON f.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear, d.MonthNum, d.MonthName
),
RankedMonths AS (
    SELECT
        CalendarYear,
        MonthName,
        TotalSales,
        RANK() OVER (ORDER BY TotalSales DESC) AS SalesRank
    FROM MonthlySales
)
SELECT * FROM RankedMonths
WHERE SalesRank <= 5
ORDER BY SalesRank;
GO
--Observation: The single highest revenue month in the dataset was September 2013
--Insight: Top-performing months are heavily clustered in Q4 and early Q1, reflecting strong seasonal purchasing cycles

-- Q9. CTE + window function: rank customers by total spend to find the top 10
WITH CustomerSpend AS (
    SELECT
        c.CustomerKey,
        c.CustomerName,
        c.Segment,
        SUM(f.Sales) AS TotalSpend
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Customer c ON f.CustomerKey = c.CustomerKey
    GROUP BY c.CustomerKey, c.CustomerName, c.Segment
)
SELECT TOP 10
    CustomerName,
    Segment,
    TotalSpend,
    RANK() OVER (ORDER BY TotalSpend DESC) AS SpendRank
FROM CustomerSpend
ORDER BY SpendRank;
GO
--Observation: The top 10 customer ranking is led by Tamara Chand (Corporate), The top 10 threshold cuts off at Laura Armstrong (Corporate).
--Insight: Customer lifetime revenue is concentrated heavily among key accounts in the Corporate and Consumer segments

-- SECTION D: BUSINESS ANALYTICS (Profitability, Customer Behavior, Sales Trends)

-- Q10. PROFITABILITY: margin % by Category and Sub-Category, 
-- with a CASE-based margin tier, sorted to surface the worst performers.
SELECT
    p.Category,
    p.SubCategory,
    SUM(f.Sales)  AS TotalSales,
    SUM(f.Profit) AS TotalProfit,
    ROUND(100.0 * SUM(f.Profit) / SUM(f.Sales), 2) AS ProfitMarginPct,
    CASE
        WHEN SUM(f.Profit) < 0 THEN 'Loss-Making'
        WHEN 100.0 * SUM(f.Profit) / SUM(f.Sales) < 10 THEN 'Thin Margin'
        ELSE 'Profitable'
    END AS MarginTier
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product p ON f.ProductKey = p.ProductKey
GROUP BY p.Category, p.SubCategory
ORDER BY ProfitMarginPct ASC;
GO
--Observation: The worst-performing product sub-category is Furnishings (Furniture) with a profit margin
--Insight: Seven total sub-categories fall into the Loss-Making tier, spanning across all three primary categories. 
--High-performing sub-categories like Copiers and Paper generate healthy cash flow, 
--but their contributions are severely diluted by heavy losses in Furnishings, Appliances, Tables, and Bookcases

-- Q11. PROFITABILITY: does heavier discounting correlate with losses?
--      Average discount on loss-making vs profitable order lines.
SELECT
    CASE WHEN f.Profit < 0 THEN 'Loss-Making' ELSE 'Profitable' END AS OrderOutcome,
    COUNT(*)              AS NumOrderLines,
    ROUND(AVG(f.Discount), 3) AS AvgDiscount
FROM dbo.Fact_Sales f
GROUP BY CASE WHEN f.Profit < 0 THEN 'Loss-Making' ELSE 'Profitable' END;
GO
--Observation: Profitable order lines have an average discount rate, whereas Loss-Making order lines suffer from an average discount rate
--Insight: There is a direct, strong positive correlation between heavy discounting and transactional net loss

-- Q12. CUSTOMER BEHAVIOR: one-time vs repeat customers (CTE + CASE).
WITH CustomerOrderCounts AS (
    SELECT c.CustomerKey, COUNT(DISTINCT f.OrderID) AS OrderCount
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Customer c ON f.CustomerKey = c.CustomerKey
    GROUP BY c.CustomerKey
)
SELECT
    CASE WHEN OrderCount = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END AS CustomerType,
    COUNT(*) AS NumCustomers
FROM CustomerOrderCounts
GROUP BY CASE WHEN OrderCount = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END;
GO
--Observation: Out of 629 total customers, 284 are One-Time Customers, while 345 are Repeat Customers.
--Insight: While a slight majority of customers return for repeat purchases, almost half of the client base churns after a single transaction

-- Q13. CUSTOMER BEHAVIOR: 
-- order count and average order value by customer Segment.
SELECT
    c.Segment,
    COUNT(DISTINCT c.CustomerKey) AS NumCustomers,
    COUNT(DISTINCT f.OrderID)     AS NumOrders,
    SUM(f.Sales)                  AS TotalSales,
    ROUND(SUM(f.Sales) / COUNT(DISTINCT f.OrderID), 2) AS AvgOrderValue
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Customer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.Segment
ORDER BY TotalSales DESC;
GO
--Observation: The Consumer segment is the largest driver of total sales volume
--Insight: While Consumer generates the bulk of total revenue due to pure customer volume, Corporate transactions are intrinsically more valuable per order

-- Q14. SALES TRENDS: yearly sales and profit trend.
SELECT
    d.CalendarYear,
    SUM(f.Sales)  AS TotalSales,
    SUM(f.Profit) AS TotalProfit
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Date d ON f.OrderDateKey = d.DateKey
GROUP BY d.CalendarYear
ORDER BY d.CalendarYear;
GO
--Observation: Top-line revenue increased significantly from 2013 to 2016. 
--However, net profit experienced extreme volatility: starting at a critically low in 2013, peaking in 2015, and dropping by in 2016 despite sales remaining virtually flat compared to 2015
--Insight: Top-line revenue growth has uncoupled from net profitability. The sharp drop in 2016 profits—despite maintaining baseline sales volume—indicates sudden cost increases, 
--heavier promotional discounting, or unfavorable product mix changes. 

-- Q15. SALES TRENDS: month-over-month sales growth using
-- window function to compare each month to the previous one.
WITH MonthlySales AS (
    SELECT
        d.CalendarYear,
        d.MonthNum,
        d.MonthName,
        SUM(f.Sales) AS TotalSales
    FROM dbo.Fact_Sales f
    JOIN dbo.Dim_Date d ON f.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear, d.MonthNum, d.MonthName
)
SELECT
    CalendarYear,
    MonthName,
    TotalSales,
    LAG(TotalSales) OVER (ORDER BY CalendarYear, MonthNum) AS PrevMonthSales,
    ROUND(
        100.0 * (TotalSales - LAG(TotalSales) OVER (ORDER BY CalendarYear, MonthNum))
        / NULLIF(LAG(TotalSales) OVER (ORDER BY CalendarYear, MonthNum), 0), 2
    ) AS MoMGrowthPct
FROM MonthlySales
ORDER BY CalendarYear, MonthNum;
GO
--Observation: Revenue demonstrates extreme monthly volatility across all years
--Insight: Revenue is driven by sharp, unpredictable purchasing bursts rather than stable, recurring demand

-- Indexing and query-optimization

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_FactSales_CustomerKey' AND object_id = OBJECT_ID('dbo.Fact_Sales'))
    EXEC('CREATE NONCLUSTERED INDEX ix_FactSales_CustomerKey ON dbo.Fact_Sales (CustomerKey);');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_FactSales_ProductKey' AND object_id = OBJECT_ID('dbo.Fact_Sales'))
    EXEC('CREATE NONCLUSTERED INDEX ix_FactSales_ProductKey ON dbo.Fact_Sales (ProductKey);');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_FactSales_LocationKey' AND object_id = OBJECT_ID('dbo.Fact_Sales'))
    EXEC('CREATE NONCLUSTERED INDEX ix_FactSales_LocationKey ON dbo.Fact_Sales (LocationKey);');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_FactSales_ShipModeKey' AND object_id = OBJECT_ID('dbo.Fact_Sales'))
    EXEC('CREATE NONCLUSTERED INDEX ix_FactSales_ShipModeKey ON dbo.Fact_Sales (ShipModeKey);');

-- OrderDateKey is the most heavily used FK
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_FactSales_OrderDateKey' AND object_id = OBJECT_ID('dbo.Fact_Sales'))
    EXEC('CREATE NONCLUSTERED INDEX ix_FactSales_OrderDateKey ON dbo.Fact_Sales (OrderDateKey) INCLUDE (Sales, Profit, Quantity);');
GO

-- Confirm the optimizer (after)
SET STATISTICS IO ON;
SELECT l.Region, p.Category, SUM(f.Sales) AS TotalSales
FROM dbo.Fact_Sales f
JOIN dbo.Dim_Product  p ON f.ProductKey  = p.ProductKey
JOIN dbo.Dim_Location l ON f.LocationKey = l.LocationKey
GROUP BY l.Region, p.Category;
SET STATISTICS IO OFF;
GO