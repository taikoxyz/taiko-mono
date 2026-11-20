#!/usr/bin/env python3
"""Audit real terminal seen-commit reconstruction against public signed inputs.

The opaque signed parents and unsigned synthetic successor are component inputs,
not a complete authenticated chain import or an Etna application deployment.
"""
from copy import deepcopy
import base64
import hashlib
from pathlib import Path
import struct
import sys

# Explicit local module root also supports the isolated -I -S CLI.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import comet_boundary_common as COMMON
import run_comet_apphash as APP
import run_comet_signed as SIGNED

ROOT = Path(__file__).resolve().parent
CLAIM = "terminal-seen-commit"
CASES = ("terminal-a", "terminal-b", "missing-commit", "subthreshold", "wrong-domain", "wrong-slot")
DOMAIN = "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
OTHER_DOMAIN = "etna-lPNjL_XC1QbJXucXeZN7hTo8cZ-aemx12WQM7raJX6o"
A = dict(hash="aa" * 32, partsTotal=1, partsHash="ab" * 32)
B = dict(hash="bb" * 32, partsTotal=2, partsHash="bc" * 32)
MISSING_REASON = "failed to reconstruct last commit; commit for height 1000 not found"
QUORUM_REASON = "failed to reconstruct last commit; extended commit does not have +2/3 majority"
DOMAIN_REASON = (
    "failed to reconstruct vote set from commit: failed to verify vote with ChainID "
    + OTHER_DOMAIN
    + " and PubKey PubKeySecp256k1eth{03CC8704B8A60A0DEFA3A99A7299F2E9C3FBC395AFB04AC078425EF8A1793CC030}: invalid signature"
)
SLOT_REASON = (
    "failed to reconstruct vote set from commit: vote.ValidatorAddress (D2431CA38735C2FD438E2CAA23F094191D89675B) "
    "does not match address (612B7BE154A64292AAE070AAA86FCD66BA218071) for vote.ValidatorIndex (1)\n"
    "Ensure the genesis file is correct across all validators: invalid validator address"
)
FAULT_BEFORE = (
    b"\tif !blockID.Equals(commit.BlockID) {\n"
    b"\t\treturn fmt.Errorf(\"invalid commit -- wrong block ID: want %v, got %v\",\n"
    b"\t\t\tblockID, commit.BlockID)\n\t}\n"
)
FAULT_AFTER = b"\t// Private conformance control: omit only the expected BlockID binding.\n"
FAULT_DIAGNOSTICS = (
    "terminal-binding id=terminal-b api=VerifyCommit expected=block-id got=accept",
    "terminal-binding id=terminal-b api=ValidateBlock expected=block-id got=accept",
)


def _constructor_expected(case):
    if type(case) is not str or case not in CASES:
        raise ValueError("unknown terminal constructor case")
    value = dict(api="consensus.NewState", accepted=True, panicType="", panicReason="",
                 wrappedError="", verificationChain=DOMAIN, signerIndex=0, signatureIndex=0,
                 seenPresent=True, fallbackPresent=False, signedPower=3, totalPower=4)
    if case == "missing-commit":
        value.update(accepted=False, panicType="string", panicReason=MISSING_REASON,
                     seenPresent=False, signedPower=0, signatureIndex=-1)
    elif case == "subthreshold":
        value.update(accepted=False, panicType="string", panicReason=QUORUM_REASON,
                     signedPower=2, totalPower=3)
    elif case == "wrong-domain":
        value.update(accepted=False, panicType="*fmt.wrapError", panicReason=DOMAIN_REASON,
                     wrappedError="types.ErrVoteInvalidSignature", verificationChain=OTHER_DOMAIN)
    elif case == "wrong-slot":
        value.update(accepted=False, panicType="*fmt.wrapError", panicReason=SLOT_REASON,
                     wrappedError="types.ErrVoteInvalidValidatorAddress", signatureIndex=1)
    return value


