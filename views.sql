USE ledger_db;

DROP VIEW IF EXISTS v_income_statement;
DROP VIEW IF EXISTS v_balance_sheet;
DROP VIEW IF EXISTS v_trial_balance;

-- -------------------------------------------------------------
-- 1. Trial Balance View
-- Displays aggregated debit/credit activity and net raw balances.
-- -------------------------------------------------------------
CREATE VIEW v_trial_balance AS
SELECT 
    a.code AS account_code,
    a.name AS account_name,
    a.type AS account_type,
    COALESCE(SUM(je.debit), 0.0000) AS total_debits,
    COALESCE(SUM(je.credit), 0.0000) AS total_credits,
    COALESCE(SUM(je.debit - je.credit), 0.0000) AS net_raw_balance
FROM accounts a
LEFT JOIN journal_entries je ON a.id = je.account_id
GROUP BY a.id, a.code, a.name, a.type;

-- -------------------------------------------------------------
-- 2. Balance Sheet View (Assets, Liabilities, Equity)
-- Correctly applies natural balance rules (Assets = Debit-Credit; Liabilities/Equity = Credit-Debit).
-- -------------------------------------------------------------
CREATE VIEW v_balance_sheet AS
SELECT 
    account_code,
    account_name,
    account_type,
    total_debits,
    total_credits,
    CASE 
        WHEN account_type = 'ASSET' THEN (total_debits - total_credits)
        WHEN account_type IN ('LIABILITY', 'EQUITY') THEN (total_credits - total_debits)
        ELSE 0.0000
    END AS reported_balance
FROM v_trial_balance
WHERE account_type IN ('ASSET', 'LIABILITY', 'EQUITY');

-- -------------------------------------------------------------
-- 3. Income Statement View (Revenues, Expenses)
-- Calculates net margins per income/expense category.
-- -------------------------------------------------------------
CREATE VIEW v_income_statement AS
SELECT 
    account_code,
    account_name,
    account_type,
    total_debits,
    total_credits,
    CASE 
        WHEN account_type = 'REVENUE' THEN (total_credits - total_debits)
        WHEN account_type = 'EXPENSE' THEN (total_debits - total_credits)
        ELSE 0.0000
    END AS reported_balance
FROM v_trial_balance
WHERE account_type IN ('REVENUE', 'EXPENSE');
