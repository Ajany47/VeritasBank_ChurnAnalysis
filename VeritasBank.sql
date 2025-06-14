create database Veritas_Bank;

DROP TABLE IF EXISTS CustomerInfo;
DROP TABLE IF EXISTS AccountInfo;

DROP TABLE IF EXISTS CustomerInfo;
DROP TABLE IF EXISTS AccountInfo;

use Veritas_Bank;

-- Staging Table: Customer Info
CREATE TABLE Stg_CustomerInfo (
    CustomerId INT,
    LastName NVARCHAR(50),
    Country NVARCHAR(50),
    Gender NVARCHAR(10),
    Age INT
);


-- Staging Table: Account Info
CREATE TABLE Stg_AccountInfo (
    CustomerId INT,
    CreditScore INT,
    Tenure INT,
    Balance DECIMAL(18,2),
    Products INT,
    CreditCard BIT,
    ActiveMember BIT,
    Exited BIT
);

SELECT TOP 5 * FROM Stg_CustomerInfo;

select * from Stg_CustomerInfo;

DROP TABLE IF EXISTS Stg_CustomerInfo;

CREATE TABLE Stg_CustomerInfo (
    CustomerId INT,
    LastName NVARCHAR(50),
    Country NVARCHAR(50),
    Gender NVARCHAR(10),
    Age INT
);

DROP TABLE IF EXISTS Stg_CustomerInfo;

SELECT * FROM Stg_CustomerInfo;

DROP TABLE IF EXISTS Stg_AccountInfo;

CREATE TABLE Stg_AccountInfo (
    CustomerId INT,
    CreditScore INT,
    Tenure INT,
    Balance DECIMAL(18,2),
    Products INT,
    CreditCard BIT,
    ActiveMember BIT,
    Exited BIT
);

SELECT COUNT(*) FROM Stg_AccountInfo;

select * from Stg_AccountInfo;
use Veritas_Bank;

SELECT * FROM Stg_CustomerInfo;

-- Cleaned Customer Dimension

CREATE TABLE Dim_Customer (
    CustomerId INT PRIMARY KEY,
    LastName NVARCHAR(50),
    Country NVARCHAR(50),
    Gender NVARCHAR(10),
    Age INT
);

-- Cleaned Account Fact Table

CREATE TABLE Fact_Account (
    CustomerId INT PRIMARY KEY,
    CreditScore INT,
    Tenure INT,
    Balance DECIMAL(18, 2),
    Products INT,
    CreditCard BIT,
    ActiveMember BIT,
    Exited BIT
);


----Data Cleaning

INSERT INTO Dim_Customer (CustomerId, LastName, Country, Gender, Age)
SELECT 
    CustomerId,
    LTRIM(RTRIM(LastName)) AS LastName,
    LTRIM(RTRIM(Country)) AS Country,
    LTRIM(RTRIM(Gender)) AS Gender,
    Age
FROM Stg_CustomerInfo
WHERE CustomerId IS NOT NULL;

SELECT COUNT(*) AS TotalCustomers FROM Dim_Customer;

SELECT * FROM Dim_Customer;


INSERT INTO Fact_Account (CustomerId, CreditScore, Tenure, Balance, Products, CreditCard, ActiveMember, Exited)
SELECT 
    CustomerId,
    CreditScore,
    Tenure,
    Balance,
    Products,
    CreditCard,
    ActiveMember,
    Exited
FROM Stg_AccountInfo
WHERE CustomerId IS NOT NULL;

SELECT COUNT(*) AS TotalAccounts FROM Fact_Account;




-- Check for duplicates in both Dim_Customer and Fact_Account

SELECT CustomerId, COUNT(*) AS Cnt
FROM Dim_Customer
GROUP BY CustomerId
HAVING COUNT(*) > 1;

SELECT CustomerId, COUNT(*) AS Cnt
FROM Fact_Account
GROUP BY CustomerId
HAVING COUNT(*) > 1;

----To check for Null or Missing Values

-- Dim_Customer null check
SELECT 
  SUM(CASE WHEN LastName IS NULL THEN 1 ELSE 0 END) AS Null_LastName,
  SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Null_Country,
  SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS Null_Gender,
  SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Null_Age
FROM Dim_Customer;

