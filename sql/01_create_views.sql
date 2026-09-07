-- 01: shared views for 02-06. Run once. Assumptions: docs/methodology.md

-- v_window_store_week: one row per store-week, markdown nulls/negatives cleaned to 0.
DROP VIEW IF EXISTS v_window_store_week;
CREATE VIEW v_window_store_week AS
SELECT f.Store                                     AS store,
       f.Date                                      AS week,
       f.IsHoliday                                 AS is_holiday,
       MAX(COALESCE(f.MarkDown1, 0), 0)            AS md1,
       MAX(COALESCE(f.MarkDown2, 0), 0)            AS md2,
       MAX(COALESCE(f.MarkDown3, 0), 0)            AS md3,
       MAX(COALESCE(f.MarkDown4, 0), 0)            AS md4,
       MAX(COALESCE(f.MarkDown5, 0), 0)            AS md5,
       MAX(COALESCE(f.MarkDown1, 0), 0) + MAX(COALESCE(f.MarkDown2, 0), 0)
     + MAX(COALESCE(f.MarkDown3, 0), 0) + MAX(COALESCE(f.MarkDown4, 0), 0)
     + MAX(COALESCE(f.MarkDown5, 0), 0)            AS total_md_spend,
       (CASE WHEN MAX(COALESCE(f.MarkDown1, 0), 0) > 0 THEN 1 ELSE 0 END)
     + (CASE WHEN MAX(COALESCE(f.MarkDown2, 0), 0) > 0 THEN 1 ELSE 0 END)
     + (CASE WHEN MAX(COALESCE(f.MarkDown3, 0), 0) > 0 THEN 1 ELSE 0 END)
     + (CASE WHEN MAX(COALESCE(f.MarkDown4, 0), 0) > 0 THEN 1 ELSE 0 END)
     + (CASE WHEN MAX(COALESCE(f.MarkDown5, 0), 0) > 0 THEN 1 ELSE 0 END)
                                                   AS types_active
FROM features f
-- Date is TEXT: upper bound must be exclusive
WHERE f.Date >= '2011-11-01' AND f.Date < '2012-10-27';


-- v_markdown_long: unpivoted to one row per store-week-per-type; spend_share is the attribution weight.
DROP VIEW IF EXISTS v_markdown_long;
CREATE VIEW v_markdown_long AS
SELECT store, week, is_holiday, 1 AS type_no, 'Markdown Type 1' AS markdown_type,
       md1 AS spend, CASE WHEN md1 > 0 THEN 1 ELSE 0 END AS is_active,
       md1 / NULLIF(total_md_spend, 0) AS spend_share
FROM v_window_store_week
UNION ALL
SELECT store, week, is_holiday, 2, 'Markdown Type 2',
       md2, CASE WHEN md2 > 0 THEN 1 ELSE 0 END,
       md2 / NULLIF(total_md_spend, 0)
FROM v_window_store_week
UNION ALL
SELECT store, week, is_holiday, 3, 'Markdown Type 3',
       md3, CASE WHEN md3 > 0 THEN 1 ELSE 0 END,
       md3 / NULLIF(total_md_spend, 0)
FROM v_window_store_week
UNION ALL
SELECT store, week, is_holiday, 4, 'Markdown Type 4',
       md4, CASE WHEN md4 > 0 THEN 1 ELSE 0 END,
       md4 / NULLIF(total_md_spend, 0)
FROM v_window_store_week
UNION ALL
SELECT store, week, is_holiday, 5, 'Markdown Type 5',
       md5, CASE WHEN md5 > 0 THEN 1 ELSE 0 END,
       md5 / NULLIF(total_md_spend, 0)
FROM v_window_store_week;


-- v_yoy_pair: store-dept-week paired with its -364 day baseline week, plus dollar lift.
DROP VIEW IF EXISTS v_yoy_pair;
CREATE VIEW v_yoy_pair AS
SELECT cur.Store                                   AS store,
       cur.Dept                                    AS dept,
       cur.Date                                    AS week,
       cur.IsHoliday                               AS is_holiday,
       cur.Weekly_Sales                            AS sales_window,
       base.Weekly_Sales                           AS sales_baseline,
       cur.Weekly_Sales - base.Weekly_Sales        AS lift_dollars
FROM train cur
JOIN train base
  ON base.Store = cur.Store
 AND base.Dept  = cur.Dept
 AND base.Date  = datetime(cur.Date, '-364 days')
WHERE cur.Date >= '2011-11-01' AND cur.Date < '2012-10-27';


-- v_store_week_lift: v_yoy_pair rolled up to store-week.
DROP VIEW IF EXISTS v_store_week_lift;
CREATE VIEW v_store_week_lift AS
SELECT store,
       week,
       is_holiday,
       COUNT(*)                 AS depts,
       SUM(sales_window)        AS sales_window,
       SUM(sales_baseline)      AS sales_baseline,
       SUM(lift_dollars)        AS lift_dollars
FROM v_yoy_pair
GROUP BY store, week, is_holiday;


-- v_dept_week_lift: adds dept's share of store-week baseline sales (spend allocation weight for 04/06).
DROP VIEW IF EXISTS v_dept_week_lift;
CREATE VIEW v_dept_week_lift AS
SELECT p.store,
       p.dept,
       p.week,
       p.is_holiday,
       p.sales_window,
       p.sales_baseline,
       p.lift_dollars,
       CASE WHEN p.sales_baseline > 0 AND s.positive_baseline > 0
            THEN p.sales_baseline / s.positive_baseline
            ELSE 0 END AS dept_baseline_share
FROM v_yoy_pair p
JOIN (SELECT store, week,
             SUM(CASE WHEN sales_baseline > 0 THEN sales_baseline ELSE 0 END) AS positive_baseline
      FROM v_yoy_pair
      GROUP BY store, week) s
  ON s.store = p.store AND s.week = p.week;
