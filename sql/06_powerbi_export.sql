-- 06: Power BI/Excel export, 3 grains so ratios stay additive under any slicer. Compute lift-per-dollar as a DAX measure over sums, not a stored column. Details: docs/methodology.md

-- 06a. fact_markdown_lift: store x dept x type.
SELECT d.store,
       d.dept,
       m.type_no,
       m.markdown_type,
       SUM(m.spend * d.dept_baseline_share)            AS allocated_spend,
       SUM(d.lift_dollars * m.spend_share)             AS attributed_lift,
       SUM(CASE WHEN d.is_holiday = 1 THEN m.spend * d.dept_baseline_share ELSE 0 END)
                                                       AS allocated_spend_holiday,
       SUM(CASE WHEN d.is_holiday = 1 THEN d.lift_dollars * m.spend_share ELSE 0 END)
                                                       AS attributed_lift_holiday
FROM v_dept_week_lift d
JOIN v_markdown_long m
  ON m.store = d.store AND m.week = d.week
GROUP BY d.store, d.dept, m.type_no, m.markdown_type
HAVING SUM(m.spend * d.dept_baseline_share) > 0
ORDER BY d.store, d.dept, m.type_no;


-- 06b. fact_dept_sales: store x dept, actual sales vs baseline, no allocation.
SELECT store,
       dept,
       COUNT(*)                                                        AS weeks,
       SUM(sales_window)                                               AS window_sales,
       SUM(sales_baseline)                                             AS baseline_sales,
       SUM(lift_dollars)                                               AS yoy_lift_dollars,
       SUM(CASE WHEN is_holiday = 1 THEN sales_window   ELSE 0 END)    AS window_sales_holiday,
       SUM(CASE WHEN is_holiday = 1 THEN sales_baseline ELSE 0 END)    AS baseline_sales_holiday
FROM v_yoy_pair
GROUP BY store, dept
ORDER BY store, dept;


-- 06c. fact_markdown_spend: store x type, exact recorded spend, no allocation.
SELECT m.store,
       m.type_no,
       m.markdown_type,
       SUM(m.spend)                                                      AS total_spend,
       SUM(m.is_active)                                                  AS active_weeks,
       SUM(CASE WHEN m.is_holiday = 1 THEN m.spend ELSE 0 END)           AS total_spend_holiday,
       SUM(CASE WHEN m.is_holiday = 1 THEN m.is_active ELSE 0 END)       AS active_weeks_holiday,
       SUM(l.lift_dollars * m.spend_share)                               AS attributed_lift
FROM v_markdown_long m
JOIN v_store_week_lift l
  ON l.store = m.store AND l.week = m.week
GROUP BY m.store, m.type_no, m.markdown_type
ORDER BY m.store, m.type_no;


-- 06d. dim_store: store dimension.
SELECT Store AS store,
       Type  AS store_format,
       Size  AS store_size_sqft,
       CASE WHEN Size >= 150000 THEN 'Large'
            WHEN Size >=  70000 THEN 'Medium'
            ELSE 'Small' END AS size_band
FROM stores
ORDER BY Store;
