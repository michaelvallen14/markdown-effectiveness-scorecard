# Power BI build guide — Trade Investment Effectiveness Scorecard

Data is pre-exported to `powerbi/data/*.csv` (from `sql/06_powerbi_export.sql`, run against
`sql/walmart.db`). This guide gets you from empty `.pbix` to finished scorecard.

---

## 1. Import the data

Power BI Desktop → **Get Data → Text/CSV**, one at a time, for all four files in `powerbi/data/`:

- `fact_markdown_lift.csv` (15,244 rows — store × dept × markdown type)
- `fact_dept_sales.csv` (3,069 rows — store × dept)
- `fact_markdown_spend.csv` (225 rows — store × markdown type)
- `dim_store.csv` (45 rows — one per store)

On each import, click **Transform Data** first (don't just hit Load) and check the column types
Power BI guessed — `store`, `dept`, `type_no` should be Whole Number; dollar columns should be
Decimal Number. Fix any it got wrong, then **Close & Apply**.

---

## 2. Build the model (Model view)

Only one relationship set is needed: **`dim_store[store]` → each fact table's `store` column**,
one-to-many, single direction. Drag `store` from `dim_store` onto `store` in each of the three
fact tables.

`dept`, `type_no`, and `markdown_type` are left as plain columns inside their fact tables
(no separate dimension) — this is a deliberate simplification for a scorecard this size, not an
oversight. You can still filter and group by them directly.

---

## 3. DAX measures

Create a new table for measures first (Model view → **New Table**, name it `_Measures`, formula
just `_Measures = {BLANK()}` deleted afterward, or use Modeling → New Measure directly on any
table — either works). Add these:

```dax
Total Spend =
SUM ( fact_markdown_spend[total_spend] )
```

```dax
Attributed Lift =
SUM ( fact_markdown_spend[attributed_lift] )
```

```dax
Sales Lift per Dollar =
DIVIDE ( [Attributed Lift], [Total Spend] )
```

```dax
Effectiveness Index =
DIVIDE (
    [Sales Lift per Dollar],
    CALCULATE ( [Sales Lift per Dollar], ALL ( fact_markdown_spend[markdown_type] ) )
)
```

```dax
Dept Allocated Spend =
SUM ( fact_markdown_lift[allocated_spend] )
```

```dax
Dept Attributed Lift =
SUM ( fact_markdown_lift[attributed_lift] )
```

```dax
Dept Sales Lift per Dollar =
DIVIDE ( [Dept Attributed Lift], [Dept Allocated Spend] )
```

```dax
Actual YoY Lift =
SUM ( fact_dept_sales[yoy_lift_dollars] )
```

```dax
YoY Growth % =
DIVIDE ( SUM ( fact_dept_sales[yoy_lift_dollars] ), SUM ( fact_dept_sales[baseline_sales] ) )
```

**Why measures, not columns:** every ratio here (`DIVIDE`) recalculates correctly under any filter
or slicer, because it sums the numerator and denominator separately before dividing. A stored
ratio column would give the wrong answer the moment someone filters — this was deliberate in how
`06_powerbi_export.sql` was built, and it's why that file has no ratio columns for you to
accidentally drag onto a visual instead of a measure.

**Two totals per type.** `[Total Spend]` reads from `fact_markdown_spend` (store × type grain —
exact, no allocation). `[Dept Allocated Spend]` reads from `fact_markdown_lift` (store × dept ×
type grain — spend allocated by department's baseline sales share, an assumption, not a recorded
fact). Use `[Sales Lift per Dollar]` for the type-level scorecard page; use
`[Dept Sales Lift per Dollar]` only on the department drill-down page, with the caveat visible
(see page 3 below).

---

## 4. Pages to build

**Page 1 — Scorecard.** The headline. One table or matrix: `markdown_type` on rows,
`[Total Spend]`, `[Attributed Lift]`, `[Sales Lift per Dollar]`, `[Effectiveness Index]` as
columns. Conditional formatting (background color scale) on `Sales Lift per Dollar` — this is the
"colour-flagged best/worst" from the project brief. A bar chart of `[Sales Lift per Dollar]` by
`markdown_type`, sorted descending, makes the ranking readable at a glance.

**Page 2 — Store breakdown.** Matrix: `store_format` (from `dim_store`) on rows, `markdown_type`
on columns, `[Sales Lift per Dollar]` as values. A slicer on `store_format` (A/B/C) and one on
`size_band`. This answers whether the best type differs by store format — worth checking, since
`sql/03_effectiveness_by_store.sql` (query 03b) found it does vary.

**Page 3 — Department drill-down.** Table: `dept`, `[Dept Allocated Spend]`,
`[Dept Attributed Lift]`, `[Dept Sales Lift per Dollar]`. **Put a visible text box on this page**
stating the allocation caveat — department spend is allocated by baseline sales share, not
recorded per department (see `docs/methodology.md`). This page is the one place in the whole
report where that assumption enters; every other page uses exact figures.

**Page 4 — Holiday vs normal (optional, time permitting).** Bar chart comparing
`[Sales Lift per Dollar]` computed on `total_spend_holiday`/`attributed_lift` filtered to holiday
weeks vs normal weeks. `sql/02_effectiveness_by_markdown_type.sql` (query 02b) found Markdown
Type 2 flips from best-ranked to negative once holiday weeks are excluded — worth surfacing
visually if there's time, since it's one of the more interesting findings.

---

## 5. Publish

Power BI Desktop → **Publish** (needs a free Power BI account, sign up with any email if you don't
have one) → **File → Publish to web** on the published report gives a public embeddable link.
That link is what goes in the portfolio/README — it's the "linkable" requirement from the
original brief, and it demonstrates the actual hands-on Power BI skill the JD-type roles ask for,
which a static export wouldn't.

---

## Rebuilding the CSVs

If the SQL changes, regenerate the four files from `sql/06_powerbi_export.sql` against
`sql/walmart.db` and re-import in Power BI (Home → Refresh picks up the new data automatically
once the file paths match).
