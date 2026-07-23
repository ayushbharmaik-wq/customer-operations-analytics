
-- =====================================================================
-- Phase 4a: SLA Calculations (SQL Server / T-SQL)
-- Joins tickets to their SLA policy (by priority + category) and
-- derives first-response and resolution breach flags.
--
-- IMPORTANT: resolution_hours is measured from created_at (NOT
-- first_response_at), matching the Python generator's logic:
--     resolved_at = created_at + resolution_hours
-- =====================================================================
USE customer_ops_analytics;
GO
IF OBJECT_ID('v_tickets_sla', 'V') IS NOT NULL DROP VIEW v_tickets_sla;
GO

CREATE VIEW v_tickets_sla AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY row_id) AS rn
    FROM tickets_raw
)
SELECT
    t.ticket_id,
    t.customer_id,
    t.agent_id,
    t.priority,
    t.category,
    t.channel,
    t.status,
    t.created_at,
    t.first_response_at,
    t.resolved_at,
    t.satisfaction_score,

    p.first_response_sla_hours,
    p.resolution_sla_hours,

    -- Actual first response time (hours), using minute-level precision
CASE
    WHEN t.first_response_at IS NULL THEN NULL
    WHEN t.first_response_at < t.created_at THEN NULL
    ELSE CAST(DATEDIFF(MINUTE, t.created_at, t.first_response_at) AS DECIMAL(10,2)) / 60.0
END AS first_response_hours,
    -- Actual resolution time, measured from ticket creation
  CASE
    WHEN t.resolved_at IS NULL THEN NULL
    WHEN t.resolved_at < t.created_at THEN NULL
    ELSE CAST(DATEDIFF(MINUTE, t.created_at, t.resolved_at) AS DECIMAL(10,2)) / 60.0
END AS resolution_hours,
    -- First response breach flag
    CASE
        WHEN t.first_response_at IS NULL THEN NULL
        WHEN CAST(DATEDIFF(MINUTE, t.created_at, t.first_response_at) AS DECIMAL(10,2)) / 60.0
             > p.first_response_sla_hours THEN 'Breached'
        ELSE 'Within SLA'
    END AS first_response_sla_status,

    -- Resolution breach flag (only meaningful for resolved tickets)
-- Resolution breach flag
CASE
    WHEN t.resolved_at IS NOT NULL AND t.resolved_at < t.created_at
        THEN 'Invalid Timestamp'

    WHEN t.status = 'Resolved' AND t.resolved_at IS NULL
        THEN 'Invalid Missing Resolved Time'

    WHEN t.resolved_at IS NULL
        THEN 'Not Resolved'

    WHEN CAST(DATEDIFF(MINUTE, t.created_at, t.resolved_at) AS DECIMAL(10,2)) / 60.0
         > p.resolution_sla_hours
        THEN 'Breached'

    ELSE 'Within SLA'
END AS resolution_sla_status

FROM deduped t
LEFT JOIN sla_policy_raw p
    ON t.priority = p.priority AND t.category = p.category
WHERE t.rn = 1;
GO

-- Quick check
SELECT resolution_sla_status, COUNT(*) AS ticket_count
FROM v_tickets_sla
GROUP BY resolution_sla_status;
GO