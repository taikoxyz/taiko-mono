"""Replay raw TLC witness states through the offline four-word settlement adapter."""
import re

from current_settlement import Context, Cut, capture, land, uint, word

S = 6
TOKENS = re.compile(r'\s*(<<|>>|\|->|:>|@@|[\[\](){},]|-?\d+|[A-Za-z_]\w*)')
STATE = re.compile(r"^State (\d+): [^\n]*$", re.M)
ASSIGN = re.compile(r"^/\\ (\w+) = ", re.M)
FIELDS = set("head generation now included fiHead activeSnapshot finalized finalizedBlock start "
             "dependency parentAnchor anchors producedCount canonical records applied jobs proofs "
             "published available privateHistory".split())


def require(ok, message):
    if not ok:
        raise ValueError(message)


class Reader:
    def __init__(self, text):
        self.text = text
        self.pos = 0

    def token(self, advance=True):
        match = TOKENS.match(self.text, self.pos)
        if match is None:
            raise ValueError("unexpected end of TLC value")
        if advance:
            self.pos = match.end()
        return match[1]

    def take(self, expected):
        require(self.token() == expected, "invalid TLC delimiter")

    def value(self):
        token = self.token()
        if token in ("TRUE", "FALSE"):
            return token == "TRUE"
        if token.lstrip("-").isdigit():
            return int(token)
        if token == "(":
            entries = {}
            while True:
                key = self.value()
                require(type(key) is int and key >= 1, "noninteger or nonpositive sequence key")
                self.take(":>")
                require(key not in entries, "duplicate function key")
                entries[key] = self.value()
                sep = self.token()
                if sep == ")":
                    break
                require(sep == "@@", "invalid TLC function")
            require(set(entries) == set(range(1, len(entries) + 1)), "nonsequence TLC function")
            return tuple(entries[k] for k in range(1, len(entries) + 1))
        close = {"<<": ">>", "{": "}", "[": "]"}.get(token)
        require(close is not None, "unexpected TLC value")
        values, fields = [], {}
        if self.token(False) != close:
            while True:
                if token == "[":
                    name = self.token()
                    self.take("|->")
                    require(name not in fields, "duplicate record field")
                    fields[name] = self.value()
                else:
                    values.append(self.value())
                if self.token(False) == close:
                    break
                self.take(",")
        self.take(close)
        if token == "[":
            return fields
        if token == "{":
            try:
                unique = frozenset(values)
            except TypeError as error:
                raise ValueError("unsupported native set member") from error
            require(len(unique) == len(values), "duplicate or aliased native set member")
            return unique
        return tuple(values)


# Only the final native statistics trailer is outside the last variable value.
# Raw prefixes without a trailer are also used to inspect a control's good edges.
FOOTER = re.compile(
    r"^\d+(?:,\d{3})* states generated, \d+(?:,\d{3})* distinct states found, \d+(?:,\d{3})* states left on queue\.\n"
    r"The depth of the complete state graph search is \d+\.\n"
    r"(?:The average outdegree of the complete state graph is \d+ \(minimum is \d+, "
    r"the maximum \d+ and the 95th percentile is \d+\)\.\n)?"
    r"Finished in [^\n]+ at \([^\n]+\)\s*\Z", re.M)


def trace_packets(text):
    footer = FOOTER.search(text)
    body = text[:footer.start()] if footer else text
    markers = list(STATE.finditer(body))
    require(markers, "missing native TLC states")
    for i, marker in enumerate(markers):
        require(int(marker[1]) == i + 1, "nonconsecutive TLC trace")
        end = markers[i+1].start() if i+1 < len(markers) else len(body)
        chunk = body[marker.end():end]
        assignments = list(ASSIGN.finditer(chunk))
        require(assignments and not chunk[:assignments[0].start()].strip(),
                "unexpected input before native state variables")
        fields = {}
        for j, assignment in enumerate(assignments):
            name = assignment[1]
            require(name not in fields, "duplicate native state variable")
            stop = assignments[j+1].start() if j+1 < len(assignments) else len(chunk)
            reader = Reader(chunk[assignment.end():stop])
            fields[name] = reader.value()
            require(not reader.text[reader.pos:].strip(), "trailing TLC terms after " + name)
        yield fields


