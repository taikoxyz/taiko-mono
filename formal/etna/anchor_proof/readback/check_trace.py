"""Read one digest-pinned TLC trace against independent, frozen source fixtures."""

import argparse
from dataclasses import replace
import hashlib
import json
from pathlib import Path
import sys

from tlc_values import Refusal, boolean, integer, record, strict_json, string
from trace_input import read_pinned_raw

ORACLE = "fee6c783b113f4aa3c1388745e2df66af7ec24b2f54ad4b46ef1cf1b65bd9cbe"
SUPPLEMENT = "5463194fdc2072dc30fe376774af4a4a0163ba6c3dc129e5a777e5a5c6e57a18"
OUTCOMES = {
    "coverage-absent":"PASS",
    "safety": "PASS", "red": "AnchorFenceSafe", "latest-c": "AnchorFenceSafe",
    "pressure": "NoPressureRefusal", "overlap": "NoOverlap",
    "direct": "NoDirectLong", "retained": "NoRetained", "pending": "NoPendingTrust",
    "recovered": "NoRecovered", "new": "NoNewDomainLanded",
    "frozen": "NoOriginFrozen", "budget": "NoAncestryBudget",
    "p-only": "NoPOnlyWitness", "omit-comet": "ActualCutSafe",
    "latest-f": "OriginFallbackSafe", "drop-pending": "SignerTrustSafe",
}
RECORDED_CAPTURE_CASES={"trimLong":"long", "noInheritedRoot":"long", "recordAtB":"long",
                        "wrongTerminalNext":"v"}
DOMAINS = {
    "s": "script l1 history node jobs auth authCaptured",
    "row": "number id parent offer outcome g c lastEL head tail m f nonce records origins signals",
    "record": "height parent g el comet fi root state",
    "signal": "height el root", "origin": "g height number time f",
    "node": "g origin base chain tip state own pin target targetEL stage matched trust candidate phase pending",
    "ledger": "seats principalD exitD snapshotHeight members",
    "block": "tag g height anchor anchorID witness el comet root parentEL parentComet lastCommit fi tx0 tx bft time current next decision state",
    "job": "id g origin p h ref refID start blocks data cuts terminal root blobs pair statement complete parentBlock pOnly ordinaryRoots readAt certs attest",
    "cut": "height el comet fi", "input": "kind arg at",
    "receipt": "event input outcome before",
}


def require(condition, label):
    if not condition:
        raise Refusal(label)


def fields(row, name):
    require(isinstance(row, dict) and set(row) == set(DOMAINS[name].split()),
            f"{name} fields differ from frozen schema")


class Sequence(tuple):
    pass


class FiniteSet(tuple):
    pass


def data(value):
    if value.kind == "record":
        return {key: data(item) for key, item in value.data}
    if value.kind == "tuple":
        return Sequence(data(item) for item in value.data)
    if value.kind == "set":
        return FiniteSet(data(item) for item in value.data)
    if value.kind == "int":
        return integer(value)
    if value.kind == "string":
        return string(value)
    if value.kind == "bool":
        return boolean(value)
    if value.kind == "model":
        return ("MODEL", value.data)
    if value.kind == "function":
        return ("FUNCTION", tuple((data(k), data(v)) for k, v in value.data))
    raise Refusal("unknown value type")


def index(rows, key):
    result = {row[key]: row for row in rows}
    require(len(result) == len(rows), f"duplicated {key} in record collection")
    return result


def subset(row, *keys):
    return tuple(row[k] for k in keys)


def storage(row):
    return subset(row, "g", "c", "lastEL", "head", "tail", "m", "f", "nonce", "records", "origins", "signals")


def fixture(path, pin):
    content = Path(path).read_bytes()
    require(hashlib.sha256(content).hexdigest() == pin, "source fixture SHA mismatch")
    return strict_json(content.decode("utf-8", "strict"))


def cut(row):
    fields(row, "cut")
    return subset(row, "height", "el", "comet", "fi")


def from_block(block):
    return subset(block, "height", "el", "comet", "fi")


def slot_record(current, h):
    return index(current["records"], "height")[h]


def rec_identity(row):
    return subset(row, "parent", "g", "fi", "el", "comet")


def signals(current):
    return {h: subset(row, "height", "el", "root")
            for h, row in index(current["signals"], "height").items()}


def role_map(value):
    if isinstance(value,dict):
        row = value
    else:
        require(type(value) is tuple and len(value)==2 and value[0]=="FUNCTION",
                "expected role-to-root function")
        row = dict(value[1])
    require(set(row)=={"origin","record","config","queue"}, "readAt exact role domain")
    return row


def indexed_sequence(value, size, label):
    if isinstance(value,Sequence):
        require(len(value)==size,f"{label} index domain")
        return value
    require(type(value) is tuple and len(value)==2 and value[0]=="FUNCTION",f"{label} function type")
    keyed = dict(value[1])
    require(set(keyed)==set(range(1,size+1)),f"{label} index domain")
    return Sequence(keyed[i] for i in range(1,size+1))


def check_extra_job(job):
    roots=job["ordinaryRoots"]
    require(isinstance(roots,FiniteSet) and all(type(k) is int for k in roots),
            "ordinaryRoots type")
    roles=role_map(job["readAt"])
    require(all(type(k) is int and k in roots for k in roles.values()), "ordinary read authority")
    require(job["ref"] in roots and all(b["anchor"] in roots for b in job["blocks"]),
            "missing reference or new block ordinary root")
    attest=job["attest"]
    require(isinstance(attest,Sequence) and len(attest)==2
            and all(isinstance(a,Sequence) and len(a)==2 and a[0]==name and a[1]==job["statement"]
                    for name,a in zip(job["pair"],attest)), "paired attestations must bind same statement")
    certs=indexed_sequence(job["certs"],len(job["blocks"]),"certs")
    for cert,b in zip(certs,job["blocks"]):
        require(isinstance(cert,dict) and set(cert)=={"g","comet","committee","power"}
                and type(cert["power"]) is int and cert["power"]==4
                and subset(cert,"g","comet","committee")==subset(b,"g","comet","current"),
                "symbolic full-participation certificate binding")
    inputs=indexed_sequence(job["data"],len(job["blocks"]),"data")
    require(tuple(inputs)==tuple(b["tag"] for b in job["blocks"]), "immutable full ordered payload labels")


