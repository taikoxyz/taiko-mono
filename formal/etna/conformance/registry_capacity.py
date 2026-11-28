"""Independent accounting and raw-trace replay for the current Registry capacity model."""
from copy import deepcopy
from dataclasses import dataclass
import json
import re

from current_spec import CURRENT_BUNDLE, DOCUMENT_PATHS, MANIFEST_PATH
from current_spec import classify_workspace_documents, select_claim
from registry_vacancy_observer import trace_states

SUPPLY = 7
STAKE = 4
IDS = (0, 1, 2)
SLOTS = (0, 1)
OWNER, PUBLIC, DAO = 1, 2, 3
NO_EXIT = 11


@dataclass(frozen=True)
class Profile:
    max_time: int = 7
    penalties: bool = True
    reporter_recycle: bool = True
    sink_recycle: bool = False
    landing: bool = True
    record_calls: bool = True
    probe: str = "None"


def minimum_stake(total_supply: int, slots: int) -> int:
    """Return the smallest integer stake whose product with slots exceeds supply."""
    if type(total_supply) is not int or type(slots) is not int:
        raise TypeError("supply and slots must be exact integers")
    if total_supply < 0 or slots <= 0:
        raise ValueError("supply must be nonnegative and slots must be positive")
    return total_supply // slots + 1


def reviewed_source(workspace):
    documents = {path: (workspace / path).read_bytes() for path in DOCUMENT_PATHS}
    workspace_source = classify_workspace_documents(
        documents, json.loads(MANIFEST_PATH.read_bytes()))
    if workspace_source["bundleId"] != CURRENT_BUNDLE:
        raise ValueError("W03 requires the exact current source bundle")
    return {"workspace": workspace_source, "claim": select_claim(
        CURRENT_BUNDLE, "registry-supply-model", "bounded-recycling")}


def _empty_bond():
    return dict(issued=False, withdrawn=False, key=0, owner=0, eff=0, pending=0,
                active=0, exit=0, confirmed=0, holds=False, slot=0, ready=0,
                topupUsed=False, forfeited=False, sinkPaid=0)


def _empty_selection():
    return {"at": 0, "powers": dict.fromkeys(IDS, 0)}


def initial_state():
    return dict(now=1, nextId=0, slots={slot: dict(occupied=False, bond=0) for slot in SLOTS},
                bonds={bond: _empty_bond() for bond in IDS},
                cash=dict(liquid=SUPPLY, reporter=0, sink=0), coverage=0,
                closed=_empty_selection(), recoveredAt=0, recovery=_empty_selection(),
                landedAt=0)


def _call(kind, bond=0, actor=0, key=0, amount=0, snapshot=0):
    return dict(kind=kind, bond=bond, actor=actor, key=key, amount=amount, snapshot=snapshot)


def _balance(bond):
    return bond["eff"] + bond["pending"]


def _live(bond):
    return bond["issued"] and not bond["withdrawn"]


def _held(state):
    return [state["bonds"][entry["bond"]] for entry in state["slots"].values()
            if entry["occupied"]]


def _selection(state):
    time = state["now"]
    powers = dict.fromkeys(IDS, 0)
    for entry in state["slots"].values():
        if entry["occupied"]:
            bond = state["bonds"][entry["bond"]]
            if bond["active"] <= time < bond["exit"]:
                powers[entry["bond"]] = bond["eff"]
    return dict(at=time, powers=powers)


class OutOfProfile(ValueError):
    """The normalized experiment does not offer this input."""