def states(text, *, allow_fault=False, fixed_calls=None, milestones=None):
    packets = list(trace_packets(text))
    result = []
    for i, fields in enumerate(packets):
        require(set(fields) == {"s", "bad", "milestone"} and type(fields["bad"]) is bool
                and type(fields["milestone"]) is (tuple if fixed_calls is not None else int),
                "invalid trace variables")
        require(fields["bad"] is (allow_fault and i == len(packets)-1),
                "unexpected diagnostic flag on native frame")
        if fixed_calls is not None:
            fixed_calls.append(fields["milestone"])
        if milestones is not None:
            milestones.append(fields["milestone"])
        result.append(fields["s"])
    return result

def raw_cut(value):
    require(type(value) is tuple and len(value) == 4, "invalid raw cut")
    h, el, comet, fi = value
    return Cut(h, word(el), word(comet), fi)


def blob(value):
    return bytes([1]) + uint(value, 248).to_bytes(31, "big")


def check_capture(pre, info):
    require(type(info) is dict and set(info) == {
        "generation", "reference", "dependency", "cuts", "data", "statement"}, "invalid capture")
    cuts, data = info["cuts"], info["data"]
    require(type(cuts) is tuple and type(data) is tuple and 1 <= len(data) <= 6
            and len(cuts) == len(data) + 1, "incomplete capture range")
    g, t, dep = (uint(info[k]) for k in ("generation", "reference", "dependency"))
    p, h = cuts[0][0], cuts[-1][0]
    require((g, t, dep) == (pre["generation"], pre["now"], pre["dependency"])
            and pre["start"] <= p <= pre["included"] < h <= pre["head"], "not a live capture")
    origin = pre["records"][p - S]
    require(origin and (origin[0] == g or p == pre["start"])
            and same(origin[2], cuts[0]), "missing current origin")
    require(same(cuts, pre["canonical"][p - S:h - S + 1]) and same(data, tuple(c[1] for c in cuts[1:])),
            "capture differs from produced range")
    first, last = cuts[0], cuts[-1]
    expected = (1, 1, 167000, 4369, 8738, g, p, first[1], first[2], 333, h, last[1], last[2],
                400 + last[1], t, 500 + t, data, first[3], last[3], dep,
                (2, g, p, h, cuts[1:-1]))
    require(same(info["statement"], expected), "actual proof binding differs from raw input")
    ctx = Context(1, 167000, 4369, 8738, word(333), word(400 + last[1]), word(500 + t), dep)
    return capture(g, t, tuple(raw_cut(c) for c in cuts), tuple(blob(x) for x in data), ctx)


def actual_call(j, pre, jobs, proofs, capacity):
    job = jobs[j]
    p, c = job.cuts[0].height, pre["included"]
    origin = pre["records"][p - S]
    return land(job, generation=pre["generation"], start=pre["start"],
                origin=(origin[0], raw_cut(origin[2])), checkpoint=raw_cut(pre["records"][c - S][2]),
                fi_head=pre["fiHead"], now=pre["now"], window=4, capacity=capacity,
                blobs=tuple(blob(x) for x in pre["published"][j]), leaves=job.leaves,
                proofs=tuple(proofs[j]))


def rejected(j, pre, jobs, proofs, capacity):
    try:
        actual_call(j, pre, jobs, proofs, capacity)
    except ValueError:
        return True
    return False


def initial(depth):
    cut = (6, 6, 0, 0)
    anchor = (0, 6, 0, cut)
    return dict(head=6, generation=0, now=0, included=6, fiHead=0, activeSnapshot=0,
                finalized=6, finalizedBlock=0, start=6, dependency=0, parentAnchor=anchor,
                anchors=frozenset({anchor}), producedCount=0, canonical=(cut,) + ((),) * depth,
                records=((0, 6, cut, 0),) + ((),) * depth, applied=(0,) * (depth + 1),
                jobs=((), ()), proofs=(((), ()), ((), ())), published=((), ()),
                available=(False, False), privateHistory=False)


def updated(seq, index, value):
    return seq[:index] + (value,) + seq[index + 1:]


def same(left, right):
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return left.keys() == right.keys() and all(same(v, right[k]) for k, v in left.items())
    if type(left) is tuple:
        return len(left) == len(right) and all(same(a, b) for a, b in zip(left, right))
    if type(left) is frozenset:
        return {repr(v) for v in left} == {repr(v) for v in right}
    return left == right


