#!/usr/bin/env python3
"""Audit public duplicate-vote evidence against stock component/state semantics.

Synthetic history and controlled peers are inputs, not authenticated Etna import.
"""
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comet_boundary_common as COMMON
import run_comet_apphash as APP
import run_comet_signed as SIGNED

ROOT = Path(__file__).resolve().parent
CLAIM = "evidence-lifecycle"
CASES = ("cold-grid", "gossip", "pending-restart", "committed-window")
HISTORICAL_SECONDS = 1699999900
BROADCAST_FRAME = "github.com/cometbft/cometbft/evidence.(*Reactor).broadcastEvidenceRoutine"
FAULT_BEFORE = b"\tif ageDuration > evidenceParams.MaxAgeDuration && ageNumBlocks > evidenceParams.MaxAgeNumBlocks {\n"
FAULT_AFTER = FAULT_BEFORE.replace(b" && ", b" || ")
FAULT_DIAGNOSTICS = ("evidence-age id=cold-grid expected=5-valid-1-expired got=2-valid-4-expired",)
blob, number, varint, merkle = APP.blob, APP.number, APP.varint, APP.merkle


def _need(value, label):
    if not value:
        raise ValueError(label)


def _cold_context(source_fault=False):
    _need(type(source_fault) is bool, "exact source-fault Boolean required")
    cells = []
    for height in (1900, 1901):
        for age in (3599, 3600, 3601):
            expired = ((height - 1000 > 900 or age > 3600) if source_fault
                       else (height - 1000 > 900 and age > 3600))
            cells.append(dict(store=f"cold-{height}-{age}", height=height,
                              seconds=HISTORICAL_SECONDS+age, accepted=not expired,
                              result="expired" if expired else "accept", headerLookups=[1000],
                              validatorLookups=[] if expired else [1000], beforePending=0,
                              afterPending=0 if expired else 1, afterGossip=False))
    return dict(case="cold-grid", evidenceHeight=1000, historicalSeconds=HISTORICAL_SECONDS,
                historicalNanos=0, voteSeconds=1700000000, voteNanos=123,
                maxAgeNumBlocks=900, maxAgeSeconds=3600, cells=cells,
                voteTimeAlias=dict(seconds=1700000000, nanos=123, accepted=False,
                                   result="historical-time", headerLookups=[1000],
                                   validatorLookups=[], beforePending=0, afterPending=0))


def _gossip_context():
    observations = []
    for height in (1900, 1901):
        send = height == 1900
        old = None if send else dict(peerHeight=1901, evHeight=1000, maxAgeNumBlocks=900,
                                     lastSeconds=HISTORICAL_SECONDS, lastNanos=0,
                                     maxAgeNanos=3600000000000)
        observations.append(dict(peerHeight=height, branch="send" if send else "old-info",
                                 sendCount=1 if send else 0, channel=56 if send else None,
                                 evidenceCount=1 if send else 0, oldInfo=old,
                                 exitMethod="runtime-goroutine-profile", broadcastAtStart=0,
                                 broadcastAtObservation=1, broadcastAfterQuit=0))
    return dict(case="gossip", evidenceHeight=1000, historicalSeconds=HISTORICAL_SECONDS,
                holderHeight=1000, holderSeconds=HISTORICAL_SECONDS, maxAgeNumBlocks=900,
                maxAgeSeconds=3600, pendingCount=1, frontPresent=True, observations=observations)


def _pending_context():
    prefix = [dict(height=h, seconds=HISTORICAL_SECONDS+a, pending=1, front=True)
              for h, a in ((1000, 0), (1900, 3600), (1901, 3601))]
    return dict(case="pending-restart", evidenceHeight=1000, historicalSeconds=HISTORICAL_SECONDS,
                maxAgeNumBlocks=900, maxAgeSeconds=3600,
                branches=[dict(store="continuing", prefix=deepcopy(prefix)),
                          dict(store="restart", prefix=deepcopy(prefix))],
                continuing=dict(beforeCheck=1, checkAccepted=True, headerLookups=[],
                                validatorLookups=[], beforePrune=1, pruneHeight=1902,
                                pruneSeconds=HISTORICAL_SECONDS+3602, afterPrune=0, frontAfterPrune=False),
                restart=dict(savedHeight=1901, savedSeconds=HISTORICAL_SECONDS+3601,
                             loadedHeight=1901, loadedSeconds=HISTORICAL_SECONDS+3601,
                             beforeStartup=1, afterStartup=0, frontAfterStartup=False))


