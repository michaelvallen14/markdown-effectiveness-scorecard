# Methodology — Trade Investment Effectiveness Scorecard

How the lift numbers are produced, what they assume, and how far they can be pushed.
Every figure quoted here is reproducible from the files in [`/sql`](../sql/), run in order.

---

## The question

Which markdown type returns the most sales lift per dollar invested — i.e. where should
next quarter's trade budget go? Not "do promotions work", but "which of these five earns
its spend".

---

## The problem that shaped everything else

The obvious design is: compare weeks when a markdown type ran against weeks when it
didn't, for the same store. **That design is not available in this dataset.**

Of the 2,340 store-weeks in the usable window:

| Markdown types running simultaneously | Store-weeks | Share |
|---|---|---|
| 0 | 45 | 1.9% |
| 1 | 5 | 0.2% |
| 2 | 81 | 3.5% |
| 3 | 179 | 7.6% |
| 4 | 658 | 28.1% |
| 5 | 1,372 | 58.6% |

Two consequences:

1. **There is no control group.** Only 45 store-weeks have zero markdown, and all 45 fall
   on a single date (2011-11-04, the first week of the window) — which looks like the start
   of markdown tracking rather than a genuine promotional pause.
2. **The types cannot be isolated by observation.** Nearly 59% of store-weeks run all five
   at once. Types 1 and 5 are active in 97% and 98% of store-weeks respectively, so for
   those two an on/off contrast is impossible even in principle.

Reproduce with [`00_window_and_coverage_checks.sql`](../sql/00_window_and_coverage_checks.sql), checks B1–B3.

---

## The window

**2011-11-04 to 2012-10-26 — 52 weeks, 45 stores, 2,340 store-weeks.**

MarkDown1–5 are 100% null for every month from Feb 2010 to Oct 2011, so the first 21 months
of the dataset carry no markdown signal and cannot serve as baseline weeks.

> **Date handling gotcha.** `Date` is stored as TEXT in `'YYYY-MM-DD 00:00:00'` form, so the
> upper bound must be exclusive: `Date < '2012-10-27'`. The natural-looking
> `Date <= '2012-10-26'` silently drops the final week, because `'2012-10-26 00:00:00'`
> sorts *after* `'2012-10-26'` under string comparison. This cost a week of data before it
> was caught.

---

## The baseline: same store, same department, same week, one year earlier

Since within-window baseline weeks don't exist, the baseline is `datetime(Date, '-364 days')`.
364 = 52 × 7, so the partner is the **same week-of-year**, not merely "about a year ago".

Three properties make this defensible, all verified in `00`, checks C1–C3:

- **Baselines are markdown-free by construction.** Every partner week falls in
  2010-11-05 – 2011-10-28, entirely inside the pre-markdown era.
- **Holiday weeks align exactly.** The holiday flag matches on all 52 week-pairs, 0
  disagreements — so the 4 holiday weeks are compared against holiday weeks.
- **Coverage is 97.1%.** 149,923 of 154,386 store-dept-weeks find a partner. The 2.9% that
  don't are new or discontinued departments, and are dropped.

---

## Assumptions, stated plainly

| # | Assumption | Why | Risk if wrong |
|---|---|---|---|
| 1 | `NULL` in MarkDown1–5 means "no markdown ran", i.e. $0 spend | Consistent with markdowns only being tracked from Nov 2011 | If nulls are unrecorded-but-real spend, all ratios are overstated |
| 2 | Negative markdown values are floored to $0 and treated as inactive | A negative denominator flips the sign of a per-dollar ratio | Negligible — 26 store-weeks total |
| 3 | Each week's lift is split across active types **pro-rata by spend share** | Types run concurrently, so lift cannot be assigned by observation | This is the weakest link; see below |
| 4 | Department spend is allocated by the department's share of **prior-year** sales | Spend is recorded per store-week, sales per store-dept-week. Baseline share is used so a department's own uplift doesn't inflate the spend it's charged | Department-level ROI is indicative only |

**On Assumption 3.** Pro-rata attribution assumes a dollar of any type is equally productive
within a given week — which is close to assuming the answer. It is a transparent allocation
convention, not a causal estimate. That is precisely why
[`05_marginal_intensity_check.sql`](../sql/05_marginal_intensity_check.sql) re-tests the ranking
by a method that makes no such assumption.

**On naming.** MarkDown1–5 are anonymised dollar amounts. They are labelled "Markdown Type
1–5" throughout; mapping them to real mechanics (multibuy, clearance, catalogue) would be
invention.

---

## The drift problem — why absolute ROI can't be claimed

A year-on-year baseline captures the markdown effect **plus everything else that changed in
a year**: inflation, store maturation, macro conditions.

- Full window YoY growth: **+2.29%**
- YoY growth on the only markdown-free week: **+6.27%**

The underlying drift may therefore be *larger* than the total measured growth. Charging the
full 6.27% against the baseline ($153M on a $2.44bn base, against $56M of measured growth)
turns every type negative.

That adjustment is not evidence, for two reasons. It rests on **one calendar week** across 45
stores. And it is structurally unfair between types: the drift charge scales with the
*baseline sales* of the weeks a type ran in, while the ratio divides by that type's *spend* —
so a cheap type is penalised hardest simply for being cheap.

