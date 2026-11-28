"""Replay complete bounded repeated-recovery traces against the current rules."""

import hashlib
import json
from pathlib import Path
import re

from boundary_scope import require_healthy_native, require_tlc_argv, reviewed_boundary
from current_settlement import Context, capture, land, word
from current_spec import _unique_object
from proving_recovery import FOOTER, STATE, blob, raw_cut, same, trace_packets
from timestamp_recovery import Authorization, Origin, Schedule, State, candidate, invalidate, recover, select_rule

CLAIM = "repeated-recovery"
GENESIS_CUTOFF = 24
MODULE = "EtnaRepeatedRecovery.tla"
TLC_CWD = "/tmp/etna-model"
TLC_BANNER = "TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)"
INVARIANTS = {
    "smoke": "NoSmoke", "progress": "NoProgress", "stale-nonce": "NoStaleNonce",
    "old-generation": "NoOldGeneration", "r1-only": "NoR1Only",
}
CONTROLS = {"origin-overwrite", "missing-bootstrap"}
KINDS = ("advance", "finalize", "invalidate", "recover", "observe", "produce", "capture", "land")
GENESIS_CUT, BASE_CUT = (0, 100, 0, 0), (6, 106, 206, 4)
PENDING, PRESERVED, REPLACED = (0, 1, 1397, 1394), (0, 1, 1397, 0), (2, 2, 0, 0)
SUPPORTED = frozenset({0, 1, 2})


def _require(valid, message):
    if not valid:
        raise ValueError(message)


def _l1_time(number):
    return number + 69


def _origin(generation, height, number, rule):
    return dict(generation=generation, height=height, number=number, time=_l1_time(number),
                rule=rule, domain=100 + generation)


def _bootstrap(origin, cut, state_root):
    return dict(origin, initialHeight=cut[0] + 1, el=cut[1], stateRoot=state_root, fi=cut[3])


def _authority(generation, nonce, rules):
    return dict(generation=generation, checkpoint=6, nonce=nonce, validUntil=107, rules=rules,
                owner=True, exclusions=(), fiToClear=())


def _block(generation, cut, bft, timestamp, anchor, anchor_cut, schedule, rule, previous):
    return dict(generation=generation, domain=100 + generation, cut=cut, stateRoot=400 + cut[1],
                bftTime=bft, elTime=timestamp, anchor=anchor, anchorCut=anchor_cut, schedule=schedule,
                rule=rule, lastBlockID=previous,
                lastCommit=() if previous == () else (generation, previous))


def _landing(generation, parent, block, reference, snapshot, cut, state_root):
    return dict(generation=generation, parentHeight=parent, number=block, reference=reference,
                activeSnapshot=snapshot,
                cut=cut, stateRoot=state_root)


def _initial():
    prefix = tuple(_block(0, (h, 100 + h, 200 + h, min(h, 4)), 93 + h, 94 + h, 24 + h,
                          GENESIS_CUT, (0, 0, 0, 0) if h <= 4 else PENDING, 0,
                          () if h == 1 else 199 + h) for h in range(1, 7))
    origin = _origin(0, 0, 25, 0)
    return dict(generation=0, nonce=0, c=6, head=6, fiHead=4, activeSnapshot=GENESIS_CUTOFF, l1=31,
                finalized=31, produces=0, schedule=PENDING, origins=(origin,),
                authBank=(_authority(0, 0, 0), _authority(0, 1, 0), _authority(1, 2, 2)),
                canonical=prefix, records=(_landing(0, 0, 31, 30, GENESIS_CUTOFF, BASE_CUT, 506),),
                bootstrap=_bootstrap(origin, GENESIS_CUT, 500), job=(), archivedBlocks=(),
                archivedJob=())


def _compare(actual, expected, label):
    _require(type(actual) is dict and actual.keys() == expected.keys(), f"{label} frame fields")
    for field, wanted in expected.items():
        _require(same(actual[field], wanted), f"{label} differs in {field}")


def _requested(pre, kind, args):
    _require(type(args) is tuple, f"{kind} arguments must be a sequence")
    current, final = pre["l1"], pre["finalized"]
    if kind == "advance":
        legal = current < 37 and args == ()
    elif kind == "finalize":
        legal = len(args) == 1 and type(args[0]) is int and final < args[0] < current
    elif kind == "invalidate":
        legal = final < current and same(args, (0,))
    elif kind == "recover":
        slots = {32: (1, 2), 35: (3,)}.get(current, ())
        _require(final < current and len(args) == 2 and type(args[0]) is int and args[0] in slots
                 and same(args[1], pre["authBank"][args[0] - 1]), "recover external authorization bank")
        return
    elif kind == "observe":
        legal = same(args, (32,)) or same(args, (35,))
    elif kind == "produce":
        legal = (pre["produces"] < 3 and len(args) == 1 and type(args[0]) is int
                 and 31 <= args[0] <= final)
    elif kind == "capture":
        legal = same(args, (6, 7, final))
    else:
        legal = final < current and any(job and same(args, (slot, job))
                                        for slot, job in enumerate((pre["job"], pre["archivedJob"]), 1))
    _require(legal, f"{kind} input outside the bounded offer domain")


