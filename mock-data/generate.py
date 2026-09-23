"""
Generate mock e-commerce dataset as Parquet files.

Tables:
    customers     ~50K
    products      ~5K
    orders        ~500K
    order_items   ~2M

Usage:
    pip install -r requirements.txt
    python generate.py --out ./output
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

RNG = np.random.default_rng(seed=42)

# ---------- reference data ----------

COUNTRIES = ["TR", "DE", "US", "UK", "FR", "NL", "IT", "ES", "PL", "SE"]
COUNTRY_WEIGHTS = [0.22, 0.16, 0.14, 0.10, 0.09, 0.07, 0.07, 0.06, 0.05, 0.04]

SEGMENTS = ["new", "returning", "vip"]
SEGMENT_WEIGHTS = [0.55, 0.35, 0.10]

CATEGORIES = ["electronics", "apparel", "home", "beauty", "books", "sports", "toys", "food"]
CATEGORY_WEIGHTS = [0.20, 0.22, 0.13, 0.10, 0.08, 0.10, 0.07, 0.10]

STATUSES = ["completed", "cancelled", "refunded"]
STATUS_WEIGHTS = [0.85, 0.10, 0.05]

BRANDS = [f"brand_{i:03d}" for i in range(50)]


# ---------- generators ----------

def gen_customers(n: int) -> pd.DataFrame:
    today = datetime.utcnow().date()
    signup_offset_days = RNG.integers(0, 365 * 3, size=n)
    return pd.DataFrame({
        "customer_id": np.arange(1, n + 1, dtype=np.int64),
        "country": RNG.choice(COUNTRIES, size=n, p=COUNTRY_WEIGHTS),
        "signup_date": [today - timedelta(days=int(d)) for d in signup_offset_days],
        "segment": RNG.choice(SEGMENTS, size=n, p=SEGMENT_WEIGHTS),
    })


def gen_products(n: int) -> pd.DataFrame:
    # Lognormal prices: most cheap, few expensive.
    list_price = np.round(RNG.lognormal(mean=3.2, sigma=0.9, size=n), 2)
    list_price = np.clip(list_price, 1.99, 4999.0)
    return pd.DataFrame({
        "product_id": np.arange(1, n + 1, dtype=np.int64),
        "category": RNG.choice(CATEGORIES, size=n, p=CATEGORY_WEIGHTS),
        "brand": RNG.choice(BRANDS, size=n),
        "list_price": list_price.astype(np.float64),
    })


def gen_order_timestamps(n: int, days: int) -> np.ndarray:
    """Random order timestamps over last `days` with weekend peak + diurnal pattern."""
    end = datetime.utcnow().replace(microsecond=0)
    start = end - timedelta(days=days)

    # Pick a day, weighted: Sat/Sun ~1.5x weekdays.
    day_weights = np.array([1.0, 1.0, 1.0, 1.0, 1.2, 1.5, 1.5])  # Mon..Sun
    day_offsets = np.arange(days)
    weekday_of_offset = np.array([
        (start + timedelta(days=int(d))).weekday() for d in day_offsets
    ])
    p_day = day_weights[weekday_of_offset]
    p_day = p_day / p_day.sum()
    chosen_days = RNG.choice(day_offsets, size=n, p=p_day)

    # Hour weights: low at night, peak around 12 and 20.
    hour_weights = np.array([
        0.2, 0.1, 0.1, 0.1, 0.1, 0.2, 0.4, 0.7,
        1.0, 1.2, 1.3, 1.4, 1.5, 1.4, 1.3, 1.3,
        1.4, 1.5, 1.6, 1.7, 1.6, 1.3, 0.9, 0.5,
    ])
    p_hour = hour_weights / hour_weights.sum()
    chosen_hours = RNG.choice(np.arange(24), size=n, p=p_hour)
    chosen_minutes = RNG.integers(0, 60, size=n)
    chosen_seconds = RNG.integers(0, 60, size=n)

    base = np.array([start + timedelta(days=int(d)) for d in chosen_days])
    return np.array([
        b.replace(hour=int(h), minute=int(m), second=int(s))
        for b, h, m, s in zip(base, chosen_hours, chosen_minutes, chosen_seconds)
    ])


def gen_orders(n: int, customers: pd.DataFrame, days: int) -> pd.DataFrame:
    # Returning/vip customers order more often.
    seg_weight = customers["segment"].map({"new": 1.0, "returning": 2.5, "vip": 6.0}).to_numpy()
    p_customer = seg_weight / seg_weight.sum()
    customer_ids = RNG.choice(customers["customer_id"].to_numpy(), size=n, p=p_customer)

    return pd.DataFrame({
        "order_id": np.arange(1, n + 1, dtype=np.int64),
        "customer_id": customer_ids.astype(np.int64),
        "order_ts": gen_order_timestamps(n, days),
        "status": RNG.choice(STATUSES, size=n, p=STATUS_WEIGHTS),
    })


def gen_order_items(orders: pd.DataFrame, products: pd.DataFrame, target_rows: int) -> pd.DataFrame:
    # Items per order: 1..8, mean ~4.
    n_orders = len(orders)
    items_per_order = RNG.integers(1, 9, size=n_orders)
    # Scale to roughly hit target_rows.
    scale = target_rows / items_per_order.sum()
    if scale < 1:
        # Trim by sampling some orders to have fewer items.
        items_per_order = np.maximum(1, (items_per_order * scale).round().astype(int))

    order_ids = np.repeat(orders["order_id"].to_numpy(), items_per_order)
    total = len(order_ids)

    product_ids = RNG.choice(products["product_id"].to_numpy(), size=total)
    product_price_lookup = products.set_index("product_id")["list_price"]
    unit_price = product_price_lookup.loc[product_ids].to_numpy()
    # Small noise around list price.
    unit_price = np.round(unit_price * RNG.uniform(0.95, 1.05, size=total), 2)

    quantity = RNG.integers(1, 6, size=total).astype(np.int32)

    # Discount: 60% no discount, 40% in [5..30]%.
    discount = np.where(
        RNG.random(total) < 0.6,
        0.0,
        np.round(RNG.uniform(0.05, 0.30, size=total), 2),
    )

    return pd.DataFrame({
        "order_id": order_ids.astype(np.int64),
        "product_id": product_ids.astype(np.int64),
        "quantity": quantity,
        "unit_price": unit_price.astype(np.float64),
        "discount_pct": discount.astype(np.float64),
    })


# ---------- main ----------

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="./output", help="Output directory")
    parser.add_argument("--customers", type=int, default=50_000)
    parser.add_argument("--products", type=int, default=5_000)
    parser.add_argument("--orders", type=int, default=500_000)
    parser.add_argument("--items", type=int, default=2_000_000, help="Target row count for order_items")
    parser.add_argument("--days", type=int, default=90, help="Days of order history")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    print(f"Generating customers ({args.customers:,})...")
    customers = gen_customers(args.customers)
    customers.to_parquet(out / "customers.parquet", index=False)

    print(f"Generating products ({args.products:,})...")
    products = gen_products(args.products)
    products.to_parquet(out / "products.parquet", index=False)

    print(f"Generating orders ({args.orders:,})...")
    orders = gen_orders(args.orders, customers, args.days)
    # pandas datetime64 defaults to nanosecond precision, which pyarrow then
    # writes as Parquet TIMESTAMP(NANOS) — a type Spark's Parquet reader
    # rejects (PARQUET_TYPE_ILLEGAL). Coerce to microseconds on write instead.
    orders.to_parquet(
        out / "orders.parquet", index=False,
        coerce_timestamps="us", allow_truncated_timestamps=True,
    )

    print(f"Generating order_items (target {args.items:,})...")
    order_items = gen_order_items(orders, products, args.items)
    order_items.to_parquet(out / "order_items.parquet", index=False)

    print("\nDone. Row counts:")
    for name, df in [
        ("customers", customers),
        ("products", products),
        ("orders", orders),
        ("order_items", order_items),
    ]:
        size_mb = (out / f"{name}.parquet").stat().st_size / 1024 / 1024
        print(f"  {name:12s} {len(df):>10,} rows   {size_mb:>6.1f} MB")


if __name__ == "__main__":
    main()
