-- =====================================================================
-- Phase 4c: Backlog Aging Analysis
-- For open/pending/escalated tickets, compute age and bucket into
-- 0-24h / 1-3d / 3-7d / 7+d
-- =====================================================================
USE customer_ops_analytics;
GO
IF OBJECT_ID('v_backlog', 'V') IS NOT NULL DROP VIEW v_backlog;
GO

CREATE VIEW v_backlog AS
SELECT
    s.ticket_id,
    s.customer_id,
    s.agent_id,
    a.agent_name,
    a.team,
    s.priority,
    s.category,
    s.channel,
    s.status,
    s.created_at,

    -- Age in hours, measured against "now" simulated as the max created_at
    -- in the dataset (since this is historical synthetic data, not live)
    CAST(
        DATEDIFF(MINUTE, s.created_at, (SELECT MAX(created_at) FROM tickets_raw)) AS DECIMAL(10,2)
    ) / 60.0 AS age_hours,

    CASE
        WHEN CAST(DATEDIFF(MINUTE, s.created_at, (SELECT MAX(created_at) FROM tickets_raw)) AS DECIMAL(10,2)) / 60.0 <= 24
            THEN '0-24h (New)'
        WHEN CAST(DATEDIFF(MINUTE, s.created_at, (SELECT MAX(created_at) FROM tickets_raw)) AS DECIMAL(10,2)) / 60.0 <= 72
            THEN '1-3d (Needs Attention)'
        WHEN CAST(DATEDIFF(MINUTE, s.created_at, (SELECT MAX(created_at) FROM tickets_raw)) AS DECIMAL(10,2)) / 60.0 <= 168
            THEN '3-7d (High Risk)'
        ELSE '7d+ (Critical Backlog)'
    END AS aging_bucket

FROM v_tickets_sla s
LEFT JOIN agents_raw a ON a.agent_id = s.agent_id
WHERE s.status IN ('Open', 'Pending', 'Escalated');
GO

-- Quick check
SELECT aging_bucket, status, COUNT(*) AS ticket_count
FROM v_backlog
GROUP BY aging_bucket, status
ORDER BY aging_bucket;
GO