def _require_constructor_outcome(case, context):
    """Only four source-pinned constructor refusals receive positive credit."""
    COMMON.same(context, _constructor_expected(case), "constructor context")
    return "accept" if case in CASES[:2] else "expected-panic"


def _binding_expected(case, source_fault=False):
    if case not in CASES[:2] or type(source_fault) is not bool:
        raise ValueError("unknown terminal binding case")
    selected = A if case == "terminal-a" else B
    outcome = "accept" if case == "terminal-a" or source_fault else "block-id"
    return dict(case=case, chainID=DOMAIN, stateHeight=1000, seenHeight=1000,
                successorHeight=1001, stateParent=deepcopy(A), seenParent=deepcopy(selected),
                majorityParent=deepcopy(selected), constructorAccepted=True,
                verifyResult=outcome, successorParent=deepcopy(A),
                successorCommitParent=deepcopy(selected), successorResult=outcome,
                successorSeconds=1700000000, successorNanos=123)


def _require_terminal_binding(context):
    if type(context) is not dict:
        raise ValueError("wrong terminal binding context")
    COMMON.same(context, _binding_expected(context.get("case")), "terminal binding")
    return "bound" if context["case"] == "terminal-a" else "mismatch-refused"


# These encoders reuse generic protobuf/Merkle primitives, not the Go fixture's
# semantic code or an independently prepared tester oracle. The complete expected
# terms are generated from the pinned public inputs and the inspected stock API.
blob, number, varint, merkle = APP.blob, APP.number, APP.varint, APP.merkle
VERSION = number(1, 11) + number(2, 17)
BLOCK_PARAMS = number(1, 55600190) + number(2, -1)
PARAMS = (blob(1, BLOCK_PARAMS) +
          blob(2, number(1, 100000) + blob(2, number(1, 172800)) + number(3, 1048576)) +
          blob(3, blob(1, b"secp256k1eth")) + blob(4, number(1, 17)) + blob(5, b"") + blob(6, b""))


def _timestamp(seconds, nanos=0):
    return number(1, seconds) + number(2, nanos)


def _block_id(value):
    return blob(1, bytes.fromhex(value["hash"])) + blob(2, number(1, value["partsTotal"]) + blob(2, bytes.fromhex(value["partsHash"])))


def _public():
    raw = COMMON.PUBLIC.read_bytes()
    if COMMON.digest(raw) != COMMON.PUBLIC_SHA:
        raise ValueError("wrong public input buffer")
    data = SIGNED.load_projection(raw)
    rows = {row["name"]: row for row in data["voteCases"]}
    for name, parent in (("precommit_a", A), ("precommit_b", B)):
        row = rows[name]
        vote = row["vote"]
        expected_id = dict(hash=vote["blockHash"][2:], partsTotal=int(vote["partsTotal"]), partsHash=vote["partsHash"][2:])
        COMMON.same(expected_id, parent, "published terminal parent")
        COMMON.same(row["chain_id"], DOMAIN, "published verification domain")
    COMMON.same(rows["gen1_precommit_a"]["chain_id"], OTHER_DOMAIN, "published generation1 domain")
    return data, rows


def _sign_bytes(row, chain):
    vote = row["vote"]
    parent = dict(hash=vote["blockHash"][2:], partsTotal=int(vote["partsTotal"]), partsHash=vote["partsHash"][2:])
    value = number(1, int(vote["voteType"]))
    height, round_ = int(vote["height"]), int(vote["round"])
    if height:
        value += varint(2 * 8 + 1) + struct.pack("<q", height)
    if round_:
        value += varint(3 * 8 + 1) + struct.pack("<q", round_)
    value += blob(4, _block_id(parent))
    value += blob(5, _timestamp(int(vote["timestampSeconds"]), int(vote["timestampNanos"])))
    value += blob(6, chain.encode())
    return (varint(len(value)) + value).hex()