def validate_shape(s):
    fields(s, "s")
    require(type(s["authCaptured"]) is bool, "authCaptured type")
    n, history = s["node"], s["history"]
    fields(n, "node")
    fields(n["origin"], "origin")
    fields(n["state"], "ledger")
    fields(n["base"], "record")
    require(isinstance(history, Sequence) and history and history[-1] == s["l1"], "history tip differs")
    by_number = index(history, "number")
    require(all(type(n[k]) is int and n[k]>=0 for k in ("g","own","pin","target","tip","matched"))
            and type(n["trust"]) is bool and isinstance(n["chain"],Sequence)
            and isinstance(n["pending"],FiniteSet), "node field types")
    require(n["stage"] in ("Matched","Pending","EL","Mismatch","Generation")
            and n["phase"] in ("Empty","Prepared","Admitted","Signed"), "node stage/phase")
    require(n["own"] in by_number and n["pin"] in by_number and isinstance(n["targetEL"],str),
            "missing own finalized header, pin, or selected EL")
    for i, r in enumerate(history):
        fields(r, "row")
        require(isinstance(r["lastEL"],str), "L1 lastEL type")
        require(all(type(r[k]) is int and r[k]>=0 for k in ("number","g","c","head","tail","nonce")), "L1 integer types")
        if i:
            prev = history[i - 1]
            require(r["number"] > prev["number"] and r["parent"] == prev["id"], "L1 parent/number")
            require(isinstance(r["id"], Sequence) and r["id"][:-1] == prev["id"], "L1 ancestry identity")
        for key, name in (("records","record"), ("signals","signal"), ("origins","origin")):
            require(isinstance(r[key], FiniteSet), f"{key} set expected")
            for item in r[key]:
                fields(item, name)
        index(r["records"], "height")
        index(r["signals"], "height")
        index(r["origins"], "g")
    for b in list(n["chain"]) + ([n["candidate"]] if isinstance(n["candidate"], dict) else []):
        fields(b, "block")
        fields(b["state"], "ledger")
        require(by_number[b["anchor"]]["id"] == b["anchorID"], "block anchor branch identity")
    require(isinstance(s["jobs"],FiniteSet), "job collection type")
    for job in s["jobs"]:
        fields(job, "job")
        check_extra_job(job)
        require(type(job["complete"]) is bool and type(job["pOnly"]) is bool
                and all(isinstance(job[k],Sequence) for k in ("blocks","cuts","statement","blobs","pair")),
                "job collection/bool types")
        require(by_number[job["ref"]]["id"] == job["refID"], "job reference identity")
    index(s["jobs"], "id")


def framed(trace):
    states, actions = [], []
    for i, frame in enumerate(trace.frames):
        receipt = record(frame.receipt, fields=DOMAINS["receipt"].split())
        expected_before = frame.state if not i else trace.frames[i - 1].state
        require(receipt["before"] == expected_before, f"receipt.before differs at state {i+1}")
        s = data(frame.state)
        validate_shape(s)
        record(receipt["input"], fields=DOMAINS["input"].split())
        a = {"event":string(receipt["event"]), "outcome":string(receipt["outcome"]), **data(receipt["input"])}
        require(a["event"] == a["kind"], f"receipt event/input disagreement at {i+1}")
        require(frame.cursor == (0 if s["script"] == "Micro" else i), f"cursor at {i+1}")
        if states:
            previous = states[-1]
            if ((a["kind"],a["outcome"]) in {("Capture","invalid"),("Rebuild","unauthenticated"),
                                              ("FailedRead","unavailable")}):
                require(trace.frames[i - 1].state == frame.state, "refused input changed typed operational state")
            require(s["script"] == previous["script"], "script changed")
            require(s["history"][:len(previous["history"])] == previous["history"], "history prefix rewritten")
            oldjobs, jobs = index(previous["jobs"],"id"), index(s["jobs"],"id")
            require(all(jobs.get(k) == v for k,v in oldjobs.items()), "captured job replaced or removed")
            if a["kind"] == "Slot":
                row = s["l1"]
                require((a["at"],a["arg"],a["outcome"]) == subset(row,"number","offer","outcome"),
                        "slot receipt disagrees with branch-local history")
                require(previous["node"] == s["node"] and previous["jobs"] == s["jobs"]
                        and previous["auth"] == s["auth"] and previous["authCaptured"] == s["authCaptured"], "landing modified node, job or saved authorization")
                if a["outcome"] != "accepted":
                    require(storage(previous["l1"]) == storage(row), "refused/idle slot changed contract storage")
        states.append(s)
        actions.append(a)
    return states, actions


def pairs(states, actions):
    return zip(states, actions[1:], states[1:])


def find(items, predicate, label):
    for item in items:
        if predicate(item):
            return item
    raise Refusal(f"missing literal evidence: {label}")


def job_in(s, name):
    return index(s["jobs"], "id")[name]


def literal_job(job, start, mids, end, root, ref, domain=0):
    require(subset(job,"g","p","h","ref","complete") == (domain,start[0],end[0],ref,True), "job range/ref/completion")
    require(cut(job["start"]) == tuple(start) and cut(job["terminal"]) == tuple(end), "job boundary cuts")
    require(tuple(cut(c) for c in job["cuts"]) == tuple(tuple(c) for c in mids), "job interior leaves")
    require(job["root"] == root and len(job["blocks"]) == end[0]-start[0]
            and len(indexed_sequence(job["data"],end[0]-start[0],"data")) == end[0]-start[0], "full blocks/data/root")
    for b, expected in zip(job["blocks"], [*mids,end]):
        fields(b, "block")
        require(from_block(b) == tuple(expected), "job block differs from ordered cuts")
    st = job["statement"]
    require(isinstance(st,Sequence) and len(st) == 19 and len(job["pair"]) == 2
            and 1 <= len(job["blobs"]) <= 6, "statement/pair/blob cardinality")
    require((st[4],st[5],st[6],st[7],st[9],st[10],st[11],st[12],st[13],st[16],st[17])
            == (domain,start[0],start[1],start[2],end[0],end[1],end[2],root,ref,start[3],end[3]),
            "actual 19-word statement does not bind concrete source endpoints")
    require(tuple(st[:4]) == ("etnaLand","L1","L2","Inbox") and st[8]=="Config"
            and st[14]==job["refID"] and st[15]==("blobDigest",job["blobs"])
            and st[18]==("cutDigest",domain,start[0],end[0],job["cuts"]),
            "abstract encoding or domain/digest inputs differ")
    require(type(job["pOnly"]) is bool and isinstance(job["origin"], dict)
            and job["pOnly"] == (start[0] > job["origin"]["height"]), "p-only selector scope")


