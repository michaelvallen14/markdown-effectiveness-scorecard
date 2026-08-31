# Schema exploration notes — Walmart Recruiting: Store Sales Forecasting

Data pulled from Kaggle (`train.csv`, `features.csv`, `stores.csv`), loaded into `sql/walmart.db` (SQLite). Explored 31 Aug 2026.

## Tables

**train** (421,570 rows) — `Store, Dept, Date, Weekly_Sales, IsHoliday`
Date range 2010-02-05 to 2012-10-26. 45 stores, 81 departments.

**features** (8,190 rows) — `Store, Date, Temperature, Fuel_Price, MarkDown1..5, CPI, Unemployment, IsHoliday`
Date range 2010-02-05 to 2013-07-26 (extends past train — the extra months support the original Kaggle forecasting competition's test set, not this project).

**stores** (45 rows) — `Store, Type (A/B/C), Size`. 22 Type A, 17 Type B, 6 Type C.

Join on `(Store, Date)` for train↔features is clean: every train row matched a features row (0 unmatched), and `IsHoliday` agrees between the two tables with 0 mismatches across all 421,570 rows.

## Critical finding: MarkDown1-5 usable window is much narrower than the full dataset

Checked null rate by month. **MarkDown1-5 are 100% null for every month from Feb 2010 through Oct 2011** — no markdown activity is recorded at all for the first 21 months. Data only starts appearing from **Nov 2011** onward, and even then coverage is uneven month to month — e.g. MarkDown2 is 94% null in May 2012, 75% null in Oct 2012, versus near-0% null in other months.

Restricting to dates within train's range (≤ 2012-10-26), overall null rates are: MarkDown1 64.6%, MarkDown2 74.6%, MarkDown3 68.2%, MarkDown4 69.5%, MarkDown5 64.3%.

**Implication for the analysis:** the real usable comparison window (markdown-active weeks vs baseline weeks, with sales data to match) is roughly **Nov 2011 – Oct 2012 (~12 months)**, not the full 2.5-year span. Restrict the lift calculation to this window — including the earlier all-null months would just be baseline noise, not a fair comparison.

**Assumption to state explicitly in the write-up:** treating `NULL` in MarkDown1-5 as "no markdown ran that week" (effectively $0 spend), consistent with markdowns only being tracked from Nov 2011. This is the standard interpretation for this dataset, but it's an assumption, not a documented fact from Kaggle — worth one sentence in the findings doc so it doesn't read as an oversight.

## Next step
Write the per-category lift SQL against `sql/walmart.db`, restricted to the Nov 2011–Oct 2012 window, joining train + features + stores.