def _set(public, power):
    members = [dict(index=0, key=public["voteKey"]["public_key"][2:], address=public["voteKey"]["signer"][2:], power=power, priority=-1),
               dict(index=1, key=public["spectators"][0]["public_key"][2:], address=public["spectators"][0]["ck_addr"][2:], power=1, priority=1)]
    # NewValidatorSet copies the two zero-priority inputs, normalizes priorities,
    # increments by power once, and subtracts total from the selected proposer.
    # Both selected powers (3,1 and 2,1) yield (-1,+1), proposer slot0.
    def encoded(member):
        return (blob(1, bytes.fromhex(member["address"])) + blob(2, blob(5, bytes.fromhex(member["key"]))) +
                number(3, member["power"]) + number(4, member["priority"]))
    elements = [encoded(member) for member in members]
    proto = b"".join(blob(1, value) for value in elements) + blob(2, elements[0])
    hashed = merkle([blob(1, blob(5, bytes.fromhex(member["key"]))) + number(2, member["power"]) for member in members])
    return dict(members=members, total=power+1, hash=hashed.hex(), proto=proto.hex())


def _vote(public, row, chain, index):
    original = row["vote"]
    # Authenticate the signing preimage from its own original domain separately
    # from a changed verification domain used by the refusal case.
    COMMON.same(_sign_bytes(row, row["chain_id"]), row["sign_bytes"][2:], "public canonical sign bytes")
    signature = row["signature"][2:]
    if len(bytes.fromhex(signature)) != 65 or bytes.fromhex(signature)[64] not in (0, 1):
        raise ValueError("wrong public recoverable signature shape")
    return dict(type=int(original["voteType"]), height=int(original["height"]), round=int(original["round"]),
                index=index, address=public["voteKey"]["signer"][2:],
                blockID=dict(hash=original["blockHash"][2:], partsTotal=int(original["partsTotal"]), partsHash=original["partsHash"][2:]),
                seconds=int(original["timestampSeconds"]), nanos=int(original["timestampNanos"]),
                signature=signature, signBytes=_sign_bytes(row, chain))


def _commit(public, row, chain, wrong_slot=False):
    signed = _vote(public, row, chain, 1 if wrong_slot else 0)
    actual_sig = (number(1, 2) + blob(2, bytes.fromhex(signed["address"])) +
                  blob(3, _timestamp(signed["seconds"], signed["nanos"])) + blob(4, bytes.fromhex(signed["signature"])))
    absent = number(1, 1) + blob(3, _timestamp(-62135596800))
    slots = [absent, actual_sig] if wrong_slot else [actual_sig, absent]
    proto = number(1, signed["height"]) + number(2, signed["round"]) + blob(3, _block_id(signed["blockID"]))
    proto += b"".join(blob(4, sig) for sig in slots)
    return dict(height=signed["height"], round=signed["round"], blockID=signed["blockID"], hash=merkle(slots).hex(),
                proto=proto.hex(), votes=[None, signed] if wrong_slot else [signed, None],
                # Stock BlockIDFlag is uint8; encoding/json serializes its slice as base64.
                flags=base64.b64encode(bytes([1, 2] if wrong_slot else [2, 1])).decode("ascii"))


def _verification(result="accept", reason="", error_type="", got=0, needed=0):
    return dict(result=result, reason=reason, errorType=error_type, got=got, needed=needed)


def _id_string(value):
    return value["hash"].upper() + ":" + str(value["partsTotal"]) + ":" + value["partsHash"][:12].upper()