-- Fact_Account null check
SELECT 
  SUM(CASE WHEN CreditScore IS NULL THEN 1 ELSE 0 END) AS Null_CreditScore,
  SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS Null_Tenure,
  SUM(CASE WHEN Balance IS NULL THEN 1 ELSE 0 END) AS Null_Balance,
  SUM(CASE WHEN Products IS NULL THEN 1 ELSE 0 END) AS Null_Products,
  SUM(CASE WHEN Exited IS NULL THEN 1 ELSE 0 END) AS Null_Exited
FROM Fact_Account;

---- To check for outliers or invalid values

--- Checking the age range to see if it is realistic
SELECT * FROM Dim_Customer WHERE Age < 16 OR Age > 100;

SELECT MIN(Age) AS MinAge, MAX(Age) AS MaxAge FROM Dim_Customer;


--- Credit Score
SELECT MIN(CreditScore), MAX(CreditScore) FROM Fact_Account;

--- To check if there is a negative balance in the account
SELECT * FROM Fact_Account WHERE Balance < 0;

SELECT COUNT(*) AS TotalRows FROM Fact_Account;


--- Profile Key Distributions

-- Country Distribution
SELECT Country, COUNT(*) as TotalCount FROM Dim_Customer GROUP BY Country;

-- Gender Distribution
SELECT Gender, COUNT(*) AS TotalCount FROM Dim_Customer GROUP BY Gender;

-- Churn Distribution
SELECT DISTINCT Exited, COUNT(*) FROM Fact_Account GROUP BY Exited;
SELECT DISTINCT Exited FROM Fact_Account;



---SQL IMPEMENTATION

-- Find PK name
SELECT name
FROM sys.key_constraints
WHERE type = 'PK' AND parent_object_id = OBJECT_ID('Fact_Account');

ALTER TABLE Fact_Account
DROP CONSTRAINT PK__Fact_Account;

ALTER TABLE Fact_Account
DROP CONSTRAINT PK__Fact_Acc__A4AE64D85157BB1B;


-----Add surrogate key

ALTER TABLE Fact_Account
ADD FactAccountId INT IDENTITY(1,1);


---- Set it as the new primary key

ALTER TABLE Fact_Account
ADD CONSTRAINT PK_FactAccount PRIMARY KEY (FactAccountId);


-- Step 3: Add foreign key

ALTER TABLE Fact_Account
ADD CONSTRAINT FK_FactAccount_DimCustomer
FOREIGN KEY (CustomerId)
REFERENCES Dim_Customer(CustomerId);

SELECT name
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('Fact_Account');


ALTER TABLE Fact_Account
DROP CONSTRAINT FK_FactAccount_DimCustomer;

ALTER TABLE Fact_Account
ADD CONSTRAINT FK_FactAccount_DimCustomer
FOREIGN KEY (CustomerId)
REFERENCES Dim_Customer(CustomerId);

SELECT * FROM Fact_Account;

-----Exploratory Data Analysis

---To create view for the Veritas Bank Churn Analysis based on Demographics, Credit Score Segmantation
--- and Customer Risk Segments.

---ChurnByDemograhicsView

CREATE VIEW  vw_ChurnByDemographics AS
SELECT
    c.CustomerId,
    c.LastName,
    c.Country,
    c.Gender,
    c.Age,
    CASE 
        WHEN c.Age < 25 THEN '18–24'
        WHEN c.Age BETWEEN 25 AND 34 THEN '25–34'
        WHEN c.Age BETWEEN 35 AND 44 THEN '35–44'
        WHEN c.Age BETWEEN 45 AND 54 THEN '45–54'
        WHEN c.Age BETWEEN 55 AND 64 THEN '55–64'
        ELSE '65+'
    END AS AgeGroup,
    a.Exited,
    CASE 
        WHEN a.Exited = 1 THEN 'Churned'
        ELSE 'Active'
    END AS CustomerStatus
FROM 
    Dim_Customer c
JOIN 
    Fact_Account a ON c.CustomerId = a.CustomerId;



SELECT * FROM vw_ChurnByDemographics;


----- ChurnByCreditScore

CREATE VIEW vw_ChurnByCreditScore AS
SELECT
    a.CustomerId,
    a.CreditScore,
    CASE 
        WHEN a.CreditScore < 580 THEN 'Poor'
        WHEN a.CreditScore BETWEEN 580 AND 669 THEN 'Fair'
        WHEN a.CreditScore BETWEEN 670 AND 739 THEN 'Good'
        WHEN a.CreditScore BETWEEN 740 AND 799 THEN 'Very Good'
        ELSE 'Excellent'
    END AS CreditScoreRange,
    a.Exited,
    CASE 
        WHEN a.Exited = 1 THEN 'Churned'
        ELSE 'Active'
    END AS CustomerStatus