def offered_calls(state, profile):
    """Derive offered inputs separately from their eligibility and effects."""
    calls = [_call("Register", actor=OWNER, key=key, amount=STAKE)
             for key in IDS if key <= state["nextId"]]
    if state["now"] < profile.max_time:
        calls.append(_call("Tick"))
    if not state["coverage"] and state["closed"]["at"]:
        calls.append(_call("Start", snapshot=state["closed"]["at"]))
    if state["coverage"] and not state["recoveredAt"]:
        calls.append(_call("Recover", snapshot=state["now"]))
    if profile.landing and state["recovery"]["at"] and not state["landedAt"]:
        calls.append(_call("Land", snapshot=state["recovery"]["at"]))
    for account, enabled in (("reporter", profile.reporter_recycle), ("sink", profile.sink_recycle)):
        amount = state["cash"][account]
        if enabled and amount:
            calls.append(_call("Recycle" + account.title(), amount=amount))
    for identity, bond in state["bonds"].items():
        if not _live(bond):
            continue
        if not bond["topupUsed"]:
            calls.append(_call("TopUp", bond=identity, actor=OWNER, amount=1))
        calls.extend((_call("Activate", bond=identity, actor=PUBLIC),
                      _call("Exit", bond=identity, actor=OWNER),
                      _call("Confirm", bond=identity, actor=PUBLIC)))
        calls.extend(_call("Withdraw", bond=identity, actor=actor) for actor in (OWNER, PUBLIC))
        if profile.penalties and state["coverage"]:
            calls.extend((_call("Slash", bond=identity, actor=PUBLIC),
                          _call("Forfeit", bond=identity, actor=DAO, key=bond["key"])))
    return calls


def _require(condition, detail):
    if not condition:
        raise ValueError(detail)


def _differences(expected, actual, path=()):
    if type(expected) is not type(actual):
        return [path]
    if isinstance(expected, dict):
        if expected.keys() != actual.keys():
            return [path]
        return [delta for key in expected
                for delta in _differences(expected[key], actual[key], (*path, key))]
    return [] if expected == actual else [path]


def expected_transition(pre, call, profile):
    """Derive the literal outcome and every next-state field from a raw call."""
    if all(_differences(offer, call) for offer in offered_calls(pre, profile)):
        raise OutOfProfile(f"input outside capacity profile {call}")
    kind = call["kind"]
    index = call["bond"]
    old = pre["bonds"][index]
    balance = _balance(old)
    time = pre["now"]
    post = deepcopy(pre)
    bond = post["bonds"][index]
    cash = post["cash"]
    if kind == "Register":
        holes = [slot for slot in SLOTS if not pre["slots"][slot]["occupied"]]
        new_id = pre["nextId"]
        if call["key"] != new_id or not holes or cash["liquid"] < STAKE:
            return False, post
        slot = holes[0]
        post["bonds"][new_id].update(issued=True, key=new_id, owner=OWNER, eff=STAKE,
                                     active=time + 1, exit=NO_EXIT, holds=True, slot=slot)
        post["slots"][slot] = dict(occupied=True, bond=new_id)
        post["nextId"] += 1
        cash["liquid"] -= STAKE
    elif kind == "Tick":
        if not pre["coverage"]:
            post["closed"] = _selection(pre)
        if pre["recoveredAt"] == time:
            post["recovery"] = _selection(pre)
        post["now"] += 1
    elif kind == "Start":
        if not any(pre["closed"]["powers"].values()):
            return False, post
        post["coverage"] = call["snapshot"]
    elif kind == "Recover":
        post["recoveredAt"] = call["snapshot"]
    elif kind == "Land":
        if not any(pre["recovery"]["powers"].values()):
            return False, post
        post["coverage"] = call["snapshot"]
        post["landedAt"] = time
    elif kind in ("RecycleReporter", "RecycleSink"):
        account = "reporter" if kind == "RecycleReporter" else "sink"
        cash[account] -= call["amount"]
        cash["liquid"] += call["amount"]
    elif kind == "TopUp":
        if time < old["active"] or not old["eff"] or old["exit"] != NO_EXIT or old["pending"] or cash["liquid"] < 1:
            return False, post
        cash["liquid"] -= 1
        bond.update(pending=1, ready=time + 1, topupUsed=True)
    elif kind == "Activate":
        if not old["pending"] or time < old["ready"] or old["exit"] != NO_EXIT:
            return False, post
        bond.update(eff=balance, pending=0, ready=0)
    elif kind == "Exit":
        if old["exit"] != NO_EXIT:
            return False, post
        bond["exit"] = max(time, old["active"]) + 1
    elif kind == "Slash":
        if not balance:
            return False, post
        bounty, _ = divmod(balance, 4)
        sink_share = balance - bounty
        cash["reporter"] += bounty
        cash["sink"] += sink_share
        bond.update(eff=0, pending=0, ready=0, exit=min(old["exit"], time),
                    sinkPaid=old["sinkPaid"] + sink_share)
    elif kind == "Forfeit":
        if not balance or old["forfeited"]:
            return False, post
        half, remainder = divmod(balance, 2)
        penalty = half + remainder
        eff_debit = min(old["eff"], penalty)
        pending = old["pending"] - (penalty - eff_debit)
        bond.update(eff=old["eff"] - eff_debit, pending=pending,
                    ready=old["ready"] if pending else 0, exit=min(old["exit"], time),
                    forfeited=True, sinkPaid=old["sinkPaid"] + penalty)
        cash["sink"] += penalty
    elif kind == "Confirm":
        if old["exit"] > pre["coverage"]:
            return False, post
        if not old["confirmed"]:
            bond["confirmed"] = time
    elif kind == "Withdraw":
        if (not old["confirmed"] or time <= old["confirmed"]
                or (balance and call["actor"] != old["owner"])):
            return False, post
        cash["liquid"] += balance
        post["slots"][old["slot"]] = dict(occupied=False, bond=0)
        bond.update(withdrawn=True, owner=0, eff=0, pending=0, confirmed=0,
                    holds=False, slot=0, ready=0)
    else:
        raise ValueError(f"unknown offered capacity operation {kind}")
    return True, post


