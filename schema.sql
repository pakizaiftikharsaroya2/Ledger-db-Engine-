-- Database Schema: LedgerDB
-- Designed for MySQL 8.0+

CREATE DATABASE IF NOT EXISTS ledger_db;
USE ledger_db;

-- -------------------------------------------------------------
-- Clean up existing structures (for ease of schema redeployment)
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_je_update;
DROP TRIGGER IF EXISTS trg_prevent_je_delete;
DROP TRIGGER IF EXISTS trg_prevent_tx_update;
DROP TRIGGER IF EXISTS trg_prevent_tx_delete;
DROP TRIGGER IF EXISTS trg_validate_fiscal_period;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS journal_entries;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS fiscal_periods;

-- -------------------------------------------------------------
-- 1. Fiscal Periods Table
-- -------------------------------------------------------------
CREATE TABLE fiscal_periods (
    id INT AUTO_INCREMENT PRIMARY KEY,
    period_name VARCHAR(20) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    closed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_period_dates CHECK (start_date < end_date)
);

-- -------------------------------------------------------------
-- 2. Hierarchical Chart of Accounts Table
-- -------------------------------------------------------------
CREATE TABLE accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    type ENUM('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE') NOT NULL,
    parent_id INT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (parent_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    INDEX idx_accounts_parent (parent_id)
);

-- -------------------------------------------------------------
-- 3. Core Transactions Table
-- -------------------------------------------------------------
CREATE TABLE transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    reference_number VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL,
    posted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fiscal_period_id INT NOT NULL,
    FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id) ON DELETE RESTRICT,
    INDEX idx_transactions_posted_at (posted_at),
    INDEX idx_transactions_fiscal_period (fiscal_period_id)
);

-- -------------------------------------------------------------
-- 4. Journal Entries Table (Double-Entry Mechanics)
-- -------------------------------------------------------------
CREATE TABLE journal_entries (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    account_id INT NOT NULL,
    debit DECIMAL(15, 4) NOT NULL DEFAULT 0.0000,
    credit DECIMAL(15, 4) NOT NULL DEFAULT 0.0000,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CONSTRAINT chk_debit_positive CHECK (debit >= 0.0000),
    CONSTRAINT chk_credit_positive CHECK (credit >= 0.0000),
    CONSTRAINT chk_mutually_exclusive CHECK (
        (debit > 0.0000 AND credit = 0.0000) OR 
        (credit > 0.0000 AND debit = 0.0000)
    ),
    INDEX idx_journal_entries_tx (transaction_id),
    INDEX idx_journal_entries_acc (account_id)
);

-- -------------------------------------------------------------
-- 5. System Audit Logs Table
-- -------------------------------------------------------------
CREATE TABLE audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(10) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- Database Triggers for Consistency, Immutability & Auditing
-- -------------------------------------------------------------

DELIMITER $$

-- Enforce that a transaction's posted date belongs to an open fiscal period
CREATE TRIGGER trg_validate_fiscal_period
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE period_is_closed BOOLEAN;
    DECLARE date_in_range BOOLEAN;

    SELECT closed, (NEW.posted_at BETWEEN start_date AND end_date)
    INTO period_is_closed, date_in_range
    FROM fiscal_periods
    WHERE id = NEW.fiscal_period_id;

    IF period_is_closed = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction rejected: Fiscal period is closed.';
    END IF;

    IF date_in_range = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction rejected: Posted date lies outside the selected fiscal period.';
    END IF;
END$$

-- Financial entries are immutable: prevent updates on journal entries
CREATE TRIGGER trg_prevent_je_update
BEFORE UPDATE ON journal_entries
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial records are immutable. Journal entry updates are forbidden.';
END$$

-- Financial entries are immutable: prevent deletes on journal entries
CREATE TRIGGER trg_prevent_je_delete
BEFORE DELETE ON journal_entries
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial records are immutable. Journal entry deletions are forbidden.';
END$$

-- Financial transactions are immutable: prevent updates on transactions
CREATE TRIGGER trg_prevent_tx_update
BEFORE UPDATE ON transactions
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial records are immutable. Transaction updates are forbidden.';
END$$

-- Financial transactions are immutable: prevent deletes on transactions
CREATE TRIGGER trg_prevent_tx_delete
BEFORE DELETE ON transactions
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial records are immutable. Transaction deletions are forbidden.';
END$$

DELIMITER ;
