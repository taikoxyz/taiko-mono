"""Offline current timestamp schedule/recovery adapter and trace observations.

The inputs stand for authenticated L1/storage and valid block/proof data. This
module executes no RPC, signing, EVM or proof generation. Empty recovery lists
are the selected scope; a validated list's external effects are not modelled.
"""
from collections import namedtuple

U48 = (1 << 48) - 1
U256 = (1 << 256) - 1
Schedule = namedtuple("Schedule", "active next time stop")
Origin = namedtuple("Origin", "generation height number timestamp")
State = namedtuple("State", "schedule generation checkpoint nonce head fi_head active_snapshot origins initialized start_written")
Authorization = namedtuple("Authorization", "generation checkpoint nonce valid_until rules")
Decision = namedtuple("Decision", "rule outcome bft_time el_time")
Block = namedtuple("Block", "parent_time bft_time anchor_number anchor_time parent_anchor_number origin_number schedule rule timestamp first origin_time")

def require(condition, message):
    if not condition:
        raise ValueError(message)


def uint(value, bits=256):
    require(type(value) is int and 0 <= value < 1 << bits, "unsigned field width")
    return value


def flag(value):
    require(type(value) is bool, "Boolean context required")
    return value


def checked_schedule(schedule):
    require(type(schedule) is Schedule, "immutable four-field schedule required")
    for value in schedule:
        uint(value, 48)
    return schedule


def pack(schedule):
    checked_schedule(schedule)
    return sum(value << (48 * i) for i, value in enumerate(schedule))


def lead(now, max_age):
    uint(now)
    uint(max_age, 48)
    return uint(now + max_age)


def schedule_rules(schedule, *, rules, time, now, max_age, owner, initialized):
    checked_schedule(schedule)
    uint(rules, 48)
    uint(time, 48)
    earliest = lead(now, max_age)
    require(flag(owner) and flag(initialized), "schedule caller or initialization")
    require(now >= schedule.time or earliest < schedule.time, "pending rules locked")
    require(rules in (schedule.next, schedule.next + 1) and time >= earliest,
            "invalid next rule or activation lead")
    result = Schedule(schedule.next if now >= schedule.time else schedule.active,
                      rules, time, schedule.stop)
    return result, pack(result)

def schedule_stop(schedule, *, time, now, max_age, owner, initialized):
    checked_schedule(schedule)
    uint(time, 48)
    earliest = lead(now, max_age)
    require(flag(owner) and flag(initialized), "schedule caller or initialization")
    require(schedule.stop == 0 or earliest < schedule.stop, "pending stop locked")
    require(time == 0 or time >= earliest, "invalid stop lead")
    result = schedule._replace(stop=time)
    return result, pack(result)

def select_rule(schedule, timestamp):
    checked_schedule(schedule)
    uint(timestamp)
    return schedule.next if timestamp >= schedule.time else schedule.active

def candidate(schedule, *, parent_time, bft_time, anchor_number, anchor_time,
              parent_anchor_number, origin_number, max_age, supported, first, origin_time):
    checked_schedule(schedule)
    for value in (parent_time, bft_time, anchor_time, origin_time):
        uint(value)
    for value in (anchor_number, parent_anchor_number, origin_number, max_age):
        uint(value, 48)
    require(type(supported) is frozenset and all(type(r) is int and 0 <= r <= U48 for r in supported),
            "immutable supported rules required")
    flag(first)
    require(anchor_number >= origin_number and (first or anchor_number >= parent_anchor_number),
            "anchor regresses behind origin or parent")
    require(not first or bft_time == origin_time, "first BFT time differs from genesis")
    timestamp = uint(max(parent_time + 1, bft_time, anchor_time))
    require(timestamp - anchor_time <= max_age, "anchor too old for candidate")
    rule = select_rule(schedule, timestamp)
    outcome = ("WAIT" if rule not in supported else
               "STOP" if schedule.stop and parent_time >= schedule.stop else "ACCEPT")
    return Decision(rule, outcome, bft_time, timestamp)