**Conclusion drawn, and its limit:** this dataset supports a **relative ranking** between the
five types. It does **not** support a claim that the markdown programme is incremental in
absolute terms. The `net_lift_per_dollar_sensitivity` column in `02` is reported as a stress
test, deliberately not as the ranking metric.

---

## Two independent methods, and where they disagree

### Method A — pro-rata attribution (`02`)
Split each store-week's YoY lift across the types running that week, weighted by each type's
share of that week's markdown spend. Divide by spend.

### Method B — within-store marginal intensity (`05`)
Because the types are almost always on, the usable contrast is not *"did this type run?"* but
*"did this store spend heavily on it this week, or barely?"* For each store × type, split the
52 weeks into spend tertiles, then:

```
bottom-tertile YoY growth = the store's own trend when this type runs lightest
incremental sales         = top-tertile sales − top-tertile baseline × (1 + bottom growth)
incremental spend         = top-tertile spend − bottom-tertile spend
marginal lift per dollar  = incremental sales / incremental spend
```

This is a within-store difference-in-differences. **Drift cancels**, because each store is
compared against itself — fixing exactly the weakness that makes Method A's drift adjustment
unreliable. And nothing is split across types, so Assumption 3 is not used.

### The comparison

| Markdown type | A: lift per $ | A: rank | B: marginal per $ | B: rank | B ex-holiday | Stores positive (of 45) |
|---|---|---|---|---|---|---|
| Type 1 | 1.34 | 3 | 1.85 | 2 | 2.06 | 38 |
| Type 2 | **1.72** | **1** | 1.04 | 4 | **−0.48** | 26 |
| Type 3 | −0.18 | 5 | −1.73 | 5 | −27.10 | 16 |
| Type 4 | 1.10 | 4 | 1.74 | 3 | **2.31** | 30 |
| Type 5 | 1.60 | 2 | 1.92 | 1 | 2.03 | 33 |

**Where they agree — the safe conclusions:**
- **Type 3 fails under every method.** Negative on both, worst-ranked on both, and positive in
  only 16 of 45 stores. It also spends 87% of its budget in holiday weeks and still returns
  0.25 per dollar there. This is the clear cut candidate.
- **Types 1 and 5 are the robust year-round performers.** Both rank top-3 on both methods and
  are positive in 38 and 33 stores respectively.

**Where they disagree — and what it means:**
- **Type 2 is the interesting case.** It ranks #1 under Method A but only #4 under Method B,
  and goes *negative* once holiday weeks are excluded. Its strength is holiday-specific:
  2.59 per dollar in holiday weeks versus 1.19 in normal weeks, with 37% of its spend
  concentrated in 4 weeks. Type 2 is a seasonal lever, not a year-round one — and the
  headline ranking alone would have got this wrong.
- **Type 4 is underrated by Method A.** Ranked 4th on pro-rata attribution but 1st on the
  non-holiday marginal contrast (2.31).

**Remaining confound.** Heavy-spend weeks for one type tend to be heavy for all types.
`05c` quantifies this: in a type's top-spend weeks, an average of 1.4–1.75 *other* types are
also at high intensity. Type 1 is the most confounded (1.75 others, alone in only 11.5% of its
heavy weeks), so its strong Method B showing should carry the widest error bar.

---

## Integrity checks

All grains reconcile exactly:

| Check | Result |
|---|---|
| Total markdown spend — raw `features` vs `v_markdown_long` vs store×type grain | $40,333,595.91, identical |
| Attributed lift — type grain vs store×dept×type grain | $52,936,998.66, identical |
| Allocated department spend vs exact store spend | $40,333,595.91, reconstructs exactly |
| Lift decomposition | $52,936,998.66 (markdown weeks) + $2,868,322.66 (zero-markdown weeks) = $55,805,321.32 total YoY lift |

---

## Known limitations

1. **No true control group.** The strongest available design is within-store
   difference-in-differences; a holdout store group would be far better and does not exist here.
2. **Absolute incrementality is unproven** — only the relative ranking is supported.
3. **Type co-activity** means no estimate fully isolates a single type.
4. **Department-level figures rest on an allocation**, not recorded spend. Replacing this with
   a real line-item trade calendar is the single biggest upgrade available to the analysis.
5. **One year of markdown data.** No ability to test whether the ranking is stable across years.
6. **Sales, not margin.** Lift is measured in revenue. A markdown that shifts volume at a lower
   margin can post strong sales lift while destroying profit — with cost-of-goods data the
   right metric would be gross-margin lift per dollar.

---

## Reproducing

```bash
python scripts/build_db.py                    # needs the Kaggle CSVs in data_raw/
sqlite3 sql/walmart.db < sql/01_create_views.sql
sqlite3 sql/walmart.db < sql/02_effectiveness_by_markdown_type.sql
```

Files run in order: `00` (checks) → `01` (views, run once) → `02`–`06` (analysis, any order).

*Data source: [Walmart Recruiting — Store Sales Forecasting](https://www.kaggle.com/c/walmart-recruiting-store-sales-forecasting), Kaggle.*
