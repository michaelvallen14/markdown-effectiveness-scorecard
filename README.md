# Markdown Type Effectiveness Scorecard

**Portfolio project — Data Analyst track, targeting retail/FMCG "Insights & Automation Analyst" type roles.**

## Why this project

Roles in this category — retail/FMCG insights and automation analyst positions — typically ask for: hands-on Power BI dashboard building, supplier/productivity scorecards and performance reporting, analysis of **promotional effectiveness and trade investment**, strong Excel, SQL as a desirable, Power Query/Power Automate as desirable, and genuine interest in using Copilot/Claude to work smarter. This project is built to demonstrate each of those directly.

## Research question

Which markdown/promotion category drives the most sales lift **per dollar (or per active week) of markdown investment** — i.e. where should next quarter's trade/promo budget go? Not "do promotions work" — which category is worth the investment, i.e. trade investment effectiveness.

## Dataset — RESOLVED: Walmart Recruiting - Store Sales Forecasting (Kaggle competition)

Confirmed by loading the real files (31 Aug 2026), not just documentation. Full detail in `docs/schema_notes.md`; summary:

- `train.csv` (421,570 rows): Store, Dept, Date, Weekly_Sales, IsHoliday. 45 stores, 81 departments, 2010-02-05 to 2012-10-26.
- `features.csv` (8,190 rows): Store, Date, Temperature, Fuel_Price, MarkDown1-5, CPI, Unemployment, IsHoliday.
- `stores.csv` (45 rows): Store, Type (A/B/C), Size.
- Join on (Store, Date) verified clean — 0 unmatched rows, 0 IsHoliday mismatches between train and features.
- **Important constraint:** MarkDown1-5 are 100% null before Nov 2011, and unevenly populated after. The real usable comparison window is **Nov 2011 – Oct 2012 (~12 months)**, not the full dataset span — see `docs/schema_notes.md` for the month-by-month null rates and the NULL-handling assumption used.
- MarkDown1-5 are anonymized dollar amounts, not named promo types — the scorecard compares "Markdown Type 1" vs "Type 2" etc., not labelled categories like "BOGO" or "clearance."

Rejected candidates (see git history for the original reasoning): the Australian retail dataset (unverified, likely no store/promo granularity) and the plain `yasserh/walmart-dataset` (confirmed missing Dept and MarkDown fields entirely).

`sql/walmart.db` (SQLite, gitignored — rebuild locally with `python scripts/build_db.py` after downloading the CSVs into `data_raw/`) has all three tables loaded and indexed on (Store, Date), ready for the lift-calculation SQL.

## Timeline

Target finish: **24 Sep 2026** (4 weeks from 27 Aug).

- [x] Dataset finalised, downloaded, schema explored, markdown fields identified
- [x] VS Code + SQLite extension, SQLite db built and verified
- [x] Git repo + GitHub
- [x] SQL — cleaning, joins, per-type lift calculations (`/sql`, see Results below)
- [ ] Power BI scorecard dashboard
- [ ] Excel pivot summary
- [ ] Written findings + polish

## What gets built

1. VS Code + SQLite: import the CSV(s), explore tables/columns, identify markdown/promo fields.
2. `.sql` files (see `/sql`): per markdown category, sales during active weeks vs baseline non-markdown weeks, normalized per dollar of spend (or per active week if $ isn't usable), broken down by store and department. Commit as you go.
3. Power BI dashboard (see `/powerbi`): scorecard ranking markdown categories by effectiveness, store/department breakdown, colour-flagged best/worst.
4. Excel pivot summary (see `/excel`): one page, same ranking.
5. Written findings (see `/docs/findings.md`): 3-4 sentences — which category earns its spend, which doesn't, what to cut/double down on. Note the use of Claude/Copilot in writing the SQL/DAX.

## Notes on the open questions

- **Claude Code in VS Code:** yes, there's an official Claude Code VS Code extension (code.claude.com/docs/en/vs-code) — install it and it runs alongside/inside the editor.
- **GitHub repo:** this scaffold is the starting point. Actually creating and pushing to a GitHub repo needs your own git/GitHub auth, which isn't available from this sandboxed session — see the setup commands below.
- **Live dashboard — Power BI vs. a Claude-built artifact:** this type of role typically names Power BI explicitly as a required, hands-on skill. A Claude/HTML artifact doesn't demonstrate that skill and shouldn't replace the Power BI deliverable. Power BI Desktop's free "Publish to web" (or a Power BI service embed) gives a shareable public link for the portfolio, which solves the "linkable" requirement without needing a substitute tool. An HTML/artifact version could be a nice-to-have companion later, but it's not a substitute for Power BI here.

## Local setup

```bash
cd markdown-effectiveness-scorecard
git init
git add .
git commit -m "Initial project scaffold"
git remote add origin <your-new-github-repo-url>
git branch -M main
git push -u origin main
```
