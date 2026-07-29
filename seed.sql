USE ledger_db;

-- -------------------------------------------------------------
-- Seed Fiscal Periods
-- -------------------------------------------------------------
INSERT INTO fiscal_periods (period_name, start_date, end_date, closed) VALUES
('FP-2026-Q1', '2026-01-01', '2026-03-31', FALSE),
('FP-2026-Q2', '2026-04-01', '2026-06-30', FALSE);

-- -------------------------------------------------------------
-- Seed Chart of Accounts (Hierarchical Structure)
-- -------------------------------------------------------------
-- Level 1: Core Account Types
INSERT INTO accounts (id, code, name, type, parent_id, active) VALUES
(1, '1000', 'Assets', 'ASSET', NULL, TRUE),
(2, '2000', 'Liabilities', 'LIABILITY', NULL, TRUE),
(3, '3000', 'Equity', 'EQUITY', NULL, TRUE),
(4, '4000', 'Revenue', 'REVENUE', NULL, TRUE),
(5, '5000', 'Expenses', 'EXPENSE', NULL, TRUE);

-- Level 2: Sub-Accounts
INSERT INTO accounts (id, code, name, type, parent_id, active) VALUES
-- Asset Sub-Accounts
(6, '1100', 'Cash & Cash Equivalents', 'ASSET', 1, TRUE),
(7, '1200', 'Accounts Receivable', 'ASSET', 1, TRUE),
(8, '1500', 'Property, Plant & Equipment', 'ASSET', 1, TRUE),
-- Liability Sub-Accounts
(9, '2100', 'Accounts Payable', 'LIABILITY', 2, TRUE),
(10, '2200', 'Accrued Liabilities', 'LIABILITY', 2, TRUE),
-- Equity Sub-Accounts
(11, '3100', 'Common Stock', 'EQUITY', 3, TRUE),
(12, '3200', 'Retained Earnings', 'EQUITY', 3, TRUE),
-- Revenue Sub-Accounts
(13, '4100', 'SaaS Subscriptions Revenue', 'REVENUE', 4, TRUE),
(14, '4200', 'Professional Services Revenue', 'REVENUE', 4, TRUE),
-- Expense Sub-Accounts
(15, '5100', 'Salaries & Wages Expense', 'EXPENSE', 5, TRUE),
(16, '5200', 'Rent & Facilities Expense', 'EXPENSE', 5, TRUE),
(17, '5300', 'Cloud Infrastructure Expense', 'EXPENSE', 5, TRUE);

-- -------------------------------------------------------------
-- Seed Transactions and Balanced Journal Entries
-- -------------------------------------------------------------

-- Transaction 1: Initial Equity Capital Inflow ($150,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (1, 'TX-1001', 'Initial common stock issuance to founders', '2026-01-02 09:00:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(1, 6, 150000.0000, 0.0000),      -- Cash (Debit)
(1, 11, 0.0000, 150000.0000);     -- Common Stock (Credit)

-- Transaction 2: Office Rent Prepayment for Q1 ($12,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (2, 'TX-1002', 'Q1 Office Lease Payment', '2026-01-03 10:30:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(2, 16, 12000.0000, 0.0000),      -- Rent Expense (Debit)
(2, 6, 0.0000, 12000.0000);       -- Cash (Credit)

-- Transaction 3: Purchase Servers on Credit ($8,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (3, 'TX-1003', 'Enterprise DB server hardware purchase', '2026-01-10 14:00:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(3, 8, 8000.0000, 0.0000),         -- PP&E (Debit)
(3, 9, 0.0000, 8000.0000);         -- Accounts Payable (Credit)

-- Transaction 4: Enterprise SaaS Contract Billed (INV-101) ($35,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (4, 'TX-1004', 'SaaS Contract Billing - Invoice INV-101', '2026-01-15 17:00:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(4, 7, 35000.0000, 0.0000),        -- Accounts Receivable (Debit)
(4, 13, 0.0000, 35000.0000);       -- SaaS Subscription Revenue (Credit)

-- Transaction 5: Partially Collect Invoice INV-101 ($20,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (5, 'TX-1005', 'Payment receipt - INV-101 part 1', '2026-01-25 11:15:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(5, 6, 20000.0000, 0.0000),        -- Cash (Debit)
(5, 7, 0.0000, 20000.0000);        -- Accounts Receivable (Credit)

-- Transaction 6: Q1 Salaries Payment ($15,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (6, 'TX-1006', 'Monthly employee payroll distribution', '2026-01-28 16:30:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(6, 15, 15000.0000, 0.0000),       -- Salaries Expense (Debit)
(6, 6, 0.0000, 15000.0000);        -- Cash (Credit)

-- Transaction 7: AWS Infrastructure Invoice ($3,200.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (7, 'TX-1007', 'AWS Cloud Infrastructure charges - Jan', '2026-01-31 23:59:59', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(7, 17, 3200.0000, 0.0000),        -- Cloud Expense (Debit)
(7, 9, 0.0000, 3200.0000);         -- Accounts Payable (Credit)

-- Transaction 8: Partial Payment of Accounts Payable ($5,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (8, 'TX-1008', 'Supplier wire transfer - payment on hardware account', '2026-02-05 10:00:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(8, 9, 5000.0000, 0.0000),         -- Accounts Payable (Debit)
(8, 6, 0.0000, 5000.0000);         -- Cash (Credit)

-- Transaction 9: Consulting Service Revenue ($9,500.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (9, 'TX-1009', 'Consulting engagement cash payment', '2026-02-15 13:00:00', 1);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(9, 6, 9500.0000, 0.0000),         -- Cash (Debit)
(9, 14, 0.0000, 9500.0000);        -- Professional Services Revenue (Credit)

-- Transaction 10: SaaS Q2 Contract Billed (INV-102) ($42,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (10, 'TX-1010', 'SaaS Contract Billing - Invoice INV-102', '2026-04-10 09:30:00', 2);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(10, 7, 42000.0000, 0.0000),       -- Accounts Receivable (Debit)
(10, 13, 0.0000, 42000.0000);      -- SaaS Subscription Revenue (Credit)

-- Transaction 11: Q2 Salaries Payment ($15,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (11, 'TX-1011', 'Monthly employee payroll distribution', '2026-04-28 16:30:00', 2);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(11, 15, 15000.0000, 0.0000),      -- Salaries Expense (Debit)
(11, 6, 0.0000, 15000.0000);       -- Cash (Credit)

-- Transaction 12: Pay remaining server cost to supplier ($3,000.00)
INSERT INTO transactions (id, reference_number, description, posted_at, fiscal_period_id)
VALUES (12, 'TX-1012', 'Supplier wire transfer - final hardware payment', '2026-05-02 11:00:00', 2);

INSERT INTO journal_entries (transaction_id, account_id, debit, credit) VALUES
(12, 9, 3000.0000, 0.0000),        -- Accounts Payable (Debit)
(12, 6, 0.0000, 3000.0000);        -- Cash (Credit)
