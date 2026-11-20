"""Offline current-rule ordinary range composition and complete TLC observations.

L1/storage authentication, valid settled prefix, EL/committee/FI execution and
each family's adjacent-image aggregation are premises, not implemented provers.
The ordered rule vector is observer data and adds no settlement ABI field.
"""
import hashlib
import json
from pathlib import Path
import re

from boundary_scope import require_healthy_native, require_tlc_argv, reviewed_boundary
from current_settlement import Context, capture, land, word
from current_spec import _unique_object
from proving_recovery import FOOTER, STATE, blob, raw_cut, same, trace_packets
from timestamp_recovery import Schedule, candidate, schedule_rules

CLAIM = "mixed-rule-landing"
MODULE = "EtnaRuleRange.tla"
TLC_CWD = "/tmp/etna-model"
TLC_BANNER = "TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)"
INVARIANTS = {"smoke": "NoSmoke", "pause": "NoPause", "progress": "NoProgress"}
CONTROLS = frozenset({"interior-check", "latest-anchor"})
KINDS = ("advance", "finalize", "schedule", "prefix", "prefix_land", "prepare",
         "admit", "upgrade", "capture", "prove", "publish", "land")
ZERO, FIRST, SECOND = (0, 0, 0, 0), (0, 1, 3600, 0), (1, 2, 5184, 0)
L1 = (191, 192, 288, 298, 299, 300, 324, 432, 433, 434)
ANCHORS = (190, 192, 288, 300, 432, 433)
ADJACENT, ENDPOINTS = ((0, 1), (1, 2)), ((0,), (2,))
ORIGIN_L1, GENESIS_CUTOFF, EPOCH_LENGTH = 25, 24, 16
BLOCK_FIELDS = frozenset("generation cut stateRoot parentTime bftTime elTime anchor parentAnchor carry anchorRoot anchorHash rule first origin originTime lastBlockID".split())
VIEW_FIELDS = frozenset("number time hash root checkpoint schedule".split())


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _uint(value, bits=256):
    _require(type(value) is int and 0 <= value < 1 << bits, "exact unsigned integer required")
    return value


def _cut(height):
    return height, 100 + height, 0 if height == 0 else 200 + height, 0


def _checked_cut(cut):
    _require(type(cut) is tuple and len(cut) == 4, "immutable complete cut required")
    for value in cut:
        _uint(value)
    _uint(cut[0], 48)
    _require(cut[0] != 0 or cut[2] == 0, "genesis checkpoint Comet hash must be zero")


def _time(number):
    return 12 * number


def _view(number, checkpoint, schedule):
    return dict(number=number, time=_time(number), hash=500 + number,
                root=900 + number, checkpoint=_cut(checkpoint), schedule=schedule)


def _block(height, parent_time, bft, timestamp, anchor, parent_anchor, carry, rule):
    return dict(generation=0, cut=_cut(height), stateRoot=400 + height,
                parentTime=parent_time, bftTime=bft, elTime=timestamp,
                anchor=anchor, parentAnchor=parent_anchor, carry=carry,
                anchorRoot=900 + anchor, anchorHash=500 + anchor,
                rule=rule, first=height == 1, origin=ORIGIN_L1, originTime=_time(ORIGIN_L1),
                lastBlockID=0 if height == 1 else 199 + height)


PREFIX = (_block(1, 0, 300, 2280, 190, 25, True, 0),
          _block(2, 2280, 2281, 2281, 190, 190, False, 0),
          _block(3, 2281, 2301, 2301, 190, 190, False, 0),
          _block(4, 2301, 2302, 2302, 190, 190, False, 0))
PARENTS = (_block(5, 2302, 3597, 3597, 192, 190, True, 0),
           _block(6, 3597, 3597, 3598, 192, 192, False, 0))
BLOCK_BANK = (_block(7, 3598, 3599, 3599, 288, 192, True, 0),
              _block(8, 3599, 3600, 3600, 288, 288, False, 1),
              _block(9, 3600, 3600, 3601, 300, 288, True, 1),
              _block(10, 3601, 5184, 5184, 432, 300, True, 2))


