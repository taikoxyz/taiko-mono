"""Literal current-Registry state frames for replaying raw TLC PRE/POST states."""
from copy import deepcopy
import json
from pathlib import Path
import re

from export_recovery import ValueParser

from current_spec import CURRENT_BUNDLE, DOCUMENT_PATHS, MANIFEST_PATH
from current_spec import classify_workspace_documents, select_claim

IDS = tuple(range(4))
SLOTS = (0, 1)
OWNERS = (1, 2)
CALLERS = (*OWNERS, 3)
NO_EXIT = 11


class OutOfProfile(ValueError):
    """The finite experiment does not offer this call."""


def reviewed_source(workspace):
    documents = {path: (workspace / path).read_bytes() for path in DOCUMENT_PATHS}
    source = classify_workspace_documents(documents, json.loads(MANIFEST_PATH.read_bytes()))
    if source["bundleId"] != CURRENT_BUNDLE:
        raise ValueError("W02 requires the exact current source bundle")
    return {"workspace": source, "claim": select_claim(
        CURRENT_BUNDLE, "registry-vacancy-model", "lowest-empty-slot")}


def empty_bond():
    return dict(issued=False, withdrawn=False, key=0, owner=0, eff=0, pending=0,
                active=0, exit=0, confirmed=0, holds=False, slot=0, ready=0)


def empty_entry():
    return dict(occupied=False, key=0, bond=0, eff=0, active=0, exit=0)


def initial_state():
    checkpoint = {"at": 0, "count": 0, "entries": {i: empty_entry() for i in SLOTS}}
    return dict(now=1, nextId=0, bonds={i: empty_bond() for i in IDS},
                slots={i: dict(occupied=False, bond=0) for i in SLOTS},
                keys={i: dict(registered=False, bond=0) for i in IDS},
                forfeits={i: False for i in IDS}, topups={i: False for i in IDS},
                uses={i: 0 for i in SLOTS}, reuse=0,
                cash=dict(deposited=0, held=0, bounty=0, sink=0, paid=0),
                covered=0, dirty=False, checkpoint=checkpoint,
                sample=dict(snapshot=0, checkpoint=deepcopy(checkpoint),
                            powers={i: 0 for i in IDS}))


def entries(state):
    result = {}
    for i in SLOTS:
        slot = state["slots"][i]
        if slot["occupied"]:
            bond = state["bonds"][slot["bond"]]
            result[i] = dict(occupied=True, bond=slot["bond"], key=bond["key"],
                             eff=bond["eff"], active=bond["active"], exit=bond["exit"])
        else:
            result[i] = empty_entry()
    return result


def _register_at(pre, post, call, slot):
    bond, key = pre["nextId"], call["key"]
    amount, actor, now, cash = call["amount"], call["actor"], pre["now"], post["cash"]
    post["bonds"][bond] = dict(issued=True, withdrawn=False, key=key, owner=actor,
                               eff=amount, pending=0, active=now + 1, exit=NO_EXIT,
                               confirmed=0, holds=True, slot=slot, ready=0)
    post["slots"][slot] = dict(occupied=True, bond=bond)
    post["keys"][key] = dict(registered=True, bond=bond)
    post["nextId"] += 1
    post["reuse"] += int(pre["uses"][slot] > 0)
    post["uses"][slot] += 1
    cash["deposited"] += amount
    cash["held"] += amount


