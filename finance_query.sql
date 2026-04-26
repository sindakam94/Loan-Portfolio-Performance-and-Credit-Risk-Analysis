	-- =========================================
-- 1. TABLE CREATION
-- =========================================
CREATE TABLE finance(
    id INTEGER,
    address VARCHAR,
    application VARCHAR,
    emp_length VARCHAR,
    emp_title VARCHAR,
    grade VARCHAR,
    home_ownership VARCHAR,
    issue_date TEXT,
    last_credit_pull_date TEXT,
    last_payment_date TEXT,
    loan_status VARCHAR,
    next_payment_date TEXT,
    member_id INTEGER,
    purpose VARCHAR,
    sub_grade VARCHAR,
    term VARCHAR,
    verification_status VARCHAR,
    annual_income FLOAT,
    dti FLOAT,
    installment FLOAT,
    int_rate FLOAT,
    loan_amount FLOAT,
    total_acc FLOAT,
    total_payment FLOAT
);

SELECT * FROM finance;

-- =========================================
-- 2. DATE CLEANING
-- =========================================
UPDATE finance SET issue_date = TO_DATE(issue_date,'DD-MM-YYYY');
UPDATE finance SET last_credit_pull_date = TO_DATE(last_credit_pull_date,'DD-MM-YYYY');
UPDATE finance SET last_payment_date = TO_DATE(last_payment_date,'DD-MM-YYYY');
UPDATE finance SET next_payment_date = TO_DATE(next_payment_date,'DD-MM-YYYY');

ALTER TABLE finance ALTER COLUMN issue_date TYPE DATE USING issue_date::DATE;
ALTER TABLE finance ALTER COLUMN last_credit_pull_date TYPE DATE USING last_credit_pull_date::DATE;
ALTER TABLE finance ALTER COLUMN last_payment_date TYPE DATE USING last_payment_date::DATE;
ALTER TABLE finance ALTER COLUMN next_payment_date TYPE DATE USING next_payment_date::DATE;

-- =========================================
-- 3. CORE KPI METRICS
-- =========================================
SELECT COUNT(id) AS total_applications FROM finance;

SELECT COUNT(id)
FROM finance
WHERE EXTRACT(MONTH FROM issue_date)=12 AND EXTRACT(YEAR FROM issue_date)=2021;

SELECT COUNT(id)
FROM finance
WHERE EXTRACT(MONTH FROM issue_date)=11 AND EXTRACT(YEAR FROM issue_date)=2021;

SELECT SUM(loan_amount) AS total_funded_amount FROM finance;

SELECT SUM(total_payment) AS total_payment FROM finance;

-- =========================================
-- 4. AVERAGE METRICS
-- =========================================
SELECT ROUND(AVG(int_rate)::numeric*100,2) AS average_interest_rate FROM finance;

SELECT ROUND(AVG(dti)::numeric*100,2) AS average_dti FROM finance;

-- =========================================
-- 5. GOOD LOAN METRICS
-- =========================================
SELECT COUNT(CASE WHEN loan_status IN ('Current','Fully Paid') THEN id END)*100.0/COUNT(id)
AS good_loan_percentage FROM finance;

SELECT COUNT(CASE WHEN loan_status IN ('Fully Paid','Current') THEN id END)
AS good_loan_applications FROM finance;

SELECT SUM(loan_amount) FROM finance
WHERE loan_status IN ('Fully Paid','Current');

SELECT SUM(total_payment) FROM finance
WHERE loan_status IN ('Fully Paid','Current');

-- =========================================
-- 6. BAD LOAN METRICS
-- =========================================
SELECT COUNT(CASE WHEN loan_status='Charged Off' THEN id END)
FROM finance;

SELECT ROUND(COUNT(CASE WHEN loan_status='Charged Off' THEN id END)*100.0/COUNT(id),2)
FROM finance;

SELECT SUM(CASE WHEN loan_status='Charged Off' THEN loan_amount END)
FROM finance;

SELECT SUM(CASE WHEN loan_status='Charged Off' THEN total_payment END)
FROM finance;