def resolve_blocks(blocks, authenticated_views) -> tuple[int, ...]:
    """Derive ordinary generation-zero rules from each authenticated own view.

    Integer hash/root labels stand for authenticated identities. Matching labels
    checks binding; it does not implement header hashing or storage proofs.
    """
    _require(type(blocks) is tuple and bool(blocks), "immutable nonempty blocks required")
    _require(type(authenticated_views) is tuple, "immutable authenticated views required")
    views = {}
    for view in authenticated_views:
        _require(type(view) is dict and view.keys() == VIEW_FIELDS, "closed anchor view schema required")
        for field in ("number", "time", "hash", "root"):
            _uint(view[field])
        _checked_cut(view["checkpoint"])
        _require(type(view["schedule"]) is tuple and len(view["schedule"]) == 4,
                 "immutable four-word schedule required")
        for value in view["schedule"]:
            _uint(value, 48)
        _require(view["number"] not in views, "duplicate anchor view")
        views[view["number"]] = view
    rules, previous = [], None
    for block in blocks:
        _require(type(block) is dict and block.keys() == BLOCK_FIELDS, "closed block schema required")
        for field in BLOCK_FIELDS - {"cut", "carry", "first"}:
            _uint(block[field])
        _require(type(block["carry"]) is bool and type(block["first"]) is bool,
                 "exact Boolean witness flags required")
        _checked_cut(block["cut"])
        anchor, height = block["anchor"], block["cut"][0]
        _require((block["generation"], block["origin"], block["originTime"])
                 == (0, ORIGIN_L1, _time(ORIGIN_L1)), "block differs from the fixed ordinary origin")
        first = height == 1
        _require(block["first"] is first, "first block must follow the ordinary genesis checkpoint")
        if first:
            _require((block["parentTime"], block["parentAnchor"], block["lastBlockID"]) == (0, ORIGIN_L1, 0),
                     "genesis predecessor differs from the selected origin")
        _require(anchor in views, "missing own anchor view")
        view = views[anchor]
        _require((block["anchorRoot"], block["anchorHash"]) == (view["root"], view["hash"]),
                 "own anchor root/hash differs from authenticated view")
        _require(block["carry"] is (first or anchor != block["parentAnchor"]),
                 "anchor witness must carry or inherit exactly")
        _require(view["checkpoint"][0] <= height - 1 and height - view["checkpoint"][0] <= 4,
                 "anchor checkpoint violates unsettled back-pressure")
        if previous is not None:
            _require(height == previous["cut"][0] + 1
                     and block["parentTime"] == previous["elTime"]
                     and block["parentAnchor"] == previous["anchor"]
                     and block["lastBlockID"] == previous["cut"][2],
                     "block parent time/hash/anchor continuity differs")
        decision = candidate(Schedule(*view["schedule"]), parent_time=block["parentTime"],
                             bft_time=block["bftTime"], anchor_number=anchor,
                             anchor_time=view["time"], parent_anchor_number=block["parentAnchor"],
                             origin_number=ORIGIN_L1, max_age=1296,
                             supported=frozenset(view["schedule"][:2]), first=first,
                             origin_time=_time(ORIGIN_L1))
        _require(decision.outcome == "ACCEPT" and decision.el_time == block["elTime"],
                 "literal timestamp successor or planned stop differs")
        _require(decision.rule == block["rule"], "block rule differs from own historical schedule")
        rules.append(decision.rule)
        previous = block
    return tuple(rules)


def _landing(height, number, reference):
    return dict(generation=0, cut=_cut(height), number=number, reference=reference,
                referenceHash=500 + reference, stateRoot=400 + height, activeSnapshot=GENESIS_CUTOFF)


def _initial():
    return dict(generation=0, c=4, head=4, fiHead=0, activeSnapshot=GENESIS_CUTOFF,
                l1=191, finalized=190, initialized=True, owner=True,
                schedule=ZERO, history=((ORIGIN_L1, ZERO),), software=(0,), canonical=PREFIX,
                records=(_landing(4, 191, 190),), views=(_view(190, 0, ZERO),),
                pending=(), job=(), proofs=(), published=(),
                aggregateAvailable=(True, True), zkFamilies=(2,))


def _compare(actual, expected, label):
    _require(type(actual) is dict and actual.keys() == expected.keys(), f"{label} frame fields")
    for key, value in expected.items():
        _require(same(actual[key], value), f"{label} frame differs in {key}")