def expected_transition(pre, call, *, max_time=8):
    """Independently evaluate one canonical funded call, including exact refusal."""
    post = deepcopy(pre)
    now = pre["now"]
    name = call["name"]
    actor = call.get("actor")
    cash = post["cash"]

    if name == "Register":
        key = call["key"]
        vacant = next((i for i in SLOTS if not pre["slots"][i]["occupied"]), None)
        if not _register_is_offered(pre, call):
            raise OutOfProfile("registration outside finite key, reuse, and amount choices")
        if pre["keys"][key]["registered"] or vacant is None:
            return False, post
        _register_at(pre, post, call, vacant)

    elif name == "Tick":
        capture = call["capture"]
        if now >= max_time or (capture and pre["sample"]["snapshot"] != 0):
            return False, post
        if pre["dirty"]:
            leaves = entries(pre)
            post["checkpoint"] = dict(at=now,
                                      count=sum(entry["occupied"] for entry in leaves.values()),
                                      entries=leaves)
        post["now"] += 1
        post["dirty"] = False
        if capture:
            checkpoint = post["checkpoint"]
            powers = {i: 0 for i in IDS}
            for entry in checkpoint["entries"].values():
                if entry["occupied"] and entry["active"] <= now < entry["exit"] and entry["eff"] > 0:
                    powers[entry["bond"]] = entry["eff"]
            post["sample"] = dict(snapshot=now, checkpoint=deepcopy(checkpoint), powers=powers)
        return True, post

    elif name == "Land":
        if not pre["covered"] < call["snapshot"] < now:
            return False, post
        post["covered"] = call["snapshot"]

    elif name in {"TopUp", "Activate", "Exit", "Slash", "Forfeit", "Confirm", "Withdraw"}:
        bond = call["bond"]
        before = pre["bonds"][bond]
        if name == "TopUp" and pre["topups"][bond]:
            raise OutOfProfile("profile offers at most one accepted top-up per bond")
        if not before["issued"] or before["withdrawn"]:
            return False, post
        after = post["bonds"][bond]
        owner = before["owner"]
        principal = before["eff"] + before["pending"]

        if name == "TopUp":
            if (actor != owner or before["exit"] != NO_EXIT or before["active"] > now
                    or before["eff"] <= 0 or before["pending"]):
                return False, post
            after.update(pending=1, ready=now + 1)
            post["topups"][bond] = True
            cash["deposited"] += 1
            cash["held"] += 1
        elif name == "Activate":
            if (actor not in CALLERS or before["exit"] != NO_EXIT or not before["pending"]
                    or before["ready"] > now):
                return False, post
            after.update(eff=principal, pending=0, ready=0)
        elif name == "Exit":
            if actor != owner or before["exit"] != NO_EXIT:
                return False, post
            after["exit"] = max(now, before["active"]) + 1
        elif name == "Slash":
            if actor not in CALLERS or not principal:
                return False, post
            reward = principal // 4
            after.update(eff=0, pending=0, ready=0, exit=min(before["exit"], now))
            cash["held"] -= principal
            cash["bounty"] += reward
            cash["sink"] += principal - reward
        elif name == "Forfeit":
            key = before["key"]
            if actor != 4 or call["key"] != key or pre["forfeits"][key] or not principal:
                return False, post
            penalty = (principal + 1) // 2
            pending = before["pending"] - max(0, penalty - before["eff"])
            after.update(eff=max(0, before["eff"] - penalty), pending=pending,
                         ready=before["ready"] if pending else 0, exit=min(before["exit"], now))
            post["forfeits"][key] = True
            cash["held"] -= penalty
            cash["sink"] += penalty
        elif name == "Confirm":
            if actor not in CALLERS or before["exit"] > pre["covered"]:
                return False, post
            if not before["confirmed"]:
                after["confirmed"] = now
        elif name == "Withdraw":
            if (actor not in CALLERS or not before["confirmed"] or now < before["confirmed"] + 1
                    or (principal and actor != owner)):
                return False, post
            after.update(withdrawn=True, owner=0, eff=0, pending=0, confirmed=0,
                         holds=False, slot=0, ready=0)
            post["slots"][before["slot"]] = dict(occupied=False, bond=0)
            cash["held"] -= principal
            cash["paid"] += principal
    else:
        raise ValueError(f"unknown raw action: {name}")

    post["dirty"] = pre["dirty"] or entries(pre) != entries(post)
    return True, post


def _require(test, detail):
    if not test:
        raise ValueError(detail)


def _canonical(value):
    if isinstance(value, dict):
        return {int(k) if k.isdecimal() else k: _canonical(v) for k, v in value.items()}
    return value


def _differences(expected, actual, path=()):
    if type(expected) is not type(actual):
        return [path]
    if isinstance(expected, dict):
        if set(expected) != set(actual):
            return [path]
        return [mismatch for key in expected for mismatch in
                _differences(expected[key], actual[key], (*path, key))]
    return [] if expected == actual else [path]


