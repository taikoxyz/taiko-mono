#!/usr/bin/env python3
"""S4 F8: highest non-zero 32-byte word (used prefix) for the four sampled blobs.

F8 reported "the highest non-zero 32-byte word is element 148 or lower, so the
used prefix is at most 4,768 bytes", but no artifact in this directory computed
the element index at all (the figure had no supporting script).  This script
supplies the missing derivation: it re-fetches the four beacon blob sidecars
(blocks 26,140,617 / 26,140,649 / 26,140,681 / 26,140,714; sidecar at the
transaction's own blob index), reads the blob bytes, and reports

  * nonzeroBytesInBlob / nonzeroFraction  (cross-check against blob-content.json)
  * blobSha256                            (cross-check against blob-content.json)
  * highestNonzeroWordIndex (0-based over the 4096 32-byte words)
  * usedPrefixBytes = (highestNonzeroWordIndex + 1) * 32

Usage:
    python3 sidecar_word_prefix.py .            # fetch live, write the JSON + trimmed sidecars
    python3 sidecar_word_prefix.py . --offline  # recompute from sidecars/ saved below

Requires curl for the fetch step (the python urllib path fails TLS verification
on the collector's system python; curl is used exactly as COMMANDS.md does).
Writes: blob-word-prefix.json (the figure table) and
        sidecars/slot-<slot>-index-<i>.json (the selected sidecar, verbatim).
"""
import hashlib, json, os, subprocess, sys

BYTES_PER_BLOB = 131072
WORDS_PER_BLOB = BYTES_PER_BLOB // 32
BEACON = "https://ethereum-beacon-api.publicnode.com"

# (execution block, slot, blob index in block, tx hash) -- from blob-content.json
SAMPLES = [
    (26140617, 15379448, 0,  "0x5a6dd687ce4f70d962d5de3bc2c649eccf61785328f9d2ad8b9523e4291c6ccb"),
    (26140649, 15379480, 0,  "0xd22898fdd9fcfd39431c377163a40a390c1dc6fe3c4cf194f3c34097165e1805"),
    (26140681, 15379512, 19, "0x198ddd408aa514f8aa8d0b649fc35838fadc7e9a1fa0b46818778b3fa8824939"),
    (26140714, 15379545, 2,  "0x4b21e840ca73be6b1a650abc3f199e79071a4b03f936ab703d3d57f94e43d94e"),
]


def fetch(url, path):
    subprocess.run(["curl", "-sS", "-m", "60", "--retry", "3", "--retry-delay", "2",
                    "-A", "Mozilla/5.0 (s4-public-data-collection)", url, "-o", path], check=True)


def highest_nonzero_word(blob):
    """Return the 0-based index of the last 32-byte word containing a non-zero byte."""
    for i in range(WORDS_PER_BLOB - 1, -1, -1):
        if any(blob[i * 32:(i + 1) * 32]):
            return i
    return -1  # all-zero blob


def main(outdir, offline=False):
    os.makedirs(os.path.join(outdir, "sidecars"), exist_ok=True)
    out = []
    for blk, slot, idx, tx in SAMPLES:
        saved = os.path.join(outdir, "sidecars", f"slot-{slot}-index-{idx}.json")
        if offline or not os.path.exists(saved):
            raw = os.path.join(outdir, "sidecars", f"_raw-{slot}.json")
            fetch(f"{BEACON}/eth/v1/beacon/blob_sidecars/{slot}", raw)
            d = json.load(open(raw))
            side = {int(s["index"]): s for s in d.get("data", [])}
            if idx not in side:
                raise SystemExit(f"slot {slot}: no sidecar at index {idx}")
            json.dump(side[idx], open(saved, "w"))
            os.remove(raw)  # keep only the sidecar this figure is derived from
        s = json.load(open(saved))
        blob = bytes.fromhex(s["blob"][2:])
        assert len(blob) == BYTES_PER_BLOB, len(blob)
        nz = sum(1 for x in blob if x)
        wi = highest_nonzero_word(blob)
        rec = {
            "block": blk, "slot": slot, "blobIndexInBlock": idx, "txHash": tx,
            "versionedHash": "0x01" + hashlib.sha256(bytes.fromhex(s["kzg_commitment"][2:])).hexdigest()[2:],
            "blobBytes": len(blob),
            "nonzeroBytesInBlob": nz,
            "nonzeroFraction": round(nz / BYTES_PER_BLOB, 6),
            "blobSha256": hashlib.sha256(blob).hexdigest(),
            "highestNonzeroWordIndex": wi,
            "usedPrefixBytes": (wi + 1) * 32,
            "trailingWordsAllZero": all(not any(blob[j * 32:(j + 1) * 32])
                                        for j in range(wi + 1, WORDS_PER_BLOB)),
        }
        out.append(rec)
        print(json.dumps(rec), flush=True)
    summary = {
        "note": "highestNonzeroWordIndex is 0-based over the 4096 32-byte words of the 131,072-byte blob; "
                "usedPrefixBytes = (index + 1) * 32 is the smallest prefix containing every non-zero byte.",
        "maxHighestNonzeroWordIndex": max(r["highestNonzeroWordIndex"] for r in out),
        "maxUsedPrefixBytes": max(r["usedPrefixBytes"] for r in out),
        "records": out,
    }
    json.dump(summary, open(os.path.join(outdir, "blob-word-prefix.json"), "w"), indent=1)
    print("\nMAX highestNonzeroWordIndex =", summary["maxHighestNonzeroWordIndex"],
          "-> max usedPrefixBytes =", summary["maxUsedPrefixBytes"])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".", offline="--offline" in sys.argv)