def _initial_compatibility(state):
    """Check protocol-consistent initial labels before frozen Init equality.

    Valid nonempty registry checkpoint24 and elapsed positive activation delays
    remain premises; this check rules out contradictory origin/snapshot/epoch data.
    """
    fields = {"generation", "activeSnapshot", "canonical", "history", "records"}
    _require(type(state) is dict and fields <= state.keys(), "initial compatibility frame fields")
    chain = state["canonical"]
    _require(type(chain) is tuple and bool(chain) and type(chain[0]) is dict
             and BLOCK_FIELDS == chain[0].keys(), "initial first block schema")
    first = chain[0]
    _checked_cut(first["cut"])
    for field in ("generation", "bftTime", "originTime", "parentAnchor"):
        _uint(first[field])
    snapshot, origin = _uint(state["activeSnapshot"], 48), _uint(first["origin"], 48)
    _require(snapshot < origin, "initial committee cutoff must strictly precede origin")
    _require(type(state["generation"]) is int and state["generation"] == first["generation"] == 0
             and first["first"] is True and first["cut"][0] == 1,
             "initial committee requires generation0 first block")
    _require(same(first["bftTime"], first["originTime"])
             and first["originTime"] == _time(origin) and first["parentAnchor"] == origin,
             "first BFT time/parent anchor differs from initial origin")
    _require(EPOCH_LENGTH >= 3 and 10 < EPOCH_LENGTH - 1,
             "initial committee profile crosses an ordinary switch")
    _require(type(state["history"]) is tuple and bool(state["history"])
             and same(state["history"][0], (origin, ZERO)), "initial origin zero-rule history")
    _require(type(state["records"]) is tuple and bool(state["records"])
             and all(type(record) is dict and "activeSnapshot" in record
                     and same(record["activeSnapshot"], snapshot) for record in state["records"]),
             "initial retained committee snapshot differs")


def _historical_view(pre, number):
    schedule = next(q for n, q in reversed(pre["history"]) if n <= number)
    records = tuple(record for record in pre["records"] if record["number"] <= number)
    checkpoint = records[-1]["cut"][0] if records else 0
    return _view(number, checkpoint, schedule)


def _requested(pre, kind, args):
    _require(type(args) is tuple, f"{kind} arguments must be immutable")
    if kind == "advance":
        index = L1.index(pre["l1"])
        legal = index + 1 < len(L1) and same(args, (L1[index + 1],))
    elif kind == "finalize":
        legal = (len(args) == 1 and type(args[0]) is int and args[0] in ANCHORS
                 and pre["finalized"] < args[0] < pre["l1"])
    elif kind == "schedule":
        legal = ((pre["l1"] == 192 and same(args, (1, 3600)))
                 or (pre["l1"] == 324 and same(args, (2, 5184))))
    elif kind == "prefix":
        legal = (pre["l1"] == 298 and pre["head"] in (4, 5)
                 and same(args, (PARENTS[pre["head"] - 4],)))
    elif kind == "prefix_land":
        legal = ((pre["l1"], pre["head"], pre["c"]) == (299, 6, 4)
                 and same(args, (6, 298)))
    elif kind == "prepare":
        legal = (pre["head"] in range(6, 10) and pre["pending"] == ()
                 and same(args, (BLOCK_BANK[pre["head"] - 6],)))
    elif kind == "admit":
        legal = bool(pre["pending"]) and args == ()
    elif kind == "upgrade":
        legal = ((pre["software"] == (0,) and bool(pre["pending"]) and same(args, (1,)))
                 or (pre["software"] == (0, 1) and pre["head"] >= 9 and same(args, (2,))))
    elif kind == "capture":
        legal = pre["head"] == 10 and not pre["job"] and same(args, (6, 10, 433))
    elif kind == "prove":
        legal = (bool(pre["job"]) and len(args) == 2 and type(args[0]) is int and args[0] in (1, 2)
                 and any(same(args[1], plan) for plan in (ADJACENT, ENDPOINTS)))
    elif kind == "publish":
        legal = (bool(pre["job"]) and not pre["published"]
                 and (same(args, ((107, 108, 109, 110),)) or same(args, ((109, 110),))))
    else:
        legal = bool(pre["job"]) and pre["c"] < 10 and same(args, (pre["job"],))
    _require(legal, f"{kind} input outside actual bounded argument bank")