SIMULATION_PROGRESS = re.compile(r"^Progress: \d+ states checked\.$", re.MULTILINE)
SIMULATION_FOOTER = re.compile(
    r"^The number of states generated: ([1-9]\d*)\nSimulation using seed (-?\d+) and aril (\d+)$",
    re.MULTILINE,
)


def _simulation_banner(log, seed):
    banners = re.findall(r"^Running Random Simulation with seed (-?\d+) with (\d+) workers? on ",
                         log, re.MULTILINE)
    _require(banners == [(str(seed), "1")], "wrong simulation seed or worker banner")


def simulation_summary(log, seed):
    """Require the simulator's own footer for a real named counterexample."""
    _simulation_banner(log, seed)
    matches = list(SIMULATION_FOOTER.finditer(log))
    _require(len(matches) == 1 and int(matches[0][2]) == seed, "wrong native simulation footer")
    _require(not re.search(r"^(?:\d[\d,]* states generated,|Running .*Model-Checking)", log, re.MULTILINE),
             "model-checking output in simulation evidence")
    tail = log[matches[0].end():].splitlines()
    _require(all(not line.strip() or SIMULATION_PROGRESS.fullmatch(line)
                 or re.fullmatch(r"Finished in .+ at \([^\n]+\)", line) for line in tail),
             "unexpected output after native simulation footer")
    return dict(generated=int(matches[0][1]), seed=seed, aril=int(matches[0][3]))


def trace_states(log, *, simulation_seed=None):
    """Parse every displayed TLC state in the selected engine mode."""
    if simulation_seed is None:
        bounds = list(re.finditer(r"^\d[\d,]* states generated,", log, re.MULTILINE))
        _require(len(bounds) == 1, "one final TLC statistics row required")
        body = log[:bounds[0].start()]
    else:
        simulation_summary(log, simulation_seed)
        # Progress may interleave with a long stdout state dump. Consume only
        # complete known progress lines in the parsing view of untouched bytes.
        body = SIMULATION_PROGRESS.sub("", log[:SIMULATION_FOOTER.search(log).start()])
    headers = list(re.finditer(r"^State (\d+):[^\n]*\n", body, re.MULTILINE))
    _require(bool(headers), "TLC did not emit trace states")
    result = []
    for i, header in enumerate(headers):
        _require(int(header[1]) == i + 1, "nonconsecutive trace")
        end = headers[i + 1].start() if i + 1 < len(headers) else len(body)
        state = body[header.end():end]
        assignments = list(re.finditer(r"^/\\ (\w+) = ", state, re.MULTILINE))
        _require(len(assignments) == 4 and not state[:assignments[0].start()].strip(),
                 "unparsed state or wrong field count")
        parsed = {}
        for j, assignment in enumerate(assignments):
            name = assignment[1]
            _require(name not in parsed, "duplicate state variable")
            stop = assignments[j + 1].start() if j + 1 < len(assignments) else len(state)
            value = ValueParser(state[assignment.end():stop])
            parsed[name] = _canonical(value.value())
            _require(not value.text[value.pos:].strip(), "trailing TLC terms after " + name)
        _require(set(parsed) == {"r", "last", "frameOK", "marks"}, "wrong state field names")
        result.append(parsed)
    return result


def _no_call():
    return dict(call=dict(kind="None", bond=0, actor=0, key=0, amount=0,
                          snapshot=0, capture=False), accepted=False)


def _initial_marks():
    return dict(holes=False, publicSlotZero=False, activation=dict.fromkeys(IDS, False),
                pendingCapture=dict.fromkeys(IDS, False), duplicateReuse=False)


def _watch_marks(previous, previous_call, pre, post, call, accepted):
    marks = deepcopy(previous)
    if accepted:
        key = previous_call["call"]["key"]
        marks["duplicateReuse"] = (call["name"] == "Register"
                                   and previous_call["call"]["kind"] == "Register"
                                   and not previous_call["accepted"] and pre["keys"][key]["registered"]
                                   and pre["bonds"][pre["keys"][key]["bond"]]["withdrawn"])
    if accepted and call["name"] == "Withdraw" and call["actor"] == 3:
        old = pre["bonds"][call["bond"]]
        marks["publicSlotZero"] |= old["slot"] == 0 and _balance(old) == 0
    if accepted and call["name"] == "Register" and pre["nextId"] == 2:
        marks["holes"] |= all(not pre["slots"][i]["occupied"] for i in SLOTS)
    if accepted and call["name"] == "Tick" and call["capture"]:
        marks["pendingCapture"] = {i: bool(pre["bonds"][i]["pending"] and
                                           post["sample"]["powers"][i]) for i in IDS}
    if accepted and call["name"] == "Activate":
        bond = call["bond"]
        marks["activation"][bond] |= marks["pendingCapture"][bond]
    return marks