def _marker_context():
    return dict(case="committed-window", evidenceHeight=1000, windowStart=1001,
                checkHeight=1901, installedAt=1001, payloadHeight=1000,
                pendingBeforeInstall=1, pendingAfterInstall=0, markerBeforeInstall=False,
                markerAfterInstall=True, markerAfterReopen=True, reopenedPayloadHeight=1000,
                loadedHeight=1901, loadedSeconds=HISTORICAL_SECONDS+3601,
                historicalHeaderPresent=False, historicalValidatorRowPresent=False,
                marked=dict(accepted=False, errorType="*types.ErrInvalidEvidence",
                            reason="evidence was already committed", headerLookups=[],
                            validatorLookups=[], pendingAfter=0),
                unmarked=dict(accepted=False, errorType="*errors.errorString", reason="don't have header #1000",
                              headerLookups=[1000], validatorLookups=[], pendingAfter=0))


def _require_cold_context(context, *, source_fault=False):
    COMMON.same(context, _cold_context(source_fault), "cold context")
    return "cold-grid"


def _require_gossip_context(context):
    COMMON.same(context, _gossip_context(), "gossip context")
    return "gossip"


def _require_pending_context(context):
    COMMON.same(context, _pending_context(), "pending context")
    return "pending-restart"


def _require_marker_context(context):
    COMMON.same(context, _marker_context(), "marker context")
    return "committed-window"


def _require_profile(profile, count):
    keys = {"complete", "inventoryComplete", "totalGoroutines", "frameCapacity", "stackDepths",
            "maxStackDepth", "emptyStacks", "saturatedStacks", "matches", "count"}
    _need(type(profile) is dict and set(profile) == keys, "closed complete goroutine profile required")
    _need(profile["complete"] is True and profile["inventoryComplete"] is True,
          "complete goroutine inventory required")
    total, depths = profile["totalGoroutines"], profile["stackDepths"]
    _need(type(total) is int and total > count and type(depths) is list and len(depths) == total,
          "goroutine inventory/depths differ")
    _need(all(type(n) is int and 1 <= n < 32 for n in depths), "empty or truncated goroutine stack")
    for key, value in (("frameCapacity", 32), ("maxStackDepth", max(depths)), ("emptyStacks", 0),
                       ("saturatedStacks", 0), ("count", count)):
        COMMON.same(profile[key], value, "profile " + key)
    matches = profile["matches"]
    _need(type(matches) is list and len(matches) == count, "broadcast stack count differs")
    for frames in matches:
        _need(type(frames) is list and frames and all(type(s) is str and s for s in frames),
              "complete named broadcast frames required")
        _need(frames.count(BROADCAST_FRAME) == 1, "actual broadcast worker frame missing")
    return deepcopy(profile)


def _timestamp(seconds, nanos=0):
    return number(1, seconds) + number(2, nanos)


def _block_id(parent):
    return blob(1, bytes.fromhex(parent["hash"])) + blob(2, number(1, parent["partsTotal"]) +
                                                               blob(2, bytes.fromhex(parent["partsHash"])))


def _time_text(seconds, nanos=0, *, canonical=False):
    stamp = datetime.fromtimestamp(seconds, timezone.utc)
    fraction = ("." + f"{nanos:09d}".rstrip("0")) if nanos else ""
    return stamp.strftime("%Y-%m-%dT%H:%M:%S" if canonical else "%Y-%m-%d %H:%M:%S") + fraction + (
        "Z" if canonical else " +0000 UTC")


def _result(reason="", kind="*errors.errorString", full=None):
    return dict(accepted=not reason, errorType=kind if reason else "", reason=reason,
                error=(reason if full is None else full) if reason else "")