def _job(pre, reference):
    blocks = pre["canonical"][6:10]
    rules = resolve_blocks(blocks, pre["views"])
    cuts = tuple(block["cut"] for block in pre["canonical"][5:10])
    data = tuple(block["cut"][1] for block in blocks)
    terminal = blocks[-1]
    statement = (1, 1, 167000, 4369, 8738, 0, cuts[0][0], cuts[0][1], cuts[0][2], 333,
                 cuts[-1][0], cuts[-1][1], cuts[-1][2], terminal["stateRoot"], reference,
                 500 + reference, data, cuts[0][3], cuts[-1][3], pre["activeSnapshot"],
                 (2, 0, cuts[0][0], cuts[-1][0], cuts[1:-1]))
    return dict(generation=0, reference=reference, referenceHash=500 + reference,
                dependency=pre["activeSnapshot"], cuts=cuts, data=data,
                statement=statement, rules=rules, blocks=blocks)


def _family_covers(pre, family, images):
    # Only declared adjacent images are in the bounded bank. The separate family
    # aggregateAvailable premise supplies composition, not image-set union alone.
    return (pre["aggregateAvailable"][family - 1]
            and all(any(rule in image for image in images) for rule in pre["job"]["rules"]))


def _settle(pre, job, *, prefix=False):
    if prefix:
        cuts = tuple(block["cut"] for block in pre["canonical"][3:6])
        data, reference, root = (105, 106), 298, 406
    else:
        cuts, data, reference = job["cuts"], job["data"], job["reference"]
        root = pre["canonical"][9]["stateRoot"]
    context = Context(1, 167000, 4369, 8738, word(333), word(root),
                      word(500 + reference), pre["activeSnapshot"])
    captured = capture(0, reference, tuple(map(raw_cut, cuts)), tuple(map(blob, data)), context)
    proofs = (captured.statement, captured.statement)
    record = next(record for record in pre["records"] if record["cut"] == cuts[0])
    land(captured, generation=0, start=0, origin=(0, raw_cut(record["cut"])),
         checkpoint=raw_cut(pre["records"][-1]["cut"]), fi_head=pre["fiHead"],
         now=pre["l1"], window=256, capacity=6, blobs=tuple(map(blob, data)),
         leaves=captured.leaves, proofs=proofs)