def verify_blocks(blocks, supported, *, max_age):
    require(type(blocks) is tuple and bool(blocks), "immutable block observations required")
    result = []
    for block in blocks:
        require(type(block) is Block, "typed block observation required")
        actual = candidate(block.schedule, parent_time=block.parent_time, bft_time=block.bft_time,
                           anchor_number=block.anchor_number, anchor_time=block.anchor_time,
                           parent_anchor_number=block.parent_anchor_number, origin_number=block.origin_number,
                           max_age=max_age, supported=supported, first=block.first, origin_time=block.origin_time)
        require(type(block.rule) is int and type(block.timestamp) is int and
                actual.outcome == "ACCEPT" and (block.rule, block.timestamp) == (actual.rule, actual.el_time),
                "guest cannot prove this block under its historical schedule")
        result.append(actual.rule)
    return tuple(result)


def checked_state(state):
    require(type(state) is State, "immutable recovery state required")
    checked_schedule(state.schedule)
    for value in (state.generation, state.checkpoint, state.head, state.fi_head, state.active_snapshot):
        uint(value, 48)
    uint(state.nonce)
    flag(state.initialized)
    flag(state.start_written)
    require(state.head >= state.checkpoint, "head precedes settled checkpoint")
    require(type(state.origins) is tuple, "immutable origin records required")
    if not state.start_written:
        require(state.generation == 0 and state.origins == (), "unwritten start has no fixed origin")
        return state
    require(bool(state.origins), "written start requires its fixed origin")
    previous = -1
    for origin in state.origins:
        require(type(origin) is Origin, "typed fixed origin required")
        for value in origin[:3]:
            uint(value, 48)
        uint(origin.timestamp)
        require(previous < origin.generation <= state.generation, "duplicate or future origin")
        previous = origin.generation
    require(previous == state.generation, "current fixed origin missing")
    return state

def recover(state, authorization, *, owner, now, number):
    checked_state(state)
    require(type(authorization) is Authorization, "immutable external authorization required")
    for value in (authorization.generation, authorization.checkpoint, authorization.rules):
        uint(value, 48)
    uint(authorization.nonce)
    uint(authorization.valid_until)
    uint(now)
    uint(number, 48)
    require(flag(owner) and state.initialized and state.start_written, "recover caller or start")
    require((authorization.generation, authorization.checkpoint, authorization.nonce) ==
            (state.generation, state.checkpoint, state.nonce) and now <= authorization.valid_until,
            "stale or expired external authorization")
    generation = uint(state.generation + 1, 48)
    nonce = uint(state.nonce + 1)
    require(authorization.rules == 0 or authorization.rules == state.schedule.next + 1,
            "structural rules must advance next by one")
    schedule = (state.schedule._replace(stop=0) if authorization.rules == 0 else
                Schedule(authorization.rules, authorization.rules, 0, 0))
    result = state._replace(schedule=schedule, generation=generation, nonce=nonce,
                            head=state.checkpoint,
                            origins=state.origins + (Origin(generation, state.checkpoint, number, now),))
    return result, pack(schedule)

def invalidate(state, expected, *, owner):
    checked_state(state)
    uint(expected)
    require(flag(owner) and state.initialized and expected == state.nonce, "invalid nonce invalidation")
    return state._replace(nonce=uint(state.nonce + 1))

def require_progress(receipts):
    require(type(receipts) is list and bool(receipts), "no transition receipts")
    terminal = fresh = 0
    stopped = recovered = distinct = finalized = advanced = False
    operations = []
    previous = None
    for receipt in receipts:
        require(type(receipt) is dict and set(receipt) == {"operation", "input", "before", "after", "accepted"},
                "incomplete transition receipt")
        require(type(receipt["accepted"]) is bool, "invalid acceptance observation")
        k, a, pre, post, ok = (receipt[name] for name in ("operation", "input", "before", "after", "accepted"))
        require(previous is None or same(previous, pre), "disconnected transition sequence")
        check_offer("structural", pre, k, a)
        check_transition(pre, post, k, a, ok, (5, 4, 4, 1))
        previous = post
        operations.append((k, ok))
        if ok and k == 14 and pre["generation"] == 0:
            block = pre["jobs"][a[0]-1]["data"][-1]
            if block["anchor"]["schedule"]["stop"] and block["time"] >= block["anchor"]["schedule"]["stop"]:
                terminal = post["c"]
        if not ok and k == 10 and terminal and pre["c"] == terminal and stop_alone(pre, a, (5, 4, 4, 1)):
            stopped = True
        if ok and k == 5 and terminal == pre["c"] and terminal and stopped and a[0][4] > 0:
            recovered = True
        if ok and k == 10 and recovered and post["blocks"][post["head"]]["first"]:
            block = post["blocks"][post["head"]]
            origin = pre["origins"][pre["generation"]]
            require(block["bft"] == origin["timestamp"], "first BFT time is not actual R time")
            distinct = block["time"] != block["bft"]
        if ok and k == 14 and recovered and pre["generation"] == 1:
            fresh = post["c"]
        if ok and k == 7 and fresh:
            finalized = post["views"][post["finalized"]]["checkpoint"] >= fresh
        if (ok and k == 10 and finalized and post["head"] > fresh
                and post["blocks"][post["head"]]["anchor"]["checkpoint"] >= fresh):
            advanced = True
    require(terminal and stopped and recovered and fresh > terminal and distinct and finalized and advanced,
            "missing actual terminal-to-fresh progress")
    return tuple(operations)


