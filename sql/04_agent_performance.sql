-- =====================================================================
-- Phase 4b: Agent Performance (SQL Server / T-SQL)
-- Tickets handled, breach rate, avg resol
USE customer_ops_analytics;
GO
IF OBJECT_ID('v_agent_performance', 'V') IS NOT NULL DROP VIEW v_agent_performance;
GO

CREATE VIEW v_agent_performance AS
SELECT
    a.agent_id,
    a.agent_name,
    a.team,
    a.shift,
    a.manager_name,
    a.experience_level,
    a.max_daily_capacity,

    COUNT(s.ticket_id) AS tickets_handled,

    SUM(CASE WHEN s.resolution_sla_status = 'Breached' THEN 1 ELSE 0 END) AS breached_tickets,

    CAST(
        100.0 * SUM(CASE WHEN s.resolution_sla_status = 'Breached' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN s.resolution_sla_status IN ('Breached','Within SLA') THEN 1 ELSE 0 END), 0)
    AS DECIMAL(10,1)) AS breach_rate_pct,

    CAST(AVG(CASE WHEN s.resolved_at IS NOT NULL THEN s.resolution_hours END) AS DECIMAL(10,1))
        AS avg_resolution_hours,

    CAST(AVG(s.first_response_hours) AS DECIMAL(10,1)) AS avg_first_response_hours,

    CAST(AVG(CASE WHEN s.satisfaction_score BETWEEN 1 AND 5 THEN s.satisfaction_score END) AS DECIMAL(10,2))
        AS avg_satisfaction_score,

    -- rough daily ticket load: tickets handled / active days in the data window
    CAST(
        COUNT(s.ticket_id) * 1.0
        / NULLIF((SELECT DATEDIFF(DAY, MIN(created_at), MAX(created_at)) FROM tickets_raw), 0)
    AS DECIMAL(10,1)) AS avg_tickets_per_day

FROM agents_raw a
LEFT JOIN v_tickets_sla s ON s.agent_id = a.agent_id
GROUP BY a.agent_id, a.agent_name, a.team, a.shift, a.manager_name,
         a.experience_level, a.max_daily_capacity;
GO

-- Team and shift level rollups (used directly in Power BI Page 3)
IF OBJECT_ID('v_team_shift_performance', 'V') IS NOT NULL DROP VIEW v_team_shift_performance;
GO

CREATE VIEW v_team_shift_performance AS
SELECT
    a.team,
    a.shift,
    COUNT(s.ticket_id) AS tickets_handled,
    CAST(
        100.0 * SUM(CASE WHEN s.resolution_sla_status = 'Breached' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN s.resolution_sla_status IN ('Breached','Within SLA') THEN 1 ELSE 0 END), 0)
    AS DECIMAL(10,1)) AS breach_rate_pct
FROM agents_raw a
LEFT JOIN v_tickets_sla s ON s.agent_id = a.agent_id
GROUP BY a.team, a.shift;
GO

-- Quick check
SELECT TOP 5 agent_id, agent_name, tickets_handled, breach_rate_pct, max_daily_capacity
FROM v_agent_performance
ORDER BY tickets_handled DESC;
GO

