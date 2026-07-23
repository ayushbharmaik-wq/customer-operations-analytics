
USE customer_ops_analytics;
GO

IF OBJECT_ID('v_backlog_summary', 'V') IS NOT NULL DROP VIEW v_backlog_summary;
IF OBJECT_ID('v_top_delayed_tickets', 'V') IS NOT NULL DROP VIEW v_top_delayed_tickets;
IF OBJECT_ID('v_sla_breach_analysis', 'V') IS NOT NULL DROP VIEW v_sla_breach_analysis;
IF OBJECT_ID('v_top_dq_rules', 'V') IS NOT NULL DROP VIEW v_top_dq_rules;
IF OBJECT_ID('v_executive_summary', 'V') IS NOT NULL DROP VIEW v_executive_summary;
IF OBJECT_ID('v_backlog', 'V') IS NOT NULL DROP VIEW v_backlog;
IF OBJECT_ID('v_team_shift_performance', 'V') IS NOT NULL DROP VIEW v_team_shift_performance;
IF OBJECT_ID('v_agent_performance', 'V') IS NOT NULL DROP VIEW v_agent_performance;
IF OBJECT_ID('v_tickets_sla', 'V') IS NOT NULL DROP VIEW v_tickets_sla;
GO

IF OBJECT_ID('tickets_raw', 'U') IS NOT NULL DROP TABLE tickets_raw;
IF OBJECT_ID('sla_policy_raw', 'U') IS NOT NULL DROP TABLE sla_policy_raw;
IF OBJECT_ID('agents_raw', 'U') IS NOT NULL DROP TABLE agents_raw;
IF OBJECT_ID('customers_raw', 'U') IS NOT NULL DROP TABLE customers_raw;
IF OBJECT_ID('data_quality_issues', 'U') IS NOT NULL DROP TABLE data_quality_issues;
GO

CREATE TABLE customers_raw (
    customer_id      INT PRIMARY KEY,
    customer_name    NVARCHAR(200),
    customer_segment NVARCHAR(50),
    city             NVARCHAR(100),
    state            NVARCHAR(100),
    signup_date      DATE
);

CREATE TABLE agents_raw (
    agent_id            INT PRIMARY KEY,
    agent_name          NVARCHAR(200),
    team                NVARCHAR(100),
    shift               NVARCHAR(50),
    manager_name        NVARCHAR(100),
    experience_level    NVARCHAR(50),
    max_daily_capacity  INT
);

CREATE TABLE sla_policy_raw (
    priority                  NVARCHAR(50),
    category                  NVARCHAR(100),
    first_response_sla_hours  DECIMAL(10,2),
    resolution_sla_hours      DECIMAL(10,2),
    PRIMARY KEY (priority, category)
);

-- ticket_id is intentionally NOT a primary key: duplicate ticket_id is a
-- deliberately injected data quality issue (DQ001) that we need to load
-- and later detect via SQL, not prevent at the schema level.
--
-- NOTE: row_id is added AFTER data load (see 00_bulk_insert.sql), not here.
-- Adding an IDENTITY column before BULK INSERT causes unreliable column
-- mapping without an explicit format file, and can shift your data into
-- the wrong columns.
CREATE TABLE tickets_raw (
    ticket_id            INT,
    customer_id          INT,
    created_at           DATETIME2,
    first_response_at    DATETIME2,
    resolved_at          DATETIME2,
    priority             NVARCHAR(50),
    category             NVARCHAR(100),
    agent_id             INT,      -- nullable: DQ002
    channel              NVARCHAR(50),
    status               NVARCHAR(50),
    satisfaction_score   INT       -- nullable, and may be invalid: DQ005
);

CREATE TABLE data_quality_issues (
    issue_id       INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id      INT,
    source_table   NVARCHAR(100),
    rule_name      NVARCHAR(100),
    severity       NVARCHAR(20),
    detected_date  DATE DEFAULT CAST(GETDATE() AS DATE)
);
GO
-- =====================================================================
-- Bulk load CSVs into SQL Server 
-- =====================================================================

USE customer_ops_analytics;
GO

BULK INSERT customers_raw
FROM 'C:\SQL_data\customers_raw.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

BULK INSERT agents_raw
FROM 'C:\SQL_data\agents_raw.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

BULK INSERT sla_policy_raw
FROM 'C:\SQL_data\sla_policy_raw.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO
BULK INSERT tickets_raw
FROM 'C:\SQL_data\tickets_raw.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO
.
ALTER TABLE tickets_raw ADD row_id INT IDENTITY(1,1) NOT NULL;
GO

-- ---------------------------------------------------------------
-- Row count check - confirm everything loaded as expected
-- ---------------------------------------------------------------
SELECT 'customers_raw' AS tbl, COUNT(*) AS row_count FROM customers_raw
UNION ALL
SELECT 'agents_raw', COUNT(*) FROM agents_raw
UNION ALL
SELECT 'sla_policy_raw', COUNT(*) FROM sla_policy_raw
UNION ALL
SELECT 'tickets_raw', COUNT(*) FROM tickets_raw;

GO