STATE_FIELDS = frozenset("schedule generation c nonce head fi activeSnapshot index finalized ready origins auth software blocks records views jobs proofs published produces writes initialized startWritten".split())
LIMITS = {
    "smoke": (2, 1, 1, 0), "small-safety": (2, 1, 1, 0),
    "structural-safety": (5, 4, 4, 1), "structural": (5, 4, 4, 1),
    "terminal": (3, 2, 2, 1), "fresh-land": (4, 3, 3, 1),
    "stale-checkpoint": (3, 2, 2, 1), "general-recovery": (2, 2, 2, 0),
    "schedule-safety": (3, 1, 1, 2), "reset-safety": (1, 0, 0, 1),
}


def same(a, b):
    if type(a) is not type(b):
        return False
    if type(a) is dict:
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if type(a) is tuple:
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if type(a) is frozenset:
        return len(a) == len(b) and all(any(same(x, y) for y in b) for x in a)
    return a == b


def native_rule_time(value):
    uint(value, 48)
    require(value <= 999, "native rulesTime outside finite representation")
    return U48 if value == 999 else value


def raw_schedule(q):
    require(type(q) is dict and set(q) == {"active", "next", "time", "stop"}, "invalid raw schedule")
    for value in q.values():
        uint(value, 48)
        require(value <= 999, "native schedule outside finite representation")
    return checked_schedule(Schedule(q["active"], q["next"], native_rule_time(q["time"]), q["stop"]))


def schedule_raw(q):
    return dict(active=q.active, next=q.next, time=999 if q.time == U48 else q.time, stop=q.stop)


def replace_at(values, index, value):
    require(type(values) is tuple and 0 <= index < len(values), "invalid sequence update")
    return values[:index] + (value,) + values[index+1:]


def view(index, generation, c, schedule):
    return dict(number=31+index, timestamp=100+index, generation=generation, checkpoint=c, schedule=schedule)


def write(pre):
    return dict(pre, views=replace_at(pre["views"], pre["index"], view(pre["index"], pre["generation"], pre["c"], pre["schedule"])))


def recovery_state(pre):
    require(type(pre) is dict and set(pre) == STATE_FIELDS, "incomplete raw transaction state")
    origins = tuple(Origin(o["generation"], o["height"], o["number"], o["timestamp"])
                    for o in pre["origins"] if o)
    result = State(raw_schedule(pre["schedule"]), pre["generation"], pre["c"], pre["nonce"],
                   pre["head"], pre["fi"], pre["activeSnapshot"], origins,
                   pre["initialized"], pre["startWritten"])
    return checked_state(result)


def initial(limits):
    l1, height, _, _ = limits
    q = dict(active=0, next=0, time=0, stop=0)
    a = view(0, 0, 0, q)
    genesis = dict(height=0, generation=0, parentTime=99, bft=100, time=99,
                   anchor=a, rule=0, first=False)
    return dict(schedule=q, generation=0, c=0, nonce=0, head=0, fi=0, activeSnapshot=31,
                index=1, finalized=0, ready=True,
                origins=(dict(generation=0, height=0, number=31, timestamp=100, index=0), ()),
                auth=(), software=frozenset({0}), blocks=(genesis,) + ((),)*height,
                records=((0, 0, raw_cut_of(genesis), 31),) + ((),)*height,
                views=tuple(view(i, 0, 0, q) if i <= 1 else () for i in range(l1+1)),
                jobs=((), ()), proofs=(((), ()), ((), ())), published=((), ()),
                produces=0, writes=0, initialized=True, startWritten=True)


