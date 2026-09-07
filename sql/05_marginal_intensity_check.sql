-- 05: independent check on 02 — within-store marginal effect of spend INTENSITY (tertiles), no pro-rata assumption. Details: docs/methodology.md

-- 05a. Marginal lift per dollar by type, all weeks.
WITH store_type_week AS (
    SELECT m.store,
           m.type_no,
           m.markdown_type,
           m.week,
           m.spend,
           l.sales_window,
           l.sales_baseline,
           NTILE(3) OVER (PARTITION BY m.store, m.type_no ORDER BY m.spend) AS spend_tertile
    FROM v_markdown_long m
    JOIN v_store_week_lift l
      ON l.store = m.store AND l.week = m.week
),
tertile_agg AS (
    SELECT store, type_no, markdown_type, spend_tertile,
           COUNT(*)            AS weeks,
           SUM(spend)          AS spend,
           SUM(sales_window)   AS sales_window,
           SUM(sales_baseline) AS sales_baseline
    FROM store_type_week
    WHERE spend_tertile IN (1, 3)
    GROUP BY store, type_no, markdown_type, spend_tertile
),
contrast AS (
    SELECT hi.store,
           hi.type_no,
           hi.markdown_type,
           hi.spend - lo.spend                                          AS incremental_spend,
           lo.sales_window / NULLIF(lo.sales_baseline, 0) - 1           AS bottom_growth,
           hi.sales_window
             - hi.sales_baseline * (lo.sales_window / NULLIF(lo.sales_baseline, 0))
                                                                        AS incremental_sales,
           hi.sales_window / NULLIF(hi.sales_baseline, 0) - 1           AS top_growth
    FROM tertile_agg hi
    JOIN tertile_agg lo
      ON lo.store = hi.store AND lo.type_no = hi.type_no AND lo.spend_tertile = 1
    WHERE hi.spend_tertile = 3
      AND lo.sales_baseline > 0
      AND hi.sales_baseline > 0
)
SELECT markdown_type,
       COUNT(*)                                                          AS stores_measured,
       ROUND(SUM(incremental_spend), 0)                                  AS incremental_spend,
       ROUND(SUM(incremental_sales), 0)                                  AS incremental_sales,
       ROUND(SUM(incremental_sales) / NULLIF(SUM(incremental_spend), 0), 2)
                                                                         AS marginal_lift_per_dollar,
       ROUND(100.0 * AVG(top_growth - bottom_growth), 1)                 AS avg_growth_gap_pp,
       SUM(CASE WHEN top_growth > bottom_growth THEN 1 ELSE 0 END)       AS stores_positive,
       RANK() OVER (ORDER BY SUM(incremental_sales) / NULLIF(SUM(incremental_spend), 0) DESC)
                                                                         AS marginal_rank
FROM contrast
GROUP BY type_no, markdown_type
ORDER BY marginal_lift_per_dollar DESC;


-- 05b. Same contrast, non-holiday weeks only.
WITH store_type_week AS (
    SELECT m.store, m.type_no, m.markdown_type, m.week, m.spend,
           l.sales_window, l.sales_baseline,
           NTILE(3) OVER (PARTITION BY m.store, m.type_no ORDER BY m.spend) AS spend_tertile
    FROM v_markdown_long m
    JOIN v_store_week_lift l
      ON l.store = m.store AND l.week = m.week
    WHERE m.is_holiday = 0
),
tertile_agg AS (
    SELECT store, type_no, markdown_type, spend_tertile,
           SUM(spend) AS spend, SUM(sales_window) AS sales_window,
           SUM(sales_baseline) AS sales_baseline
    FROM store_type_week
    WHERE spend_tertile IN (1, 3)
    GROUP BY store, type_no, markdown_type, spend_tertile
),
contrast AS (
    SELECT hi.markdown_type, hi.type_no,
           hi.spend - lo.spend AS incremental_spend,
           hi.sales_window
             - hi.sales_baseline * (lo.sales_window / NULLIF(lo.sales_baseline, 0)) AS incremental_sales,
           hi.sales_window / NULLIF(hi.sales_baseline, 0)
             - lo.sales_window / NULLIF(lo.sales_baseline, 0)                        AS growth_gap
    FROM tertile_agg hi
    JOIN tertile_agg lo
      ON lo.store = hi.store AND lo.type_no = hi.type_no AND lo.spend_tertile = 1
    WHERE hi.spend_tertile = 3 AND lo.sales_baseline > 0 AND hi.sales_baseline > 0
)
SELECT markdown_type,
       ROUND(SUM(incremental_spend), 0)                                  AS incremental_spend,
       ROUND(SUM(incremental_sales), 0)                                  AS incremental_sales,
       ROUND(SUM(incremental_sales) / NULLIF(SUM(incremental_spend), 0), 2)
                                                                         AS marginal_lift_per_dollar_ex_holiday,
       ROUND(100.0 * AVG(growth_gap), 1)                                 AS avg_growth_gap_pp,
       RANK() OVER (ORDER BY SUM(incremental_sales) / NULLIF(SUM(incremental_spend), 0) DESC)
                                                                         AS marginal_rank_ex_holiday
FROM contrast
GROUP BY type_no, markdown_type
ORDER BY marginal_lift_per_dollar_ex_holiday DESC;


-- 05c. Confound check: other types also at high spend, same weeks.
WITH tertiled AS (
    SELECT store, week, type_no, markdown_type, spend,
           NTILE(3) OVER (PARTITION BY store, type_no ORDER BY spend) AS spend_tertile
    FROM v_markdown_long
),
week_intensity AS (
    SELECT store, week, SUM(CASE WHEN spend_tertile = 3 THEN 1 ELSE 0 END) AS types_at_high_intensity
    FROM tertiled
    GROUP BY store, week
)
SELECT t.markdown_type,
       COUNT(*)                                                          AS top_tertile_store_weeks,
       ROUND(AVG(wi.types_at_high_intensity - 1), 2)                     AS avg_other_types_also_high,
       ROUND(100.0 * SUM(CASE WHEN wi.types_at_high_intensity = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                         AS pct_weeks_this_type_alone_high
FROM tertiled t
JOIN week_intensity wi ON wi.store = t.store AND wi.week = t.week
WHERE t.spend_tertile = 3
GROUP BY t.type_no, t.markdown_type
ORDER BY avg_other_types_also_high ASC;
