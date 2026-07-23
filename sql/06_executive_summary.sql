-- =====================================================================
-- Phase 4d: Final Views for Power BI (SQL Server / T-SQL)
-- One view per dashboard page. Power BI connects to these directly,
-- never to raw tables.
-- =====================================================================

-- ---------------------------------------------------------------
-- Page 1: Executive Overview
-- ---------------------------------------------------------------
USE customer_ops_analytics;
GO
IF OBJECT_ID('v_executive_summary', 'V') IS NOT NULL DROP VIEW v_executive_summary;
GO

CREATE VIEW v_executive_summary AS
SELECT
    (SELECT COUNT(*) FROM v_tickets_sla) AS total_tickets,
    (SELECT COUNT(*) FROM v_tickets_sla WHERE status IN ('Open','Pending','Escalated')) AS open_tickets,
    (SELECT CAST(
        100.0 * SUM(CASE WHEN resolution_sla_status = 'Breached' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN resolution_sla_status IN ('Breached','Within SLA') THEN 1 ELSE 0 END), 0)
     AS DECIMAL(10,1)) FROM v_tickets_sla) AS sla_breach_pct,
    (SELECT CAST(
        100.0 * SUM(CASE WHEN first_response_sla_status = 'Breached' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_response_sla_status IS NOT NULL THEN 1 ELSE 0 END), 0)
     AS DECIMAL(10,1)) FROM v_tickets_sla) AS first_response_breach_pct,
    (SELECT CAST(AVG(CASE WHEN resolved_at IS NOT NULL THEN resolution_hours END) AS DECIMAL(10,1))
        FROM v_tickets_sla) AS avg_resolution_hours,
    (SELECT CAST(AVG(first_response_hours) AS DECIMAL(10,1)) FROM v_tickets_sla) AS avg_first_response_hours,
    (SELECT COUNT(*) FROM v_backlog) AS backlog_count,
    (SELECT COUNT(*) FROM data_quality_issues) AS data_quality_issue_count;
GO

-- Top 5 DQ rules by failed record count (small table on Page 1)
IF OBJECT_ID('v_top_dq_rules', 'V') IS NOT NULL DROP VIEW v_top_dq_rules;
GO

CREATE VIEW v_top_dq_rules AS
SELECT TOP 5 rule_name, severity, COUNT(*) AS failed_record_count
FROM data_quality_issues
GROUP BY rule_name, severity
ORDER BY failed_record_count DESC;
GO

-- ---------------------------------------------------------------
-- Page 2: SLA Breach Analysis
-- ---------------------------------------------------------------
IF OBJECT_ID('v_sla_breach_analysis', 'V') IS NOT NULL DROP VIEW v_sla_breach_analysis;
GO

CREATE VIEW v_sla_breach_analysis AS
SELECT
    ticket_id, category, priority, channel, agent_id, created_at,
    resolution_hours, resolution_sla_hours,
    first_response_hours, first_response_sla_hours,
    resolution_sla_status, first_response_sla_status,
    DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1) AS created_month
FROM v_tickets_sla;
GO

-- Top 10 delayed tickets (highest overshoot vs SLA)
IF OBJECT_ID('v_top_delayed_tickets', 'V') IS NOT NULL DROP VIEW v_top_delayed_tickets;
GO

CREATE VIEW v_top_delayed_tickets AS
SELECT TOP 10
    ticket_id, category, priority, channel, agent_id,
    resolution_hours, resolution_sla_hours,
    CAST(resolution_hours - resolution_sla_hours AS DECIMAL(10,1)) AS hours_over_sla
FROM v_tickets_sla
WHERE resolution_sla_status = 'Breached'
ORDER BY hours_over_sla DESC;
GO

-- ---------------------------------------------------------------
-- Page 4: Backlog Monitoring summary rollup
-- ---------------------------------------------------------------
IF OBJECT_ID('v_backlog_summary', 'V') IS NOT NULL DROP VIEW v_backlog_summary;
GO

CREATE VIEW v_backlog_summary AS
SELECT aging_bucket, priority, category, COUNT(*) AS ticket_count
FROM v_backlog
GROUP BY aging_bucket, priority, category;
GO

-- Sanity check
SELECT * FROM v_executive_summary;
GO

