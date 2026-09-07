-- 03: store breakdown. Spend is recorded at store level, no allocation needed here.

-- 03a. Store league table.
WITH store_totals AS (
    SELECT l.store,
           SUM(l.lift_dollars)    AS lift_dollars,
           SUM(l.sales_baseline)  AS sales_baseline,
           SUM(w.total_md_spend)  AS total_md_spend
    FROM v_store_week_lift l
    JOIN v_window_store_week w
      ON w.store = l.store AND w.week = l.week
    GROUP BY l.store
)
SELECT t.store,
       s.Type                                                        AS store_format,
       s.Size                                                        AS store_size_sqft,
       ROUND(t.total_md_spend, 0)                                    AS total_md_spend,
       ROUND(t.lift_dollars, 0)                                      AS yoy_lift_dollars,
       ROUND(100.0 * t.lift_dollars / NULLIF(t.sales_baseline, 0), 1) AS yoy_growth_pct,
       ROUND(t.lift_dollars / NULLIF(t.total_md_spend, 0), 2)        AS sales_lift_per_dollar,
       ROUND(100.0 * t.total_md_spend / NULLIF(t.sales_baseline, 0), 2) AS md_spend_pct_of_baseline,
       RANK() OVER (ORDER BY t.lift_dollars / NULLIF(t.total_md_spend, 0) DESC) AS store_rank
FROM store_totals t
JOIN stores s ON s.Store = t.store
ORDER BY sales_lift_per_dollar DESC;


-- 03b. Markdown type x store format (A/B/C).
WITH attributed AS (
    SELECT m.type_no,
           m.markdown_type,
           s.Type                              AS store_format,
           m.spend,
           m.is_active,
           l.lift_dollars * m.spend_share      AS attributed_lift
    FROM v_markdown_long m
    JOIN v_store_week_lift l ON l.store = m.store AND l.week = m.week
    JOIN stores s            ON s.Store = m.store
)
SELECT markdown_type,
       store_format,
       ROUND(SUM(spend), 0)                                          AS total_spend,
       SUM(is_active)                                                AS active_store_weeks,
       ROUND(SUM(attributed_lift), 0)                                AS attributed_lift,
       ROUND(SUM(attributed_lift) / NULLIF(SUM(spend), 0), 2)        AS sales_lift_per_dollar,
       RANK() OVER (PARTITION BY store_format
                    ORDER BY SUM(attributed_lift) / NULLIF(SUM(spend), 0) DESC)
                                                                     AS rank_within_format
FROM attributed
GROUP BY type_no, markdown_type, store_format
ORDER BY store_format, sales_lift_per_dollar DESC;


-- 03c. Store x type grid (Power BI drill-through).
WITH attributed AS (
    SELECT m.store,
           m.type_no,
           m.markdown_type,
           m.spend,
           m.is_active,
           l.lift_dollars * m.spend_share AS attributed_lift
    FROM v_markdown_long m
    JOIN v_store_week_lift l ON l.store = m.store AND l.week = m.week
)
SELECT a.store,
       s.Type                                                        AS store_format,
       a.markdown_type,
       ROUND(SUM(a.spend), 0)                                        AS total_spend,
       SUM(a.is_active)                                              AS active_weeks,
       ROUND(SUM(a.attributed_lift), 0)                              AS attributed_lift,
       ROUND(SUM(a.attributed_lift) / NULLIF(SUM(a.spend), 0), 2)    AS sales_lift_per_dollar,
       RANK() OVER (PARTITION BY a.store
                    ORDER BY SUM(a.attributed_lift) / NULLIF(SUM(a.spend), 0) DESC)
                                                                     AS best_type_rank_in_store
FROM attributed a
JOIN stores s ON s.Store = a.store
GROUP BY a.store, s.Type, a.type_no, a.markdown_type
HAVING SUM(a.spend) > 0
ORDER BY a.store, best_type_rank_in_store;
