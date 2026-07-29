USE ledger_db;

DROP PROCEDURE IF EXISTS sp_create_transaction;
DROP PROCEDURE IF EXISTS sp_close_fiscal_period;

DELIMITER $$

-- -------------------------------------------------------------
-- Atomic Multi-Entry Transaction Creator
-- Accepts journal entries as a JSON array of objects.
-- E.g. '[{"account_id": 6, "debit": 500.0, "credit": 0.0}, ...]'
-- -------------------------------------------------------------
CREATE PROCEDURE sp_create_transaction(
    IN p_reference_number VARCHAR(100),
    IN p_description VARCHAR(255),
    IN p_posted_at TIMESTAMP,
    IN p_fiscal_period_id INT,
    IN p_entries_json JSON
)
this_sp: BEGIN
    DECLARE v_total_debit DECIMAL(15, 4) DEFAULT 0.0000;
    DECLARE v_total_credit DECIMAL(15, 4) DEFAULT 0.0000;
    DECLARE v_tx_id BIGINT;
    
    -- Error handling block for transaction failures
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validate JSON structure is a non-empty array
    IF JSON_TYPE(p_entries_json) <> 'ARRAY' OR JSON_LENGTH(p_entries_json) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid payload: Entries must be a non-empty JSON array.';
    END IF;

    -- Sum debits and credits from JSON
    SELECT 
        COALESCE(SUM(jt.debit), 0.0000), 
        COALESCE(SUM(jt.credit), 0.0000)
    INTO v_total_debit, v_total_credit
    FROM JSON_TABLE(
        p_entries_json,
        '$[*]' COLUMNS (
            debit DECIMAL(15, 4) PATH '$.debit',
            credit DECIMAL(15, 4) PATH '$.credit'
        )
    ) AS jt;

    -- Enforce fundamental accounting equation
    IF ABS(v_total_debit - v_total_credit) > 0.0001 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction out-of-balance: Total Debits must equal Total Credits.';
    END IF;

    -- Begin ACID transaction
    START TRANSACTION;

    -- Insert parent transaction row (triggers will validate date/period)
    INSERT INTO transactions (reference_number, description, posted_at, fiscal_period_id)
    VALUES (p_reference_number, p_description, p_posted_at, p_fiscal_period_id);
    
    SET v_tx_id = LAST_INSERT_ID();

    -- Insert individual journal entries using JSON_TABLE parser
    INSERT INTO journal_entries (transaction_id, account_id, debit, credit)
    SELECT 
        v_tx_id,
        jt.account_id,
        jt.debit,
        jt.credit
    FROM JSON_TABLE(
        p_entries_json,
        '$[*]' COLUMNS (
            account_id INT PATH '$.account_id',
            debit DECIMAL(15, 4) PATH '$.debit',
            credit DECIMAL(15, 4) PATH '$.credit'
        )
    ) AS jt;

    COMMIT;
END$$

-- -------------------------------------------------------------
-- Fiscal Period Closing Controller
-- Closes a period and ensures trial balance integrity.
-- -------------------------------------------------------------
CREATE PROCEDURE sp_close_fiscal_period(
    IN p_fiscal_period_id INT
)
BEGIN
    DECLARE v_period_exists INT DEFAULT 0;
    DECLARE v_net_difference DECIMAL(15, 4) DEFAULT 0.0000;
    
    -- Verify period exists
    SELECT COUNT(*) INTO v_period_exists 
    FROM fiscal_periods 
    WHERE id = p_fiscal_period_id;
    
    IF v_period_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fiscal period not found.';
    END IF;

    -- Verify trial balance of that period equals zero
    SELECT COALESCE(SUM(je.debit - je.credit), 0.0000) INTO v_net_difference
    FROM journal_entries je
    JOIN transactions t ON je.transaction_id = t.id
    WHERE t.fiscal_period_id = p_fiscal_period_id;

    IF ABS(v_net_difference) > 0.0001 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot close period: Cumulative trial balance is unbalanced.';
    END IF;

    -- Close period
    UPDATE fiscal_periods 
    SET closed = TRUE 
    WHERE id = p_fiscal_period_id;
END$$

DELIMITER ;