def replay(frames, *, capacity, max_time, max_produces, overlap=False, allow_stale=False):
    require(frames and type(frames[0]) is dict and set(frames[0]) == FIELDS, "missing real Init")
    depth = len(frames[0]["canonical"]) - 1
    require(same(frames[0], initial(depth)), "incorrect initial frame")
    jobs, proofs = [None, None], [[None, None], [None, None]]
    events = []
    for pre, post in zip(frames, frames[1:]):
        require(type(post) is dict and set(post) == FIELDS, "invalid full frame")
        changed = {k for k in FIELDS if not same(pre[k], post[k])}
        exp = dict(pre)
        event = None
        if post["generation"] != pre["generation"]:
            c, r = pre["included"], pre["now"] + 1
            require(pre["generation"] == 0 and r + 1 <= max_time, "illegal recovery")
            anchor = (1, c, r, pre["records"][c - S][2])
            exp.update(generation=1, head=c, start=c, now=r + 1, dependency=r,
                       finalized=c, finalizedBlock=r, parentAnchor=anchor,
                       anchors=pre["anchors"] | {anchor})
            event = ("recover", c, pre["head"])
        elif "producedCount" in changed:
            h, g, a = pre["head"] + 1, pre["generation"], post["parentAnchor"]
            require(pre["producedCount"] < max_produces and h <= S + depth
                    and any(same(a, anchor) for anchor in pre["anchors"])
                    and a[2] >= pre["dependency"]
                    and (pre["head"] == pre["start"] or a[2] >= pre["parentAnchor"][2])
                    and a[0] == g and 0 <= pre["now"] - a[2] <= 4 and h <= a[1] + 2,
                    "unavailable candidate anchor or headroom")
            exp.update(head=h, producedCount=pre["producedCount"] + 1, parentAnchor=a,
                       canonical=updated(pre["canonical"], h - S, (h, 100*g+h, 200+100*g+h, h-S)))
            event = ("produce", g, h, a)
        elif "jobs" in changed:
            for j, (old, info) in enumerate(zip(pre["jobs"], post["jobs"])):
                if not same(old, info):
                    require(not old and jobs[j] is None and (overlap or j == pre["generation"]),
                            "capture rewrites an immutable slot")
                    jobs[j] = check_capture(pre, info)
                    exp["jobs"] = updated(pre["jobs"], j, info)
                    event = ("capture", j, jobs[j].generation, jobs[j].cuts[0].height,
                             jobs[j].cuts[-1].height)
        elif "proofs" in changed:
            for j in range(2):
                for b in range(2):
                    value = post["proofs"][j][b]
                    if not same(pre["proofs"][j][b], value):
                        sources = [k for k in range(2) if jobs[k] and
                                   same(pre["jobs"][k]["statement"], value) and
                                   pre["jobs"][k]["reference"] - pre["jobs"][k]["dependency"] <= 4]
                        require(jobs[j] and pre["privateHistory"] and pre["available"][b] and sources,
                                "backend source/resource mismatch")
                        proofs[j][b] = jobs[sources[0]].statement
                        exp["proofs"] = updated(pre["proofs"], j, updated(pre["proofs"][j], b, value))
                        event = ("complete", j, b, tuple(sources))
        elif "published" in changed:
            for j in range(2):
                value = post["published"][j]
                if not same(pre["published"][j], value):
                    require(jobs[j] is not None, "published absent job")
                    data = pre["jobs"][j]["data"]
                    suffix = data[max(0, pre["included"]-jobs[j].cuts[0].height):]
                    full = same(value, data)
                    require(full or same(value, suffix), "invalid publication")
                    exp["published"] = updated(pre["published"], j, value)
                    event = ("publish", j, full)
                    if not full and proofs[j] == [jobs[j].statement] * 2:
                        require(rejected(j, post, jobs, proofs, capacity), "suffix-only landing accepted")
        elif "included" in changed:
            c, h = pre["included"], post["included"]
            j = next((i for i, x in enumerate(jobs) if x and x.cuts[-1].height == h
                      and proofs[i] == [x.statement] * 2
                      and tuple(blob(n) for n in pre["published"][i]) == x.blobs
                      and (allow_stale or x.generation == pre["generation"])), None)
            require(j is not None, "landing has no completed and fully published job")
            x = jobs[j]
            rec = (pre["generation"], c, pre["jobs"][j]["cuts"][-1], pre["now"])
            if x.generation != pre["generation"]:
                require(allow_stale and rejected(j, pre, jobs, proofs, capacity),
                        "stale concrete job accepted")
                # Rebind only the current-generation argument to the captured
                # generation. Every unrelated byte/resource/overlap guard runs.
                prior = dict(pre, generation=x.generation)
                actual_call(j, prior, jobs, proofs, capacity)
            else:
                require(actual_call(j, pre, jobs, proofs, capacity) ==
                        (rec[0], c, raw_cut(rec[2]), rec[3]), "byte landing differs from raw record")
            exp.update(included=h, fiHead=rec[2][3], activeSnapshot=x.context.snapshot,
                       records=updated(pre["records"], h-S, rec),
                       applied=tuple(n + int(c < S+i <= h) for i,n in enumerate(pre["applied"])))
            event = ("land", j, x.generation, c, h)
        elif changed == {"now"}:
            require(pre["now"] < max_time, "tick past horizon")
            exp["now"] += 1
            event = ("tick", exp["now"])
        elif "finalizedBlock" in changed:
            b = post["finalizedBlock"]
            require(type(b) is int and pre["finalizedBlock"] < b < pre["now"],
                    "invalid finalization block")
            top = max(i+S for i,r in enumerate(pre["records"]) if r and r[3] <= b)
            exp.update(finalized=top, finalizedBlock=b)
            event = ("finalize", top, b)
        elif changed == {"anchors"}:
            h, b = pre["finalized"], pre["finalizedBlock"]
            exp["anchors"] |= {(pre["generation"], h, b, pre["records"][h-S][2])}
            event = ("anchor", h, b)
        elif changed == {"privateHistory"}:
            exp["privateHistory"] = not pre["privateHistory"]
            event = ("history", exp["privateHistory"])
        elif changed == {"available"}:
            b = next((b for b in range(2) if pre["available"][b] != post["available"][b]), None)
            require(b is not None, "invalid availability")
            exp["available"] = updated(pre["available"], b, not pre["available"][b])
            event = ("availability", b, exp["available"][b])
        require(event is not None and same(exp, post), "unexpected action or inaccurate complete frame")
        events.append(event)
        if event[0] == "recover" and jobs[0] and proofs[0] == [jobs[0].statement] * 2:
            require(rejected(0, post, jobs, proofs, capacity), "old job can land after recovery")
    return events