def _transition(pre, kind, args, previous_receipt):
    if kind == "advance":
        return True, dict(pre, l1=args[0])
    if kind == "finalize":
        number = args[0]
        views = tuple(_historical_view(pre, n) for n in ANCHORS if n <= number)
        return True, dict(pre, finalized=number, views=views)
    if kind == "schedule":
        rules, time = args
        if pre["l1"] != (192 if rules == 1 else 324) or pre["finalized"] >= pre["l1"]:
            return False, pre
        try:
            result, _ = schedule_rules(Schedule(*pre["schedule"]), rules=rules, time=time,
                                       now=_time(pre["l1"]), max_age=1296,
                                       owner=pre["owner"], initialized=pre["initialized"])
        except ValueError:
            return False, pre
        result = tuple(result)
        if result == pre["schedule"]:
            return False, pre
        return True, dict(pre, schedule=result, history=pre["history"] + ((pre["l1"], result),))
    if kind in ("prefix", "prepare"):
        block = args[0]
        valid = (block["cut"][0] == pre["head"] + 1 and pre["pending"] == ()
                 and block["parentTime"] == pre["canonical"][-1]["elTime"]
                 and block["parentAnchor"] == pre["canonical"][-1]["anchor"]
                 and block["lastBlockID"] == pre["canonical"][-1]["cut"][2]
                 and block["generation"] == pre["generation"]
                 and block["anchor"] == max(pre["finalized"], pre["canonical"][-1]["anchor"]))
        if kind == "prefix":
            valid = valid and pre["l1"] == 298
        else:
            valid = valid and pre["c"] == 6
        if not valid:
            return False, pre
        try:
            resolve_blocks((block,), pre["views"])
        except ValueError:
            return False, pre
        if kind == "prepare":
            return True, dict(pre, pending=block)
        return True, dict(pre, head=block["cut"][0], canonical=pre["canonical"] + (block,))
    if kind == "prefix_land":
        if (pre["l1"], pre["head"], pre["c"]) != (299, 6, 4):
            return False, pre
        _settle(pre, (), prefix=True)
        return True, dict(pre, c=6, records=pre["records"] + (_landing(6, 299, 298),))
    if kind == "admit":
        if not pre["pending"]:
            return False, pre
        block = pre["pending"]
        rules = resolve_blocks((block,), pre["views"])
        if rules[0] not in pre["software"]:
            return False, pre
        return True, dict(pre, head=block["cut"][0], canonical=pre["canonical"] + (block,), pending=())
    if kind == "upgrade":
        rule = args[0]
        paused = (type(previous_receipt) is dict and previous_receipt["kind"] == 7
                  and previous_receipt["accepted"] is False)
        valid = (rule == 1 and pre["software"] == (0,) and bool(pre["pending"])
                 and pre["pending"]["cut"][0] == 8 and paused)
        valid = valid or (rule == 2 and pre["software"] == (0, 1) and pre["head"] >= 9)
        return (True, dict(pre, software=pre["software"] + (rule,))) if valid else (False, pre)
    if kind == "capture":
        if (pre["head"], pre["c"], pre["job"]) != (10, 6, ()) or pre["finalized"] < 433:
            return False, pre
        return True, dict(pre, job=_job(pre, args[2]))
    if kind == "prove":
        family, images = args
        if (not pre["job"] or any(proof[0] == family for proof in pre["proofs"])
                or not _family_covers(pre, family, images)):
            return False, pre
        return True, dict(pre, proofs=pre["proofs"] + ((family, images, pre["job"]["statement"]),))
    if kind == "publish":
        if not pre["job"] or pre["published"] or not same(args[0], pre["job"]["data"]):
            return False, pre
        return True, dict(pre, published=args[0])
    job = pre["job"]
    if (not job or pre["c"] >= 10 or not same(pre["published"], job["data"])
            or {proof[0] for proof in pre["proofs"]} != {1, 2}
            or not any(proof[0] in pre["zkFamilies"] for proof in pre["proofs"])
            or not all(same(proof[2], job["statement"]) for proof in pre["proofs"])):
        return False, pre
    _require(all(_family_covers(pre, proof[0], proof[1]) for proof in pre["proofs"]),
             "every proof family must cover every interior rule")
    _settle(pre, job)
    return True, dict(pre, c=10, records=pre["records"] + (_landing(10, pre["l1"], 433),))


def _endpoint(case, event):
    pre, post, kind, ok = (event[key] for key in ("pre", "post", "kind", "accepted"))
    if case == "smoke":
        return kind == "admit" and ok and post["head"] == 7
    if case == "pause":
        return kind == "admit" and not ok and pre["pending"] and pre["pending"]["cut"][0] == 8
    return kind == "land" and ok and post["c"] == 10 and post["job"]["rules"] == (0, 1, 1, 2)


def audit(text: str, case: str) -> list[dict]:
    """Validate full raw Init and every adjacent frame against actual call inputs."""
    _require(type(text) is str and type(case) is str and case in INVARIANTS,
             "unknown ordinary rule-range trajectory profile")
    packets, events, previous_receipt = tuple(trace_packets(text)), [], ()
    for index, packet in enumerate(packets):
        _require(type(packet) is dict and packet.keys() == {"s", "receipt"}, "unexpected native state variables")
        state, receipt = packet["s"], packet["receipt"]
        if index == 0:
            _initial_compatibility(state)
            _compare(state, _initial(), "Init")
            _require(same(receipt, ()), "Init receipt must be empty")
        else:
            _require(type(receipt) is dict and receipt.keys() == {"kind", "args", "accepted"}
                     and type(receipt["kind"]) is int and 1 <= receipt["kind"] <= len(KINDS)
                     and type(receipt["accepted"]) is bool, "invalid exact typed transition receipt")
            kind, args = KINDS[receipt["kind"] - 1], receipt["args"]
            _requested(pre, kind, args)
            accepted, expected = _transition(pre, kind, args, previous_receipt)
            _require(receipt["accepted"] is accepted, f"{kind} decision differs from actual argument inputs")
            _compare(state, expected, f"{kind} post-state")
            events.append(dict(kind=kind, args=args, accepted=accepted, pre=pre, post=state))
        pre, previous_receipt = state, receipt
    _require(events and _endpoint(case, events[-1]), f"{case} endpoint was not reached")
    return events