def _check_ledger(state, profile):
    amounts = [*state["cash"].values()]
    held = _held(state)
    for identity, bond in state["bonds"].items():
        amounts.extend((bond["eff"], bond["pending"]))
        _require(bond["issued"] is (identity < state["nextId"]), "lifetime issuance mismatch")
        _require(not bond["issued"] or bond["key"] == identity, "lifetime key mismatch")
        _require(bond["holds"] is _live(bond), "issued unwithdrawn bond lost its slot")
        if bond["holds"]:
            _require(state["slots"][bond["slot"]] == dict(occupied=True, bond=identity),
                     "bond and slot presence mismatch")
        else:
            _require(_balance(bond) == 0, "principal outside an occupied slot")
        if bond["confirmed"]:
            _require(bond["exit"] <= state["coverage"] and bond["confirmed"] <= state["now"],
                     "recorded confirmation without landed coverage")
    for slot, entry in state["slots"].items():
        if entry["occupied"]:
            bond = state["bonds"][entry["bond"]]
            _require(bond["holds"] and bond["slot"] == slot, "slot has no matching holder")
        else:
            _require(entry["bond"] == 0, "vacant slot retained a bond id")
    _require(all(type(value) is int and value >= 0 for value in amounts), "negative or invalid balance")
    _require(sum(amounts) == SUPPLY, "circulating and held funds do not sum to supply")
    if len(held) == len(SLOTS):
        _require(any(_balance(bond) < STAKE for bond in held), "all registered principal intact")
        _require(profile.penalties, "unpenalized profile saturated")
        if not profile.sink_recycle:
            held_or_sink = sum(_balance(bond) + bond["sinkPaid"] for bond in held)
            _require(4 * held_or_sink > 3 * SUPPLY, "no-return strict sink share failed")
    if not profile.sink_recycle:
        paid = sum(bond["sinkPaid"] for bond in state["bonds"].values())
        _require(paid == state["cash"]["sink"], "sink provenance differs from account")


