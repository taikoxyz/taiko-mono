#!/usr/bin/env python3
"""S3: Kraken ETH/USD window statistics and the REWARD_QUOTE USD range.

The report's §2.2 read "Hourly closes covering the window: min $2,561, median
$2,696, max $2,755".  The fetched series is 182 hours (through 2026-10-07T13:00Z);
the $2,561.15 close is at 2026-10-07T13:00Z, 13 h *after* the census window ends
(2026-10-07T00:00:11Z).  This script separates the whole fetched series from the
168 in-window hours and recomputes the USD range of the 0.0002146 ETH REWARD_QUOTE
floor from in-window prices, and for the 8 fully-covered sampled batches at their
own hour's close (the same usd_at() rule analyze_l1.py uses).

Reads kraken-ethusd-hourly.json, coverage-metrics.csv, join-metrics.csv,
propose-metrics.csv.  Writes kraken-window-stats.json.
Usage: python3 kraken_window_stats.py
"""
import csv, json, statistics

WIN_START, WIN_END = 1790726400, 1791331200   # window.json: 2026-09-30T00:00Z - 2026-10-07T00:00Z
FLOOR_ETH = 0.0002146322352424301              # coverage-summary.json aggregate l1_total_eth / 8 batches


def main():
    res = json.load(open("kraken-ethusd-hourly.json"))["result"]
    pair = [k for k in res if k != "last"][0]
    series = {int(r[0]): float(r[4]) for r in res[pair]}
    win = {t: c for t, c in series.items() if WIN_START <= t < WIN_END}

    def stats(d):
        cs = sorted(d.values())
        return {"n": len(cs), "min": cs[0], "median": statistics.median(cs), "max": cs[-1]}

    out = {
        "pair": pair,
        "fetched_series": stats(series),
        "in_window_hours": stats(win),
        "window_ts": [WIN_START, WIN_END],
        "out_of_window_extremes": {
            t: c for t, c in series.items() if c == min(series.values())
        },
        "reward_quote_floor_eth": FLOOR_ETH,
        "floor_usd_in_window": [FLOOR_ETH * min(win.values()), FLOOR_ETH * max(win.values())],
    }

    # the 8 sampled batches at their own hour's close
    pm = {r["hash"]: r["ts"] for r in csv.DictReader(open("propose-metrics.csv"))}
    jm = {int(r["proposalId"]): r for r in csv.DictReader(open("join-metrics.csv"))}
    cov = list(csv.DictReader(open("coverage-metrics.csv")))
    batches = []
    for c in cov:
        j = jm[int(c["proposalId"])]
        # the 8 sampled batches all have headers; fall back to the L2 batch ts if not
        ts = int(pm[j["l1_tx"]]) if pm[j["l1_tx"]] != "None" else int(j["ts_first"])
        h = ts - (ts % 3600)
        price = series.get(h) or series.get(h - 3600) or series.get(h + 3600)
        l1_total = float(c["l1_total_eth"])
        batches.append({"proposalId": int(c["proposalId"]), "l1_block": int(j["l1_block"]),
                        "ts": ts, "hour": h, "price_usd": price, "l1_total_eth": l1_total,
                        "l1_total_usd": l1_total * price})
    out["sampled_batches"] = batches
    out["sampled_batches_usd_range"] = [min(b["l1_total_usd"] for b in batches),
                                        max(b["l1_total_usd"] for b in batches)]
    out["sampled_batches_price_usd"] = sorted({b["price_usd"] for b in batches})
    json.dump(out, open("kraken-window-stats.json", "w"), indent=1)

    print("fetched series  n=%d  min %.2f median %.2f max %.2f" % (
        out["fetched_series"]["n"], out["fetched_series"]["min"], out["fetched_series"]["median"],
        out["fetched_series"]["max"]))
    print("in-window hours n=%d  min %.2f median %.2f max %.2f" % (
        out["in_window_hours"]["n"], out["in_window_hours"]["min"], out["in_window_hours"]["median"],
        out["in_window_hours"]["max"]))
    print("out-of-window series minimum close(s):", out["out_of_window_extremes"])
    print("REWARD_QUOTE floor 0.0002146 ETH = $%.3f - $%.3f at in-window closes" %
          (out["floor_usd_in_window"][0], out["floor_usd_in_window"][1]))
    print("8 sampled batches: prices %s USD range $%.4f - $%.4f" % (
        out["sampled_batches_price_usd"], out["sampled_batches_usd_range"][0], out["sampled_batches_usd_range"][1]))


if __name__ == "__main__":
    main()