def micro_block_values(b, micro):
    names = ["height","anchor","witness","parentEL","EL","parentCometID",
             "Comet","root","fi","currentSet","nextSet","decidesSetAtHeightPlus2"]
    require(micro["blockFields"] == names, "unexpected frozen Micro field order")
    expected = list(find(micro["blocks"],lambda r:r[0]==b["height"],"Micro literal block"))
    expected[1] = micro["anchors"][expected[1]][0]
    actual = subset(b,"height","anchor","witness","parentEL","el","parentComet",
                    "comet","root","fi","current","next","decision")
    require(b["g"] == 0 and actual == tuple(expected),
            f"Micro g=0 H{expected[0]} fields including current/next/decision")


def micro_visible_blocks(states, micro):
    for state in states:
        for job in state["jobs"]:
            expected = micro["proofs"][job["id"]]
            require(tuple(b["height"] for b in job["blocks"]) == tuple(expected[3]),
                    "Micro job's ordered heights")
            for b in job["blocks"]:
                micro_block_values(b,micro)
        n = state["node"]
        for b in n["chain"]:
            micro_block_values(b,micro)
        if isinstance(n["candidate"],dict):
            micro_block_values(n["candidate"],micro)


def check_micro(s, actions, profile, sup):
    micro = sup["micro"]
    _, first, second = profile.split(":")
    expected = find(micro["allOffers"],lambda r:r[0]==first and r[3]==second,"declared offer pair")
    i0 = s[0]
    require(i0["script"] == "Micro" and subset(i0["node"],"tip","own","matched","target","trust") == (10,200,10,10,True), "Micro origin gate")
    initial = i0["l1"]
    require(subset(initial,"number","g","c","head","tail","nonce") == (450,0,10,0,0,0), "Micro actual start")
    for name, spec in micro["proofs"].items():
        literal_job(job_in(i0,name),spec[4],spec[5],spec[6],spec[7],450)
    slots = [(a,now) for _,a,now in pairs(s,actions) if a["kind"] == "Slot"]
    require(len(slots) == 2, "requires exactly two real attempted slots")
    for idx,(act,now) in enumerate(slots):
        ref=expected[3*idx:3*idx+3]
        st = micro["states"][ref[2]]
        row=now["l1"]
        require((act["at"],act["arg"],act["outcome"]) == ((500,600)[idx],ref[0],"accepted" if ref[1].startswith("accepted") else ref[1]), "slot input/outcome")
        require(subset(row,"c","g","head","tail","nonce") == (st[0],0,0,0,0), "slot storage")
        require(slot_record(row,10) == slot_record(initial,10), "Micro start landing changed")
        add = tuple(rec_identity(r) for h,r in sorted(index(row["records"],"height").items()) if h!=10)
        require(add == tuple(tuple(r) for r in st[1]), "Micro landing parent or saved record")
        require(signals(row) == {**signals(initial),**{r[0]:tuple(r) for r in st[2]}}, "Micro signals")
        require(job_in(now,"l") == job_in(i0,"l"), "Micro changed long")
    return {"offers":[first,second],"actualC":[r[1]["l1"]["c"] for r in slots],"endState":expected[-1]}


def profile_job(oracle, state, name):
    j=oracle["proofs"][name]
    job=job_in(state,name)
    literal_job(job,[j[1],j[3],j[4],j[5]],j[12],[j[2],j[6],j[7],j[9]],j[8],j[10],j[0])
    require(len(job["blocks"]) == len(j[11]), "Main literal proof block count")
    for b,key in zip(job["blocks"],j[11]):
        block_values(b,oracle["blocks"][key],oracle["l1Rows"])
    return job


def slot(states,actions,job,outcome):
    return find(pairs(states,actions),lambda t:(t[1]["kind"],t[1]["arg"],t[1]["outcome"])==("Slot",job,outcome),f"{job} slot {outcome}")


def committed(s,h,domain=0):
    return find(s["node"]["chain"],lambda b:b["g"]==domain and b["height"]==h,f"committed domain{domain} H{h}")


# Per-height next sets on the two committed main chains. Origin F fixes
# H11/H12 and new H15/H16. H11's A decision makes H13 Stake. H12/B and
# subsequent disabled/F decisions make old H14..H16 F. New H15/Z decides
# new H17 G, and new H16/Z decides H18 G.
MAIN_NEXT = {(0,11):"F", (0,12):"Stake", (0,13):"F", (0,14):"F", (0,15):"F",
             (1,15):"F", (1,16):"G", (1,17):"G"}


def block_values(b, fixture, anchor_names):
    g,h,anchor,witness,el,comet,root,fi,current,decision,_ = fixture
    require(subset(b,"g","height","anchor","witness","el","comet","root","fi","current","next","decision")
            == (g,h,anchor_names[anchor][0],witness,el,comet,root,fi,current,MAIN_NEXT[g,h],decision),
            f"Main g={g} H{h} fields including current/next/decision")


def check_ledger(value, source):
    require(set(value["seats"]) == set(source[0]) and value["exitD"] == (0 if source[1]=="unset" else source[1])
            and value["principalD"] == 1 and value["snapshotHeight"] == source[3]
            and set(value["members"]) == set(source[4]), "actual ledger differs from source")


def main_baseline(s,actions,o):
    prev,_,now = slot(s,actions,"P","accepted")
    profile_job(o,prev,"P")
    require(subset(prev["l1"],"c","head")==(10,0)
            and subset(now["l1"],"number","c","head")==(600,12,0), "P actual frontier")
    require(rec_identity(slot_record(now["l1"],12))==tuple(o["slot285"]["12"]), "P record")
    for name in ("h11","h12"):
        b=committed(prev,o["blocks"][name][1])
        block_values(b,o["blocks"][name],o["l1Rows"])
    return now


def complete_gate(states, target, exact_origin=0):
    seen=[]
    for z in states:
        n=z["node"]
        if n["g"]!=exact_origin or n["target"]!=target:
            continue
        r=index(z["history"],"number")[n["own"]]
        if r["c"]!=target:
            continue
        tup=(n["stage"], n["trust"])
        if not seen or seen[-1]!=tup:
            seen.append(tup)
    for want in (("Pending",False),("EL",False),("Matched",True)):
        require(want in seen, f"target{target} missing stage {want}")
    require(seen.index(("Pending",False)) < seen.index(("EL",False)) < seen.index(("Matched",True)),
            "target gate stage order")
    return seen


def recovery_detail(s,actions,o):
    old,_,_ = find(pairs(s,actions),lambda t:t[0]["l1"]["g"]==0 and t[2]["l1"]["g"]==1,"contract recovery")
    for name in ("h13","h14","h15"):
        block_values(committed(old,o["blocks"][name][1]),o["blocks"][name],o["l1Rows"])
    check_ledger(old["node"]["state"],o["ledgers"]["oldL15"])
    check_ledger(slot_record(old["l1"],14)["state"],o["ledgers"]["L14"])
    find(s,lambda z:z["node"]["g"]==1 and z["node"]["tip"]==14
         and z["node"]["state"]==slot_record(z["l1"],14)["state"],"new domain rebuilt from actual saved ledger")