-- =========================================
-- 7. MONTHLY LOAN TREND
-- ======================================
WITH monthly_trend_analysis AS (
    SELECT
        TRIM(TO_CHAR(issue_date::date, 'month')) AS month_name,
        EXTRACT(MONTH FROM issue_date) AS month_no,

        COUNT(*) AS total_loans,

        COUNT(
            CASE 
                WHEN loan_status IN ('Fully Paid','Current') THEN id 
            END
        ) AS good_loans,

        COUNT(
            CASE 
                WHEN loan_status = 'Charged Off' THEN id 
            END
        ) AS bad_loans

    FROM finance
    GROUP BY 1,2
)

SELECT
    month_no,
    month_name,
    total_loans,

    -- ======================
    -- GOOD LOANS
    -- ======================
    good_loans,
    LAG(good_loans) OVER (ORDER BY month_no) AS prev_good_loans,
    good_loans - LAG(good_loans) OVER (ORDER BY month_no) AS good_loan_diff,

    ROUND(
        (
            100.0 * (good_loans - LAG(good_loans) OVER (ORDER BY month_no))
            / NULLIF(LAG(good_loans) OVER (ORDER BY month_no), 0)
        )::numeric,
        2
    ) AS good_loan_pct_change,

    -- ======================
    -- BAD LOANS
    -- ======================
    bad_loans,
    LAG(bad_loans) OVER (ORDER BY month_no) AS prev_bad_loans,
    bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) AS bad_loan_diff,

    ROUND(
        (
            100.0 * (bad_loans - LAG(bad_loans) OVER (ORDER BY month_no))
            / NULLIF(LAG(bad_loans) OVER (ORDER BY month_no), 0)
        )::numeric,
        2
    ) AS bad_loan_pct_change,

    -- ======================
    -- SMART INSIGHT LABEL
    -- ======================
    CASE
        WHEN 
            good_loans - LAG(good_loans) OVER (ORDER BY month_no) > 0
            AND
            bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) < 0
        THEN 'healthy growth'

        WHEN 
            good_loans - LAG(good_loans) OVER (ORDER BY month_no) > 0
            AND
            bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) > 0
        THEN 'risky growth'

        WHEN 
            good_loans - LAG(good_loans) OVER (ORDER BY month_no) < 0
            AND
            bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) > 0
        THEN 'deteriorating'

        WHEN 
            good_loans - LAG(good_loans) OVER (ORDER BY month_no) < 0
            AND
            bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) < 0
        THEN 'weak activity'

        ELSE 'stable'
    END AS loan_trend_status

FROM monthly_trend_analysis

ORDER BY month_no;
--OR 
WITH monthly_trend_analysis AS (
    SELECT
        TRIM(TO_CHAR(issue_date::date, 'month')) AS month_name,
        EXTRACT(MONTH FROM issue_date) AS month_no,

        COUNT(*) AS total_loans,

        COUNT(
            CASE 
                WHEN loan_status IN ('Fully Paid','Current') THEN id 
            END
        ) AS good_loans,

        COUNT(
            CASE 
                WHEN loan_status = 'Charged Off' THEN id 
            END
        ) AS bad_loans

    FROM finance
    GROUP BY 1,2
)

SELECT
    month_no,
    month_name,
    total_loans,

    -- ======================
    -- GOOD LOANS
    -- ======================
    good_loans,
    LAG(good_loans) OVER (ORDER BY month_no) AS prev_good_loans,
    good_loans - LAG(good_loans) OVER (ORDER BY month_no) AS good_loan_diff,

    ROUND(
        (
            100.0 * (good_loans - LAG(good_loans) OVER (ORDER BY month_no))
            / NULLIF(LAG(good_loans) OVER (ORDER BY month_no), 0)
        )::numeric,
        2
    ) AS good_loan_pct_change,

    -- ======================
    -- BAD LOANS
    -- ======================
    bad_loans,
    LAG(bad_loans) OVER (ORDER BY month_no) AS prev_bad_loans,
    bad_loans - LAG(bad_loans) OVER (ORDER BY month_no) AS bad_loan_diff,

    ROUND(
        (
            100.0 * (bad_loans - LAG(bad_loans) OVER (ORDER BY month_no))
            / NULLIF(LAG(bad_loans) OVER (ORDER BY month_no), 0)
        )::numeric,
        2
    ) AS bad_loan_pct_change