def raw_cut_of(block):
    el = tuple(block[k] for k in ("generation", "height", "time", "bft")) + (block["anchor"]["number"], block["rule"])
    return block["height"], el, (() if block["height"] == 0 else (9, el)), block["height"]


def raw_bound(g, p, h, reference, snapshot, cuts, data):
    lo, hi = cuts[0], cuts[-1]
    return (1, 1, 167000, 4369, 8738, g, p, lo[1], lo[2], 333, h, hi[1], hi[2], 444,
            reference, 500+reference, data, lo[3], hi[3], snapshot, (2, g, p, h, cuts[1:-1]))


def raw_capture(pre, p, h, ref):
    cuts = tuple(raw_cut_of(pre["blocks"][n]) for n in range(p, h+1))
    data = pre["blocks"][p+1:h+1]
    snapshot = pre["origins"][pre["generation"]]["number"]
    reference = 31+ref
    return dict(generation=pre["generation"], p=p, h=h, reference=reference, snapshot=snapshot,
                cuts=cuts, data=data, statement=raw_bound(pre["generation"], p, h, reference, snapshot, cuts, data))


def projected_cut(value):
    from current_settlement import Cut, word
    from run_comet_apphash import keccak256
    require(type(value) is tuple and len(value) == 4 and type(value[1]) is tuple and len(value[1]) == 6,
            "invalid symbolic four-field cut")
    el = keccak256(b"ETNA_TEST_EL" + b"".join(word(n) for n in value[1]))
    comet = bytes(32) if value[2] == () else keccak256(b"ETNA_TEST_COMET" + b"".join(word(n) for n in value[1]))
    require(value[2] == () or same(value[2], (9, value[1])), "incorrect symbolic Comet identity")
    return Cut(value[0], el, comet, value[3])


def blob_of(block):
    from current_settlement import word
    from run_comet_apphash import keccak256
    require(type(block) is dict and set(block) == {"height", "generation", "parentTime", "bft", "time", "anchor", "rule", "first"},
            "incomplete block representation")
    flag(block["first"])
    raw_schedule(block["anchor"]["schedule"])
    # A fixture's EL identity only: private provenance below is never a claimed
    # DA codec. This finite EL label is not an actual execution-header encoding.
    label = raw_cut_of(block)[1]
    return b"\x01" + keccak256(b"ETNA_TEST_BLOB" + b"".join(word(v) for v in label))[1:]


def project_job(job):
    from current_settlement import Context, capture, word
    require(type(job) is dict and set(job) == {"generation", "p", "h", "reference", "snapshot", "cuts", "data", "statement"},
            "incomplete captured transaction")
    p, h = uint(job["p"], 48), uint(job["h"], 48)
    require(1 <= h-p <= 6 and type(job["data"]) is tuple and type(job["cuts"]) is tuple
            and len(job["data"]) == h-p and len(job["cuts"]) == h-p+1,
            "incomplete original transaction data")
    require(same(job["statement"], raw_bound(job["generation"], p, h, job["reference"], job["snapshot"], job["cuts"], job["data"])),
            "raw statement does not bind full capture")
    for index, block in enumerate(job["data"]):
        require(type(block) is dict and same(job["cuts"][index+1], raw_cut_of(block)), "captured block differs from its cut")
        require(block["height"] == p+index+1 and block["generation"] == job["generation"], "noncontiguous captured blocks")
        q = raw_schedule(block["anchor"]["schedule"])
        expected_time = max(block["parentTime"]+1, block["bft"], block["anchor"]["timestamp"])
        require(type(block["rule"]) is int and block["rule"] == select_rule(q, expected_time)
                and type(block["time"]) is int and block["time"] == expected_time
                and expected_time-block["anchor"]["timestamp"] <= 2
                and not (q.stop and block["parentTime"] >= q.stop), "guest block violates own historical schedule or stop")
        require(block["anchor"]["number"] <= job["reference"] and block["anchor"]["number"] >= job["snapshot"],
                "proof uses an L1 root outside its reference/origin")
    context = Context(1, 167000, 4369, 8738, word(333), word(444), word(500+job["reference"]), job["snapshot"])
    return capture(job["generation"], job["reference"], tuple(projected_cut(c) for c in job["cuts"]),
                   tuple(blob_of(b) for b in job["data"]), context)