def full_roles(states,o):
    seen={}
    for z in states:
        for b in z["node"]["chain"]:
            if b["g"]==1 and b["height"] in (15,16,17):
                name=f'n{b["height"]}'
                block_values(b,o["blocks"][name],o["l1Rows"])
                if b["height"]==15:
                    check_ledger(b["state"],o["ledgers"]["newL15"])
                    require(subset(b,"parentEL","parentComet","lastCommit")==("E14","EMPTY","EMPTY"),"first new-domain links")
                seen[b["height"]]=b["current"]
    return seen

def check_overlap(s,actions,o,direct):
    prev,act,now=slot(s,actions,"long","accepted")
    long=profile_job(o,prev,"long")
    find(s,lambda z:z["l1"]["c"]==12 and {"short","long"}<=set(index(z["jobs"],"id")), "both jobs already captured while c12")
    profile_job(o,prev,"short")
    require(job_in(now,"long")==long, "unchanged long")
    c_expected=12 if direct else 13
    require(subset(prev["l1"],"g","c","head")== (0,c_expected,0 if direct else 1), "overlap prestate")
    cur=now["l1"]
    require(subset(cur,"g","c","head")==(0,14,2) and rec_identity(slot_record(cur,14))==(c_expected,0,2,"E14","K14"),"actual parent/terminal record")
    require(signals(cur)[14]==(14,"E14","S14"), "signal at14")
    if direct:
        require(13 not in index(cur["records"],"height"), "direct-long materialized13")
    else:
        require(cut(long["cuts"][0])==(13,"E13","K13",1)
                and rec_identity(slot_record(cur,13))==(12,0,1,"E13","K13"),"current13 exact cut")
    return {"p":12,"c":c_expected,"h":14,"appliedSuffix":list(range(c_expected+1,15))}


def gate(n):
    return {k:n[k] for k in ("g","tip","own","pin","target","targetEL","stage","matched","trust")}


def pending_transition(states,actions,fault):
    for prev,a,now in pairs(states,actions):
        n=now["node"]; old=prev["node"]
        r=index(now["history"],"number")[n["own"]]
        if r["c"] > old["matched"] and n["own"] != old["own"] and r["g"]==n["g"]:
            if fault and n["trust"]:
                return {"previous":gate(old),"after":gate(n),"actualKnown":r["c"]}
            if not fault and n["target"]==r["c"] and n["stage"] in ("Pending","EL") and not n["trust"]:
                return {"previous":gate(old),"after":gate(n),"actualKnown":r["c"]}
    raise Refusal("missing newly learned target and corresponding gate transition")


def pressure(s,actions,accept):
    for prev,a,now in pairs(s,actions):
        p=prev["node"]; n=now["node"]; b=p["candidate"]
        if not isinstance(b,dict) or (p["tip"],prev["l1"]["c"],b["height"],b["anchor"]) != (13,12,14,320):
            continue
        anchor=index(prev["history"],"number")[320]
        prior=committed(prev,13)
        if (anchor["c"],prior["anchor"],prior["witness"],prior["el"]) != (10,320,"inherit","E13"):
            continue
        admitted = n["phase"] in ("Admitted","Signed") or n["tip"]==14
        if a["kind"] != "Admit" or a["outcome"] != ("admitted" if accept else "pressure"):
            continue
        if accept == admitted:
            require(not admitted or p["phase"]=="Prepared", "pressure: pre-admission phase")
            if not admitted:
                require(subset(p,"chain","tip","state","pending")==subset(n,"chain","tip","state","pending"),"refused block changed committed state")
            return {"height":14,"anchoredC":10,"actualC":12,"outcome":a["outcome"],"admitted":admitted}
    raise Refusal("missing actual 14/B admission or refusal after valid prefix")


def recovered(s,actions):
    before,fresh,after=find(pairs(s,actions),lambda t:t[0]["l1"]["g"]==0 and t[2]["l1"]["g"]==1,"successful recover")
    l=after["l1"]; old=before["l1"]
    require(subset(old,"c","nonce","head")== (14,0,2) and subset(l,"number","c","nonce","head","f")== (141000,14,1,2,"F"),"recovery contract counters")
    old15=committed(before,15)
    require(old15["state"]["exitD"]==15 and slot_record(old,14)["state"]["exitD"]==0, "discarded exit and retained ledger")
    require(old["records"]==l["records"] and old["signals"]==l["signals"],"recover rewrote landings/signals")
    origin=index(l["origins"],"g")[1]
    require(subset(origin,"height","number","time","f")==(14,141000,1701692000,"F"),"fixed origin")
    stalePrev,staleA,staleAfter=find(pairs(s,actions),lambda t:t[2]["l1"]["number"]==1000 and t[0]["l1"]["number"]!=1000,"stale recovery attempt")
    require(staleA["kind"]=="Recover" and staleA["outcome"]=="stale" and stalePrev["authCaptured"] is True,"stale recovery receipt")
    require(isinstance(stalePrev["auth"],dict) and subset(stalePrev["auth"],"g","c","nonce")== (0,12,0),"captured old authorization")
    require(storage(stalePrev["l1"])==storage(staleAfter["l1"]) and stalePrev["node"]==staleAfter["node"],"stale recovery changed contract or node")
    require(subset(fresh,"kind","arg","at","outcome")==("Recover","fresh",141000,"recovered"),
            "fresh independent recovery receipt")
    require(before["authCaptured"] is True and after["authCaptured"] is True
            and before["auth"]==after["auth"]==stalePrev["auth"]
            and subset(before["auth"],"g","c","nonce","until")== (0,12,0,1720000000),
            "old diagnostic capture must remain the original c12 input")
    return {"c":14,"r":141000,"discardedExit":15,"staleOutcome":staleA["outcome"],
            "freshReceipt":subset(fresh,"kind","arg","at","outcome"),
            "actualPrestate":subset(old,"g","c","nonce"),
            "freshInputScope":"Raw input exposes the fresh tag. The full tuple is a pinned internal recipe, not an independently visible receipt payload."}


def same_except(before, after, changed):
    require(set(before)==set(after) and all(before[k]==after[k] for k in before if k not in changed),
            "actual frame changed outside allowed fields")


