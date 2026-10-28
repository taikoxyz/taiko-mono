#!/usr/bin/env python3
"""S3 F8: the break-even blob base fee, derived and checked.

F8 reported "Break-even blob base fee, holding execution cost at the sampled-hour
value: 1,069,729,806 wei" but no script in this directory computed it and the
reviewer's three reconstructions (1.048e9 / 0.949e9 / 0.222e9 wei) did not match.

The rule that reproduces it exactly: hold the sampled hour's *execution* cost
(propose cost minus the transaction's own blob line) and ask at what blob base
fee the remaining L2 fee revenue is exactly consumed by the 8 batches' blob gas:

    f* = [ sum_8(L2 fees) - sum_8(propose cost - blob cost) ] / (8 x 131,072)

The three reconstructions differ because they subtracted propose-cost-including-
blob (1.048e9), or used only L2 base fees (0.949e9), or subtracted the full L1
total including amortised proving (0.222e9).

Reads coverage-metrics.csv, join-metrics.csv, propose-metrics.csv.
Writes blob-breakeven.json.  Usage: python3 blob_breakeven.py
"""
import csv, json

GAS_PER_BLOB = 131072


def main():
    cov = list(csv.DictReader(open("coverage-metrics.csv")))
    jm = {int(r["proposalId"]): r for r in csv.DictReader(open("join-metrics.csv"))}
    rows = []
    for c in cov:
        j = jm[int(c["proposalId"])]
        rows.append({
            "proposalId": int(c["proposalId"]), "l1_block": int(j["l1_block"]),
            "l2_fees_eth": float(c["l2_fee_total_eth"]),
            "l2_base_fees_eth": float(c["l2_base_fee_eth"]),
            "propose_total_eth": float(j["l1_cost_eth"]),
            "blob_cost_eth": float(j["l1_blob_eth"]),
            "propose_exec_eth": float(j["l1_cost_eth"]) - float(j["l1_blob_eth"]),
        })
    fees = sum(r["l2_fees_eth"] for r in rows)
    base = sum(r["l2_base_fees_eth"] for r in rows)
    exec_ = sum(r["propose_exec_eth"] for r in rows)
    propose = sum(r["propose_total_eth"] for r in rows)
    blob_gas = len(rows) * GAS_PER_BLOB
    out = {
        "n_batches": len(rows),
        "blob_gas": blob_gas,
        "l2_fees_eth": fees, "l2_base_fees_eth": base,
        "l1_propose_total_eth": propose, "l1_propose_exec_only_eth": exec_,
        "residual_all_fees_eth": fees - exec_,
        "break_even_blob_base_fee_wei": (fees - exec_) * 1e18 / blob_gas,
        "rows": rows,
    }
    json.dump(out, open("blob-breakeven.json", "w"), indent=1)
    print("8 batches: L2 fees %.12f ETH, propose total %.12f, propose exec-only %.12f, blob %.12f" %
          (fees, propose, exec_, propose - exec_))
    print("residual after execution = %.12f ETH over %d blob gas" % (fees - exec_, blob_gas))
    print("break-even blob base fee = %.3f wei/blob-gas = %.4f gwei" %
          (out["break_even_blob_base_fee_wei"], out["break_even_blob_base_fee_wei"] / 1e9))
    print()
    print("reconstructions that do NOT match (for the record):")
    print("  all fees - propose total          : %.0f wei" % ((fees - propose) * 1e18 / blob_gas))
    print("  base fees only - propose total    : %.0f wei" % ((base - propose) * 1e18 / blob_gas))
    print("  all fees - (propose total + amortised prove): %.0f wei" %
          ((fees - propose - 8 * 0.00010835572739617461) * 1e18 / blob_gas))


if __name__ == "__main__":
    main()
