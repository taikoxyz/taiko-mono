"""Current positional Registry byte vectors and complete selected recovery histories."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

from boundary_scope import require_healthy_native, require_tlc_argv, reviewed_boundary
from current_spec import _unique_object
from proving_recovery import ASSIGN, FOOTER, STATE, Reader, same
from run_comet_apphash import keccak256

CLAIM = "registry-origin-selection"
PRODUCT = "registry-recovery-snapshot"
MODULE = "EtnaRegistryRecoverySnapshot.tla"
TLC_BANNER = "TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)"
INVARIANTS = {"smoke": "NoSmoke", "progress": "NoProgress", "recover-first": "NoRecoverFirst",
              "activate-first": "NoActivateFirst", "closed-hole": "NoClosedHole",
              "closed-hole-progress": "NoProgress"}
Q, CHAIN_ID, NO_EXIT = 10**23, 167001, 2**48 - 1
MAX_POWER = (2**63 - 1) // 8
EMPTY = (0, 0, 0, 0, 0)
PUBLIC_KEYS = (
    (2, 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798),
    (2, 0xC6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5),
    (2, 0xF9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9),
)
KINDS = {"register", "exit", "terminal-land", "confirm", "withdraw", "topup", "activate",
         "recover", "close", "tick", "land"}
STRING_TOKENS = re.compile(r'\s*(<<|>>|\|->|:>|@@|[\[\](){},]|-?\d+|"(?:[^"\\]|\\["\\ntfr])*"|[A-Za-z_]\w*)')


def _need(condition, message):
    if not condition:
        raise ValueError(message)


def _uint(value, bits, label, minimum=0):
    _need(type(value) is int and minimum <= value < 1 << bits, "invalid " + label)
    return value


def _word(value):
    return value.to_bytes(32, "big")


def _abi_tag(tag, fields):
    data = tag.encode("ascii")
    _need(len(data) <= 32, "domain tag exceeds bytes32")
    return data.ljust(32, b"\0") + b"".join(map(_word, fields))


def _entries(entries, width):
    _uint(width, 48, "authenticated width")
    _need(width <= 4096 and type(entries) is tuple and len(entries) == width,
          "entries do not match authenticated width")
    for row in entries:
        _need(type(row) is tuple and len(row) == 5, "entry must be a closed five-word tuple")
        prefix, x, stake, active, exit_at = row
        _uint(prefix, 8, "key prefix")
        _uint(x, 256, "key X")
        _uint(stake, 256, "effective stake")
        _uint(active, 48, "activation block")
        _uint(exit_at, 48, "effective exit")
        _need(row == EMPTY or prefix in (2, 3), "nonempty slot lacks a compressed key")
    return entries


def entries_root(entries: tuple, width: int) -> bytes:
    """Hash every authenticated position; only power-of-two padding is raw zero."""
    rows = _entries(entries, width)
    if not rows:
        return bytes(32)
    nodes = [keccak256(_abi_tag("ETNA_REG_ENTRY_V1", (slot, *row)))
             for slot, row in enumerate(rows)]
    nodes.extend([bytes(32)] * ((1 << (width - 1).bit_length()) - width))
    while len(nodes) > 1:
        nodes = [keccak256(nodes[j] + nodes[j + 1]) for j in range(0, len(nodes), 2)]
    return nodes[0]


def encode_checkpoint(l1_block: int, width: int, entries: tuple) -> bytes:
    """Encode the two checkpoint storage words under STOR-B-21/23/24."""
    _uint(l1_block, 48, "checkpoint block")
    root = entries_root(entries, width)
    return _word(l1_block | (width << 48)) + root


def encode_entry(entry: tuple) -> bytes:
    """Encode exactly the three positional entry storage words."""
    row = _entries((entry,), 1)[0]
    prefix, x, stake, active, exit_at = row
    return _word(x) + _word(stake) + _word(prefix | (active << 8) | (exit_at << 56))


def _set_key(key, chain_id):
    return keccak256(_abi_tag("ETNA_SET_KEY_V1", (chain_id, *key)))


def select_committee(entries, snapshot, s_min, vp_unit, n_max, chain_id):
    """Select/rank/encode a component set; deployment/governance is not asserted."""
    _need(type(entries) is tuple, "entries must be a positional tuple")
    rows = _entries(entries, len(entries))
    _uint(snapshot, 48, "selection snapshot")
    _uint(s_min, 256, "selection minimum", 1)
    _uint(vp_unit, 256, "voting power unit", 1)
    _uint(n_max, 48, "committee limit", 1)
    _uint(chain_id, 256, "L2 chain id")
    eligible = [row for row in rows if row != EMPTY and row[3] <= snapshot < row[4]
                and row[2] >= max(s_min, vp_unit)]
    _need(len({row[:2] for row in eligible}) == len(eligible), "duplicate eligible consensus key")
    ranked = sorted(eligible, key=lambda row: (-row[2], _set_key(row[:2], chain_id)))[:n_max]
    result = tuple((*row[:3], row[2] // vp_unit)
                   for row in sorted(ranked, key=lambda row: _set_key(row[:2], chain_id)))
    _need(result and all(0 < row[3] < 2**64 for row in result)
          and sum(row[3] for row in result) <= MAX_POWER, "invalid empty or overflowing selected set")
    return result


class _Reader(Reader):
    def token(self, advance=True):
        match = STRING_TOKENS.match(self.text, self.pos)
        _need(match is not None, "unexpected end of Registry TLC value")
        if advance:
            self.pos = match.end()
        return match[1]

    def value(self):
        if self.token(False).startswith('"'):
            return json.loads(self.token())
        return super().value()


def trace_packets(text):
    footer = FOOTER.search(text)
    body = text[:footer.start()] if footer else text
    markers = list(STATE.finditer(body))
    _need(markers, "missing Registry TLC states")
    for index, marker in enumerate(markers):
        _need(int(marker[1]) == index + 1, "nonconsecutive Registry state")
        end = markers[index + 1].start() if index + 1 < len(markers) else len(body)
        chunk = body[marker.end():end]
        assignments = list(ASSIGN.finditer(chunk))
        _need(assignments and not chunk[:assignments[0].start()].strip(), "unexpected Registry state prelude")
        fields = {}
        for j, assignment in enumerate(assignments):
            name = assignment[1]
            _need(name not in fields, "duplicate Registry variable")
            stop = assignments[j + 1].start() if j + 1 < len(assignments) else len(chunk)
            reader = _Reader(chunk[assignment.end():stop])
            fields[name] = reader.value()
            _need(not reader.text[reader.pos:].strip(), "trailing Registry native terms")
        yield fields


def _empty_entry():
    return dict(key=-1, eff=0, active=0, exit=0)


def _empty_bond():
    return dict(issued=False, withdrawn=False, key=-1, owner=0, eff=0, pending=0,
                ready=0, active=0, exit=0, confirmed=0, holds=False, slot=-1)


def _initial():
    empty_snapshot = dict(at=0, checkpointAt=0, width=2,
                          entries=(_empty_entry(), _empty_entry()))
    state = dict(now=1, nextId=0, slots=(-1, -1), bonds=tuple(_empty_bond() for _ in range(4)),
                 keys=(False, False, False), entryChangedAt=0,
                 snapshots=tuple(deepcopy(empty_snapshot) for _ in range(8)), closed=(False,) * 8,
                 activeSnapshot=0, generation=0, recoveryAt=0,
                 origin=dict(at=0, entries=(), members=()))
    marks = dict(invalid=(False, False, False), badLand=False, transientHole=False,
                 closedHole=False, order=(), atomic=True)
    return state, marks


def _replace(sequence, index, value):
    return sequence[:index] + (value,) + sequence[index + 1:]


def _positional(state):
    entries = []
    for identity in state["slots"]:
        if identity == -1:
            entries.append(_empty_entry())
        else:
            bond = state["bonds"][identity]
            entries.append({key: bond[key] for key in ("key", "eff", "active", "exit")})
    return tuple(entries)


def _key_map():
    ordered = sorted(PUBLIC_KEYS, key=lambda key: _set_key(key, CHAIN_ID))
    return {0: ordered[2], 1: ordered[0], 2: ordered[1]}


def _concrete(entries):
    keys = _key_map()
    return tuple(EMPTY if row["key"] == -1 else
                 (*keys[row["key"]], row["eff"] * Q, row["active"],
                  NO_EXIT if row["exit"] == 11 else row["exit"]) for row in entries)


def _members(entries, at):
    keys = _key_map()
    inverse = {value: key for key, value in keys.items()}
    chosen = select_committee(_concrete(entries), at, 4 * Q, 2 * Q, 1, CHAIN_ID)
    return tuple(dict(key=inverse[row[:2]], eff=row[2] // Q, power=row[3]) for row in chosen)


def _lists():
    return ((dict(bond=0, key=0),), (dict(bond=1, key=1), dict(bond=3, key=3)),
            (dict(bond=0, key=2),), (dict(bond=1, key=1), dict(bond=0, key=0)))


def _ready(state, marks, route):
    now, bonds = state["now"], state["bonds"]
    if now == 1:
        return state["nextId"] == 2
    if now == 2:
        return bonds[0]["exit"] == 3
    if now == 3:
        return True
    if now == 4:
        return bonds[0]["confirmed"] == 4
    if now == 5:
        return bonds[0]["withdrawn"] and (route == "closed-hole" or state["nextId"] == 3)
    if now == 6:
        return bonds[2]["pending"] == 1 if route == "main" else state["nextId"] == 3
    if now == 7:
        return (state["generation"] == 1 and marks["invalid"] == (True, True, True)
                and (bonds[2]["eff"] == 5 and bonds[1]["pending"] == 2 if route == "main"
                     else bonds[2]["pending"] == 1))
    return bonds[1]["eff"] == 6 if route == "main" else bonds[2]["eff"] == 5


def _transition(pre, before_marks, kind, args, route, *, wrong_occupant=False):
    """Derive whole business state and observer terms from literal offered inputs."""
    state, marks = deepcopy(pre), deepcopy(before_marks)
    now, bonds = pre["now"], pre["bonds"]
    _need(type(args) is tuple, "call arguments must be a sequence")
    if kind not in ("close", "tick"):
        _need(not pre["closed"][now - 1], kind + " requires an open block")
    accepted = True
    if kind == "register":
        _need(len(args) == 4 and all(type(value) is int for value in args), "register input shape")
        identity, actor, key, amount = args
        offered = (now == 1 and identity in (0, 1) and identity == pre["nextId"]
                   or identity == 2 and pre["nextId"] == 2 and bonds[0]["withdrawn"]
                   and now == (5 if route == "main" else 6))
        _need(offered and (actor, key, amount) == (identity + 1, identity, 4), "register offer")
        _need(-1 in pre["slots"] and not pre["keys"][key], "register admission")
        slot = pre["slots"].index(-1)
        bond = dict(_empty_bond(), issued=True, key=key, owner=actor, eff=amount,
                    active=now + 1, exit=11, holds=True, slot=slot)
        state.update(nextId=identity + 1, slots=_replace(pre["slots"], slot, identity),
                     bonds=_replace(bonds, identity, bond), keys=_replace(pre["keys"], key, True))
    elif kind == "exit":
        _need(same(args, (0, 1)) and now == 2 and bonds[0]["issued"] and bonds[0]["exit"] == 11,
              "exit offer/owner")
        state["bonds"] = _replace(bonds, 0, dict(bonds[0], exit=max(now, bonds[0]["active"]) + 1))
    elif kind == "terminal-land":
        _need(same(args, (3,)) and now == 4 and pre["closed"][2] and pre["activeSnapshot"] == 0,
              "terminal landing offer/closed snapshot")
        state["activeSnapshot"] = 3
    elif kind == "confirm":
        _need(same(args, (0, 4)) and now == 4 and pre["activeSnapshot"] >= bonds[0]["exit"]
              and bonds[0]["confirmed"] == 0, "confirm offer/coverage")
        state["bonds"] = _replace(bonds, 0, dict(bonds[0], confirmed=now))
    elif kind == "withdraw":
        _need(same(args, (0, 1)) and now == 5 and bonds[0]["confirmed"] == 4
              and not bonds[0]["withdrawn"], "withdraw offer/owner/delay")
        old = bonds[0]
        withdrawn = dict(old, withdrawn=True, owner=0, eff=0, pending=0, ready=0,
                         confirmed=0, holds=False, slot=-1)
        state.update(slots=_replace(pre["slots"], old["slot"], -1), bonds=_replace(bonds, 0, withdrawn))
        marks["transientHole"] = True
    elif kind == "topup":
        _need(len(args) == 3 and all(type(value) is int for value in args), "topup input shape")
        identity, actor, amount = args
        offered = (identity == 2 and amount == 1 and now == (6 if route == "main" else 7)
                   or route == "main" and identity == 1 and amount == 2 and now == 7)
        _need(offered and actor == identity + 1, "topup offer/owner")
        bond = bonds[identity]
        _need(bond["issued"] and not bond["withdrawn"] and bond["active"] <= now
              and bond["eff"] == 4 and bond["exit"] == 11 and bond["pending"] == 0,
              "topup lifecycle")
        state["bonds"] = _replace(bonds, identity, dict(bond, pending=amount, ready=now + 1))
    elif kind == "activate":
        _need(len(args) == 2 and type(args[0]) is int and args[0] in (1, 2)
              and same(args[1], 4), "activate actor/identity")
        identity, _ = args
        bond = bonds[identity]
        _need(bond["pending"] > 0 and bond["ready"] <= now and bond["exit"] == 11,
              "activate maturity/exit")
        state["bonds"] = _replace(bonds, identity, dict(bond, eff=bond["eff"] + bond["pending"],
                                                       pending=0, ready=0))
        if identity == 2 and now == 7:
            marks["order"] += ("activate",)
    elif kind == "recover":
        _need(len(args) == 2 and type(args[0]) is int and 1 <= args[0] <= 4
              and same(args[1], _lists()[args[0] - 1]), "recover fixed external list")
        index, exclusions = args
        _need(now == 7 and (pre["generation"] == 0 if index == 1
              else not before_marks["invalid"][index - 2]), "recover offer")
        accepted = (all(bonds[row["bond"]]["issued"] and bonds[row["bond"]]["key"] == row["key"]
                        for row in exclusions)
                    and all(left["bond"] < right["bond"] for left, right in zip(exclusions, exclusions[1:])))
        if accepted:
            updated = list(bonds)
            for row in exclusions:
                target = row["bond"]
                if wrong_occupant:
                    _need(index == 1 and bonds[0]["withdrawn"] and pre["slots"][0] == 2,
                          "wrong-occupant control premise")
                    target = pre["slots"][0]
                updated[target] = dict(updated[target], exit=min(updated[target]["exit"], now))
            state.update(bonds=tuple(updated), generation=1, recoveryAt=now)
            marks["order"] += ("recover",)
        else:
            marks["invalid"] = _replace(before_marks["invalid"], index - 2, True)
            marks["atomic"] = before_marks["atomic"] and same(pre, state)
    elif kind == "close":
        _need(same(args, (now,)) and not pre["closed"][now - 1] and _ready(pre, before_marks, route),
              "block close offer/lifecycle")
        rows = _positional(pre)
        snapshot = dict(at=now, checkpointAt=pre["entryChangedAt"], width=2, entries=rows)
        state.update(snapshots=_replace(pre["snapshots"], now - 1, snapshot),
                     closed=_replace(pre["closed"], now - 1, True))
        if pre["recoveryAt"] == now:
            state["origin"] = dict(at=now, entries=rows, members=_members(rows, now))
        marks["closedHole"] = before_marks["closedHole"] or (now == 5 and rows[0] == _empty_entry())
    elif kind == "tick":
        _need(args == () and now < 8 and pre["closed"][now - 1], "tick requires closed block")
        state["now"] = now + 1
    elif kind == "land":
        _need(len(args) == 1 and type(args[0]) is int and args[0] in (7, 8)
              and now == 8 and pre["origin"]["at"] == 7, "land terminal origin")
        accepted = args[0] == 7
        _need(pre["activeSnapshot"] == 3 if accepted else not before_marks["badLand"], "land offer")
        if accepted:
            state["activeSnapshot"] = 7
        else:
            marks["badLand"] = True
            marks["atomic"] = before_marks["atomic"] and same(pre, state)
    else:
        raise ValueError("unknown Registry call")
    if _positional(pre) != _positional(state):
        state["entryChangedAt"] = now
    return accepted, state, marks


def _done(state, marks):
    return (state["now"] == 8 and state["closed"][7] and state["activeSnapshot"] == 7
            and marks["badLand"] and marks["invalid"] == (True, True, True) and marks["transientHole"])


def audit(text: str, case: str) -> list[dict]:
    """Replay Init and every complete offered input, decision, state and observer frame."""
    _need(type(text) is str and case in INVARIANTS.keys() | {"wrong-occupant"}, "unknown Registry profile")
    require_healthy_native(text)
    route = "closed-hole" if case.startswith("closed-hole") else "main"
    packets = tuple(trace_packets(text))
    initial, initial_marks = _initial()
    events = []
    for index, packet in enumerate(packets):
        _need(type(packet) is dict and packet.keys() == {"s", "receipt", "marks"}, "Registry frame variables")
        state, receipt, marks = packet["s"], packet["receipt"], packet["marks"]
        if index == 0:
            _need(same(state, initial) and same(marks, initial_marks)
                  and same(receipt, dict(kind="init", args=(), accepted=True)), "Registry Init differs")
        else:
            _need(type(receipt) is dict and receipt.keys() == {"kind", "args", "accepted"}
                  and type(receipt["kind"]) is str and receipt["kind"] in KINDS
                  and type(receipt["accepted"]) is bool, "typed Registry receipt")
            kind, args = receipt["kind"], receipt["args"]
            fault = case == "wrong-occupant" and index == len(packets) - 1
            _need(not fault or kind == "recover", "wrong-occupant did not reach recovery")
            accepted, expected, wanted_marks = _transition(pre, previous_marks, kind, args, route,
                                                           wrong_occupant=fault)
            _need(receipt["accepted"] is accepted, kind + " decision differs")
            _need(same(state, expected), kind + " complete post-state differs")
            _need(same(marks, wanted_marks), kind + " complete observer frame differs")
            event = dict(kind=kind, args=args, accepted=accepted, pre=pre, post=state, marks=marks)
            if kind == "close":
                cp = state["snapshots"][args[0] - 1]
                concrete = _concrete(cp["entries"])
                event["checkpoint"] = encode_checkpoint(cp["checkpointAt"], cp["width"], concrete).hex()
                event["entryWords"] = tuple(encode_entry(row).hex() for row in concrete)
            events.append(event)
        pre, previous_marks = state, marks
    _need(events, "empty Registry history")
    endpoint = (pre["nextId"] == 2 if case == "smoke" else previous_marks["closedHole"]
                if case == "closed-hole" else events[-1]["kind"] == "recover" and pre["bonds"][2]["exit"] == 7
                if case == "wrong-occupant" else _done(pre, previous_marks))
    _need(endpoint, case + " Registry endpoint not reached")
    if case in ("recover-first", "activate-first"):
        order = ("recover", "activate") if case == "recover-first" else ("activate", "recover")
        _need(previous_marks["order"] == order, "selected same-R order not reached")
    return events


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _native_result(raw, case, cwd):
    text = raw.decode("utf-8")
    require_healthy_native(text)
    lines = text.splitlines()
    _need(lines[:1] == [TLC_BANNER] and lines.count(TLC_BANNER) == 1
          and lines.count("Semantic processing of module EtnaRegistryRecoverySnapshot") == 1,
          "unexpected TLC version/module identity")
    footer = FOOTER.search(text)
    _need(footer and len(re.findall(r"^Finished in ", text, re.M)) == 1
          and re.findall(r"^Parsing file (.*" + re.escape(MODULE) + r")$", text, re.M)
          == [str(Path(cwd) / MODULE)], "incomplete/unrelated Registry native transcript")
    errors = re.findall(r"^Error:[^\n]*$", text, re.M)
    if case != "safety":
        _need(errors == [f"Error: Invariant {INVARIANTS[case]} is violated.",
                         "Error: The behavior up to this point is:"], "wrong named Registry outcome")
        events = audit(text, case)
        return dict(outcome="NAMED_WITNESS_REPLAYED", transitions=len(events),
                    closedSnapshots=sum(event["kind"] == "close" for event in events))
    _need(not errors and not STATE.search(text)
          and text.count("Model checking completed. No error has been found.") == 1,
          "unexpected ordinary Registry outcome")
    count = re.match(r"([\d,]+) states generated, ([\d,]+) distinct states found, "
                     r"([\d,]+) states left on queue\.", footer[0])
    generated, distinct, queued = (int(value.replace(",", "")) for value in count.groups())
    _need(1 <= distinct <= generated and queued == 0, "Registry finite graph not exhausted")
    return dict(outcome="FINITE_SAFETY_EXHAUSTED", graph=dict(generated=generated, distinct=distinct, queued=queued))


def current_receipt(workspace_root: Path, case: str, raw: bytes, *, execution: bytes,
                    staged_model: Path, expected_claim=None) -> dict:
    """Bind fixed current claim to exact staged source, argv, capture and complete replay."""
    _need(expected_claim is None or expected_claim == CLAIM, "wrong expected Registry claim")
    _need(type(case) is str and case in INVARIANTS.keys() | {"safety"}, "unattributable Registry profile")
    _need(type(raw) is bytes and type(execution) is bytes, "Registry native/execution must be raw bytes")
    record = json.loads(execution.decode("utf-8"), object_pairs_hook=_unique_object)
    _need(type(record) is dict and record.keys() == {
        "schema", "case", "argv", "cwd", "returncode", "timedOut", "rawSha256", "inputSha256"}
          and record["schema"] == "etna-registry-snapshot-execution-1" and record["case"] == case,
          "Registry execution schema/case")
    _need(type(record["returncode"]) is int and record["returncode"] == (0 if case == "safety" else 12)
          and record["timedOut"] is False and record["rawSha256"] == _sha(raw), "Registry execution result")
    config = case + ".cfg"
    require_tlc_argv(record["argv"], config, MODULE)
    _need(record["cwd"] == "/tmp/etna-model", "Registry native cwd differs")
    formal = workspace_root / "formal/etna"
    expected = {MODULE: formal / MODULE, config: formal / "products" / PRODUCT / config}
    inputs = {name: _sha((staged_model / name).read_bytes()) for name in expected}
    _need(same(record["inputSha256"], inputs)
          and all(inputs[name] == _sha(path.read_bytes()) for name, path in expected.items()),
          "Registry staged source/capture/workspace differ")
    source = reviewed_boundary(workspace_root, CLAIM)
    return dict(source, case=case, **_native_result(raw, case, record["cwd"]),
                rawSha256=record["rawSha256"], executionSha256=_sha(execution), inputSha256=inputs,
                argv=record["argv"], cwd=record["cwd"], returncode=record["returncode"], timedOut=record["timedOut"])