def check_pin(states,actions):
    expected=[
        ("Slot","s","accepted",500), ("Learn",None,"learned",500),
        ("EL",None,"elMatched",None), ("FailedRead",None,"unavailable",None),
        ("Slot",("idle","s"),None,600), ("Learn",None,"learned",600),
        ("Comet",None,"matched",None),
    ]
    index_in_path=0
    observed=[]
    for before,a,after in pairs(states,actions):
        kind,arg,outcome,at=expected[index_in_path]
        if a["kind"]!=kind or (at is not None and a["at"]!=at):
            continue
        if arg is not None and a["arg"] not in ((arg,) if isinstance(arg,str) else arg):
            continue
        if outcome is not None and a["outcome"]!=outcome:
            continue
        n=after["node"]
        if index_in_path==0:
            require(subset(after["l1"],"c","lastEL")==(11,"mE11"), "pin setup short landing")
        elif index_in_path in (1,2,3,4,5):
            stage="Pending" if index_in_path==1 else "EL"
            own=600 if index_in_path==5 else 500
            require(subset(n,"own","pin","target","targetEL","stage","trust")
                    == (own,500,11,"mE11",stage,False),"wrong intermediate pin or gate")
            if index_in_path==3:
                require(before==after, "failed read changed operational state")
            if index_in_path==4:
                require(a["outcome"]==("idle" if a["arg"]=="idle" else "alreadySettled"),
                        "wrong second-slot result")
        else:
            old=before["node"]
            require(subset(old,"own","pin","target","stage","trust")== (600,500,11,"EL",False),
                    "pinned read predecessor")
            pin=index(before["history"],"number")[500]
            local=committed(before,11)
            source=slot_record(pin,11)
            require(subset(source,"el","comet")==subset(local,"el","comet")==("mE11","mK11"),
                    "pinned 285 record and local ancestor")
            require(subset(n,"own","pin","target","targetEL","stage","matched","trust")
                    ==(600,500,11,"mE11","Matched",11,True), "pin completion")
        observed.append({"event":a["kind"],"arg":a["arg"],"outcome":a["outcome"],"gate":gate(n)})
        index_in_path+=1
        if index_in_path==len(expected):
            return {"stages":observed}
    raise Refusal("missing ordered pin/failed read/unchanged target/comparison history")


def check_remote_gate(states,actions):
    observations=[]
    landed=learned=compared_el=failed=False
    replayed=[]
    for previous,a,current in pairs(states,actions):
        old=previous["node"]; node=current["node"]
        event,result=a["kind"],a["outcome"]
        if (not landed and (event,a["arg"],result)==("Slot","l","accepted")
                and current["l1"]["c"]==12 and node["tip"]==10):
            landed=True
        elif (landed and not learned and (event,result)==("Learn","learned")
              and node["tip"]==10 and node["target"]==12 and node["stage"]=="Pending" and not node["trust"]):
            learned=True
        elif learned and (event,result)==("FailedRead","unavailable") and old["target"]==12:
            require(old["stage"] in ("Pending","EL") and not old["trust"] and previous==current,
                    "failed remote checkpoint read cleared or changed pending state")
            failed=True
        elif learned and (event,result)==("Replay","replayed") and not compared_el:
            require(old["target"]==node["target"]==12 and not old["trust"] and not node["trust"]
                    and node["tip"]==old["tip"]+1 and node["stage"]=="Pending",
                    "remote certified catch-up changed gate or skipped height")
            replayed.append(node["tip"])
        elif learned and (event,result)==("EL","elMatched"):
            require(replayed==[11,12] and node["targetEL"]=="mE12" and node["stage"]=="EL"
                    and not node["trust"] and committed(current,12)["el"]==node["targetEL"],
                    "expected explicit EL match after non-signing replay")
            compared_el=True
        elif learned and (event,result)==("Comet","matched"):
            r=index(previous["history"],"number")[old["pin"]]
            require(compared_el and failed and old["stage"]=="EL" and not old["trust"]
                    and subset(slot_record(r,12),"el","comet")==("mE12","mK12")
                    and subset(committed(current,12),"el","comet")==("mE12","mK12")
                    and node["target"]==node["matched"]==12 and node["stage"]=="Matched" and node["trust"],
                    "missing failed read or pinned EL/Comet terminal match")
            observations.append({"event":event,"outcome":result,"gate":gate(node)})
            return {"actualC":12,"nonSigningReplayedHeights":replayed,"actualEvents":observations}
        else:
            if learned:
                require(not node["trust"] and not (event=="Sign" and result=="signed"),
                        "gate opened or signed before full remote checkpoint match")
            continue
        observations.append({"event":event,"outcome":result,"gate":gate(node)})
    raise Refusal("missing ordered remote landing, pending, failed read, replay or checkpoint match")


def check_bad_read(states,actions,mode):
    early=mode=="early-el"
    event="Learn" if early else "Comet"
    arg="wrongComet" if mode=="record-comet" else "wrongEL"
    before,a,after=find(pairs(states,actions),lambda t:(t[1]["kind"],t[1]["arg"])==(event,arg),
                        "tagged inconsistent finalized or record response")
    old=before["node"]; n=after["node"]
    same_except(before,after,{"node"})
    require(n["stage"]=="Mismatch" and not n["trust"] and n["matched"]==old["matched"],
            "mismatch failed to keep signing closed")
    if early:
        r=index(before["history"],"number")[a["at"]]
        require(r["g"]==old["g"] and old["tip"]>=r["c"]>old["origin"]["height"],
                "EL comparison lacks locally available post-origin target")
        local=committed(before,r["c"])
        require(a["outcome"]=="learned" and n["target"]==r["c"] and n["own"]==a["at"]
                and n["targetEL"]!=local["el"] and local["el"]==r["lastEL"],"immediate EL conflict")
        same_except(old,n,{"own","pin","target","targetEL","stage","trust"})
    else:
        require(a["outcome"]=="mismatch" and old["stage"]=="EL" and not old["trust"],
                "285 rejection before EL matched")
        r=index(before["history"],"number")[old["pin"]]
        local=committed(before,old["target"])
        actual=slot_record(r,old["target"])
        require(old["target"]>old["origin"]["height"] and old["targetEL"]==r["lastEL"]==local["el"]
                and subset(actual,"el","comet")==subset(local,"el","comet"),"canonical positive read neighbour")
        same_except(old,n,{"stage","trust","matched"})
    return {"event":event,"input":arg,"before":gate(old),"after":gate(n),
            "scope":"Inconsistent abstract read offered to the consumer; canonical storage preserved."}


CAPTURE_INPUTS={"recordAtB","wrongOriginNext","wrongTerminalNext","trimLong","noInheritedRoot",
                "pConfig","pRecord","pQueue"}
REBUILD_INPUTS={"wrongArchiveEL","wrongArchiveRoot","noStateAuth","noOriginAuth","noGenesisAuth","noSessionAuth"}