def _hash(raw):
    return hashlib.sha256(raw).hexdigest()


def current_receipt(workspace_root: Path, case: str, raw: bytes, *, execution: bytes,
                    staged_model: Path, expected_claim=None) -> dict:
    """Consume pinned results supplied by a trusted same-run native collector.

    Genuine collection is a caller precondition; these metadata bytes cannot
    attest provenance. Synthetic parser-fixture acceptance grants no native
    execution evidence.
    """
    _require(expected_claim is None or expected_claim == CLAIM, "expected claim differs from rule range")
    _require(type(case) is str and case in INVARIANTS.keys() | {"safety"}, "unattributable rule-range profile")
    _require(type(raw) is bytes and type(execution) is bytes, "native/execution raw bytes required")
    record = json.loads(execution.decode("utf-8"), object_pairs_hook=_unique_object)
    fields = {"schema", "case", "argv", "cwd", "returncode", "timedOut", "rawSha256", "inputSha256"}
    _require(type(record) is dict and record.keys() == fields
             and record["schema"] == "etna-rule-range-execution-1" and record["case"] == case,
             "unexpected execution schema/case")
    _require(type(record["returncode"]) is int and record["returncode"] == (0 if case == "safety" else 12)
             and record["timedOut"] is False and record["rawSha256"] == _hash(raw),
             "native execution did not reach selected normal outcome")
    require_tlc_argv(record["argv"], case + ".cfg", MODULE)
    _require(record["cwd"] == TLC_CWD, "unexpected actual native cwd")
    formal = workspace_root / "formal/etna"
    sources = {MODULE: formal / MODULE, case + ".cfg": formal / "products/rule-range" / (case + ".cfg")}
    inputs = {name: _hash((staged_model / name).read_bytes()) for name in sources}
    _require(same(record["inputSha256"], inputs)
             and all(inputs[name] == _hash(path.read_bytes()) for name, path in sources.items()),
             "actual staged source/config differs from same-run workspace inputs")
    text, lines = raw.decode("utf-8"), raw.decode("utf-8").splitlines()
    require_healthy_native(text)
    _require(lines[:1] == [TLC_BANNER] and lines.count(TLC_BANNER) == 1
             and lines.count("Semantic processing of module EtnaRuleRange") == 1
             and re.findall(r"^Parsing file (.*" + re.escape(MODULE) + r")$", text, re.M)
             == [str(Path(record["cwd"]) / MODULE)], "unexpected TLC/module identity")
    footer = FOOTER.search(text)
    _require(footer is not None and len(re.findall(r"^Finished in ", text, re.M)) == 1,
             "incomplete native footer")
    errors = re.findall(r"^Error:[^\n]*$", text, re.M)
    if case == "safety":
        _require(not errors and not STATE.search(text)
                 and text.count("Model checking completed. No error has been found.") == 1,
                 "unexpected ordinary safety diagnostics")
        counts = re.match(r"([\d,]+) states generated, ([\d,]+) distinct states found, ([\d,]+) states left on queue\.", footer[0])
        generated, distinct, queued = (int(value.replace(",", "")) for value in counts.groups())
        _require(1 <= distinct <= generated and queued == 0, "finite graph not exhausted")
        outcome = dict(outcome="FINITE_SAFETY_EXHAUSTED", graph=dict(generated=generated, distinct=distinct, queued=queued))
    else:
        _require(errors == [f"Error: Invariant {INVARIANTS[case]} is violated.",
                            "Error: The behavior up to this point is:"], "unexpected named native outcome")
        outcome = dict(outcome="NAMED_WITNESS_REPLAYED", transitions=len(audit(text, case)))
    return dict(reviewed_boundary(workspace_root, CLAIM), case=case, **outcome,
                rawSha256=_hash(raw), executionSha256=_hash(execution), inputSha256=inputs,
                argv=record["argv"], cwd=record["cwd"], returncode=record["returncode"], timedOut=False)
