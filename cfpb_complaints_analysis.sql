/* =====================================================================
   CFPB credit card complaints: complaint drivers and relief rate
   Database: CFPB_Complaints (SQL Server)
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0. SETUP
-- ---------------------------------------------------------------------
CREATE DATABASE CFPB_Complaints;
GO
USE CFPB_Complaints;
GO

-- The table complaints_raw was created with SSMS: Tasks > Import Flat File.
-- Settings used: Allow Nulls ticked on every column; Date_received and
-- Date_sent_to_company left as text (nvarchar); Sub_product, Issue,
-- Sub_issue, Company_public_response and Company widened to nvarchar(255);
-- Complaint_ID as int, no primary key. complaints_raw is never modified.

-- ---------------------------------------------------------------------
-- 1. DATA CHECKS
-- ---------------------------------------------------------------------

-- 1a. Row count. Should match the "Showing ___ matches" number on the CFPB page.
SELECT COUNT(*) AS total_rows
FROM complaints_raw;                                   -- 97,861

-- 1b. Look at the data.
SELECT TOP 10 * FROM complaints_raw;

-- 1c. Is every Complaint_ID unique? Zero rows back means yes.
SELECT Complaint_ID, COUNT(*) AS times_seen
FROM complaints_raw
GROUP BY Complaint_ID
HAVING COUNT(*) > 1;

-- 1d. Date range. ISO-format text sorts correctly without conversion.
SELECT MIN(Date_received) AS earliest,
       MAX(Date_received) AS latest
FROM complaints_raw;                                   -- 2023-08-17 to 2024-12-31

-- 1e. Is "None" a real NULL or the text 'None'?
SELECT
    SUM(CASE WHEN Tags IS NULL   THEN 1 ELSE 0 END) AS tags_null,        -- 0
    SUM(CASE WHEN Tags = 'None'  THEN 1 ELSE 0 END) AS tags_none_text    -- 83,728
FROM complaints_raw;

-- ---------------------------------------------------------------------
-- 2. FIRST IDEA, TESTED AND REJECTED: IS RESPONSE SPEED THE PROBLEM?
-- ---------------------------------------------------------------------
SELECT Timely_response, COUNT(*) AS complaints
FROM complaints_raw
GROUP BY Timely_response
ORDER BY complaints DESC;                              -- Yes 97,694 / No 167 (99.83% timely)

-- ---------------------------------------------------------------------
-- 3. EXPLORING WHO AND WHAT
-- ---------------------------------------------------------------------

-- 3a. How many companies?
SELECT COUNT(DISTINCT Company) AS distinct_companies
FROM complaints_raw;                                   -- 516

-- 3b. Top 30 companies by complaint count (used to decide who counts as a bureau).
SELECT TOP 30 Company, COUNT(*) AS complaints
FROM complaints_raw
GROUP BY Company
ORDER BY complaints DESC;

-- 3c. How complaints ended.
SELECT Company_response_to_consumer, COUNT(*) AS complaints
FROM complaints_raw
GROUP BY Company_response_to_consumer
ORDER BY complaints DESC;

-- 3d. Most common issues, with each one's share of all complaints.
SELECT TOP 10
    Issue,
    COUNT(*) AS complaints,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints_raw) AS DECIMAL(5,1)) AS pct_of_all
FROM complaints_raw
GROUP BY Issue
ORDER BY complaints DESC;

-- 3e. Relief rate by issue, all companies combined (baseline: 38.8% overall).
-- Relief = closed with monetary relief OR non-monetary relief.
-- The 29 'Untimely response' rows are excluded because they have no outcome.
SELECT TOP 10
    Issue,
    COUNT(*) AS complaints,
    SUM(CASE WHEN Company_response_to_consumer IN
        ('Closed with monetary relief','Closed with non-monetary relief')
        THEN 1 ELSE 0 END) AS relief_cases,
    CAST(100.0 * SUM(CASE WHEN Company_response_to_consumer IN
        ('Closed with monetary relief','Closed with non-monetary relief')
        THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS relief_rate_pct
FROM complaints_raw
WHERE Company_response_to_consumer <> 'Untimely response'
GROUP BY Issue
ORDER BY complaints DESC;

-- ---------------------------------------------------------------------
-- 4. SPLIT CREDIT BUREAUS FROM CARD ISSUERS (a view; raw table untouched)
-- ---------------------------------------------------------------------
GO
CREATE VIEW dbo.complaints_labeled AS
SELECT *,
    CASE WHEN Company IN (
        'EQUIFAX, INC.',
        'Experian Information Solutions Inc.',
        'TRANSUNION INTERMEDIATE HOLDINGS, INC.')
    THEN 'Bureau' ELSE 'Card issuer' END AS company_type
FROM dbo.complaints_raw;
GO

-- Check: Bureau 27,110 + Card issuer 70,751 = 97,861.
SELECT company_type, COUNT(*) AS complaints
FROM dbo.complaints_labeled
GROUP BY company_type;

-- ---------------------------------------------------------------------
-- 5. RELIEF RATE, BY GROUP AND ISSUE
-- ---------------------------------------------------------------------

-- 5a. By issue within each group.
SELECT
    company_type,
    Issue,
    COUNT(*) AS complaints,
    SUM(CASE WHEN Company_response_to_consumer IN
        ('Closed with monetary relief','Closed with non-monetary relief')
        THEN 1 ELSE 0 END) AS relief_cases,
    CAST(100.0 * SUM(CASE WHEN Company_response_to_consumer IN
        ('Closed with monetary relief','Closed with non-monetary relief')
        THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS relief_rate_pct
FROM dbo.complaints_labeled
WHERE Company_response_to_consumer <> 'Untimely response'
GROUP BY company_type, Issue
ORDER BY company_type, complaints DESC;

-- 5b. Overall relief rate per group (Bureau 55.9%, Card issuer 32.3%).
SELECT
    company_type,
    COUNT(*) AS complaints,
    CAST(100.0 * SUM(CASE WHEN Company_response_to_consumer IN
        ('Closed with monetary relief','Closed with non-monetary relief')
        THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS relief_rate_pct
FROM dbo.complaints_labeled
WHERE Company_response_to_consumer <> 'Untimely response'
GROUP BY company_type;

-- ---------------------------------------------------------------------
-- 6. PRIORITY ISSUES FOR CARD ISSUERS (checked: returns the same four
--    issues as the "Card issuer focus" sheet in the Excel workbook)
--    High volume  = issue is at least 5% of card issuer complaints
--    Below average = issue's relief rate is under the card issuer average
-- ---------------------------------------------------------------------
WITH issuer AS (
    SELECT
        Issue,
        COUNT(*) AS complaints,
        SUM(CASE WHEN Company_response_to_consumer IN
            ('Closed with monetary relief','Closed with non-monetary relief')
            THEN 1 ELSE 0 END) AS relief_cases
    FROM dbo.complaints_labeled
    WHERE company_type = 'Card issuer'
      AND Company_response_to_consumer <> 'Untimely response'
    GROUP BY Issue
),
totals AS (
    SELECT
        SUM(complaints)   AS total_complaints,
        SUM(relief_cases) AS total_relief
    FROM issuer
)
SELECT
    i.Issue,
    i.complaints,
    CAST(100.0 * i.complaints   / t.total_complaints AS DECIMAL(5,1)) AS share_pct,
    CAST(100.0 * i.relief_cases / i.complaints       AS DECIMAL(5,1)) AS relief_rate_pct
FROM issuer i
CROSS JOIN totals t
WHERE 1.0 * i.complaints   / t.total_complaints >= 0.05
  AND 1.0 * i.relief_cases / i.complaints < 1.0 * t.total_relief / t.total_complaints
ORDER BY i.complaints DESC;