def _recovery_state(pre):
    origins = tuple(Origin(o["generation"], o["height"], o["number"], o["time"])
                    for o in pre["origins"])
    return State(Schedule(*pre["schedule"]), pre["generation"], pre["c"], pre["nonce"],
                 pre["head"], pre["fiHead"], pre["activeSnapshot"], origins, True, True)


def _recovery(pre, auth):
    authorization = Authorization(auth["generation"], auth["checkpoint"], auth["nonce"],
                                  auth["validUntil"], auth["rules"])
    try:
        state, _ = recover(_recovery_state(pre), authorization, owner=auth["owner"],
                           now=_l1_time(pre["l1"]), number=pre["l1"])
    except ValueError:
        return False, pre
    g, c = state.generation, state.checkpoint
    actual = state.origins[-1]
    origin = _origin(g, c, actual.number, select_rule(state.schedule, actual.timestamp))
    updated = dict(pre, generation=g, nonce=state.nonce, schedule=tuple(state.schedule),
                   origins=pre["origins"] + (origin,), head=state.head,
                   canonical=pre["canonical"][:c], bootstrap=(), job=())
    if g == 2:
        updated.update(archivedBlocks=pre["canonical"][c:], archivedJob=pre["job"])
    return True, updated


def _anchor_view(pre, anchor):
    record = next(r for r in reversed(pre["records"]) if r["number"] <= anchor)
    when = (o["number"] for o in pre["origins"][1:] if o["number"] <= anchor)
    schedule = {32: PRESERVED, 35: REPLACED}.get(max(when, default=0), PENDING)
    return record["cut"], schedule


def _number_label(g, height, anchor, parent, origin, checkpoint, first):
    preferred = (32 if g == 1 else 35 if height == 7 else 36)
    anchor_variant = 0 if anchor == preferred else anchor - 30
    parent_variant = 0 if first or parent["anchor"] == origin else parent["anchor"] - 30
    expected_checkpoint = 7 if (g, height, anchor) == (2, 8, 36) else 6
    variant = anchor_variant + 8 * parent_variant + 64 * (checkpoint != expected_checkpoint)
    return 100 * g + 100 + height + 1000 * variant


def _production(pre, anchor):
    observed = dict(pre, produces=pre["produces"] + 1)
    g, height = pre["generation"], pre["head"] + 1
    anchor_cut, schedule = _anchor_view(pre, anchor)
    if not pre["bootstrap"] or height > 8 or height - anchor_cut[0] > 6:
        return False, observed
    origin = pre["origins"][-1]
    parent = pre["canonical"][-1]
    first = parent["cut"][0] == origin["height"]
    bft = origin["time"] if first else parent["bftTime"] + 1
    try:
        decision = candidate(Schedule(*schedule), parent_time=parent["elTime"], bft_time=bft,
                             anchor_number=anchor, anchor_time=_l1_time(anchor),
                             parent_anchor_number=parent["anchor"], origin_number=origin["number"],
                             max_age=1296, supported=SUPPORTED, first=first, origin_time=origin["time"])
    except ValueError:
        return False, observed
    if decision.outcome != "ACCEPT":
        return False, observed
    el = _number_label(g, height, anchor, parent, origin["number"], anchor_cut[0], first)
    cut = (height, el, el + 100, pre["fiHead"])
    block = _block(g, cut, bft, decision.el_time, anchor, anchor_cut, schedule, decision.rule,
                   () if first else parent["cut"][2])
    return True, dict(observed, head=height, canonical=pre["canonical"] + (block,))


def _capture(pre, reference):
    if pre["generation"] == 0 or pre["c"] != 6 or pre["head"] < 7 or pre["job"]:
        return False, pre
    block = pre["canonical"][6]
    if block["anchor"] > reference:
        return False, pre
    g, dependency = pre["generation"], pre["origins"][-1]["number"]
    lo, hi = pre["records"][0]["cut"], block["cut"]
    data = (hi[1],)
    statement = (1, 1, 167000, 4369, 8738, g, lo[0], lo[1], lo[2], 333, hi[0], hi[1], hi[2],
                 block["stateRoot"], reference, 500 + reference, data, lo[3], hi[3],
                 dependency, (2, g, lo[0], hi[0], ()))
    job = dict(generation=g, reference=reference, dependency=dependency, cuts=(lo, hi),
               data=data, statement=statement)
    return True, dict(pre, job=job)