FROM 
    Fact_Account a;

SELECT * FROM vw_ChurnByCreditScore;


----- CustomerRiskSegments

CREATE VIEW vw_CustomerRiskSegments AS
SELECT
    a.CustomerId,
    a.Balance,
    a.Products,
    a.CreditCard,
    a.ActiveMember,
    a.Exited,
    CASE 
        WHEN a.Exited = 1 THEN 'Churned'
        WHEN a.Balance < 5000 AND a.ActiveMember = 0 THEN 'High Risk'
        WHEN a.Balance BETWEEN 5000 AND 30000 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS RiskSegment
FROM 
    Fact_Account a;


SELECT * FROM vw_CustomerRiskSegments;

---- Project Objectives

---1. To identify common characteristics among Churned Customers

--Churned Rate by Age Group

SELECT 
    AgeGroup,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate_Percent
FROM vw_ChurnByDemographics
GROUP BY AgeGroup
ORDER BY AgeGroup;


----Churned Rate by Gender

SELECT 
    Gender,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate_Percent
FROM vw_ChurnByDemographics
GROUP BY Gender;

--- Churned Rate by Product Count

SELECT 
    Products,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(
        100.0 * SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2
    ) AS ChurnRate_Percent
FROM vw_CustomerRiskSegments
GROUP BY Products
ORDER BY Products;

---- Churned Rate by Active Member Status

SELECT 
    CASE 
        WHEN ActiveMember = 1 THEN 'Active Member'
        WHEN ActiveMember = 0 THEN 'Inactive Member'
    END AS MemberStatus,
    
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate_Percent

FROM vw_CustomerRiskSegments
GROUP BY ActiveMember;



----2.To  Compare Account Behavior Across UK, Germany, France

--- Country-wise Account Behaviour Analysis

SELECT 
    d.Country,
    COUNT(*) AS TotalCustomers,
    ROUND(AVG(r.Balance), 2) AS AvgBalance,
    ROUND(AVG(f.Tenure), 1) AS AvgTenure,
    ROUND(AVG(CAST(r.CreditCard AS FLOAT)), 2) AS CreditCardRate,
    ROUND(AVG(CAST(r.ActiveMember AS FLOAT)), 2) AS ActiveRate,
    ROUND(AVG(CAST(r.Exited AS FLOAT)) * 100, 2) AS ChurnRate_Percent
FROM vw_CustomerRiskSegments r
JOIN vw_ChurnByDemographics d ON r.CustomerId = d.CustomerId
JOIN Fact_Account f ON r.CustomerId = f.CustomerId
GROUP BY d.Country;


----3. To Segment Customers by Risk Profile

----ChurnRate by Risk Segment

SELECT 
    RiskSegment,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate_Percent
FROM vw_CustomerRiskSegments
GROUP BY RiskSegment;

---- Combine Risk with the Country

SELECT 
    d.Country,
    r.RiskSegment,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN r.Exited = 1 THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN r.Exited = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ChurnRate_Percent
FROM vw_CustomerRiskSegments r
JOIN vw_ChurnByDemographics d ON r.CustomerId = d.CustomerId
GROUP BY d.Country, r.RiskSegment
ORDER BY d.Country, r.RiskSegment;


use Veritas_Bank;



---To create more views for the Veritas Bank Churn Analysis based on Country, Activity Status, credit card impact,
--- High value Customers and Segmentation

---- ChurnByCountry

CREATE VIEW vw_ChurnByCountry AS
SELECT 
    c.Country,
    COUNT(a.CustomerId) AS TotalCustomers,
    SUM(CAST(a.Exited AS INT)) AS ChurnedCustomers,
    ROUND(100.0 * SUM(CAST(a.Exited AS FLOAT)) / COUNT(*), 2) AS ChurnRatePercent
FROM Dim_Customer c
JOIN Fact_Account a ON c.CustomerId = a.CustomerId
GROUP BY c.Country;

select * from vw_ChurnByCountry;


---- ChurnBYActivityStatus

CREATE VIEW vw_ChurnByActivityStatus AS
SELECT 
    a.ActiveMember,
    COUNT(*) AS TotalCustomers,
    SUM(CAST(Exited AS INT)) AS ChurnedCustomers,
    ROUND(100.0 * SUM(CAST(Exited AS FLOAT)) / COUNT(*), 2) AS ChurnRatePercent