def _register_is_offered(pre, call):
    key = call["key"]
    if key not in IDS or call["actor"] not in OWNERS or call["amount"] not in (3, 4):
        return False
    if pre["keys"][key]["registered"]:
        return True
    slot = next((s for s in SLOTS if not pre["slots"][s]["occupied"]), None)
    return key == pre["nextId"] and (slot is None or pre["uses"][slot] == 0 or pre["reuse"] < 2)


def validate_raw_call(pre, last, *, capture_history):
    """Check the offered call and all unused sentinel cells against the trace profile."""
    _require(set(last) == {"accepted", "call"} and type(last["accepted"]) is bool,
             "wrong raw action envelope")
    actual = last["call"]
    canonical = _no_call()["call"]
    _require(set(actual) == set(canonical), "wrong raw call fields")
    _require(all(type(actual[field]) is type(canonical[field]) for field in canonical),
             "wrong raw call types")
    kind = actual["kind"]
    canonical["kind"] = kind
    _require(last["accepted"] or kind == "Register", "only Register offers a rejected edge")

    if kind == "Register":
        canonical.update(key=actual["key"], actor=actual["actor"], amount=actual["amount"])
        _require(_register_is_offered(pre, canonical), "registration outside the selected finite inputs")
    elif kind == "Tick":
        _require(capture_history or not actual["capture"], "capture disabled in this profile")
        canonical["capture"] = actual["capture"]
    elif kind == "Land":
        _require(pre["covered"] < actual["snapshot"] < pre["now"], "landing snapshot outside offers")
        canonical["snapshot"] = actual["snapshot"]
    elif kind in {"TopUp", "Exit", "Activate", "Slash", "Forfeit", "Confirm", "Withdraw"}:
        bond = actual["bond"]
        _require(bond in IDS, "invalid offered bond ID")
        canonical["bond"] = bond
        old = pre["bonds"][bond]
        if kind in {"TopUp", "Exit"}:
            canonical["actor"] = old["owner"]
        elif kind == "Forfeit":
            canonical.update(actor=4, key=old["key"])
        elif kind == "Withdraw":
            _require(actual["actor"] in (old["owner"], 3), "invalid withdrawal actor offer")
            canonical["actor"] = actual["actor"]
        else:
            canonical["actor"] = 3
    else:
        raise ValueError("unknown actual action")
    _require(not _differences(canonical, actual), "noncanonical raw action metadata")
    canonical["name"] = canonical.pop("kind")
    return canonical


def _balance(bond):
    return bond["eff"] + bond["pending"]


def _two_initial_slots_released(steps):
    held_together = any(p["slots"] == {
        0: {"occupied": True, "bond": 0},
        1: {"occupied": True, "bond": 1},
    } for p, _, _ in steps)
    released = {(q["call"]["bond"], p["bonds"][q["call"]["bond"]]["slot"])
                for p, q, a in steps
                if q["accepted"] and q["call"]["kind"] == "Withdraw"
                and a["bonds"][q["call"]["bond"]]["withdrawn"]}
    return held_together and {(0, 0), (1, 1)} <= released