def _settle(pre, requested_job):
    # The model premises supply a verified pair only for the selected g2 job.
    # They give no result about whether the DAO could have settled the g1 suffix.
    if requested_job["generation"] != 2:
        return False, pre
    lo, hi = requested_job["cuts"]
    now, ref = pre["l1"], requested_job["reference"]
    g, dependency = requested_job["generation"], requested_job["dependency"]
    context = Context(1, 167000, 4369, 8738, word(333), word(400 + hi[1]), word(500 + ref), dependency)
    blobs = tuple(map(blob, requested_job["data"]))
    job = capture(g, ref, (raw_cut(lo), raw_cut(hi)), blobs, context)
    checkpoint = pre["records"][-1]
    origin = pre["records"][0]
    try:
        landed_generation, parent, terminal, block = land(
            job, generation=pre["generation"], start=pre["origins"][-1]["height"],
            origin=(origin["generation"], raw_cut(origin["cut"])), checkpoint=raw_cut(checkpoint["cut"]),
            fi_head=pre["fiHead"], now=now, window=256, capacity=1, blobs=blobs, leaves=(),
            proofs=(job.statement, job.statement))
    except ValueError:
        return False, pre
    record = _landing(landed_generation, parent, block, ref, dependency, hi, 400 + hi[1])
    return True, dict(pre, c=terminal.height, fiHead=terminal.fi, activeSnapshot=dependency,
                      records=pre["records"] + (record,))


def _transition(pre, kind, args):
    if kind == "advance":
        return True, dict(pre, l1=pre["l1"] + 1)
    if kind == "finalize":
        return True, dict(pre, finalized=args[0])
    if kind == "invalidate":
        try:
            state = invalidate(_recovery_state(pre), args[0], owner=True)
        except ValueError:
            return False, pre
        return True, dict(pre, nonce=state.nonce)
    if kind == "recover":
        return _recovery(pre, args[1])
    if kind == "observe":
        origin = pre["origins"][-1]
        if pre["generation"] == 0 or args[0] != origin["number"] or args[0] > pre["finalized"]:
            return False, pre
        record = pre["records"][0]
        return True, dict(pre, bootstrap=_bootstrap(origin, record["cut"], record["stateRoot"]))
    if kind == "produce":
        return _production(pre, args[0])
    if kind == "capture":
        return _capture(pre, args[2])
    return _settle(pre, args[1])


def _endpoint(case, last):
    pre, post = last["pre"], last["post"]
    kind, args, accepted = last["kind"], last["args"], last["accepted"]
    if case == "smoke":
        return (post["generation"], post["head"], kind, args, accepted) == (1, 7, "produce", (32,), True)
    if case == "stale-nonce":
        return ((pre["generation"], pre["nonce"], kind, args, accepted) ==
                (0, 1, "recover", (1, pre["authBank"][0]), False))
    if case == "old-generation":
        return ((pre["generation"], pre["nonce"], kind, args, accepted) ==
                (1, 1, "recover", (2, pre["authBank"][1]), False))
    if case == "r1-only":
        return ((pre["generation"], pre["finalized"], pre["bootstrap"], kind, args, accepted) ==
                (2, 32, (), "observe", (35,), False))
    if case == "origin-overwrite":
        return kind == "recover" and accepted and pre["generation"] == 1 and post["generation"] == 2
    if case == "missing-bootstrap":
        # This is only a prefix observation. It cannot establish dispatch omission.
        return post["generation"] == 2 and post["finalized"] >= 35 and not post["bootstrap"]
    records, blocks = post["records"], post["canonical"]
    return (post["generation"] == 2 and post["c"] == 7 and post["head"] == 8 and post["produces"] == 3
            and len(post["archivedBlocks"]) == 1 and bool(post["archivedJob"])
            and blocks[6]["anchor"] == 35 and records[-1]["number"] == 36
            and blocks[-1]["anchorCut"] == records[-1]["cut"]
            and (kind, args, accepted) == ("produce", (36,), True))


def audit(text: str, case: str) -> list[dict]:
    """Validate full Init and adjacent frames. Named control endpoints are diagnostic."""
    _require(type(text) is str and type(case) is str and case in INVARIANTS.keys() | CONTROLS,
             "unknown repeated-recovery trajectory profile")
    packets = tuple(trace_packets(text))
    events = []
    for i, packet in enumerate(packets):
        _require(set(packet) == {"s", "receipt"}, "unexpected native state variables")
        state, receipt = packet["s"], packet["receipt"]
        if i == 0:
            _compare(state, _initial(), "Init")
            _require(same(receipt, ()), "Init receipt must be empty")
        else:
            _require(type(receipt) is dict and receipt.keys() == {"kind", "args", "accepted"}
                     and type(receipt["kind"]) is int and 1 <= receipt["kind"] <= len(KINDS)
                     and type(receipt["accepted"]) is bool, "invalid typed transition receipt")
            kind = KINDS[receipt["kind"] - 1]
            args = receipt["args"]
            _requested(pre, kind, args)
            accepted, expected = _transition(pre, kind, args)
            _require(receipt["accepted"] is accepted, f"{kind} decision differs from its raw inputs")
            if case == "origin-overwrite" and i == len(packets) - 1:
                _require(kind == "recover" and accepted and expected["generation"] == 2,
                         "origin-overwrite did not reach the second recovery")
                zero, _, second = expected["origins"]
                expected = dict(expected, origins=(zero, second, second))
            _compare(state, expected, f"{kind} post-state")
            events.append(dict(kind=kind, args=args, accepted=accepted, pre=pre, post=state))
        pre = state
    _require(events and _endpoint(case, events[-1]), f"{case} endpoint was not reached")
    return events


