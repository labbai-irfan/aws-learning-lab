-- HRMS schema for Amazon RDS MySQL 8.0
-- Run as the master user. Uses utf8mb4 + InnoDB throughout.

CREATE DATABASE IF NOT EXISTS hrms
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE hrms;

-- ---------- Departments ----------
CREATE TABLE departments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  location    VARCHAR(100),
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------- Employees ----------
CREATE TABLE employees (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  emp_code     VARCHAR(20)  NOT NULL UNIQUE,
  first_name   VARCHAR(60)  NOT NULL,
  last_name    VARCHAR(60)  NOT NULL,
  email        VARCHAR(160) NOT NULL UNIQUE,
  phone        VARCHAR(30),
  dept_id      INT          NOT NULL,
  designation  VARCHAR(80),
  hire_date    DATE         NOT NULL,
  status       ENUM('active','on_leave','terminated') NOT NULL DEFAULT 'active',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES departments(id),
  INDEX idx_emp_dept (dept_id),
  INDEX idx_emp_status (status),
  INDEX idx_emp_name (last_name, first_name)
) ENGINE=InnoDB;

-- ---------- Attendance ----------
CREATE TABLE attendance (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  employee_id  INT NOT NULL,
  work_date    DATE NOT NULL,
  check_in     DATETIME,
  check_out    DATETIME,
  status       ENUM('present','absent','half_day','wfh') NOT NULL DEFAULT 'present',
  CONSTRAINT fk_att_emp FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  UNIQUE KEY uq_att_emp_date (employee_id, work_date),
  INDEX idx_att_date (work_date)
) ENGINE=InnoDB;

-- ---------- Leave requests ----------
CREATE TABLE leave_requests (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  employee_id  INT NOT NULL,
  leave_type   ENUM('casual','sick','earned','unpaid') NOT NULL,
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  reason       VARCHAR(255),
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_leave_emp FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  INDEX idx_leave_emp_status (employee_id, status)
) ENGINE=InnoDB;

-- ---------- Payroll ----------
CREATE TABLE payroll (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  employee_id   INT NOT NULL,
  pay_period    CHAR(7) NOT NULL,            -- 'YYYY-MM'
  basic         DECIMAL(12,2) NOT NULL,
  allowances    DECIMAL(12,2) NOT NULL DEFAULT 0,
  deductions    DECIMAL(12,2) NOT NULL DEFAULT 0,
  net_pay       DECIMAL(12,2) AS (basic + allowances - deductions) STORED,
  paid_on       DATE,
  CONSTRAINT fk_pay_emp FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  UNIQUE KEY uq_pay_emp_period (employee_id, pay_period),
  INDEX idx_pay_period (pay_period)
) ENGINE=InnoDB;

-- ---------- Audit log ----------
CREATE TABLE audit_log (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  actor       VARCHAR(80) NOT NULL,
  action      VARCHAR(120) NOT NULL,
  entity      VARCHAR(60),
  entity_id   VARCHAR(40),
  at_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_time (at_time)
) ENGINE=InnoDB;

-- ---------- Seed data ----------
INSERT INTO departments (name, location) VALUES
  ('Engineering','Bangalore'),
  ('Human Resources','Mumbai'),
  ('Finance','Delhi');

INSERT INTO employees (emp_code, first_name, last_name, email, dept_id, designation, hire_date) VALUES
  ('E001','Aisha','Khan','aisha.khan@hrms.local',1,'Senior Engineer','2023-04-10'),
  ('E002','Rahul','Verma','rahul.verma@hrms.local',1,'Engineer','2024-01-15'),
  ('E003','Meera','Nair','meera.nair@hrms.local',2,'HR Manager','2022-09-01'),
  ('E004','John','Doe','john.doe@hrms.local',3,'Accountant','2023-11-20');

INSERT INTO payroll (employee_id, pay_period, basic, allowances, deductions, paid_on) VALUES
  (1,'2026-05',120000,20000,15000,'2026-05-31'),
  (2,'2026-05', 80000,12000, 9000,'2026-05-31'),
  (3,'2026-05', 95000,15000,11000,'2026-05-31'),
  (4,'2026-05', 70000,10000, 8000,'2026-05-31');
