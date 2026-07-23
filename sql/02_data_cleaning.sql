-- =====================================================================
-- Phase 3: Data Quality Checks (SQL Server / T-SQL)
-- Detects the 5 injected data quality issues and logs them into
-- data_quality_issues
-- =====================================================================
USE customer_ops_analytics;
GO


TRUNCATE TABLE data_quality_issues;
GO

-- DQ001: Duplicate ticket_id
-- Business meaning: same ticket entered twice -> can double-count metrics
INSERT INTO data_quality_issues (ticket_id, source_table, rule_name, severity)
SELECT ticket_id, 'tickets_raw', 'DQ001_duplicate_ticket_id', 'High'
FROM (
    SELECT ticket_id,
           ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY row_id) AS rn
    FROM tickets_raw
) t
WHERE rn > 1;

-- DQ002: Null agent_id
-- Business meaning: ticket never properly assigned to an agent
INSERT INTO data_quality_issues (ticket_id, source_table, rule_name, severity)
SELECT ticket_id, 'tickets_raw', 'DQ002_null_agent_id', 'Medium'
FROM tickets_raw
WHERE agent_id IS NULL;

-- DQ003: resolved_at earlier than created_at
-- Business meaning: broken timestamp / clock sync issue between systems
INSERT INTO data_quality_issues (ticket_id, source_table, rule_name, severity)
SELECT ticket_id, 'tickets_raw', 'DQ003_resolved_before_created', 'High'
FROM tickets_raw
WHERE resolved_at IS NOT NULL
  AND resolved_at < created_at;

-- DQ004: status = 'Resolved' but resolved_at is NULL
-- Business meaning: status update wasn't paired with a timestamp write
INSERT INTO data_quality_issues (ticket_id, source_table, rule_name, severity)
SELECT ticket_id, 'tickets_raw', 'DQ004_resolved_status_null_timestamp', 'Medium'
FROM tickets_raw
WHERE status = 'Resolved'
  AND resolved_at IS NULL;

-- DQ005: satisfaction_score outside valid range (1-5)
-- Business meaning: invalid rating captured, corrupts CSAT reporting
INSERT INTO data_quality_issues (ticket_id, source_table, rule_name, severity)
SELECT ticket_id, 'tickets_raw', 'DQ005_invalid_satisfaction_score', 'Low'
FROM tickets_raw
WHERE satisfaction_score IS NOT NULL
  AND (satisfaction_score < 1 OR satisfaction_score > 5);
GO

-- Validation: check counts roughly match injected percentages
SELECT rule_name, severity, COUNT(*) AS issue_count
FROM data_quality_issues
GROUP BY rule_name, severity
ORDER BY rule_name;