# These names select the interpretation of an observed profile, never its actions.
PROFILES = {
    "smoke": (Profile(2, sink_recycle=True, record_calls=False), None),
    "no-penalty": (Profile(7, penalties=False, reporter_recycle=False, record_calls=False), None),
    "reporter-saturation": (Profile(3, probe="Reporter"), "ReporterSaturationNotReached"),
    "sink-saturation": (Profile(3, reporter_recycle=False, sink_recycle=True, probe="Sink"),
                        "SinkSaturationNotReached"),
    "funded-full-refusal": (Profile(3, reporter_recycle=False, sink_recycle=True, probe="Funded"),
                            "FundedFullRefusalNotReached"),
    "stalled-release": (Profile(7, landing=False, probe="Stalled"), "StalledReleaseNotReached"),
    "covered-release": (Profile(6, probe="Progress"), "CoveredReleaseNotReached"),
    "pending-withdrawal": (Profile(6, reporter_recycle=False, sink_recycle=True, probe="Pending"),
                           "PendingWithdrawalNotReached"),
}


def _initial_marks(profile):
    return dict(profile=dict(maxTime=profile.max_time, penalties=profile.penalties,
                             reporter=profile.reporter_recycle, sink=profile.sink_recycle,
                             landing=profile.landing, record=profile.record_calls, probe=profile.probe),
                reporter=False, sink=False, funded=False, stallConfirm=False, stallWithdraw=False,
                stallFull=False, early=False, released=False, unfunded=False,
                positiveDenied=False, positivePaid=False)


def _canonical_full(state):
    return state["slots"] == {slot: dict(occupied=True, bond=slot) for slot in SLOTS}


def _reporter_shape(state):
    a, b = state["bonds"][0], state["bonds"][1]
    return (_canonical_full(state) and state["cash"] == dict(liquid=0, reporter=0, sink=3)
            and (a["eff"], a["pending"], a["sinkPaid"]) == (0, 0, 3)
            and (b["eff"], b["pending"], b["exit"]) == (4, 0, NO_EXIT))


def _sink_shape(state):
    a, b = state["bonds"][0], state["bonds"][1]
    return (_canonical_full(state) and state["cash"] == dict(liquid=1, reporter=0, sink=0)
            and a["forfeited"] and a["exit"] < NO_EXIT
            and (a["eff"], a["pending"], a["sinkPaid"]) == (2, 0, 2)
            and (b["eff"], b["pending"], b["exit"]) == (4, 0, NO_EXIT))


def _stalled_gap(state):
    exit_at = state["bonds"][0]["exit"]
    origin = state["recoveredAt"]
    return (_reporter_shape(state) and state["closed"]["at"] == state["coverage"] < exit_at <= origin
            and not state["landedAt"] and state["now"] >= origin + 3
            and state["bonds"][0]["confirmed"] == 0
            and state["recovery"] == dict(at=origin, powers={0: 0, 1: 4, 2: 0}))


def _covered_gap(state):
    a = state["bonds"][0]
    origin = state["recoveredAt"]
    return (state["closed"]["at"] < a["exit"] <= state["coverage"] == origin
            and origin < state["landedAt"] <= a["confirmed"]
            and state["recovery"] == dict(at=origin, powers={0: 0, 1: 4, 2: 0}))