def _lookups(headers=(), validators=()):
    return dict(headers=list(headers), validators=list(validators), commits=[], heightCalls=0)


class _EvidenceModel:
    """Derive bytes from pinned public inputs and inspected stock protobuf/store code."""
    def __init__(self):
        raw = COMMON.PUBLIC.read_bytes()
        _need(COMMON.digest(raw) == COMMON.PUBLIC_SHA, "public evidence input changed")
        self.public = SIGNED.load_projection(raw)
        rows = {row["name"]: row for row in self.public["voteCases"]}
        source = [rows[name] for name in ("precommit_a", "precommit_b")]
        self.chain = source[0]["chain_id"]
        _need(all(row["chain_id"] == self.chain for row in source), "public votes use different domains")
        self.votes = [self._vote(row) for row in source]
        self.parent = deepcopy(self.votes[0]["blockID"])
        # BlockID.Key concatenates hash and PartSetHeader protobuf. The pinned
        # public A hash sorts before B; sorting here mirrors that actual input rule.
        self.votes.sort(key=lambda vote: bytes.fromhex(vote["blockID"]["hash"]) +
                        number(1, vote["blockID"]["partsTotal"]) + blob(2, bytes.fromhex(vote["blockID"]["partsHash"])))
        signer = self.public["voteKey"]
        spectator = next(row for row in self.public["spectators"] if row["name"] == "a2")
        members = [dict(index=0, key=signer["public_key"][2:], address=signer["signer"][2:], power=3, priority=-1),
                   dict(index=1, key=spectator["public_key"][2:], address=spectator["ck_addr"][2:], power=1, priority=1)]
        encoded = [blob(1, bytes.fromhex(m["address"])) + blob(2, blob(5, bytes.fromhex(m["key"]))) +
                   number(3, m["power"]) + number(4, m["priority"]) for m in members]
        set_proto = b"".join(blob(1, value) for value in encoded) + blob(2, encoded[0])
        set_hash = merkle([blob(1, blob(5, bytes.fromhex(m["key"]))) + number(2, m["power"]) for m in members])
        self.validators = dict(members=members, total=4, hash=set_hash.hex(), proto=set_proto.hex())
        self.set_proto = set_proto
        self.params = (blob(1, number(1, 55600190) + number(2, -1)) +
                       blob(2, number(1, 900) + blob(2, number(1, 3600)) + number(3, 1048576)) +
                       blob(3, blob(1, b"secp256k1eth")) + blob(4, number(1, 17)) + blob(5, b"") + blob(6, b""))
        self.evidence = self.evidence_view()
        self.hash = self.evidence["hash"]
        tail = f"{1000:016X}/{self.hash.upper()}".encode()
        self.pending = {(b"\x01" + tail).hex(): self.evidence["envelopeProto"]}
        self.committed_key = (b"\x00" + tail).hex()
        self.committed = {self.committed_key: number(1, 1000).hex()}

    def _vote(self, row):
        vote = row["vote"]
        parent = dict(hash=vote["blockHash"][2:], partsTotal=int(vote["partsTotal"]), partsHash=vote["partsHash"][2:])
        seconds, nanos = int(vote["timestampSeconds"]), int(vote["timestampNanos"])
        height, round_, kind = int(vote["height"]), int(vote["round"]), int(vote["voteType"])
        canonical = number(1, kind) + varint(2*8+1) + struct.pack("<q", height)
        if round_:
            canonical += varint(3*8+1) + struct.pack("<q", round_)
        canonical += blob(4, _block_id(parent)) + blob(5, _timestamp(seconds, nanos)) + blob(6, row["chain_id"].encode())
        COMMON.same((varint(len(canonical)) + canonical).hex(), row["sign_bytes"][2:], "public canonical vote preimage")
        _need((height, round_, kind, seconds, nanos) == (1000, 0, 2, 1700000000, 123),
              "public evidence corpus context differs")
        signature = row["signature"][2:]
        _need(len(bytes.fromhex(signature)) == 65, "public evidence signature length")
        return dict(type=kind, height=height, round=round_, index=0,
                    address=self.public["voteKey"]["signer"][2:], blockID=parent, seconds=seconds, nanos=nanos,
                    signature=signature, signBytes=(varint(len(canonical)) + canonical).hex())

    @staticmethod
    def vote_proto(vote):
        return (number(1, vote["type"]) + number(2, vote["height"]) + number(3, vote["round"]) +
                blob(4, _block_id(vote["blockID"])) + blob(5, _timestamp(vote["seconds"], vote["nanos"])) +
                blob(6, bytes.fromhex(vote["address"])) + number(7, vote["index"]) + blob(8, bytes.fromhex(vote["signature"])))

    def evidence_view(self, seconds=HISTORICAL_SECONDS, nanos=0):
        bare = (b"".join(blob(i, self.vote_proto(vote)) for i, vote in enumerate(self.votes, 1)) +
                number(3, 4) + number(4, 3) + blob(5, _timestamp(seconds, nanos)))
        envelope = blob(1, bare)
        listing = blob(1, envelope)
        return dict(height=1000, seconds=seconds, nanos=nanos, voteA=deepcopy(self.votes[0]),
                    voteB=deepcopy(self.votes[1]), validatorPower=3, totalVotingPower=4,
                    duplicateProto=bare.hex(), evidenceBytes=bare.hex(), hash=COMMON.digest(bare),
                    envelopeProto=envelope.hex(), listProto=listing.hex(), listBytes=len(listing),
                    listHash=merkle([bare]).hex(), validators=deepcopy(self.validators))

    def state(self, height, age):
        version = blob(1, number(1, 11) + number(2, 17)) + blob(2, b"0.39.0")
        return (blob(1, version) + blob(2, self.chain.encode()) + number(3, height) +
                blob(4, _block_id(self.parent)) + blob(5, _timestamp(HISTORICAL_SECONDS+age)) +
                b"".join(blob(i, self.set_proto) for i in (6, 7, 8)) + number(9, 1001) +
                blob(10, self.params) + number(11, 1001) + blob(12, b"\x20"*32) +
                blob(13, b"\x10"*32) + number(14, 1)).hex()

    def state_rows(self, steps=(), *, pruned=False):
        rows = {b"stateKey".hex(): self.state(1000, 0),
                b"consensusParamsKey:1001".hex(): (blob(1, self.params) + number(2, 1001)).hex()}
        for h in (1000, 1001, 1002):
            rows[("validatorsKey:"+str(h)).encode().hex()] = (blob(1, self.set_proto) + number(2, h)).hex()
        for height, age in steps:
            rows[b"stateKey".hex()] = self.state(height, age)
            rows[("validatorsKey:"+str(height+2)).encode().hex()] = number(2, 1001).hex()
            rows[("consensusParamsKey:"+str(height+1)).encode().hex()] = (blob(1, b"") + number(2, 1001)).hex()
        if pruned:
            rows.pop(b"validatorsKey:1000".hex())
        return rows

    def view(self, name, steps=(), *, pending=False, front=False, committed=False, pruned=False):
        height, age = steps[-1] if steps else (1000, 0)
        evidence = dict(self.pending) if pending else dict(self.committed) if committed else {}
        return dict(store=name, stateProto=self.state(height, age), poolStateProto=self.state(height, age),
                    height=height, seconds=HISTORICAL_SECONDS+age, nanos=0, paramsProto=self.params.hex(),
                    stateRows=self.state_rows(steps, pruned=pruned), evidenceRows=evidence, size=1 if pending else 0,
                    pendingHashes=[self.hash] if pending else [], pendingBytes=self.evidence["listBytes"] if pending else 0,
                    frontPresent=front)

    def cold_details(self, source_fault):
        cells = []
        for cell in _cold_context(source_fault)["cells"]:
            h, age, name = cell["height"], cell["seconds"]-HISTORICAL_SECONDS, cell["store"]
            expired = not cell["accepted"]
            reason = (f"evidence from height 1000 (created at: {_time_text(HISTORICAL_SECONDS)}) is too old; "
                      f"min height is {h-900} and evidence can not be older than {_time_text(HISTORICAL_SECONDS+age+3600)}") if expired else ""
            cells.append(dict(before=self.view(name, ((h, age),)),
                              after=self.view(name, ((h, age),), pending=not expired),
                              result=_result(reason), lookups=_lookups((1000,), () if expired else (1000,))))
        alias = self.evidence_view(1700000000, 123)
        reason = ("evidence has a different time to the block it is associated with "
                  f"({_time_text(1700000000, 123)} != {_time_text(HISTORICAL_SECONDS)})")
        return dict(cells=cells, voteTimeAlias=dict(evidence=alias,
                    before=self.view("cold-vote-time-alias", ((1900, 3599),)),
                    after=self.view("cold-vote-time-alias", ((1900, 3599),)),
                    result=_result(reason), lookups=_lookups((1000,))))

    def gossip_details(self, actual):
        _need(type(actual) is dict and set(actual) == {"probes"} and type(actual["probes"]) is list
              and len(actual["probes"]) == 2, "two closed native gossip probes required")
        probes = []
        for height, detail in zip((1900, 1901), actual["probes"]):
            send = height == 1900
            if send:
                branch = dict(branch="send", channel=56, sourceAbsent=True, messageType="*types.EvidenceList",
                              listProto=self.evidence["listProto"], evidenceCount=1, error="")
            else:
                values = [("peerHeight", "int64", 1901), ("evHeight", "int64", 1000),
                          ("maxAgeNumBlocks", "int64", 900),
                          ("lastBlockTime", "time.Time", dict(seconds=HISTORICAL_SECONDS, nanos=0)),
                          ("maxAgeDuration", "time.Duration", 3600000000000),
                          ("peer", "*boundary.evidencePeer", "controlled-peer-1901")]
                branch = dict(branch="old-info", message="Not sending peer old evidence", termCount=12,
                              terms=[dict(key=k, type=t, value=v) for k, t, v in values])
            probes.append(dict(seed=self.view(f"gossip-{height}", pending=True, front=True), branch=branch,
                               baselineProfile=_require_profile(detail["baselineProfile"], 0),
                               observedProfile=_require_profile(detail["observedProfile"], 1),
                               afterProfile=_require_profile(detail["afterProfile"], 0), sendCount=1 if send else 0,
                               eventOverflow=False, accountingAfterExit=True, unconsumedEvents=0,
                               peerQuit=True, reactorRunningAfterStop=False, databaseClosedAfterExit=True))
        return dict(probes=probes)

    def pending_details(self):
        steps = ((1900, 3600), (1901, 3601))
        prefixes = [[self.view(name, steps[:i], pending=True, front=True) for i in range(3)]
                    for name in ("continuing", "restart")]
        current, restart = prefixes[0][-1], prefixes[1][-1]
        return dict(continuingPrefix=prefixes[0], restartPrefix=prefixes[1], beforeCheck=deepcopy(current),
                    checkResult=_result(), checkLookups=_lookups(), beforePrune=deepcopy(current),
                    afterPrune=self.view("continuing", (*steps, (1902, 3602))), beforeStartup=deepcopy(restart),
                    loadedStateProto=self.state(1901, 3601), preNewPoolRows=dict(self.pending),
                    afterStartup=self.view("restart", steps))

    def _vote_string(self, vote):
        fingerprint = lambda value: bytes.fromhex(value)[:6].ljust(6, b"\x00").hex().upper()
        return (f"Vote{{{vote['index']}:{fingerprint(vote['address'])} {vote['height']}/{vote['round']:02d}/SIGNED_MSG_TYPE_PRECOMMIT(Precommit) "
                f"{fingerprint(vote['blockID']['hash'])} {fingerprint(vote['signature'])} 000000000000 @ "
                f"{_time_text(vote['seconds'], vote['nanos'], canonical=True)}}}")

    def marker_details(self):
        branches = {}
        steps = ((1001, 1), (1901, 3601))
        for marked in (True, False):
            name = "marked" if marked else "unmarked"
            reason = "evidence was already committed" if marked else "don't have header #1000"
            full = ("Invalid evidence: " + reason + ". Evidence: DuplicateVoteEvidence{VoteA: " +
                    self._vote_string(self.votes[0]) + ", VoteB: " + self._vote_string(self.votes[1]) + "}") if marked else reason
            branches[name] = dict(marked=marked,
                before=self.view(name, pending=marked, front=marked),
                afterInstall=self.view(name, steps[:1], committed=marked),
                beforePrune=self.view(name, steps, committed=marked),
                pruneArgs=[1000, 1001, 1001], pruneResult=_result(), prunedStateRows=self.state_rows(steps, pruned=True),
                setupPrecheck=dict(api="LoadValidators", height=1001, validators=deepcopy(self.validators)),
                loadedStateProto=self.state(1901, 3601), beforeCheck=self.view(name, steps, committed=marked, pruned=True),
                checkResult=_result(reason, "*types.ErrInvalidEvidence" if marked else "*errors.errorString", full),
                checkLookups=_lookups(() if marked else (1000,)),
                afterCheck=self.view(name, steps, committed=marked, pruned=True), markerKey=self.committed_key,
                markerValue=number(1, 1000).hex() if marked else "", markerPayloadHeight=1000 if marked else 0,
                historicalValidatorRowPresent=False, historicalHeaderPresent=False)
        return branches


