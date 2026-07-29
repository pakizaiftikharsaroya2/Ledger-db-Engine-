USE ledger_db;
-- Performance Indexes & Query Optimization Strategy

-- Drop indexes if they exist to avoid collision during schema recreation
DROP INDEX IF EXISTS idx_je_covering_account_balance ON journal_entries;
DROP INDEX IF EXISTS idx_tx_period_posted ON transactions;
DROP INDEX IF EXISTS idx_je_tx_lookup ON journal_entries;

-- 1. Covering Index for General Ledger Balance Calculations
-- Target Query: Summing debits/credits for trial balances.
-- Explanation: By including debit and credit in the index, MySQL can resolve 
-- account totals directly from the index leaf nodes (Covering Index), 
-- avoiding expensive disk reads of the data pages.
CREATE INDEX idx_je_covering_account_balance 
ON journal_entries (account_id, debit, credit);
-- 2. Compound Index for Chronological Period Reports
-- Target Query: Filtering transactions by fiscal period and sorting by date.
-- Explanation: The compound key (fiscal_period_id, posted_at) allows MySQL 
-- to perform index range scans on the period ID and immediately retrieve 
-- records in sorted chronological order without triggering a filesort.
CREATE INDEX idx_tx_period_posted 
ON transactions (fiscal_period_id, posted_at);
-- 3. Composite Join Index for Transaction Reconstructs
-- Target Query: Reconstructing journal entries for detailed transaction lists.
-- Explanation: Speed up lookups joining journal entries to transaction records.

CREATE INDEX idx_je_tx_lookup 
ON journal_entries (transaction_id, account_id);