def require_fresh_progress(frames, *, capacity=2, max_time=4, max_produces=5):
    events = replay(frames, capacity=capacity, max_time=max_time, max_produces=max_produces)
    kinds = [e[0] for e in events]
    require("recover" in kinds, "missing live recovery")
    boundary = kinds.index("recover")
    require(any(e[:3] == ("capture", 0, 0) for e in events[:boundary]), "missing old capture")
    require(any(e[:3] == ("capture", 1, 1) for e in events[boundary+1:]), "missing live fresh capture")
    require(any(e[:3] == ("land", 1, 1) for e in events[boundary+1:]), "missing fresh landing")
    return events


def fixed_audit(frames, calls):
    require(frames and type(frames[0]) is dict, "missing fixed fixture")
    require(len(calls) == len(frames) and same(calls[0], (0, (), (), ())), "missing fixed dispatch receipts")
    cuts = ((6, 6, 0, 0),) + tuple((h, h, 200+h, h-6) for h in range(7, 11))
    pre = initial(4)
    cpre = dict(pre, head=10, canonical=cuts)
    long_info = frames[0]["jobs"][0]
    long = check_capture(cpre, long_info)
    require(long.reference == 0 and long.cuts[-1].height == 10, "incorrect fixed range")
    pre.update(head=10, canonical=cuts, now=1, jobs=(long_info, ()),
               proofs=((long_info["statement"], long_info["statement"]), ((), ())),
               published=((7, 8, 9, 10), ()), available=(True, True), privateHistory=True)
    require(same(pre, frames[0]), "incorrect fixed initial state")
    events = []
    for state in frames:
        c = state["included"]
        if c == 10:
            break
        accepted = actual_call(0, state, [long], [[long.statement] * 2], 4)
        require(accepted == (0, c, long.cuts[-1], state["now"]),
                "immutable transaction unavailable at interior frontier")
    for pre, post, call in zip(frames, frames[1:], calls[1:]):
        c, h, now = pre["included"], post["included"], pre["now"]
        require(6 <= c < h <= 10 and (h == c + 1 or h == 10), "wrong fixed competitor")
        require(type(call) is tuple and len(call) == 4, "missing actual fixed transaction")
        choice, observed, backend, published = call
        require(type(observed) is dict and set(observed) == set(long_info), "invalid selected fixed job")
        require(type(choice) is int and choice in (1, 2), "invalid actual fixed offer")
        short = choice == 1
        require(h == (c + 1 if short else 10), "dispatched transaction differs from successor")
        if short:
            origin_height = c
            ref = pre["records"][c-6][3]
            require(ref < now, "reference must authenticate written origin")
            require(same(observed["cuts"], cuts[c-6:h-5]) and same(observed["reference"], ref),
                    "actual shortest offer changed origin, terminal, or reference")
            tx = check_capture(dict(pre, now=ref), observed)
        else:
            origin_height = 6
            require(same(observed, long_info), "actual long job differs from immutable capture")
            tx = long
        require(same(backend, (observed["statement"],)*2) and same(published, observed["data"]),
                "fixed backend or publication differs from captured transaction")
        record = land(tx, generation=0, start=6, origin=(0, raw_cut(pre["records"][origin_height-6][2])),
                      checkpoint=raw_cut(pre["records"][c-6][2]), fi_head=c-6, now=now,
                      window=4, capacity=4, blobs=tuple(blob(n) for n in published),
                      leaves=tx.leaves, proofs=(tx.statement,)*2)
        require(record == (0, c, raw_cut(cuts[h-6]), now), "fixed concrete record differs")
        expected = dict(pre, included=h, fiHead=h-6, activeSnapshot=0,
                        now=now+int(short and h<10),
                        records=updated(pre["records"], h-6, (0, c, cuts[h-6], now)),
                        applied=tuple(int(6<i<=h) for i in range(6, 11)))
        require(same(expected, post) and 10-h < 10-c, "incorrect fixed successor")
        events.append(("short" if short else "long", c, h, tx.reference))
    return events