def audit_evidence(receipt: bytes, *, source_fault=False):
    if type(receipt) is not bytes or type(source_fault) is not bool:
        raise ValueError("original receipt bytes and exact source context required")
    try:
        actual = SIGNED.strict_json(receipt)
        _need(type(actual) is dict and set(actual) == {"schema", "case", "publicInputSha256", "evidence", "context", "details"},
              "closed evidence receipt required")
        case = actual["case"]
        _need(type(case) is str and case in CASES, "unknown evidence case")
        model = _EvidenceModel()
        if case == "cold-grid":
            _require_cold_context(actual["context"], source_fault=source_fault)
            details = model.cold_details(source_fault)
        elif case == "gossip":
            _require_gossip_context(actual["context"])
            details = model.gossip_details(actual["details"])
        elif case == "pending-restart":
            _require_pending_context(actual["context"])
            details = model.pending_details()
        else:
            _require_marker_context(actual["context"])
            details = model.marker_details()
        expected = dict(schema="etna-comet-evidence-1", case=case, publicInputSha256=COMMON.PUBLIC_SHA,
                        evidence=model.evidence, context=actual["context"], details=details)
        COMMON.same(actual, expected, "complete evidence receipt")
    except (KeyError, IndexError, TypeError, StopIteration) as error:
        raise ValueError("malformed evidence observation: " + str(error)) from error
    return dict(case=case, status="SOURCE_FAULT_OBSERVED" if source_fault and case == "cold-grid" else "PASS",
                evidenceHash=model.hash, height=1000, receiptSha256=COMMON.digest(receipt))


PROFILE = COMMON.BoundaryProfile(
    CLAIM, "comet_evidence", "example.org/etna-comet-evidence", "TestEvidenceLifecycle", "cold-grid", CASES,
    (("comet_boundary/public_input.go.txt", "public_input.go"), ("comet_evidence/evidence_test.go", "evidence_test.go"),
     ("comet_evidence/go.mod", "go.mod"), ("comet_evidence/go.sum", "go.sum"),
     ("comet_signed/public-votes.json", "public-votes.json")),
    audit_evidence, "evidence/verify.go", FAULT_BEFORE, FAULT_AFTER, "cold-grid", FAULT_DIAGNOSTICS,
)


def main(argv=None):
    try:
        summary = COMMON.run_profile(PROFILE, COMMON.arguments(argv))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Comet evidence INCONCLUSIVE: " + str(error), file=sys.stderr)
        return 1
    print("PASS: " + ", ".join(report["phase"] + " " + str(len(report["outcomes"])) + " exact leaves" for report in summary["reports"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