def decision(pre, args):
    anchor, bft, known = args
    p, a = pre["blocks"][pre["head"]], pre["views"][anchor]
    origin = pre["origins"][pre["generation"]]
    return candidate(raw_schedule(a["schedule"]), parent_time=p["time"], bft_time=bft,
                     anchor_number=a["number"], anchor_time=a["timestamp"],
                     parent_anchor_number=p["anchor"]["number"], origin_number=origin["number"],
                     max_age=2, supported=known, first=pre["head"] == origin["height"], origin_time=origin["timestamp"])


def can(pre, k, a, limits):
    l1, height, produces, writes = limits
    try:
        q = raw_schedule(pre["schedule"])
        if k == 1:
            schedule_rules(q, rules=a[0], time=native_rule_time(a[1]), now=100+pre["index"], max_age=2, owner=a[2], initialized=pre["initialized"])
            return pre["writes"] < writes
        if k == 2:
            schedule_stop(q, time=a[0], now=100+pre["index"], max_age=2, owner=a[1], initialized=pre["initialized"])
            return pre["writes"] < writes
        if k == 3:
            return True
        if k == 4:
            invalidate(recovery_state(pre), a[0], owner=a[1])
            return True
        if k == 5:
            require(type(a[0]) is tuple and len(a[0]) == 5, "missing external authorization")
            recover(recovery_state(pre), Authorization(*a[0]), owner=a[1], now=100+pre["index"], number=31+pre["index"])
            return True
        if k == 6:
            return pre["index"] < l1
        if k == 7:
            return pre["finalized"] <= a[0] < pre["index"]
        if k == 8:
            return (pre["finalized"] >= pre["origins"][pre["generation"]]["index"] and
                    pre["views"][pre["finalized"]]["generation"] == pre["generation"])
        if k == 9:
            return True
        if k == 10:
            d = decision(pre, a)
            origin, parent, v = pre["origins"][pre["generation"]], pre["blocks"][pre["head"]], pre["views"][a[0]]
            return (pre["ready"] and pre["produces"] < produces and pre["head"] < height
                    and a[0] <= pre["finalized"] and v["generation"] == pre["generation"]
                    and (pre["head"] == origin["height"] or a[1] >= parent["bft"])
                    and pre["head"]+1 <= v["checkpoint"]+2 and d.outcome == "ACCEPT" and same(a[2], pre["software"]))
        if k == 11:
            j, p, h, ref = a
            origin = pre["origins"][pre["generation"]]
            if not (j == pre["generation"]+1 and pre["jobs"][j-1] == () and origin["height"] <= p <= pre["c"] < h <= pre["head"]):
                return False
            record = pre["records"][p]
            return (record != () and (record[0] == pre["generation"] or p == origin["height"])
                    and origin["index"] <= ref <= pre["index"] and record[3] <= 31+ref
                    and all(b["generation"] == pre["generation"] and b["anchor"]["number"] <= 31+ref for b in pre["blocks"][p+1:h+1]))
        if k == 12:
            j, backend, image = a
            job = pre["jobs"][j-1]
            return job != () and all(b["rule"] in image for b in job["data"])
        if k == 13:
            return pre["jobs"][a[0]-1] != ()
        if k == 14:
            from current_settlement import land
            j = a[0]-1
            raw = pre["jobs"][j]
            if raw == ():
                return False
            tx = project_job(raw)
            for proof in pre["proofs"][j]:
                if not proof or not same(proof[0], raw["statement"]) or not all(b["rule"] in proof[1] for b in raw["data"]):
                    return False
            origin, current = pre["records"][raw["p"]], pre["records"][pre["c"]]
            if not origin or not current:
                return False
            land(tx, generation=pre["generation"], start=pre["origins"][pre["generation"]]["height"],
                 origin=(origin[0], projected_cut(origin[2])), checkpoint=projected_cut(current[2]),
                 fi_head=pre["fi"], now=31+pre["index"], window=5, capacity=6,
                 blobs=tuple(blob_of(b) for b in pre["published"][j]), leaves=tx.leaves,
                 proofs=(tx.statement, tx.statement))
            return True
    except ValueError:
        return False
    raise ValueError("unknown action")