FROM Fact_Account a
GROUP BY a.ActiveMember;

Select * from vw_ChurnByActivityStatus;

--- ChurnByCreditCardImpact

CREATE VIEW vw_CreditCardImpact AS
SELECT 
    a.CreditCard,
    COUNT(*) AS TotalCustomers,
    SUM(CAST(Exited AS INT)) AS ChurnedCustomers,
    ROUND(100.0 * SUM(CAST(Exited AS FLOAT)) / COUNT(*), 2) AS ChurnRatePercent
FROM Fact_Account a
GROUP BY a.CreditCard;

select * from vw_CreditCardImpact;

----HighValueCustomers

CREATE VIEW vw_HighValueCustomers AS
SELECT 
    a.CustomerId,
    c.Country,
    a.Balance,
    a.Products,
    a.Tenure,
    a.ActiveMember,
    a.Exited,
    CASE 
        WHEN a.Balance > 30000 AND a.Products >= 2 AND a.Tenure >= 5 THEN 'High Value'
        ELSE 'Standard'
    END AS ValueSegment
FROM Fact_Account a
JOIN Dim_Customer c ON c.CustomerId = a.CustomerId;

select * from vw_HighValueCustomers;

------ChurnBySegmantation

CREATE VIEW vw_EnhancedChurnSegmentation AS
SELECT 
    c.Country,
    c.Gender,
    a.CreditScore,
    c.Age,
    a.Balance,
    a.Products,
    a.Tenure,
    a.CreditCard,
    a.ActiveMember,
    a.Exited,
    CASE 
        WHEN a.Balance < 5000 AND a.ActiveMember = 0 AND a.Products = 1 THEN 'High Risk'
        WHEN a.Balance BETWEEN 5000 AND 30000 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS RiskSegment
FROM Dim_Customer c
JOIN Fact_Account a ON c.CustomerId = a.CustomerId;


select * from vw_EnhancedChurnSegmentation;

--- Top 10 Customers by Account Balance
SELECT TOP 10 
    a.CustomerId,
    c.Country,
    c.Gender,
    c.Age,
    a.Balance,
    a.Products,
    a.Tenure,
    a.ActiveMember
FROM Fact_Account a
JOIN Dim_Customer c ON a.CustomerId = c.CustomerId
ORDER BY a.Balance DESC;

---- Top Customers by Product Count and Balance
SELECT TOP 10
    a.CustomerId,
    c.Country,
    a.Products,
    a.Balance,
    a.Tenure
FROM Fact_Account a
JOIN Dim_Customer c ON a.CustomerId = c.CustomerId
ORDER BY a.Products DESC, a.Balance DESC;


DROP VIEW IF EXISTS vw_EnhancedChurnSegmentation;

CREATE VIEW vw_EnhancedChurnSegmentation AS
SELECT 
    c.Country,
    c.Gender,
    a.CreditScore,
    c.Age,
    a.Balance,
    a.Products,
    a.Tenure,
    a.CreditCard,
    a.ActiveMember,
    a.Exited,
    CASE 
        WHEN a.Balance < 2000 AND a.ActiveMember = 0 AND a.Products = 1 THEN 'Very High Risk'
        WHEN a.Balance < 5000 AND a.ActiveMember = 0 THEN 'High Risk'
        WHEN a.Balance BETWEEN 5000 AND 30000 THEN 'Moderate Risk'
        WHEN a.Balance > 30000 AND a.Products = 1 THEN 'Low Risk'
        ELSE 'Very Low Risk'
    END AS RiskSegment
FROM Dim_Customer c
JOIN Fact_Account a ON c.CustomerId = a.CustomerId;
 

 use Veritas_Bank;

 CREATE VIEW vw_ChurnByCountryAgeGroup AS
SELECT 
    c.Country,
    -- AgeGroup buckets
    CASE 
        WHEN c.Age < 25 THEN 'Under 25'
        WHEN c.Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.Age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS AgeGroup,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN a.Exited = 1 THEN 1 ELSE 0 END) AS ChurnedCustomers,
    CAST(SUM(CASE WHEN a.Exited = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS ChurnRatePercent
FROM Dim_Customer c
JOIN Fact_Account a ON c.CustomerId = a.CustomerId
GROUP BY 
    c.Country,
    CASE 
        WHEN c.Age < 25 THEN 'Under 25'
        WHEN c.Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.Age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END;
use Veritas_Bank;