"""Extract the two Main identity projections from the original pinned TLC data."""
import argparse
import json
from pathlib import Path
import sys

# Isolated Python omits the entry point's directory from its import path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_trace import framed, index, job_in, require, subset
from trace_input import read_pinned_raw

CASES = (
    ("DirectLong", "NoNewDomainLanded", "36337161d2e92515166a89d77c2e2b6555a75c438d5357f5f09eeaad4506e956"),
    ("ShortFirst", "NoProbe", "b2a70b23e5081d5ffcd7de42f074fa9583e2385ed050ed14d3540e738ce67075"),
)


def projection(path, case):
    script, outcome, digest = case
    trace = read_pinned_raw(path, digest, outcome)
    states, actions = framed(trace)
    end = states[-1]
    require(end["script"] == script, "wrong Main history")
    require(any(subset(a, "kind", "arg", "outcome") == ("Slot", "new", "accepted")
                for a in actions), "missing accepted new landing")
    history = index(end["history"], "number")
    recovery, anchor, ref = (history[n] for n in (141000, 141100, 141200))
    records = index(anchor["records"], "height")
    block = end["node"]["chain"][0]
    job = job_in(end, "new")
    require(subset(block, "g", "height", "anchor", "anchorID") == (1, 15, 141100, anchor["id"]),
            "wrong generation-1 first block")
    require(job["blocks"] == (block,) and job["ref"] == 141200 and job["refID"] == ref["id"],
            "wrong new block or reference")
    require(len(job["statement"]) == 19 and job["statement"][14] == ref["id"],
            "wrong statement reference")
    require((13 in records, records[14]["parent"]) ==
            ((True, 13) if script == "ShortFirst" else (False, 12)), "wrong Z checkpoint links")
    return {
        "script": script, "rawSha256": digest, "rawOutcome": trace.invariant,
        "terminalState": trace.frames[-1].index,
        "R141000": recovery["id"],
        "Z141100": {"id": anchor["id"], "checkpointHeights": sorted(records),
                    "record13Present": 13 in records, "record14Parent": records[14]["parent"]},
        "firstNewBlock": {key: block[key] for key in
                          ("tag", "g", "height", "anchor", "anchorID", "witness", "el", "comet", "root")},
        "reference141200": ref["id"],
        "newJob": {key: job[key] for key in ("id", "refID", "data", "blobs", "pair", "statement")},
    }


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("direct_long", type=Path)
    args.add_argument("short_first", type=Path)
    paths = args.parse_args()
    direct, short = (projection(path, case) for path, case in zip(
        (paths.direct_long, paths.short_first), CASES))
    labels = ("el", "comet", "root")
    expected = ("E15new", "K15new", "S15new")
    require(subset(direct["firstNewBlock"], *labels) == subset(short["firstNewBlock"], *labels)
            == expected, "first-block display labels do not coincide")
    require(direct["R141000"] != short["R141000"] and
            direct["Z141100"]["id"] != short["Z141100"]["id"] and
            direct["firstNewBlock"]["anchorID"] != short["firstNewBlock"]["anchorID"] and
            direct["reference141200"] != short["reference141200"] and
            direct["newJob"]["statement"] != short["newJob"]["statement"],
            "expected distinct branch-dependent identity structures")
    print(json.dumps({"schema": "etna-main-dual-identity-1", "histories": [direct, short]},
                     sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