def check_refused_input(states,actions,mode):
    prefix,arg=mode.split(":",1)
    capture=prefix=="capture-invalid"
    require(arg in (CAPTURE_INPUTS if capture else REBUILD_INPUTS),"unknown refusal input")
    kind,outcome=("Capture","invalid") if capture else ("Rebuild","unauthenticated")
    before,a,after=find(pairs(states,actions),lambda t:(t[1]["kind"],t[1]["arg"],t[1]["outcome"])
                        ==(kind,arg,outcome),"actual consumer refusal")
    require(before==after,"refused interface operation changed operational state")
    if not capture:
        r=before["l1"]
        require(r["g"]==1 and r["c"]==14 and before["node"]["g"]==0
                and slot_record(r,14)["el"]==r["lastEL"]=="E14","rebuild refusal without valid saved frontier")
    return {"consumer":kind,"input":arg,"outcome":a["outcome"],
            "fullOperationalFrameEqual":True,"jobs":[j["id"] for j in before["jobs"]],
            "scope":"Malformed abstract input rejected; no sound proof or actual authentication constructed."}


def check_recover_unavailable(states,actions):
    require(len(states)==2 and states[0]["script"]=="ShortFirst", "expected direct initial-state probe")
    before,a,after=next(pairs(states,actions))
    require(subset(a,"kind","arg","at","outcome")==("Recover","stale",1000,"unavailable"),
            "expected missing-authorization recovery attempt")
    old=before["l1"]; new=after["l1"]
    require(subset(old,"number","g","c","nonce")==(450,0,10,0)
            and before["authCaptured"] is False and before["auth"]=="none", "missing unauthorized initial frontier")
    require(new["number"]==1000 and new["outcome"]=="unavailable" and new["parent"]==old["id"]
            and after["history"]==(*before["history"],new),"one new L1 attempt expected")
    require(storage(old)==storage(new),"unavailable recovery changed actual Inbox storage")
    same_except(before,after,{"l1","history"})
    return {"previousNumber":450,"newNumber":1000,"outcome":a["outcome"],"actualC":new["c"],
            "cursorAdvancedBy":1,"storageAndNodeJobsAuthUnchanged":True}


def check_old_jobs(states,actions,oracle):
    require(states[0]["script"]=="ShortFirst" and states[-1]["l1"]["number"]==141330,
            "old-job witness requires the completed ShortFirst history")
    pre_new,_,landed=slot(states,actions,"new","accepted")
    profile_job(oracle,pre_new,"new")
    require(pre_new["l1"]["c"]==14 and subset(landed["l1"],"g","c","nonce","lastEL")
            ==(1,15,1,"E15new") and rec_identity(slot_record(landed["l1"],15))
            ==(14,1,2,"E15new","K15new"),"new-domain landing must precede stale attempts")
    offers=[(p,a,n) for p,a,n in pairs(states,actions)
            if a["kind"]=="Slot" and a["at"]>landed["l1"]["number"]]
    expected=[("P",141310),("short",141320),("long",141330)]
    require([(a["arg"],a["at"]) for _,a,_ in offers]==expected,"old-job order and inclusion slots")
    observations=[]
    for p,a,n in offers:
        j=profile_job(oracle,p,a["arg"])
        require(a["outcome"]=="alreadySettled" and n["l1"]["number"]==a["at"]
                and p["l1"]["number"]<a["at"],"actual stale transaction outcome")
        require(j==job_in(landed,a["arg"])==job_in(n,a["arg"])
                and p["jobs"]==n["jobs"],"captured old packet changed")
        require(storage(p["l1"])==storage(n["l1"])==storage(landed["l1"])
                and n["history"]==(*p["history"],n["l1"]),"old-job protocol frame")
        same_except(p,n,{"l1","history"})
        require(j["h"]<=p["l1"]["c"] and a["at"]-j["ref"]>8191
                and j["g"]!=p["l1"]["g"],"compound old target/reference/generation evidence")
        observations.append({"job":a["arg"],"at":a["at"],"outcome":a["outcome"],
                             "p":j["p"],"h":j["h"],"proofGeneration":j["g"],"reference":j["ref"]})
    return {"actualC":15,"actualGeneration":1,"nonce":1,"attempts":observations,
            "scope":"Already settled targets, expired references and old generation coincide; isolated generation sensitivity remains OPEN."}