def check_milestones(frames, events, milestones, case):
    expected = 0
    require(milestones[0] == expected, "incorrect initial milestone")
    for pre, event, observed in zip(frames, events, milestones[1:]):
        if event[0] == "recover" and pre["head"] >= S+2 and pre["jobs"][0]:
            job = pre["jobs"][0]
            if (pre["included"] == S and job["cuts"][-1][0] == S+2
                    and same(pre["published"][0], job["data"])
                    and same(pre["proofs"][0], (job["statement"],)*2)):
                expected = 1
            elif pre["included"] == S+1:
                expected = 2
        elif case == "two-old-overlap" and event[0] == "publish":
            _, slot, full = event
            job = pre["jobs"][slot]
            if (not full and pre["included"] == S+1 and job["cuts"][0][0] == S
                    and len(job["data"]) == 2
                    and same(pre["proofs"][slot], (job["statement"],)*2)):
                expected = 3
        require(observed == expected, "incorrect witness milestone on native edge")


def named_endpoint(case, end, milestone):
    c = end["included"]
    record = end["records"][c-S]
    old, fresh = end["jobs"]
    fresh_land = (end["generation"] == 1 and fresh and c >= S+2
                  and record[0] == 1 and fresh["generation"] == 1)
    if case == "recovery-c0":
        return (milestone == 1 and fresh_land and end["start"] == S and end["finalized"] == S+2
                and end["parentAnchor"][:2] == (1, S+2) and end["head"] == S+3)
    if case == "recovery-c1":
        return (milestone == 2 and fresh_land and end["start"] == S+1 and end["records"][1][0] == 0)
    if case == "old-authority-fault":
        return (milestone == 1 and end["generation"] == 1 and old and old["generation"] == 0
                and end["privateHistory"] and end["available"] == (True, True)
                and c > end["start"] and record[2][1] < 100)
    if case == "two-old-overlap":
        return milestone == 3 and c == S+2 and record[1] == S+1
    if case == "unit":
        return c == S+1 and record[1] == S
    if case == "late-capture":
        return old and old["reference"] > 0 and old["generation"] == 0
    raise ValueError("unknown proving witness")


