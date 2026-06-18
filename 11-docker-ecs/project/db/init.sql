-- HRMS schema + seed. Loaded by the local MySQL container (compose) and
-- run once against RDS in the cloud (via a bastion or a one-off ECS migrate task).
CREATE DATABASE IF NOT EXISTS hrms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hrms;

CREATE TABLE IF NOT EXISTS employees (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(120) NOT NULL,
  department VARCHAR(80),
  email      VARCHAR(160),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS salaries (
  employee_id INT PRIMARY KEY,
  base_salary DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_emp FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
);

INSERT INTO employees (name, department, email) VALUES
  ('Asha Rao',    'Engineering', 'asha@hrms.local'),
  ('Vikram Singh','Finance',     'vikram@hrms.local'),
  ('Lena Müller', 'People Ops',  'lena@hrms.local');

INSERT INTO salaries (employee_id, base_salary) VALUES
  (1, 95000.00),
  (2, 82000.00),
  (3, 76000.00);