def _step_marks(marks, pre, last, post):
    updated = deepcopy(marks)
    probe = marks["profile"]["probe"]
    call, accepted = last["call"], last["accepted"]
    kind, bid, actor = call["kind"], call["bond"], call["actor"]
    fresh = kind == "Register" and call["key"] == pre["nextId"]
    if probe == "Reporter":
        updated["reporter"] |= accepted and fresh and call["key"] == 1 and (
            pre["cash"]["liquid"] == 4 and _reporter_shape(post))
    elif probe == "Sink":
        updated["sink"] |= accepted and fresh and call["key"] == 1 and (
            pre["cash"]["liquid"] == 5 and _sink_shape(post))
    elif probe == "Funded":
        updated["funded"] |= (not accepted and fresh and pre["cash"]["liquid"] >= 4
                              and all(place["occupied"] for place in pre["slots"].values()))
    elif probe == "Stalled" and not accepted and _stalled_gap(pre):
        updated["stallConfirm"] |= kind == "Confirm" and bid == 0
        updated["stallWithdraw"] |= kind == "Withdraw" and bid == 0 and actor == PUBLIC
        updated["stallFull"] |= fresh
    elif probe == "Progress":
        confirmed = pre["bonds"][0]["confirmed"]
        if kind == "Withdraw" and bid == 0 and actor == PUBLIC and _reporter_shape(pre) and _covered_gap(pre):
            updated["early"] |= not accepted and pre["now"] == confirmed
            updated["released"] |= accepted and pre["now"] > confirmed
        if (marks["released"] and not accepted and fresh and not pre["slots"][0]["occupied"]
                and pre["slots"][1] == dict(occupied=True, bond=1)
                and pre["cash"] == dict(liquid=0, reporter=0, sink=3)):
            updated["unfunded"] = True
    elif probe == "Pending":
        a = pre["bonds"][0]
        if (kind == "Withdraw" and bid == 0 and _canonical_full(pre) and _covered_gap(pre)
                and pre["now"] > a["confirmed"] and a["forfeited"]
                and (a["eff"], a["pending"]) == (1, 1)):
            updated["positiveDenied"] |= not accepted and actor == PUBLIC
            updated["positivePaid"] |= marks["positiveDenied"] and accepted and actor == OWNER
    return updated


def _observed(steps, kind, *, accepted=True, **inputs):
    for index, (pre, last, post) in enumerate(steps):
        call = last["call"]
        if last["accepted"] is accepted and call["kind"] == kind and all(
                call[field] == value for field, value in inputs.items()):
            yield index, pre, post


def _ordered(steps, *actions):
    """Require executed edges in order. Each action supplies its own PRE/POST test."""
    earlier = -1
    for kind, attributes, predicate in actions:
        candidate = next((i for i, pre, post in _observed(steps, kind, **attributes)
                          if i > earlier and predicate(pre, post)), None)
        _require(candidate is not None, f"witness has no required {kind} edge")
        earlier = candidate