def after(pre, k, a):
    if k in (1, 2):
        q = raw_schedule(pre["schedule"])
        f = (schedule_rules(q, rules=a[0], time=native_rule_time(a[1]), now=100+pre["index"], max_age=2,
                            owner=a[2], initialized=pre["initialized"]) if k == 1 else
             schedule_stop(q, time=a[0], now=100+pre["index"], max_age=2, owner=a[1], initialized=pre["initialized"]))
        return write(dict(pre, schedule=schedule_raw(f[0]), writes=pre["writes"]+1))
    if k == 3:
        return dict(pre, auth=(pre["generation"], pre["c"], pre["nonce"], a[1], a[0]))
    if k == 4:
        return write(dict(pre, nonce=pre["nonce"]+1))
    if k == 5:
        result, _ = recover(recovery_state(pre), Authorization(*a[0]), owner=a[1], now=100+pre["index"], number=31+pre["index"])
        g = result.generation
        origin = dict(generation=g, height=pre["c"], number=31+pre["index"], timestamp=100+pre["index"], index=pre["index"])
        return write(dict(pre, schedule=schedule_raw(result.schedule), generation=g, nonce=result.nonce,
                          head=pre["c"], ready=False, origins=replace_at(pre["origins"], g, origin),
                          blocks=pre["blocks"][:pre["c"]+1] + ((),)*(len(pre["blocks"])-pre["c"]-1)))
    if k == 6:
        return write(dict(pre, index=pre["index"]+1))
    if k == 7:
        return dict(pre, finalized=a[0])
    if k == 8:
        return dict(pre, ready=True)
    if k == 9:
        return dict(pre, software=a[0])
    if k == 10:
        anchor, bft, known = a
        p, v = pre["blocks"][pre["head"]], pre["views"][anchor]
        d = decision(pre, a)
        block = dict(height=pre["head"]+1, generation=pre["generation"], parentTime=p["time"], bft=bft,
                     time=d.el_time, anchor=v, rule=d.rule, first=pre["head"] == pre["origins"][pre["generation"]]["height"])
        return dict(pre, head=pre["head"]+1, produces=pre["produces"]+1, blocks=replace_at(pre["blocks"], pre["head"]+1, block))
    if k == 11:
        j, p, h, ref = a
        raw = raw_capture(pre, p, h, ref)
        project_job(raw)
        return dict(pre, jobs=replace_at(pre["jobs"], j-1, raw))
    if k == 12:
        j, backend, image = a
        pair = replace_at(pre["proofs"][j-1], backend-1, (pre["jobs"][j-1]["statement"], image))
        return dict(pre, proofs=replace_at(pre["proofs"], j-1, pair))
    if k == 13:
        return dict(pre, published=replace_at(pre["published"], a[0]-1, pre["jobs"][a[0]-1]["data"]))
    if k == 14:
        job = pre["jobs"][a[0]-1]
        record = (pre["generation"], pre["c"], job["cuts"][-1], 31+pre["index"])
        return write(dict(pre, c=job["h"], fi=record[2][3], activeSnapshot=job["snapshot"],
                          records=replace_at(pre["records"], job["h"], record)))
    raise ValueError("unknown action")


def event(pre, k, a, accepted):
    if k == 10:
        parent, v = pre["blocks"][pre["head"]], pre["views"][a[0]]
        t = max(parent["time"]+1, a[1], v["timestamp"])
        q = raw_schedule(v["schedule"])
        rule = select_rule(q, t)
        outcome = 2 if rule not in a[2] else 3 if q.stop and parent["time"] >= q.stop else 1
        return rule, outcome, a[1], t
    return tuple(after(pre, k, a)["schedule"][name] for name in ("active", "next", "time", "stop")) if accepted and k in (1, 2, 5) else 0