FROM monthly_trend_analysis

ORDER BY month_no;

-- =========================================
-- 8. Total Expected Loss from Bad Loans by Credit Pull Timing
-- =========================================
SELECT
    CASE
        WHEN issue_date < last_credit_pull_date THEN 'after'
        WHEN issue_date > last_credit_pull_date THEN 'before'
        ELSE 'same_date'
    END AS credit_pull_recency,

    COUNT(*) AS total_loans,

    SUM(
        CASE 
            WHEN loan_status IN ('Fully Paid','Current') THEN 1 
            ELSE 0 
        END
    ) AS good_loans,

    SUM(
        CASE 
            WHEN loan_status = 'Charged Off' THEN 1 
            ELSE 0 
        END
    ) AS bad_loans,

    SUM(
        CASE 
            WHEN loan_status = 'Charged Off' 
            THEN loan_amount + (loan_amount * int_rate) 
            ELSE 0 
        END
    ) AS expected_bad_loan_payment,

   
    ROUND(
        (
            100.0 * SUM(CASE 
                WHEN loan_status IN ('Fully Paid','Current') THEN 1 
                ELSE 0 
            END)
            / COUNT(*)
        )::numeric,
        2
    ) AS good_loan_pct,

 
    ROUND(
        (
            100.0 * SUM(CASE 
                WHEN loan_status = 'Charged Off' THEN 1 
                ELSE 0 
            END)
            / COUNT(*)
        )::numeric,
        2
    ) AS bad_loan_pct

FROM finance

GROUP BY credit_pull_recency
ORDER BY good_loan_pct;

-- =========================================
-- 9. RATE OF REPAYMENT BY EMPLOYEE TENURE
-- =========================================
SELECT
    emp_length AS years_of_emp,
    SUM(CASE WHEN loan_status='Charged Off' THEN total_payment ELSE 0 END) AS actual_bad_loan_repaid,
    SUM(CASE WHEN loan_status='Charged Off'
        THEN loan_amount + (loan_amount*int_rate) ELSE 0 END) AS expected_bad_loan_payment,
    SUM(CASE WHEN loan_status='Charged Off'
        THEN loan_amount + (loan_amount*int_rate) ELSE 0 END)
    - SUM(CASE WHEN loan_status='Charged Off'
        THEN total_payment ELSE 0 END) AS loss_on_bad_loans
FROM finance
GROUP BY emp_length
ORDER BY expected_bad_loan_payment DESC;
--OR
SELECT
    emp_length AS years_of_emp,

    COUNT(
        CASE 
            WHEN loan_status = 'Charged Off' THEN 1 
        END
    ) AS bad_loan_count,

    SUM(
        CASE 
            WHEN loan_status = 'Charged Off' 
            THEN total_payment 
            ELSE 0 
        END
    ) AS actual_bad_loan_repaid,

    SUM(
        CASE 
            WHEN loan_status = 'Charged Off'
            THEN loan_amount + (loan_amount * int_rate) 
            ELSE 0 
        END
    ) AS expected_bad_loan_payment,

    SUM(
        CASE 
            WHEN loan_status = 'Charged Off'
            THEN loan_amount + (loan_amount * int_rate) 
            ELSE 0 
        END
    )
    -
    SUM(
        CASE 
            WHEN loan_status = 'Charged Off'
            THEN total_payment 
            ELSE 0 
        END
    ) AS loss_on_bad_loans,

 
    SUM(
        CASE 
            WHEN loan_status = 'Charged Off' 
            THEN total_payment 
            ELSE 0 
        END
    )
    /
    NULLIF(
        COUNT(
            CASE 
                WHEN loan_status = 'Charged Off' THEN 1 
            END
        ),
        0
    ) AS avg_repaid_per_bad_loan

FROM finance
WHERE loan_status <> 'Current'
GROUP BY emp_length
ORDER BY 6 DESC;

