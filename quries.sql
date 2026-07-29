USE ledger_db;

-- -------------------------------------------------------------
-- 1. Hierarchical Account Balance Rollup (Recursive CTE)
-- Explodes the parent-child relationships in the chart of accounts
-- and aggregates balances from sub-accounts up to the parent accounts.
-- -------------------------------------------------------------
WITH RECURSIVE AccountHierarchy AS (
    -- Anchor Member: Select all base accounts and compute their direct balances
    SELECT 
        id, 
        code, 
        name, 
        parent_id,
        (SELECT COALESCE(SUM(debit - credit), 0.0000) FROM journal_entries WHERE account_id = accounts.id) AS raw_balance
    FROM accounts
    
    UNION ALL
    
    -- Recursive Member: Bubbles up raw balances from child to parent
    SELECT 
        a.id, 
        a.code, 
        a.name, 
        a.parent_id,
        h.raw_balance
    FROM accounts a
    INNER JOIN AccountHierarchy h ON h.parent_id = a.id
)
SELECT 
    code, 
    name, 
    SUM(raw_balance) AS rolled_up_balance
FROM AccountHierarchy
GROUP BY code, name
ORDER BY code;

-- -------------------------------------------------------------
-- 2. General Ledger Running Balance for Cash Account
-- Uses window functions to generate a running balance ledger over time.
-- -------------------------------------------------------------
SELECT 
    t.id AS tx_id,
    t.reference_number,
    t.posted_at,
    t.description,
    je.debit,
    je.credit,
    -- Compute running sum of debit - credit
    SUM(je.debit - je.credit) OVER (
        PARTITION BY je.account_id 
        ORDER BY t.posted_at, t.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM journal_entries je
JOIN transactions t ON je.transaction_id = t.id
WHERE je.account_id = 6  -- Cash & Cash Equivalents Account
ORDER BY t.posted_at, t.id;

-- -------------------------------------------------------------
-- 3. Monthly Recurring SaaS Revenue Growth Tracking
-- Calculates SaaS Revenue by month and uses LAG() to compute growth rates.
-- -------------------------------------------------------------
WITH MonthlySaaSRevenue AS (
    SELECT 
        DATE_FORMAT(t.posted_at, '%Y-%m') AS fiscal_month,
        SUM(je.credit - je.debit) AS revenue_amount
    FROM journal_entries je
    JOIN transactions t ON je.transaction_id = t.id
    JOIN accounts a ON je.account_id = a.id
    WHERE a.code = '4100' -- SaaS Subscriptions Revenue Account
    GROUP BY DATE_FORMAT(t.posted_at, '%Y-%m')
)
SELECT 
    fiscal_month,
    revenue_amount,
    LAG(revenue_amount, 1) OVER (ORDER BY fiscal_month) AS previous_month_revenue,
    (revenue_amount - LAG(revenue_amount, 1) OVER (ORDER BY fiscal_month)) AS net_growth,
    ROUND(
        ((revenue_amount - LAG(revenue_amount, 1) OVER (ORDER BY fiscal_month)) / 
        LAG(revenue_amount, 1) OVER (ORDER BY fiscal_month)) * 100, 
        2
    ) AS growth_percentage
FROM MonthlySaaSRevenue;

-- -------------------------------------------------------------
-- 4. Global Ledger Verification (Trial Balance Health Check)
-- Validates if the sum of all debits and credits in the ledger equals zero.
-- -------------------------------------------------------------
SELECT 
    SUM(debit) AS total_debits,
    SUM(credit) AS total_credits,
    (SUM(debit) - SUM(credit)) AS net_discrepancy,
    CASE 
        WHEN ABS(SUM(debit) - SUM(credit)) < 0.0001 THEN 'BALANCED'
        ELSE 'ERROR: UNBALANCED'
    END AS ledger_status
FROM journal_entries;