def check_offer(case, pre, kind, args):
    """Check the selected native scenario's offers independently of admission."""
    from itertools import product
    require(case in LIMITS and type(kind) is int and 1 <= kind <= 14 and type(args) is tuple,
            "invalid timestamp profile or call")
    require(type(pre) is dict and set(pre) == STATE_FIELDS, "incomplete native PRE frame")
    smoke = case in ("smoke", "small-safety")
    dispatch = case == "schedule-safety"
    reset = case == "reset-safety"
    structural = not (smoke or dispatch)
    require(not (dispatch and kind not in (1, 2, 6) or reset and kind not in (2, 3, 5)),
            "operation outside profile offer domain")
    owners = (False, True)
    full = frozenset({0, 1, 2})
    images = (full,) if structural else (frozenset({0}), full)
    slots = (1, 2)
    heights = range(LIMITS[case][1]+1)
    indices = range(pre["index"]+1)
    if kind == 1:
        offers = () if structural or smoke else product(range(3), (0, 102, 103, 104, 106, 999), owners)
    elif kind == 2:
        if smoke or case == "general-recovery":
            offers = ()
        else:
            offers = ((103, True),) if structural else product((0, 102, 103, 104, 106), owners)
    elif kind == 3:
        offers = () if smoke or pre["generation"] != 0 else (
            ((1, 108),) if structural else product(range(3), (101, 104, 106, 108)))
    elif kind == 4:
        offers = () if structural or smoke else product(range(3), owners)
    elif kind == 5:
        offers = () if smoke or pre["generation"] != 0 else product(
            (pre["auth"],), (True,) if structural else owners)
    elif kind in (6, 8):
        offers = ((),)
    elif kind == 7:
        offers = ((pre["index"]-1,),) if structural else product(indices)
    elif kind == 9:
        offers = product(images)
    elif kind == 10:
        origin = pre["origins"][pre["generation"]]
        clocks = (origin["timestamp"], 101, 103, 104, 105) if structural else range(100, 107)
        offers = product(indices, clocks, (pre["software"],))
    elif kind == 11:
        if structural:
            origin = pre["origins"][1]
            offers = ((1, 0, 2, 1),) + (((2, 2, 3, origin["index"]),) if origin else ())
        else:
            offers = product(slots, heights, heights, indices)
    elif kind == 12:
        offers = product(slots, slots, images)
    else:
        offers = product(slots)
    require(any(same(args, offer) for offer in offers), "arguments outside profile offer domain")


def check_transition(pre, post, k, a, accepted, limits):
    require(type(pre) is dict and set(pre) == STATE_FIELDS and type(post) is dict and set(post) == STATE_FIELDS,
            "incomplete before/after transaction frame")
    require(type(k) is int and 1 <= k <= 14 and type(a) is tuple and type(accepted) is bool,
            "invalid actual action input")
    lengths = (3, 2, 2, 2, 2, 0, 1, 0, 1, 3, 4, 3, 1, 1)
    require(len(a) == lengths[k-1], "wrong actual call arity")
    if k in (3, 7, 10, 11, 12, 13, 14):
        numeric = a if k in (3, 7, 11, 13, 14) else a[:2]
        for value in numeric:
            uint(value)
    if k in (9, 10, 12):
        image = a[0] if k == 9 else a[2]
        require(type(image) is frozenset and all(type(r) is int and 0 <= r <= 2 for r in image),
                "invalid actual supported-rule set")
    if k in (13, 14):
        require(1 <= a[0] <= 2, "invalid job slot")
    if k == 11:
        require(1 <= a[0] <= 2 and a[1] < len(pre["records"]) and a[2] < len(pre["blocks"])
                and a[3] < len(pre["views"]), "capture outside finite envelope")
    if k == 12:
        require(1 <= a[0] <= 2 and 1 <= a[1] <= 2, "invalid job or backend")
    if k in (7, 10):
        require(a[0] < len(pre["views"]), "anchor outside finite envelope")
    expected = can(pre, k, a, limits)
    require(type(expected) is bool and accepted is expected, "actual admission differs from current rule")
    require(same(post, after(pre, k, a) if accepted else pre), "actual full state frame differs")


def stop_alone(pre, a, limits):
    # Change only the selected anchor's stop for this independent eligibility
    # counterfactual; execution always uses the actual original anchor.
    index = a[0]
    anchor = pre["views"][index]
    original_stop = anchor["schedule"]["stop"]
    if not original_stop or pre["blocks"][pre["head"]]["time"] < original_stop:
        return False
    alternate = dict(anchor, schedule=dict(anchor["schedule"], stop=0))
    trial = dict(pre, views=replace_at(pre["views"], index, alternate))
    return can(trial, 10, a, limits)