def _hash(raw):
    return hashlib.sha256(raw).hexdigest()


def _execution(record, case, raw):
    fields = {"schema", "case", "argv", "cwd", "returncode", "timedOut", "rawSha256", "inputSha256"}
    _require(type(record) is dict and record.keys() == fields
             and record["schema"] == "etna-repeated-recovery-execution-1" and record["case"] == case,
             "unexpected execution record schema or case")
    code = 0 if case == "safety" else 12
    _require(type(record["returncode"]) is int and record["returncode"] == code
             and record["timedOut"] is False and record["rawSha256"] == _hash(raw),
             "execution did not reach the selected result")
    require_tlc_argv(record["argv"], case + ".cfg", MODULE)
    _require(record["cwd"] == TLC_CWD, "unexpected native working directory")


def _native_result(raw, case, cwd):
    text = raw.decode("utf-8")
    require_healthy_native(text)
    lines = text.splitlines()
    _require(lines[:1] == [TLC_BANNER] and lines.count(TLC_BANNER) == 1
             and lines.count("Semantic processing of module EtnaRepeatedRecovery") == 1,
             "unexpected TLC version or missing module identity")
    footer = FOOTER.search(text)
    _require(bool(footer) and len(re.findall(r"^Finished in ", text, re.M)) == 1
             and re.findall(r"^Parsing file (.*" + re.escape(MODULE) + r")$", text, re.M) ==
             [str(Path(cwd) / MODULE)], "incomplete or unrelated TLC transcript")
    errors = re.findall(r"^Error:[^\n]*$", text, re.M)
    if case != "safety":
        _require(errors == [f"Error: Invariant {INVARIANTS[case]} is violated.",
                            "Error: The behavior up to this point is:"],
                 "unexpected named TLC outcome")
        return dict(outcome="NAMED_WITNESS_REPLAYED", transitions=len(audit(text, case)))
    _require(not errors and not STATE.search(text)
             and text.count("Model checking completed. No error has been found.") == 1,
             "unexpected ordinary TLC outcome")
    counts = re.match(r"([\d,]+) states generated, ([\d,]+) distinct states found, "
                      r"([\d,]+) states left on queue\.", footer[0])
    generated, distinct, queued = (int(value.replace(",", "")) for value in counts.groups())
    _require(1 <= distinct <= generated and queued == 0, "finite graph did not exhaust")
    return dict(outcome="FINITE_SAFETY_EXHAUSTED", graph=dict(generated=generated, distinct=distinct, queued=queued))


def current_receipt(workspace_root: Path, case: str, raw: bytes, *, execution: bytes,
                    staged_model: Path, expected_claim=None) -> dict:
    """Attribute an offline execution after checking its actual staged inputs and result."""
    _require(expected_claim is None or expected_claim == CLAIM, "expected claim differs from repeated recovery")
    _require(type(case) is str and case in INVARIANTS.keys() | {"safety"}, "unattributable repeated-recovery profile")
    _require(type(raw) is bytes and type(execution) is bytes, "native output and execution must be raw bytes")
    record = json.loads(execution.decode("utf-8"), object_pairs_hook=_unique_object)
    _execution(record, case, raw)
    config = case + ".cfg"
    formal = workspace_root / "formal/etna"
    expected = {MODULE: formal / MODULE, config: formal / "products" / CLAIM / config}
    inputs = {name: _hash((staged_model / name).read_bytes()) for name in expected}
    _require(record["inputSha256"] == inputs, "staged TLC inputs differ from the captured execution")
    _require(all(inputs[name] == _hash(path.read_bytes()) for name, path in expected.items()),
             "staged TLC model or profile differs from the workspace source")
    scope = reviewed_boundary(workspace_root, CLAIM)
    return dict(scope, case=case, **_native_result(raw, case, record["cwd"]),
                rawSha256=record["rawSha256"], executionSha256=_hash(execution),
                inputSha256=inputs, argv=record["argv"], cwd=record["cwd"],
                returncode=record["returncode"], timedOut=record["timedOut"])