def _expected(case, source_fault):
    if case not in CASES or type(source_fault) is not bool:
        raise ValueError("unknown terminal receipt case or source context")
    public, rows = _public()
    context = _constructor_expected(case)
    chain = context["verificationChain"]
    row = rows["precommit_b" if case == "terminal-b" else "precommit_a"]
    vals = _set(public, 2 if case == "subthreshold" else 3)
    seen = None if case == "missing-commit" else _commit(public, row, chain, case == "wrong-slot")
    state = (blob(1, blob(1, VERSION) + blob(2, b"0.39.0")) + blob(2, chain.encode()) + number(3, 1000) +
             blob(4, _block_id(A)) + blob(5, _timestamp(1699999999)) +
             b"".join(blob(field, bytes.fromhex(vals["proto"])) for field in (6, 7, 8)) + number(9, 1001) +
             blob(10, PARAMS) + number(11, 1001) + blob(12, b"\x20"*32) + blob(13, b"\x10"*32) + number(14, 1))
    state_rows = {b"stateKey".hex(): state.hex(),
                  b"consensusParamsKey:1001".hex(): (blob(1, PARAMS) + number(2, 1001)).hex()}
    for height in (1000, 1001, 1002):
        state_rows[("validatorsKey:" + str(height)).encode().hex()] = (blob(1, bytes.fromhex(vals["proto"])) + number(2, height)).hex()
    block_rows = {} if seen is None else {b"SC:1000".hex(): seen["proto"]}
    explicit = _verification()
    if case == "terminal-b" and not source_fault:
        explicit = _verification("block-id", "invalid commit -- wrong block ID: want " + _id_string(A) + ", got " + _id_string(B), "*errors.errorString")
    elif case == "subthreshold":
        explicit = _verification("insufficient-power", "invalid commit -- insufficient voting power: got 2, needed more than 2", "types.ErrNotEnoughVotingPowerSigned", 2, 2)
    elif case == "wrong-domain":
        explicit = _verification("signature", "wrong signature (#0): " + row["signature"][2:].upper(), "*errors.errorString")
    elif case == "wrong-slot":
        explicit = _verification("address", "validator address mismatch at index 1: expected " + vals["members"][1]["address"].upper() + ", got " + vals["members"][0]["address"].upper(), "*errors.errorString")
    elif case == "missing-commit":
        explicit = None
    result = dict(schema="etna-terminal-receipt-1", case=case, publicInputSha256=COMMON.PUBLIC_SHA,
                  stateProto=state.hex(), stateParent=deepcopy(A), stateHeight=1000, initialHeight=1,
                  stateChain=chain, stateSeconds=1699999999, stateNanos=0,
                  lastValidators=deepcopy(vals), validators=deepcopy(vals), nextValidators=deepcopy(vals),
                  writerStateRows=deepcopy(state_rows), writerBlockRows=deepcopy(block_rows),
                  reopenedStateRows=deepcopy(state_rows), reopenedBlockRows=deepcopy(block_rows),
                  storedValidators=[dict(height=h, set=deepcopy(vals)) for h in (1000, 1001, 1002)],
                  seen=seen, fallback=None, storeBase=0, storeHeight=0, freshStores=True, reopened=True,
                  constructor=context, voteExtensions1000=False, voteExtensions1001=False,
                  initialVerify=None, explicitVerify=explicit, roundState=None, successor=None)
    if case in CASES[:2]:
        result["initialVerify"] = dict(chain=chain, target=deepcopy(seen["blockID"]), height=1000, verification=_verification())
        result["roundState"] = dict(height=1001, round=0, commitHeight=1000, commitRound=0,
                                    majority=deepcopy(seen["blockID"]), hasMajority=True, anyQuorum=True,
                                    votes=deepcopy(seen["votes"]), bits=[True, False], commit=deepcopy(seen))
        child_time = _timestamp(1700000000, 123)
        empty = merkle([])
        hashes = [bytes.fromhex(seen["hash"]), empty, bytes.fromhex(vals["hash"]), bytes.fromhex(vals["hash"]),
                  hashlib.sha256(BLOCK_PARAMS).digest(), b"\x10"*32, b"\x20"*32, empty,
                  bytes.fromhex(vals["members"][0]["address"])]
        header = blob(1, VERSION) + blob(2, chain.encode()) + number(3, 1001) + blob(4, child_time) + blob(5, _block_id(A))
        header += b"".join(blob(field, value) for field, value in enumerate(hashes, 6))
        header_hash = merkle([VERSION, blob(1, chain.encode()), number(1, 1001), child_time, _block_id(A)] + [blob(1, value) for value in hashes])
        block = blob(1, header) + blob(2, b"") + blob(3, b"") + blob(4, bytes.fromhex(seen["proto"]))
        result["successor"] = dict(height=1001, parent=deepcopy(A), lastCommit=deepcopy(seen),
                                   seconds=1700000000, nanos=123, headerProto=header.hex(), blockProto=block.hex(),
                                   hash=header_hash.hex(), verification=deepcopy(explicit),
                                   evidenceChecks=1 if case == "terminal-a" or source_fault else 0)
    return result


