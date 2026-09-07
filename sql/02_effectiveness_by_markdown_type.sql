-- 02: HEADLINE SCORECARD by markdown type. Ranking metric is sales_lift_per_dollar; net_lift_per_dollar_sensitivity is a stress test, not the ranking. Details: docs/methodology.md

WITH params AS (
    SELECT 0.0627 AS drift_rate     -- from 00/C4
),

store_week AS (
    SELECT l.store,
           l.week,
           l.sales_window,
           l.sales_baseline,
           l.lift_dollars,
           l.sales_window - l.sales_baseline * (1 + p.drift_rate) AS net_lift_dollars
    FROM v_store_week_lift l
    CROSS JOIN params p
),

-- lift split by spend share
attributed AS (
    SELECT m.type_no,
           m.markdown_type,
           m.spend,
           m.is_active,
           sw.lift_dollars     * m.spend_share AS attributed_lift,
           sw.net_lift_dollars * m.spend_share AS attributed_net_lift
    FROM v_markdown_long m
    JOIN store_week sw
      ON sw.store = m.store AND sw.week = m.week
),

by_type AS (
    SELECT type_no,
           markdown_type,
           SUM(spend)                AS total_spend,
           SUM(is_active)            AS active_store_weeks,
           SUM(attributed_lift)      AS attributed_lift,
           SUM(attributed_net_lift)  AS attributed_net_lift
    FROM attributed
    GROUP BY type_no, markdown_type
)

SELECT markdown_type,
       ROUND(total_spend, 0)                                         AS total_spend,
       active_store_weeks,
       ROUND(total_spend / NULLIF(active_store_weeks, 0), 0)         AS avg_spend_per_active_week,
       ROUND(100.0 * total_spend / SUM(total_spend) OVER (), 1)      AS pct_of_total_spend,
       ROUND(attributed_lift, 0)                                     AS attributed_lift,
       ROUND(attributed_lift / NULLIF(total_spend, 0), 2)            AS sales_lift_per_dollar,
       ROUND(attributed_lift / NULLIF(active_store_weeks, 0), 0)     AS lift_per_active_week,
       ROUND( (attributed_lift / NULLIF(total_spend, 0))
              / NULLIF(SUM(attributed_lift) OVER () / SUM(total_spend) OVER (), 0), 2)
                                                                     AS effectiveness_index,
       RANK() OVER (ORDER BY attributed_lift / NULLIF(total_spend, 0) DESC)
                                                                     AS effectiveness_rank,
       CASE
           WHEN attributed_lift <= 0 THEN 'Cut'
           WHEN (attributed_lift / NULLIF(total_spend, 0))
                / NULLIF(SUM(attributed_lift) OVER () / SUM(total_spend) OVER (), 0) >= 1.15
                THEN 'Double down'
           WHEN (attributed_lift / NULLIF(total_spend, 0))
                / NULLIF(SUM(attributed_lift) OVER () / SUM(total_spend) OVER (), 0) >= 0.85
                THEN 'Hold'
           ELSE 'Reduce'
       END                                                           AS recommendation,
       ROUND(attributed_net_lift / NULLIF(total_spend, 0), 2)        AS net_lift_per_dollar_sensitivity

FROM by_type
ORDER BY sales_lift_per_dollar DESC;


-- 02b. Ranking split by holiday vs normal week.
WITH params AS (
    SELECT 0.0627 AS drift_rate
),
store_week AS (
    SELECT l.store, l.week, l.is_holiday,
           l.lift_dollars,
           l.sales_window - l.sales_baseline * (1 + p.drift_rate) AS net_lift_dollars
    FROM v_store_week_lift l
    CROSS JOIN params p
),
attributed AS (
    SELECT m.type_no,
           m.markdown_type,
           CASE WHEN sw.is_holiday = 1 THEN 'Holiday week' ELSE 'Normal week' END AS week_type,
           m.spend,
           m.is_active,
           sw.lift_dollars     * m.spend_share AS attributed_lift,
           sw.net_lift_dollars * m.spend_share AS attributed_net_lift
    FROM v_markdown_long m
    JOIN store_week sw
      ON sw.store = m.store AND sw.week = m.week
)
SELECT markdown_type,
       week_type,
       ROUND(SUM(spend), 0)                                          AS total_spend,
       SUM(is_active)                                                AS active_store_weeks,
       ROUND(SUM(attributed_lift), 0)                                AS attributed_lift,
       ROUND(SUM(attributed_lift)     / NULLIF(SUM(spend), 0), 2)    AS sales_lift_per_dollar,
       ROUND(SUM(attributed_net_lift) / NULLIF(SUM(spend), 0), 2)    AS net_lift_per_dollar
FROM attributed
GROUP BY type_no, markdown_type, week_type
ORDER BY markdown_type, week_type;
