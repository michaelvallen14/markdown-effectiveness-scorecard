-- 00: validates window + baseline design for 01-06. Full reasoning: docs/methodology.md

-- A1. Window shape.
SELECT 'A1. window shape'                         AS check_name,
       COUNT(*)                                   AS store_weeks,
       COUNT(DISTINCT Store)                      AS stores,
       COUNT(DISTINCT Date)                       AS weeks,
       MIN(Date)                                  AS first_week,
       MAX(Date)                                  AS last_week
FROM features
-- Date is TEXT: upper bound must be exclusive
WHERE Date >= '2011-11-01' AND Date < '2012-10-27';


-- A2. Markdown null-rate by month.
SELECT 'A2. coverage by month'                                        AS check_name,
       strftime('%Y-%m', Date)                                        AS month,
       COUNT(*)                                                       AS store_weeks,
       ROUND(100.0 * SUM(CASE WHEN MarkDown1 IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS md1_pct_null,
       ROUND(100.0 * SUM(CASE WHEN MarkDown2 IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS md2_pct_null,
       ROUND(100.0 * SUM(CASE WHEN MarkDown3 IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS md3_pct_null,
       ROUND(100.0 * SUM(CASE WHEN MarkDown4 IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS md4_pct_null,
       ROUND(100.0 * SUM(CASE WHEN MarkDown5 IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS md5_pct_null
FROM features
WHERE Date < '2012-10-27'
GROUP BY month
ORDER BY month;


-- B1. Markdown types running at once, per store-week.
WITH activity AS (
    SELECT Store,
           Date,
           (CASE WHEN MarkDown1 > 0 THEN 1 ELSE 0 END)
         + (CASE WHEN MarkDown2 > 0 THEN 1 ELSE 0 END)
         + (CASE WHEN MarkDown3 > 0 THEN 1 ELSE 0 END)
         + (CASE WHEN MarkDown4 > 0 THEN 1 ELSE 0 END)
         + (CASE WHEN MarkDown5 > 0 THEN 1 ELSE 0 END) AS types_active
    FROM features
    WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
)
SELECT 'B1. co-activity'                                    AS check_name,
       types_active,
       COUNT(*)                                             AS store_weeks,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_store_weeks
FROM activity
GROUP BY types_active
ORDER BY types_active;


-- B2. Where zero-markdown store-weeks fall.
SELECT 'B2. zero-markdown weeks' AS check_name,
       Date,
       COUNT(*)                  AS stores_with_no_markdown
FROM features
WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
  AND MAX(COALESCE(MarkDown1, 0), 0) + MAX(COALESCE(MarkDown2, 0), 0)
    + MAX(COALESCE(MarkDown3, 0), 0) + MAX(COALESCE(MarkDown4, 0), 0)
    + MAX(COALESCE(MarkDown5, 0), 0) = 0
GROUP BY Date
ORDER BY Date;


-- B3. Activity rate and spend per type.
WITH long_md AS (
    SELECT 'Markdown Type 1' AS markdown_type, MAX(COALESCE(MarkDown1, 0), 0) AS spend FROM features WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
    UNION ALL SELECT 'Markdown Type 2', MAX(COALESCE(MarkDown2, 0), 0) FROM features WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
    UNION ALL SELECT 'Markdown Type 3', MAX(COALESCE(MarkDown3, 0), 0) FROM features WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
    UNION ALL SELECT 'Markdown Type 4', MAX(COALESCE(MarkDown4, 0), 0) FROM features WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
    UNION ALL SELECT 'Markdown Type 5', MAX(COALESCE(MarkDown5, 0), 0) FROM features WHERE Date >= '2011-11-01' AND Date < '2012-10-27'
)
SELECT 'B3. spend and activity by type'                         AS check_name,
       markdown_type,
       SUM(CASE WHEN spend > 0 THEN 1 ELSE 0 END)               AS active_store_weeks,
       ROUND(100.0 * SUM(CASE WHEN spend > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_store_weeks_active,
       ROUND(SUM(spend), 0)                                     AS total_spend,
       ROUND(SUM(spend) / NULLIF(SUM(CASE WHEN spend > 0 THEN 1 ELSE 0 END), 0), 0) AS avg_spend_per_active_week
FROM long_md
GROUP BY markdown_type
ORDER BY markdown_type;


-- B4. Negative markdown values (floored to 0 downstream).
SELECT 'B4. negative markdown values' AS check_name,
       SUM(CASE WHEN MarkDown1 < 0 THEN 1 ELSE 0 END) AS md1_negative_weeks,
       SUM(CASE WHEN MarkDown2 < 0 THEN 1 ELSE 0 END) AS md2_negative_weeks,
       SUM(CASE WHEN MarkDown3 < 0 THEN 1 ELSE 0 END) AS md3_negative_weeks,
       SUM(CASE WHEN MarkDown4 < 0 THEN 1 ELSE 0 END) AS md4_negative_weeks,
       SUM(CASE WHEN MarkDown5 < 0 THEN 1 ELSE 0 END) AS md5_negative_weeks
FROM features
WHERE Date >= '2011-11-01' AND Date < '2012-10-27';


-- C1. Baseline (-364 day) week match rate.
SELECT 'C1. baseline week match'                       AS check_name,
       COUNT(DISTINCT cur.Date)                        AS window_weeks,
       COUNT(DISTINCT base.Date)                       AS matched_baseline_weeks,
       MIN(datetime(cur.Date, '-364 days'))            AS earliest_baseline_week,
       MAX(datetime(cur.Date, '-364 days'))            AS latest_baseline_week
FROM      (SELECT DISTINCT Date FROM train WHERE Date >= '2011-11-01' AND Date < '2012-10-27') cur
LEFT JOIN (SELECT DISTINCT Date FROM train) base
       ON base.Date = datetime(cur.Date, '-364 days');


-- C2. Holiday flag alignment, window vs baseline.
SELECT 'C2. holiday misalignment' AS check_name,
       cur.Date                   AS window_week,
       cur.IsHoliday              AS window_is_holiday,
       base.Date                  AS baseline_week,
       base.IsHoliday             AS baseline_is_holiday
FROM (SELECT DISTINCT Date, IsHoliday FROM train WHERE Date >= '2011-11-01' AND Date < '2012-10-27') cur
JOIN (SELECT DISTINCT Date, IsHoliday FROM train) base
  ON base.Date = datetime(cur.Date, '-364 days')
WHERE cur.IsHoliday <> base.IsHoliday;


-- C3. Store-dept-week baseline coverage.
SELECT 'C3. store-dept-week coverage'                                      AS check_name,
       COUNT(*)                                                            AS window_rows,
       SUM(CASE WHEN base.Weekly_Sales IS NOT NULL THEN 1 ELSE 0 END)      AS matched_rows,
       COUNT(*) - SUM(CASE WHEN base.Weekly_Sales IS NOT NULL THEN 1 ELSE 0 END) AS unmatched_rows,
       ROUND(100.0 * SUM(CASE WHEN base.Weekly_Sales IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_matched
FROM train cur
LEFT JOIN train base
       ON base.Store = cur.Store
      AND base.Dept  = cur.Dept
      AND base.Date  = datetime(cur.Date, '-364 days')
WHERE cur.Date >= '2011-11-01' AND cur.Date < '2012-10-27';


-- C4. YoY drift, zero-markdown weeks (feeds drift_rate in 02).
SELECT 'C4. YoY drift on zero-markdown weeks'                          AS check_name,
       COUNT(*)                                                        AS store_dept_weeks,
       ROUND(SUM(cur.Weekly_Sales), 0)                                 AS window_sales,
       ROUND(SUM(base.Weekly_Sales), 0)                                AS baseline_sales,
       ROUND(SUM(cur.Weekly_Sales) / NULLIF(SUM(base.Weekly_Sales), 0) - 1, 4) AS yoy_drift_rate
FROM train cur
JOIN train base
  ON base.Store = cur.Store AND base.Dept = cur.Dept
 AND base.Date  = datetime(cur.Date, '-364 days')
JOIN features f
  ON f.Store = cur.Store AND f.Date = cur.Date
WHERE cur.Date >= '2011-11-01' AND cur.Date < '2012-10-27'
  AND MAX(COALESCE(f.MarkDown1, 0), 0) + MAX(COALESCE(f.MarkDown2, 0), 0)
    + MAX(COALESCE(f.MarkDown3, 0), 0) + MAX(COALESCE(f.MarkDown4, 0), 0)
    + MAX(COALESCE(f.MarkDown5, 0), 0) = 0;


-- C5. YoY growth, full window (compare to C4).
SELECT 'C5. YoY growth, full window'                                   AS check_name,
       COUNT(*)                                                        AS store_dept_weeks,
       ROUND(SUM(cur.Weekly_Sales), 0)                                 AS window_sales,
       ROUND(SUM(base.Weekly_Sales), 0)                                AS baseline_sales,
       ROUND(SUM(cur.Weekly_Sales) / NULLIF(SUM(base.Weekly_Sales), 0) - 1, 4) AS yoy_growth_rate
FROM train cur
JOIN train base
  ON base.Store = cur.Store AND base.Dept = cur.Dept
 AND base.Date  = datetime(cur.Date, '-364 days')
WHERE cur.Date >= '2011-11-01' AND cur.Date < '2012-10-27';