def _witness(invariant, steps, terminal):
    pre, last, after = steps[-1]
    call, accepted = last["call"], last["accepted"]
    slots = pre["slots"]
    bonds = pre["bonds"]
    if invariant == "HeldZeroNotReached":
        _require(call["kind"] == "Register" and accepted and slots[0]["occupied"]
                 and _balance(bonds[slots[0]["bond"]]) == 0 and not slots[1]["occupied"]
                 and after["slots"][0] == slots[0] and after["slots"][1]["bond"] == pre["nextId"],
                 "missing admission with held-zero lower slot")
    elif invariant == "FullRefusalNotReached":
        _require(call["kind"] == "Register" and not accepted and call["key"] == pre["nextId"]
                 and all(slots[s]["occupied"] for s in SLOTS) and after == pre
                 and any(_balance(bonds[slots[s]["bond"]]) == 0
                         and bonds[slots[1 - s]["bond"]]["pending"] > 0
                         and bonds[slots[1 - s]["bond"]]["exit"] != NO_EXIT for s in SLOTS),
                 "missing atomic full refusal with held-zero and exiting-pending occupants")
    elif invariant == "TwoHolesNotReached":
        _require(call["kind"] == "Withdraw" and accepted and after["nextId"] == 2
                 and all(not after["slots"][s]["occupied"] for s in SLOTS)
                 and all(after["bonds"][i]["withdrawn"] for i in (0, 1))
                 and _two_initial_slots_released(steps),
                 "missing two withdrawals with simultaneous vacancies")
    elif invariant == "TwoReusesNotReached":
        _require(call["kind"] == "Register" and accepted and after["nextId"] == 4
                 and all(after["bonds"][i]["withdrawn"] for i in (0, 1))
                 and after["uses"] == {0: 2, 1: 2} and _two_initial_slots_released(steps)
                 and [after["slots"][s]["bond"] for s in SLOTS] == [2, 3]
                 and any(q["call"]["kind"] == "Register" and q["accepted"]
                         and p["nextId"] == 2 and all(not p["slots"][s]["occupied"] for s in SLOTS)
                         and a["slots"][0]["bond"] == 2 for p, q, a in steps),
                 "missing ordered successive reuse after two simultaneous holes")
    elif invariant == "FrozenSelectionNotReached":
        sample = after["sample"]
        _require(any(terminal["marks"]["activation"][i] and after["bonds"][i]["withdrawn"]
                     and sample["powers"][i] > 0
                     and any(e["occupied"] and e["bond"] == i
                             and after["slots"][s]["occupied"] and after["slots"][s]["bond"] != i
                             for s, e in sample["checkpoint"]["entries"].items()) for i in IDS),
                 "missing saved old identity after pending capture, activation and reuse")
    elif invariant == "ZeroPublicReuseNotReached":
        _require(call["kind"] == "Register" and accepted and not pre["keys"][call["key"]]["registered"]
                 and not slots[0]["occupied"] and after["slots"][0]["bond"] == pre["nextId"]
                 and any(q["call"]["kind"] == "Withdraw" and q["accepted"] and q["call"]["actor"] == 3
                         and p["bonds"][q["call"]["bond"]]["slot"] == 0
                         and _balance(p["bonds"][q["call"]["bond"]]) == 0
                         and 0 < p["bonds"][q["call"]["bond"]]["confirmed"] < p["now"]
                         and a["bonds"][q["call"]["bond"]]["withdrawn"] for p, q, a in steps[:-1]),
                 "missing delayed public zero withdrawal followed by fresh slot-zero reuse")
    elif invariant == "PartialForfeitNotReached":
        b = after["bonds"][call["bond"]]
        _require(call["kind"] == "Forfeit" and accepted and b["holds"] and b["eff"] and b["pending"]
                 and after["cash"]["sink"] > pre["cash"]["sink"],
                 "missing held slot after partial forfeiture")
    elif invariant == "DuplicateKeyNotReached":
        p, duplicate, a = steps[-2]
        key = duplicate["call"]["key"]
        _require(duplicate["call"]["kind"] == "Register" and not duplicate["accepted"]
                 and p == a == pre and pre["keys"][key]["registered"]
                 and pre["bonds"][pre["keys"][key]["bond"]]["withdrawn"]
                 and call["kind"] == "Register" and accepted and call["key"] != key,
                 "missing withdrawn-key refusal and distinct fresh admission from the same prestate")
    else:
        raise ValueError("unknown witness invariant")