def evaluate(mode, states, actions, oracle, sup):
    end=states[-1]
    if end["script"] == "Micro":
        micro_visible_blocks(states,sup["micro"])
    if mode.startswith("micro:"):
        return check_micro(states,actions,mode,sup)
    if mode=="pin":
        return check_pin(states,actions)
    if mode in ("early-el","record-el","record-comet"):
        return check_bad_read(states,actions,mode)
    if mode.startswith(("capture-invalid:","restore-refusal:")):
        return check_refused_input(states,actions,mode)
    if mode=="recover-unavailable":
        return check_recover_unavailable(states,actions)
    if mode=="old-jobs":
        return check_old_jobs(states,actions,oracle)
    if mode in ("red","latest-c","pressure"):
        return pressure(states,actions,mode!="pressure")
    if mode in ("overlap","direct"):
        main_baseline(states,actions,oracle)
        block_values(committed(end,13),oracle["blocks"]["h13"],oracle["l1Rows"])
        block_values(committed(end,14),oracle["blocks"]["h14"],oracle["l1Rows"])
        return check_overlap(states,actions,oracle,mode=="direct")
    if mode in ("pending","drop-pending"):
        return pending_transition(states,actions,mode=="drop-pending")
    if mode=="retained":
        for prev,a,now in pairs(states,actions):
            p=prev["node"]; n=now["node"]; b=n["candidate"]
            if isinstance(b,dict) and p["candidate"]==b and p["own"]!=n["own"] and n["own"]==320:
                require(subset(b,"height","anchor","decision","current")==(11,200,"Stake","F"), "retained proposal")
                return {"height":11,"anchor":200,"learned":320,"decision":"Stake","time":b["time"]}
        raise Refusal("missing unchanged candidate on learning B")
    if mode=="p-only":
        prev,a,now=slot(states,actions,"v","accepted"); j=job_in(prev,"v"); expected=sup["pOnlyPositive"]["fullFrozenProof"]
        literal_job(j,expected["origin"],expected["interiors"],expected["terminal"],expected["terminalRoot"],141200)
        require(subset(j["parentBlock"],"height","el","comet","anchor","next","decision")== (12,"E12","K12",320,"Stake","F"), "p12 fields and sets")
        require(j["pOnly"] is True, "p-only scope not represented")
        require(320 not in j["ordinaryRoots"] and {141100,141200}<=set(j["ordinaryRoots"]) and
                all(number!=320 for number in role_map(j["readAt"]).values()),"p.EL-only root leaked into ordinary authority")
        for b,v in zip(j["blocks"],sup["pOnlyPositive"]["blocks"]):
            require(subset(b,"height","anchor","witness","el","parentEL","comet","parentComet","root","fi","current","next","decision")
                    ==(v[0],141100,*v[2:9],*v[10:13]),"V-block ancestry and sets")
            require(b["tx0"]==b["height"]-13, "due FI index")
        require(subset(now["l1"],"number","c","head")== (141300,14,2)
                and rec_identity(slot_record(now["l1"],14))==(12,0,2,"vE14","vK14"),"V landing")
        return {"reference":141200,"pAnchorDistance":140880,"ordinaryNewAnchorDistance":100,"newCurrent":["Stake","F"]}
    if mode in ("twin","omit-comet"):
        p,a,n=slot(states,actions,"beta","accepted" if mode=="omit-comet" else "cutMismatch")
        _,_,alpha=slot(states,actions,"alpha","accepted")
        live=slot_record(p["l1"],11); j=job_in(p,"beta")
        ac=rec_identity(live); bc=cut(j["cuts"][0])
        require(ac==(10,0,0,"forkE11","forkK11a") and bc==(11,"forkE11","forkK11b",0)
                and alpha["l1"]["c"]==11,"independent conditional cuts")
        require(p["l1"]["c"]==11 and n["l1"]["c"]==(12 if mode=="omit-comet" else 11), "Twin resulting frontier")
        return {"live":[11,ac[3],ac[4],ac[2]],"proof":bc,"outcome":a["outcome"]}
    if mode=="budget":
        row=find(states,lambda z:z["l1"]["number"]==140000,"outage position")
        b=committed(row,15)
        require((row["l1"]["c"],b["anchor"],b["witness"],b["state"]["exitD"])==(14,600,"inherit",15),"H15 and retained frontier")
        minref=row["l1"]["number"]-8191
        require(minref-b["anchor"]>131072,"actual ancestry bound")
        return {"N":140000,"oldestReference":minref,"leastDistance":minref-b["anchor"]}
    if mode in ("recovered","new","frozen","latest-f"):
        facts=recovered(states,actions)
        if mode=="recovered":
            facts["localRebuildObserved"]=any(z["node"]["g"]==1 and z["node"]["tip"]==14
                    and z["node"]["state"]==slot_record(z["l1"],14)["state"] for z in states)
            return facts
        if mode=="new":
            recovery_detail(states,actions,oracle)
            require(end["script"] in ("ShortFirst","DirectLong"), "unknown Main landing order")
            targets=(12,13,14) if end["script"]=="ShortFirst" else (12,14)
            for target in targets:
                complete_gate(states,target)
            facts["script"]=end["script"]
            facts["fullyComparedTargets"]=targets
            facts["committedNewSetsObserved"]=full_roles(states,oracle)
            prev,a,now=slot(states,actions,"new","accepted")
            j=profile_job(oracle,prev,"new")
            b=j["blocks"][0]
            require(subset(b,"anchor","witness","parentEL","parentComet","lastCommit","current","decision")
                    ==(141100,"carry","E14","EMPTY","EMPTY","F","G"),"new first block")
            require(rec_identity(slot_record(now["l1"],15))==(14,1,2,"E15new","K15new"),"new-domain saved record")
            return {**facts,"pRecordGeneration":slot_record(prev["l1"],14)["g"],"newTerminal":15}
        for z in states:
            n=z["node"]; l=z["l1"]
            if l["g"]!=1 or l["f"]!="G" or index(l["origins"],"g")[1]["f"]!="F": continue
            blocks=list(n["chain"])+([n["candidate"]] if isinstance(n["candidate"],dict) else [])
            for b in blocks:
                if b["g"]==1 and b["height"] in (15,16) and b["current"]==("G" if mode=="latest-f" else "F"):
                    return {**facts,"height":b["height"],"signatureSet":b["current"],"slot278":"G","slot290":"F"}
            if mode=="latest-f" and n["g"]==1 and any(r["height"] in (15,16) and r["committee"]=="G" for r in n["pending"]):
                return {**facts,"incorrectPendingAtOrigin":True}
        raise Refusal("missing origin set sensitivity")
    if mode=="remote-gate":
        return check_remote_gate(states,actions)
    if mode=="full-roles":
        recovered(states,actions)
        recovery_detail(states,actions,oracle)
        seen=full_roles(states,oracle)
        require(seen=={15:"F",16:"F",17:"G"},"missing committed new-domain roles F/F/G")
        return {"newRoles":seen}
    if mode=="remote":
        last=find(states,lambda z:z["node"]["tip"]==10 and z["l1"]["c"]==12,"remote c12 while local10")
        return {"localTip":last["node"]["tip"],"actualC":12}
    raise Refusal("unknown semantic profile")


