"""
Rebuilds sql/walmart.db from the raw Kaggle CSVs (train.csv, features.csv, stores.csv).
Expects the three CSVs in data_raw/ (gitignored — download from the Kaggle competition
page: kaggle.com/c/walmart-recruiting-store-sales-forecasting/data).
"""
import pandas as pd
import sqlite3
from pathlib import Path

RAW = Path(__file__).parent.parent / "data_raw"
DB = Path(__file__).parent.parent / "sql" / "walmart.db"

def main():
    train = pd.read_csv(RAW / "train.csv", parse_dates=["Date"])
    features = pd.read_csv(RAW / "features.csv", parse_dates=["Date"])
    stores = pd.read_csv(RAW / "stores.csv")

    conn = sqlite3.connect(DB)
    train.to_sql("train", conn, if_exists="replace", index=False)
    features.to_sql("features", conn, if_exists="replace", index=False)
    stores.to_sql("stores", conn, if_exists="replace", index=False)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_train_store_date ON train(Store, Date)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_features_store_date ON features(Store, Date)")
    # The lift SQL joins train to itself on (Store, Dept, Date) to pull the
    # prior-year baseline week. Without this the self-join degrades to a scan
    # per row and the scorecard queries take minutes instead of seconds.
    conn.execute("CREATE INDEX IF NOT EXISTS idx_train_store_dept_date ON train(Store, Dept, Date)")
    conn.commit()
    conn.close()
    print(f"Built {DB} — train:{len(train)} features:{len(features)} stores:{len(stores)}")

if __name__ == "__main__":
    main()
