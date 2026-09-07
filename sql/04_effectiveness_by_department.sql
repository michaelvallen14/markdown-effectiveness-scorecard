-- 04: department breakdown. CAVEAT: spend is allocated by baseline sales share, not recorded per dept — indicative only. Details: docs/methodology.md

-- 04a. Department league table.
WITH dept_totals AS (
    SELECT d.dept,
           SUM(d.lift_dollars)                          AS lift_dollars,
           SUM(d.sales_baseline)                        AS sales_baseline,
           SUM(d.sales_window)                          AS sales_window,
           SUM(w.total_md_spend * d.dept_baseline_share) AS allocated_md_spend,
           COUNT(DISTINCT d.store)                      AS stores,
           COUNT(*)                                     AS store_dept_weeks
    FROM v_dept_week_lift d
    JOIN v_window_store_week w
      ON w.store = d.store AND w.week = d.week
    GROUP BY d.dept
)
SELECT dept,
       stores,
       ROUND(sales_baseline, 0)                                      AS baseline_sales,
       ROUND(allocated_md_spend, 0)                                  AS allocated_md_spend,
       ROUND(lift_dollars, 0)                                        AS yoy_lift_dollars,
       ROUND(100.0 * lift_dollars / NULLIF(sales_baseline, 0), 1)    AS yoy_growth_pct,
       ROUND(lift_dollars / NULLIF(allocated_md_spend, 0), 2)        AS sales_lift_per_allocated_dollar,
       -- flagged not filtered: small depts post extreme ratios on trivial bases
       CASE WHEN stores < 30 OR sales_baseline < 5000000
            THEN 'Low base - treat with caution'
            ELSE 'Material' END                                      AS materiality,
       RANK() OVER (ORDER BY lift_dollars / NULLIF(allocated_md_spend, 0) DESC) AS dept_rank,
       RANK() OVER (PARTITION BY CASE WHEN stores < 30 OR sales_baseline < 5000000 THEN 1 ELSE 0 END
                    ORDER BY lift_dollars / NULLIF(allocated_md_spend, 0) DESC)
                                                                     AS rank_among_material
FROM dept_totals
WHERE allocated_md_spend > 0
ORDER BY materiality, sales_lift_per_allocated_dollar DESC;


-- 04b. Dept x type, top 10 by allocated spend.
WITH dept_type AS (
    SELECT d.dept,
           m.type_no,
           m.markdown_type,
           SUM(m.spend * d.dept_baseline_share)   AS allocated_spend,
           SUM(d.lift_dollars * m.spend_share)    AS attributed_lift
    FROM v_dept_week_lift d
    JOIN v_markdown_long m
      ON m.store = d.store AND m.week = d.week
    GROUP BY d.dept, m.type_no, m.markdown_type
),
top_depts AS (
    SELECT dept
    FROM dept_type
    GROUP BY dept
    ORDER BY SUM(allocated_spend) DESC
    LIMIT 10
)
SELECT dt.dept,
       dt.markdown_type,
       ROUND(dt.allocated_spend, 0)                                        AS allocated_spend,
       ROUND(dt.attributed_lift, 0)                                        AS attributed_lift,
       ROUND(dt.attributed_lift / NULLIF(dt.allocated_spend, 0), 2)        AS sales_lift_per_allocated_dollar,
       RANK() OVER (PARTITION BY dt.dept
                    ORDER BY dt.attributed_lift / NULLIF(dt.allocated_spend, 0) DESC)
                                                                           AS best_type_in_dept
FROM dept_type dt
JOIN top_depts td ON td.dept = dt.dept
WHERE dt.allocated_spend > 0
ORDER BY dt.dept, best_type_in_dept;


-- 04c. Cut list: real spend, still went backwards YoY.
WITH dept_totals AS (
    SELECT d.dept,
           SUM(d.lift_dollars)                           AS lift_dollars,
           SUM(d.sales_baseline)                         AS sales_baseline,
           SUM(w.total_md_spend * d.dept_baseline_share) AS allocated_md_spend
    FROM v_dept_week_lift d
    JOIN v_window_store_week w
      ON w.store = d.store AND w.week = d.week
    GROUP BY d.dept
)
SELECT dept,
       ROUND(allocated_md_spend, 0)                                  AS allocated_md_spend,
       ROUND(lift_dollars, 0)                                        AS yoy_lift_dollars,
       ROUND(100.0 * lift_dollars / NULLIF(sales_baseline, 0), 1)    AS yoy_growth_pct,
       ROUND(lift_dollars / NULLIF(allocated_md_spend, 0), 2)        AS sales_lift_per_allocated_dollar
FROM dept_totals
WHERE lift_dollars < 0
  AND allocated_md_spend > 100000        -- skip trivial-scale depts
ORDER BY lift_dollars ASC;