def _qualify_witness(case, steps, marks):
    # Check the terminal conjunction and independently require its causal edges.
    # Rejected attempts count only when the raw input and surrounding state fit.
    if case == "reporter-saturation":
        _require(marks["reporter"] and not list(_observed(steps, "RecycleSink")),
                 "reporter-only endpoint missing")
        _ordered(steps,
                 ("Slash", {"bond": 0}, lambda p, q: _balance(p["bonds"][0]) == 4
                  and q["cash"] == dict(liquid=3, reporter=1, sink=3) and q["slots"][0]["occupied"]),
                 ("RecycleReporter", {"amount": 1}, lambda p, q: p["cash"]["reporter"] == 1
                  and q["cash"] == dict(liquid=4, reporter=0, sink=3)),
                 ("Register", {"key": 1, "amount": 4}, lambda p, q: _reporter_shape(q)))
    elif case == "sink-saturation":
        _require(marks["sink"] and not list(_observed(steps, "RecycleReporter")),
                 "sink-only endpoint missing")
        _ordered(steps,
                 ("Forfeit", {"bond": 0}, lambda p, q: _balance(p["bonds"][0]) == 4
                  and q["cash"] == dict(liquid=3, reporter=0, sink=2)
                  and q["bonds"][0]["eff"] == 2 and q["slots"][0]["occupied"]),
                 ("RecycleSink", {"amount": 2}, lambda p, q: p["cash"]["sink"] == 2
                  and q["cash"] == dict(liquid=5, reporter=0, sink=0)),
                 ("Register", {"key": 1, "amount": 4}, lambda p, q: _sink_shape(q)))
    elif case == "funded-full-refusal":
        _require(marks["funded"], "funded full refusal missing")
        _require(any(pre == post and pre["cash"]["liquid"] >= 4
                     and all(entry["occupied"] for entry in pre["slots"].values())
                     and steps[i][1]["call"]["key"] == pre["nextId"]
                     for i, pre, post in _observed(steps, "Register", accepted=False, amount=4)),
                 "no attempted funded fresh registration at full capacity")
    elif case == "stalled-release":
        _require(marks["stallConfirm"] and marks["stallWithdraw"] and marks["stallFull"],
                 "stalled release endpoint missing")
        _require(not list(_observed(steps, "Land")), "stalled witness contains a landing")
        for kind, attributes in (("Confirm", {"bond": 0, "actor": PUBLIC}),
                                 ("Withdraw", {"bond": 0, "actor": PUBLIC}),
                                 ("Register", {"amount": 4})):
            _require(any(_stalled_gap(pre) and pre == post
                         and (kind != "Register" or steps[i][1]["call"]["key"] == pre["nextId"])
                         for i, pre, post in _observed(steps, kind, accepted=False, **attributes)),
                     f"no concrete stalled {kind} refusal")
        _require(any(pre["coverage"] == post["coverage"] < post["recoveredAt"]
                     and _reporter_shape(post)
                     for _, pre, post in _observed(steps, "Recover")),
                 "no actual recovery from reporter-saturated topology")
    elif case == "covered-release":
        _require(marks["early"] and marks["released"] and marks["unfunded"], "covered release incomplete")
        _ordered(steps,
                 ("Recover", {}, lambda p, q: _reporter_shape(q)
                  and p["coverage"] == q["coverage"] < q["bonds"][0]["exit"] <= q["recoveredAt"]),
                 ("Land", {}, lambda p, q: p["coverage"] < p["bonds"][0]["exit"] <= q["coverage"]
                  and q["coverage"] == q["recoveredAt"]
                  and q["recovery"] == dict(at=q["recoveredAt"], powers={0: 0, 1: 4, 2: 0})),
                 ("Confirm", {"bond": 0}, lambda p, q: not p["bonds"][0]["confirmed"]
                  and _covered_gap(q) and q["bonds"][0]["confirmed"] == q["now"]),
                 ("Withdraw", {"bond": 0, "actor": PUBLIC, "accepted": False},
                  lambda p, q: _reporter_shape(p) and _covered_gap(p)
                  and p == q and p["now"] == p["bonds"][0]["confirmed"]),
                 ("Withdraw", {"bond": 0, "actor": PUBLIC},
                  lambda p, q: _reporter_shape(p) and _covered_gap(p)
                  and p["now"] > p["bonds"][0]["confirmed"] and not q["slots"][0]["occupied"]
                  and q["bonds"][0]["withdrawn"] and q["bonds"][0]["key"] == 0
                  and p["cash"] == q["cash"]),
                 ("Register", {"key": 2, "amount": 4, "accepted": False}, lambda p, q: p == q
                  and not p["slots"][0]["occupied"] and p["cash"]["liquid"] == 0))
    elif case == "pending-withdrawal":
        _require(marks["positiveDenied"] and marks["positivePaid"], "positive withdrawal incomplete")
        _ordered(steps,
                 ("TopUp", {"bond": 0, "amount": 1}, lambda p, q: q["bonds"][0]["pending"] == 1
                  and q["cash"]["liquid"] == p["cash"]["liquid"] - 1),
                 ("Forfeit", {"bond": 0}, lambda p, q: p["bonds"][0]["pending"] == 1
                  and q["bonds"][0]["eff"] == q["bonds"][0]["pending"] == 1),
                 ("Land", {}, lambda p, q: p["coverage"] < p["bonds"][0]["exit"] <= q["coverage"]),
                 ("Withdraw", {"bond": 0, "actor": PUBLIC, "accepted": False},
                  lambda p, q: p == q and _covered_gap(p) and p["now"] > p["bonds"][0]["confirmed"]
                  and _balance(p["bonds"][0]) == 2),
                 ("Withdraw", {"bond": 0, "actor": OWNER}, lambda p, q: _covered_gap(p)
                  and p["now"] > p["bonds"][0]["confirmed"] and _balance(p["bonds"][0]) == 2
                  and q["cash"]["liquid"] == p["cash"]["liquid"] + 2
                  and not q["slots"][0]["occupied"] and _balance(q["bonds"][0]) == 0))
    else:
        raise ValueError(f"no selected capacity witness {case}")


