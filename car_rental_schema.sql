
-- ── Create & select database ─────────────────────────────────
CREATE DATABASE IF NOT EXISTS CarRentalDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE CarRentalDB;


CREATE TABLE IF NOT EXISTS Branches (
    branch_id   INT AUTO_INCREMENT PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    city        VARCHAR(80)  NOT NULL,
    address     VARCHAR(200),
    phone       VARCHAR(20),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Cars (
    car_id        INT AUTO_INCREMENT PRIMARY KEY,
    branch_id     INT NOT NULL,
    make          VARCHAR(50)  NOT NULL,
    model         VARCHAR(50)  NOT NULL,
    year          YEAR         NOT NULL,
    license_plate VARCHAR(20)  NOT NULL UNIQUE,
    category      ENUM('Economy','Compact','SUV','Luxury','Van') DEFAULT 'Economy',
    daily_rate    DECIMAL(8,2) NOT NULL,
    is_available  TINYINT(1)   DEFAULT 1   COMMENT '1=available, 0=rented',
    added_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (branch_id) REFERENCES Branches(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Users (
    user_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    phone      VARCHAR(20),
    license_no VARCHAR(30)  NOT NULL UNIQUE  COMMENT 'Driving licence number',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ────────────────────────────────────────────────────────────
--  TABLE: Rentals
--  Core transaction table.
--  * rent_date      — when car was handed over
--  * expected_return — agreed return deadline
--  * actual_return   — NULL while active, filled on return
--  * fine_amount     — 20% of daily_rate per overdue day
--  * status          — Active | Returned | Overdue
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS Rentals (
    rental_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT          NOT NULL,
    car_id          INT          NOT NULL,
    branch_id       INT          NOT NULL,
    rent_date       DATETIME     NOT NULL,
    expected_return DATETIME     NOT NULL,
    actual_return   DATETIME     DEFAULT NULL,
    daily_rate      DECIMAL(8,2) NOT NULL,
    base_charge     DECIMAL(10,2) DEFAULT NULL  COMMENT 'daily_rate × actual days',
    fine_amount     DECIMAL(10,2) DEFAULT 0.00,
    total_charge    DECIMAL(10,2) DEFAULT NULL,
    status          ENUM('Active','Returned','Overdue') DEFAULT 'Active',

    FOREIGN KEY (user_id)   REFERENCES Users(user_id)    ON DELETE RESTRICT,
    FOREIGN KEY (car_id)    REFERENCES Cars(car_id)      ON DELETE RESTRICT,
    FOREIGN KEY (branch_id) REFERENCES Branches(branch_id) ON DELETE RESTRICT
);


CREATE TABLE IF NOT EXISTS Payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    rental_id  INT           NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    paid_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    method     ENUM('Cash','Card','Online') DEFAULT 'Cash',

    FOREIGN KEY (rental_id) REFERENCES Rentals(rental_id) ON DELETE RESTRICT
);

-- ============================================================
--  VIEWS  (handy shortcuts)
-- ============================================================

-- Active rentals with customer & car info
CREATE OR REPLACE VIEW v_active_rentals AS
SELECT
    r.rental_id,
    u.full_name     AS customer,
    u.phone         AS customer_phone,
    c.make, c.model, c.license_plate,
    b.branch_name,
    r.rent_date,
    r.expected_return,
    r.daily_rate,
    r.status
FROM Rentals r
JOIN Users    u ON r.user_id   = u.user_id
JOIN Cars     c ON r.car_id    = c.car_id
JOIN Branches b ON r.branch_id = b.branch_id
WHERE r.status IN ('Active','Overdue');

-- Overdue rentals with estimated fine
CREATE OR REPLACE VIEW v_overdue_rentals AS
SELECT
    r.rental_id,
    u.full_name  AS customer,
    u.phone,
    c.license_plate,
    r.expected_return,
    TIMESTAMPDIFF(DAY, r.expected_return, NOW())           AS overdue_days,
    r.daily_rate * 0.20
        * TIMESTAMPDIFF(DAY, r.expected_return, NOW())     AS estimated_fine
FROM Rentals r
JOIN Users u ON r.user_id = u.user_id
JOIN Cars  c ON r.car_id  = c.car_id
WHERE r.status = 'Overdue';

-- Revenue summary by branch
CREATE OR REPLACE VIEW v_branch_revenue AS
SELECT
    b.branch_name,
    COUNT(r.rental_id)           AS total_rentals,
    IFNULL(SUM(r.base_charge),0) AS base_revenue,
    IFNULL(SUM(r.fine_amount),0) AS fines_collected,
    IFNULL(SUM(r.total_charge),0) AS total_revenue
FROM Branches b
LEFT JOIN Rentals r ON b.branch_id = r.branch_id AND r.status = 'Returned'
GROUP BY b.branch_id;

-- ============================================================
--  STORED PROCEDURE: mark_overdue
--  Call periodically (or via cron) to flag late returns
-- ============================================================
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS mark_overdue()
BEGIN
    UPDATE Rentals
    SET    status = 'Overdue'
    WHERE  status = 'Active'
    AND    expected_return < NOW();
END $$
DELIMITER ;

INSERT IGNORE INTO Branches (branch_name, city, address, phone) VALUES
    ('Downtown Branch', 'Karachi',   'Block 5, Clifton',                '021-1111111'),
    ('Airport Branch',  'Lahore',    'Near Allama Iqbal Airport',        '042-2222222'),
    ('Mall Branch',     'Islamabad', 'F-10 Markaz',                     '051-3333333');

INSERT IGNORE INTO Cars (branch_id, make, model, year, license_plate, category, daily_rate) VALUES
    (1, 'Toyota',  'Corolla',   2022, 'KHI-001', 'Compact', 3500.00),
    (1, 'Honda',   'Civic',     2023, 'KHI-002', 'Compact', 4000.00),
    (1, 'Suzuki',  'Alto',      2021, 'KHI-003', 'Economy', 2000.00),
    (2, 'Toyota',  'Fortuner',  2023, 'LHR-001', 'SUV',     8000.00),
    (2, 'Kia',     'Sportage',  2022, 'LHR-002', 'SUV',     6500.00),
    (3, 'Mercedes','C-Class',   2023, 'ISB-001', 'Luxury', 15000.00),
    (3, 'Toyota',  'Hiace',     2022, 'ISB-002', 'Van',     7000.00);

-- ================VIEWS==================
-- SELECT * FROM v_active_rentals;
-- SELECT * FROM v_overdue_rentals;
-- SELECT * FROM v_branch_revenue;
-- CALL mark_overdue();