-- =========================================
-- 10.RECOVERY RATE BY HOME OWNERSHIP
-- =========================================
SELECT
    home_ownership,
    SUM(loan_amount + (loan_amount*int_rate)) AS expected,
    SUM(total_payment) AS repaid,
    SUM(total_payment) /
    NULLIF(SUM(loan_amount + (loan_amount*int_rate)),0) AS recovery_rate,
    ROUND(
        (100.0*SUM(total_payment) /
        NULLIF(SUM(loan_amount + (loan_amount*int_rate)),0))::numeric,
        2
    ) AS recovery_pct
FROM finance
WHERE loan_status != 'Current'
GROUP BY home_ownership
ORDER BY 3 DESC;
--OR
 SELECT home_ownership,

    COUNT(*) AS loan_count,

    SUM(loan_amount + (loan_amount * int_rate)) AS expected,

    SUM(total_payment) AS repaid,

    SUM(total_payment) /
    NULLIF(SUM(loan_amount + (loan_amount * int_rate)), 0) AS recovery_rate,

    ROUND(
        (100.0 * SUM(total_payment) /
        NULLIF(SUM(loan_amount + (loan_amount * int_rate)), 0))::numeric,
        2
    ) AS recovery_pct,

    -- ✅ NEW COLUMN
    SUM(total_payment) /
    NULLIF(COUNT(*), 0) AS avg_repaid_per_loan

FROM finance
WHERE loan_status != 'Current'
GROUP BY home_ownership
ORDER BY 7 DESC;

-- =========================================
-- 11. ADDRESS RECOVERY
-- =========================================
SELECT
    address,
    SUM(loan_amount + (loan_amount*int_rate)) AS expected,
    SUM(total_payment) AS repaid,
    SUM(total_payment) /
    NULLIF(SUM(loan_amount + (loan_amount*int_rate)),0) AS recovery_rate,
    ROUND(
        (100.0*SUM(total_payment) /
        NULLIF(SUM(loan_amount + (loan_amount*int_rate)),0))::numeric,
        2
    ) AS recovery_pct
FROM finance
WHERE loan_status != 'Current'
GROUP BY address
ORDER BY 3 DESC;

-- =========================================
-- 12. MONTHLY PAYMENT TREND
-- =========================================
WITH monthly_payment_trend AS (
    SELECT
        TRIM(TO_CHAR(issue_date,'month')) AS month_name,
        EXTRACT(MONTH FROM issue_date) AS month_no,
        SUM(loan_amount) AS total_disbursed,
        SUM(total_payment) AS total_payment_made,
        SUM(CASE WHEN loan_status IN ('Fully Paid','Current') THEN loan_amount ELSE 0 END) AS good_loan_disbursed,
        SUM(CASE WHEN loan_status='Charged Off' THEN loan_amount ELSE 0 END) AS bad_loan_disbursed,
        SUM(CASE WHEN loan_status IN ('Fully Paid','Current') THEN total_payment ELSE 0 END) AS good_loan_payment,
        SUM(CASE WHEN loan_status='Charged Off' THEN total_payment ELSE 0 END) AS bad_loan_payment
    FROM finance
    GROUP BY 1,2
)
SELECT *
FROM monthly_payment_trend
ORDER BY month_no;

-- =========================================
-- 13. RUNNING LOSS ANALYSIS
-- =========================================
WITH monthly_ble_amount AS (
    SELECT
        TRIM(TO_CHAR(issue_date::date,'month')) AS month_name,
        EXTRACT(MONTH FROM issue_date) AS month_no,
        SUM(CASE WHEN loan_status='Charged Off' THEN total_payment ELSE 0 END) AS actual_bad_loan_repaid,
        SUM(CASE WHEN loan_status='Charged Off'
            THEN loan_amount + (loan_amount*int_rate) ELSE 0 END) AS expected_bad_loan_payment
    FROM finance
    GROUP BY 1,2
)
SELECT
    month_no,
    month_name,
    actual_bad_loan_repaid,
    expected_bad_loan_payment,
    (expected_bad_loan_payment - actual_bad_loan_repaid) AS loss
FROM monthly_ble_amount
ORDER BY month_no;