def audit(text, case):
    fixed = {"fixed-7": "NoFrontier7", "fixed-8": "NoFrontier8", "fixed-9": "NoFrontier9",
             "fixed-interior-long": "NoInteriorLong", "fixed-last-long": "NoLastLong",
             "fixed-last-short": "NoLastShort"}
    if case in fixed:
        require(re.findall(r"^Error: Invariant (\w+) is violated\.$", text, re.M) == [fixed[case]],
                "wrong fixed witness")
        calls = []
        frames = states(text, fixed_calls=calls)
        events = fixed_audit(frames, calls)
        if case == "fixed-interior-long":
            require(events and events[-1][1] in (7, 8) and events[-1][2] == 10, "missing interior long success")
        elif case in ("fixed-last-long", "fixed-last-short"):
            require(events and events[-1] == (("long", 9, 10, 0) if case.endswith("long") else
                                              ("short", 9, 10, 3)), "incorrect last-frontier dispatch")
        else:
            require(frames[-1]["included"] == int(case[-1]), "wrong interior frontier")
        return events
    settings = {
        "recovery-c0": ("NoFreshC0", 2, 4, 5),
        "recovery-c1": ("NoFreshC1", 1, 4, 3),
        "two-old-overlap": ("NoOverlap", 2, 1, 2),
        "old-authority-fault": ("NoOldAuthority", 2, 2, 2),
        "unit": ("NoSingle", 1, 1, 1),
        "late-capture": ("NoLateCapture", 1, 1, 1),
    }
    require(case in settings, "unknown proving witness")
    name, cap, horizon, budget = settings[case]
    require(re.findall(r"^Error: Invariant (\w+) is violated\.$", text, re.M) == [name],
            "wrong native witness")
    fault = case == "old-authority-fault"
    milestones = []
    frames = states(text, allow_fault=fault, milestones=milestones)
    depth = {"recovery-c0": 3, "recovery-c1": 2, "two-old-overlap": 2,
             "old-authority-fault": 2, "unit": 1, "late-capture": 1}[case]
    require(len(frames[0]["canonical"]) == depth + 1, "wrong native profile depth")
    args = dict(capacity=cap, max_time=horizon, max_produces=budget)
    if case.startswith("recovery-"):
        events = require_fresh_progress(frames, **args)
    else:
        events = replay(frames, overlap=case == "two-old-overlap", allow_stale=fault, **args)
    check_milestones(frames, events, milestones, case)
    end = frames[-1]
    require(named_endpoint(case, end, milestones[-1]), "final state misses named witness")
    if case in ("recovery-c0", "old-authority-fault"):
        i = next(i for i, e in enumerate(events) if e[0] == "recover")
        pre = frames[i]
        old = pre["jobs"][0]
        require(pre["head"] >= 8 and pre["included"] == 6 and old["cuts"][-1][0] == 8
                and pre["published"][0] == old["data"] and pre["proofs"][0] == (old["statement"],)*2,
                "old transaction was not complete at recovery")
        if fault:
            require(frames[-2]["privateHistory"] is True and frames[-2]["available"] == (True, True),
                    "selected stale landing missing live resources")
            require(events[-1] == ("land", 0, 0, 6, 8) and end["generation"] == 1,
                    "missing actual stale-generation landing")
        else:
            require(end["head"] == 9 and end["parentAnchor"][:2] == (1, 8)
                    and end["finalized"] == 8 and end["activeSnapshot"] == pre["now"] + 1,
                    "fresh finalized anchor was not used for third block")
    elif case == "recovery-c1":
        require(("recover", 7, 8) in events and end["records"][1][0] == 0
                and end["records"][2][0:2] == (1, 7) and end["jobs"][1]["cuts"][0] == end["records"][1][2],
                "retained checkpoint was not used for replacement")
    elif case == "two-old-overlap":
        require(("land", 1, 0, 6, 7) in events and ("publish", 0, False) in events
                and events[-1] == ("land", 0, 0, 7, 8), "missing actual overlap")
        i = events.index(("publish", 0, False))
        pre = frames[i + 1]
        require(pre["proofs"][0] == (pre["jobs"][0]["statement"],)*2 and
                ("publish", 0, True) in events[i+1:], "suffix rejection was masked")
    elif case == "unit":
        require(events[-1] == ("land", 0, 0, 6, 7) and len(end["jobs"][0]["cuts"]) == 2,
                "missing capacity-one landing")
    elif case == "late-capture":
        require(end["jobs"][0]["reference"] > 0, "missing late capture")
    return events


def current_receipt(workspace_root, case, raw, *, expected_claim=None):
    from product_claim import emit
    return emit("proving", workspace_root, case, raw, expected_claim=expected_claim)


if __name__ == "__main__":
    from product_claim import command
    command(current_receipt, __doc__)