def seen_after(seen, pre, post, k, a, accepted, limits):
    result = dict(seen)
    if accepted and k == 14:
        block = pre["jobs"][a[0]-1]["data"][-1]
        if block["anchor"]["schedule"]["stop"] and block["time"] >= block["anchor"]["schedule"]["stop"]:
            result["terminal"] = post["c"]
        if pre["generation"] == 1:
            result["fresh"] = post["c"]
    if not accepted and k == 10 and seen["terminal"] == pre["c"] and seen["terminal"] and stop_alone(pre, a, limits):
        result["stopRefused"] = True
    if accepted and k == 5:
        if a[0][4] > 0 and seen["terminal"] == pre["c"] and seen["terminal"] and seen["stopRefused"]:
            result["recovered"] = True
        if pre["schedule"]["stop"] == 0:
            result["noStop"] = True
    if not accepted and k == 5 and a[0] and a[0][1] != pre["c"]:
        fixed = (a[0][0], pre["c"], *a[0][2:])
        if can(pre, 5, (fixed, a[1]), limits):
            result["stale"] = True
    if accepted and k == 10 and pre["generation"] == 1:
        block = post["blocks"][post["head"]]
        if block["first"] and block["time"] != block["bft"]:
            result["distinctClocks"] = True
    return result


def audit(text, case):
    from proving_recovery import trace_packets
    require(case in LIMITS, "unknown timestamp profile")
    limits = LIMITS[case]
    packets = list(trace_packets(text))
    for fields in packets:
        require(set(fields) == {"s", "bad", "last", "seen"} and fields["bad"] is False,
                "invalid or failed native frame")
    require(same(packets[0]["s"], initial(limits)) and same(packets[0]["last"], (0, (), False, ())),
            "native initialization differs from configured profile")
    expected_seen = dict(terminal=0, stopRefused=False, recovered=False, fresh=0, stale=False, noStop=False, distinctClocks=False)
    require(same(packets[0]["seen"], expected_seen), "incorrect initial observations")
    receipts = []
    for before, after_packet in zip(packets, packets[1:]):
        pre, post = before["s"], after_packet["s"]
        call = after_packet["last"]
        require(type(call) is tuple and len(call) == 4, "incomplete actual call receipt")
        k, a, accepted, observed_event = call
        check_offer(case, pre, k, a)
        check_transition(pre, post, k, a, accepted, limits)
        require(same(observed_event, event(pre, k, a, accepted)), "actual event or candidate outputs differ")
        expected_seen = seen_after(expected_seen, pre, post, k, a, accepted, limits)
        require(same(after_packet["seen"], expected_seen), "native witness observation differs")
        receipts.append(dict(operation=k, input=a, before=pre, after=post, accepted=accepted))
    if case == "structural":
        require_progress(receipts)
    elif case == "terminal":
        require(expected_seen["terminal"] > 0, "no actual terminal landing")
    elif case == "fresh-land":
        require(expected_seen["recovered"] and expected_seen["fresh"] > expected_seen["terminal"]
                and expected_seen["distinctClocks"], "no actual terminal-to-fresh landing")
    elif case == "stale-checkpoint":
        require(expected_seen["stale"], "no isolated stale-checkpoint refusal")
    elif case == "general-recovery":
        require(expected_seen["noStop"], "no actual recovery without planned stop")
    return receipts


def audit_named(text, case):
    """A source-bound receipt needs the selected native witness and its endpoint."""
    import re
    names = {"structural": "NoStructural", "terminal": "NoTerminal",
             "fresh-land": "NoFreshLand", "stale-checkpoint": "NoStale",
             "general-recovery": "NoGeneralRecovery", "reset-safety": "NoResetReached"}
    require(case in names, "timestamp claim requires a named witness")
    require(re.findall(r"^Error: Invariant (\w+) is violated\.$", text, re.M) == [names[case]],
            "wrong native timestamp witness")
    edges = audit(text, case)
    require(edges, "missing timestamp witness transitions")
    if case == "reset-safety":
        end = edges[-1]["after"]
        require(end["generation"] == 1 and end["writes"] == 1
                and same(end["schedule"], dict(active=1, next=1, time=0, stop=0)),
                "missing successful nonzero-rules reset")
    return edges


def current_receipt(workspace_root, case, raw, *, expected_claim=None):
    from product_claim import emit
    return emit("timestamp", workspace_root, case, raw, expected_claim=expected_claim)


if __name__ == "__main__":
    from product_claim import command
    command(current_receipt, __doc__)