def compare_capture_logs(trace, baseline, case, oracle, supplement):
    """Compare data in two finished TLC logs; no model evaluation."""
    name=RECORDED_CAPTURE_CASES[case]
    valid_states,_=framed(replace(trace,frames=trace.frames[:-1]))
    before=valid_states[-1]
    final=trace.frames[-1]
    raw=record(final.receipt, fields=DOMAINS["receipt"].split())
    args=record(raw["input"], fields=DOMAINS["input"].split())
    require(raw["before"]==trace.frames[-2].state and final.cursor==trace.frames[-2].cursor+1,
            "recorded failing edge predecessor or input position")
    require((string(raw["event"]),string(args["kind"]),string(args["arg"]),string(raw["outcome"]))
            ==("Capture","Capture",case,"captured"),"unexpected recorded failing edge")
    old_s=record(trace.frames[-2].state, fields=DOMAINS["s"].split())
    new_s=record(final.state, fields=DOMAINS["s"].split())
    require(all(old_s[k]==new_s[k] for k in old_s if k!="jobs"),"non-job operational fields changed")
    old_jobs=old_s["jobs"]; new_jobs=new_s["jobs"]
    require(old_jobs.kind==new_jobs.kind=="set" and set(old_jobs.data)<=set(new_jobs.data),
            "old opaque jobs not preserved")
    delta=set(new_jobs.data)-set(old_jobs.data)
    require(len(delta)==1,"exactly one new recorded packet required")
    item=data(next(iter(delta)))
    fields(item,"job")
    require(item["id"]==name and name not in index(before["jobs"],"id"),"unexpected added packet identity")

    good_states,good_actions=framed(baseline)
    good_prev,good_act,good_post=find(pairs(good_states,good_actions),
        lambda t:(t[1]["kind"],t[1]["arg"],t[1]["outcome"])==("Capture",name,"captured"),
        "canonical positive capture in separate raw baseline")
    # The large Main profile selects either event order only after this common
    # prefix. A script selector can differ, but no protocol input may differ.
    same_except(before,good_prev,{"script"})
    canon=job_in(good_post,name)
    require(good_act["at"]==integer(args["at"]),"different capture position")
    if name=="long":
        profile_job(oracle,good_post,name)
    else:
        exp=supplement["pOnlyPositive"]["fullFrozenProof"]
        literal_job(canon,exp["origin"],exp["interiors"],exp["terminal"],exp["terminalRoot"],141200)
        for b,row in zip(canon["blocks"],supplement["pOnlyPositive"]["blocks"]):
            require(subset(b,"height","el","comet","current","next","decision")
                    ==(row[0],row[3],row[5],row[10],row[11],row[12]),"canonical V block literal")
    if case=="trimLong":
        same_except(canon,item,{"data"})
        inp=indexed_sequence(item["data"],1,"recorded payload")
        require(inp==(item["blocks"][1]["tag"],) and item["blocks"][1]["height"]==14
                and item["blocks"][0]["height"]==13 and item["blocks"][0]["tag"]!=inp[0],
                "recorded payload differs from specified missing first item")
        evidence={"coveredHeights":[13,14],"recordedPayloadLabels":inp}
    elif case=="noInheritedRoot":
        same_except(canon,item,{"ordinaryRoots"})
        require(set(item["ordinaryRoots"])==set(canon["ordinaryRoots"])-{320}
                and 320 in canon["ordinaryRoots"] and item["ref"]==700
                and subset(item["blocks"][0],"height","anchor","witness")==(13,320,"inherit"),
                "wrong ordinary-root difference")
        evidence={"inheritedHeight":13,"anchor":320,"reference":700,"distance":380,
                  "recordedOrdinaryRoots":sorted(item["ordinaryRoots"])}
    elif case=="recordAtB":
        same_except(canon,item,{"readAt"})
        ref_roles=role_map(canon["readAt"]); roles=role_map(item["readAt"])
        same_except(ref_roles,roles,{"record"})
        row=index(before["history"],"number")[320]
        heights=sorted(index(row["records"],"height"))
        require(ref_roles["record"]!=320 and roles["record"]==320 and 320 in item["ordinaryRoots"]
                and item["p"]==12 and 12 not in heights and item["ref"]==700,
                "absence of p12 record in the specified old ordinary root")
        evidence={"readRole":"record","actualRoot":320,"reference":700,"availableRecordHeights":heights}
    else:
        same_except(canon,item,{"blocks"})
        require(len(item["blocks"])==2 and canon["blocks"][0]==item["blocks"][0],"different V prefix")
        good=canon["blocks"][1]; actual=item["blocks"][1]
        same_except(good,actual,{"next"})
        require(good["next"]=="Stake" and subset(actual,"height","current","next")== (14,"F","F"),
                "wrong independently expected next committee comparison")
        evidence={"height":14,"recordedNext":actual["next"],"expectedNext":good["next"]}
    return {"packet":name,"sourceFixtureCase":case,"recordedCaptureOutcome":"captured",
            "nonJobOperationalFrameEqual":True,"unrelatedPacketFieldsEqual":True,"difference":evidence,
            "baselineLogSha256":baseline.raw_digest,
            "scope":"Passive comparison of finite-model trace values and an independently observed positive call."}


def main():
    p=argparse.ArgumentParser()
    for arg in ("mode","log","sha256","oracle","supplement"):
        p.add_argument("--"+arg,required=True)
    p.add_argument("--invariant",help="required for root-named observer-only probes")
    for key in ("log","sha256","invariant"):
        p.add_argument("--baseline-"+key,help="normal recorded Capture log, for passive fault comparisons")
    args=p.parse_args()
    mode=args.mode
    if mode.startswith("fault-capture:"):
        case=mode.split(":",1)[1]
        require(case in RECORDED_CAPTURE_CASES,"unknown recorded case")
        outcome="ProofBindingSafe"
        require(args.invariant is None or args.invariant==outcome,"incorrect recorded fault invariant")
    elif mode.startswith(("micro:","capture-invalid:","restore-refusal:")) or mode in (
            "remote","remote-gate","full-roles","twin","pin","early-el","record-el","record-comet",
            "old-jobs","recover-unavailable"):
        require(args.invariant and args.invariant.startswith("No"), "observer-only probe invariant required")
        outcome=args.invariant
    else:
        outcome=OUTCOMES[mode]
        require(args.invariant is None or args.invariant==outcome,"invariant differs from frozen profile")
    oracle=fixture(args.oracle,ORACLE)
    sup=fixture(args.supplement,SUPPLEMENT)
    # The source fixture uses symbolic preimages; this reader does not compute ABI, KZG, ZK or cryptographic hashes.
    trace=read_pinned_raw(args.log,args.sha256,outcome,allow_probe=mode in ("pin","remote-gate"))
    result={"mode":mode,"logSha256":args.sha256,"expectedOutcome":outcome,"counts":trace.counts,
            "statesRead":len(trace.frames),"exhausted":trace.complete,
            "encodingScope":"Symbolic statement and digest preimages only; no ABI, KZG, ZK or cryptographic proof."}
    if mode=="coverage-absent":
        require(trace.complete and not trace.frames and trace.counts["queued"]==0,
                "observation absence requires complete exhaustion")
        result["scope"]="Selected observation was unreachable in the externally pinned branch-deletion profile. No protocol safety conclusion."
    elif mode.startswith("fault-capture:"):
        normal=args.baseline_invariant
        require(normal in ("NoOverlap","NoDirectLong","NoPOnlyWitness") and args.baseline_log and args.baseline_sha256,
                "normal raw/sha/invariant required for passive packet comparison")
        expected={"NoPOnlyWitness"} if RECORDED_CAPTURE_CASES[case]=="v" else {"NoOverlap","NoDirectLong"}
        require(normal in expected,"normal baseline from incorrect input family")
        other=read_pinned_raw(args.baseline_log,args.baseline_sha256,normal)
        result["actual"]=compare_capture_logs(trace,other,case,oracle,sup)
    elif outcome!="PASS":
        states,actions=framed(trace)
        result["actual"]=evaluate(mode,states,actions,oracle,sup)
    print(json.dumps(result,sort_keys=True))


if __name__=="__main__":
    try:
        main()
    except (Refusal,KeyError,TypeError,ValueError,OSError) as exc:
        sys.exit("independent readback refused: "+str(exc))