def audit_terminal(receipt: bytes, *, source_fault=False) -> dict:
    """Bind every raw/typed term to public bytes and source-derived full state.

    Exact comparison also rejects unknown fields, duplicate JSON keys, boolean
    number aliases, vote/context swaps and unchanged-result metadata substitutions.
    Expected source faults are a separate explicit mode; ordinary callers receive
    no bypass merely because a constructor accepted or a native command failed.
    """
    if type(receipt) is not bytes:
        raise ValueError("terminal auditor requires original receipt bytes")
    actual = SIGNED.strict_json(receipt)
    if type(actual) is not dict or type(actual.get("case")) is not str:
        raise ValueError("wrong terminal receipt")
    expected = _expected(actual["case"], source_fault)
    COMMON.same(actual, expected, "full terminal receipt")
    _require_constructor_outcome(actual["case"], actual["constructor"])
    child = actual["successor"]
    if child is not None:
        context = dict(case=actual["case"], chainID=actual["stateChain"], stateHeight=actual["stateHeight"],
                       seenHeight=actual["seen"]["height"], successorHeight=child["height"], stateParent=actual["stateParent"],
                       seenParent=actual["seen"]["blockID"], majorityParent=actual["roundState"]["majority"],
                       constructorAccepted=actual["constructor"]["accepted"], verifyResult=actual["explicitVerify"]["result"],
                       successorParent=child["parent"], successorCommitParent=child["lastCommit"]["blockID"],
                       successorResult=child["verification"]["result"], successorSeconds=child["seconds"], successorNanos=child["nanos"])
        COMMON.same(context, _binding_expected(actual["case"], source_fault), "actual terminal binding")
    return dict(case=actual["case"], status="SOURCE_FAULT_OBSERVED" if source_fault and actual["case"] == "terminal-b" else "PASS",
                constructor="accept" if actual["constructor"]["accepted"] else "expected-panic",
                explicitVerify=None if actual["explicitVerify"] is None else actual["explicitVerify"]["result"],
                successor=None if child is None else child["verification"]["result"],
                successorHash=None if child is None else child["hash"], receiptSha256=COMMON.digest(receipt))


PROFILE = COMMON.BoundaryProfile(
    CLAIM, "comet_boundary", "example.org/etna-comet-boundary", "TestTerminalSeenCommit", "terminal-a", CASES,
    (("comet_boundary/public_input.go.txt", "public_input.go"), ("comet_boundary/terminal_test.go", "terminal_test.go"),
     ("comet_boundary/go.mod", "go.mod"), ("comet_boundary/go.sum", "go.sum"),
     ("comet_signed/public-votes.json", "public-votes.json")),
    audit_terminal, "types/validation.go", FAULT_BEFORE, FAULT_AFTER, "terminal-b", FAULT_DIAGNOSTICS,
)


def main(argv=None):
    try:
        summary = COMMON.run_profile(PROFILE, COMMON.arguments(argv))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Comet terminal INCONCLUSIVE: " + str(error), file=sys.stderr)
        return 1
    print("PASS: " + ", ".join(report["phase"] + " " + str(len(report["outcomes"])) + " exact leaves" for report in summary["reports"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