def _fault_shape(fault, pre, last, post, expected, allowed):
    call = last["call"]
    if fault == "premature-confirm":
        bond_id = call["bond"]
        bond = pre["bonds"][bond_id]
        forged = deepcopy(pre)
        forged["bonds"][bond_id]["confirmed"] = pre["now"]
        _require(call["kind"] == "Confirm" and last["accepted"] is True and allowed is False
                 and expected == pre and pre["coverage"] < bond["exit"] <= pre["recoveredAt"]
                 and pre["recovery"]["at"] in (0, pre["recoveredAt"]) and pre["landedAt"] == 0
                 and not bond["confirmed"] and not _differences(forged, post), "wrong premature confirmation effect")
    elif fault == "reporter-no-debit":
        _require(call["kind"] == "RecycleReporter" and last["accepted"] is True and allowed is True
                 and pre["cash"]["reporter"] > 0 and post["cash"]["reporter"] == pre["cash"]["reporter"]
                 and _differences(expected, post) == [("cash", "reporter")],
                 "wrong reporter debit fault effect")
    else:
        raise ValueError(f"unknown capacity source fault {fault}")


def audit_trace(log, case, *, fault=None, simulation_seed=None):
    """Audit an actual named TLC trace and reject mismatched case or fault metadata."""
    profile, witness = PROFILES[case]
    invariant = "FramesExact" if fault else witness
    _require(profile.record_calls and invariant is not None, "case has no trace contract")
    errors = re.findall(r"^Error: (.*)$", log, re.MULTILINE)
    _require(errors == [f"Invariant {invariant} is violated.", "The behavior up to this point is:"],
             "unexpected checker outcome")
    states = trace_states(log, simulation_seed=simulation_seed)
    initial = dict(r=initial_state(), last=dict(call=_call("None"), accepted=False),
                   marks=_initial_marks(profile), frameOK=True)
    _require(not _differences(initial, states[0]), "incorrect initial state or expected profile")
    steps = []
    findings = []
    for before, after in zip(states, states[1:]):
        pre, last, post = before["r"], after["last"], after["r"]
        _require(set(last) == {"call", "accepted"} and type(last["accepted"]) is bool,
                 "invalid raw capacity call record")
        allowed, expected = expected_transition(pre, last["call"], profile)
        matches = allowed is last["accepted"] and not _differences(expected, post)
        _require(after["frameOK"] is matches, "reported frame check differs from independent replay")
        _require(not _differences(_step_marks(before["marks"], pre, last, post), after["marks"]),
                 "reported witness frame differs from independent replay")
        if matches:
            _check_ledger(post, profile)
        else:
            _require(fault is not None and after is states[-1], "unexpected or earlier frame error")
            _fault_shape(fault, pre, last, post, expected, allowed)
            findings = _differences(expected, post)
        steps.append((pre, last, post))
    _require(steps, "trace has no executed inputs")
    if fault:
        _require(findings, "trace never hit the intended balance or snapshot fault")
    else:
        _qualify_witness(case, steps, states[-1]["marks"])
    return {"invariant": invariant, "fault": fault, "case": case, "transitions": len(steps),
            "mismatched_fields": findings, "trace": steps}