def _fault_shape(fault, pre, last, actual, expected, eligible):
    call, accepted = last["call"], last["accepted"]
    slots = pre["slots"]
    if fault == "held-zero":
        _require(call["kind"] == "Register" and accepted and eligible and slots[0]["occupied"]
                 and _balance(pre["bonds"][slots[0]["bond"]]) == 0 and not slots[1]["occupied"]
                 and expected["slots"][0] == slots[0] and actual["slots"][0]["bond"] == pre["nextId"],
                 "not held-zero mistaken vacancy")
    elif fault == "two-holes":
        _require(call["kind"] == "Register" and accepted and eligible and
                 all(not slots[s]["occupied"] and pre["uses"][s] for s in SLOTS)
                 and expected["slots"][0]["occupied"] and actual["slots"][1]["occupied"],
                 "not wrong order between formerly used holes")
    elif fault == "refusal":
        _require(call["kind"] == "Register" and accepted is False and eligible is False
                 and all(slots[s]["occupied"] for s in SLOTS) and expected == pre
                 and actual["nextId"] == pre["nextId"] + 1
                 and actual["keys"][call["key"]]["registered"]
                 and actual["cash"]["held"] == pre["cash"]["held"] + call["amount"],
                 "not full refusal with illegal ID, key and cash changes")
    else:
        raise ValueError("unknown source fault")

    faulted = deepcopy(pre)
    if fault == "refusal":
        key, amount = call["key"], call["amount"]
        _require(key == pre["nextId"], "refusal fault requires fresh next ID")
        faulted["nextId"] += 1
        faulted["keys"][key] = dict(registered=True, bond=key)
        faulted["cash"]["deposited"] += amount
        faulted["cash"]["held"] += amount
    else:
        _register_at(pre, faulted, call, 0 if fault == "held-zero" else 1)
        faulted["dirty"] = pre["dirty"] or entries(pre) != entries(faulted)
    _require(not _differences(faulted, actual), "incorrect complete faulted Registry POST")


def audit_trace(log, invariant, *, max_time=8, capture_history=False, fault=None,
                simulation_seed=None):
    """Replay observed calls and exact full-state frames from an actual named TLC violation."""
    errors = re.findall(r"^Error: (.*)$", log, re.MULTILINE)
    _require(errors == [f"Invariant {invariant} is violated.", "The behavior up to this point is:"],
             "unexpected TLC violation")
    states = trace_states(log, simulation_seed=simulation_seed)
    _require(not _differences(dict(r=initial_state(), frameOK=True,
                                   last=_no_call(), marks=_initial_marks()), states[0]),
             "trace does not start at the literal initial state")
    steps = []
    findings = []
    for index, (before, after) in enumerate(zip(states, states[1:]), start=1):
        pre, actual, last = before["r"], after["r"], after["last"]
        call = validate_raw_call(pre, last, capture_history=capture_history)
        eligible, expected = expected_transition(pre, call, max_time=max_time)
        mismatches = _differences(expected, actual)
        same = eligible is last["accepted"] and not mismatches
        _require(after["frameOK"] is same, f"model frame classifier disagrees at step {index}")
        if not same:
            _require(fault and index + 1 == len(states), f"unexpected state difference at step {index}")
            _fault_shape(fault, pre, last, actual, expected, eligible)
            findings = mismatches
        else:
            marks = _watch_marks(before["marks"], before["last"], pre, actual, call, last["accepted"])
            _require(not _differences(marks, after["marks"]), f"observer metadata differs at step {index}")
        steps.append((pre, last, actual))
    _require(bool(steps), "trace contains no actual calls")
    if fault == "missing-full-amount4":
        _, last, target = steps[-1]
        key = target["nextId"]
        probe = {"name": "Register", "actor": 2, "key": key, "amount": 4}
        _require(invariant == "AdmissionEnabled" and not findings and last["accepted"]
                 and last["call"]["kind"] == "Register" and key in IDS
                 and all(target["slots"][slot]["occupied"] for slot in SLOTS)
                 and _register_is_offered(target, probe)
                 and expected_transition(target, probe) == (False, target),
                 "missing full-capacity amount-four refusal offer discriminator")
    elif fault:
        _require(invariant == "FramesExact" and findings, "missing intended source fault")
    else:
        _witness(invariant, steps, states[-1])
    return {"invariant": invariant, "transitions": len(steps), "fault": fault,
            "mismatched_fields": findings, "trace": steps}
