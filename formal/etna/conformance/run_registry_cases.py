#!/usr/bin/env python3
"""Replay exact public Registry cases through pinned offline Forge."""
import argparse
from collections import Counter
from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys

ROOT = Path(__file__).resolve().parent
STOCK_PATH = ROOT / "run_comet_signed.py"
spec = importlib.util.spec_from_file_location("etna_registry_cases_stock", STOCK_PATH)
STOCK = importlib.util.module_from_spec(spec)
spec.loader.exec_module(STOCK)
EXEC = STOCK.COMET.EXECUTION
BASELINE = STOCK.COMET.load_module("etna_registry_baseline", ROOT / "run_baseline.py")

PIN_PATH = ROOT / "registry_cases/pins.json"
MANIFEST_PATH = ROOT / "manifests/contracts.json"
TEST_ROOT = "test/layer1/etna/conformance"
SOLIDITY_FILES = (
    "EtnaRegistryCasesBase.sol", "EtnaRegistryPublicReplay.t.sol", "EtnaRegistryDoubleSignReplay.t.sol"
)
CONTRACT = "EtnaRegistryDoubleSignReplayTest"
SUITE = f"{TEST_ROOT}/{SOLIDITY_FILES[-1]}:{CONTRACT}"
FAULT_PATH = "packages/protocol/contracts/layer1/etna/impl/EtnaStakingRegistry.sol"
LIFECYCLE_FILE = "EtnaRegistryLifecycleCases.t.sol"
LIFECYCLE_CONTRACT = "EtnaRegistryLifecycleCasesTest"
LIFECYCLE_SUITE = f"{TEST_ROOT}/{LIFECYCLE_FILE}:{LIFECYCLE_CONTRACT}"
LIFECYCLE_TEST = "test_exit_withdraw_and_reuse()"
LIFECYCLE_FAULT_FUNCTION = b"function activateTopUp("
LIFECYCLE_FAULT_BEFORE = (
    b"        require(entry.exitEffectiveL1 == NO_EXIT, ExitAlreadySet());\n"
    b"        TopUp memory pending = _topUpsStorage().topUps[_bondId];\n"
)
LIFECYCLE_FAULT_AFTER = b"        TopUp memory pending = _topUpsStorage().topUps[_bondId];\n"
LIFECYCLE_FAULT_DIAGNOSTIC = "N03 activate_mature_exiting: expected ExitAlreadySet, got success"
ATOMICITY_FILE = "EtnaRegistryAtomicityCases.t.sol"
ATOMICITY_CONTRACT = "EtnaRegistryAtomicityCasesTest"
ATOMICITY_REGISTER = "test_register_allowance_rollback_and_retry()"
ATOMICITY_TOPUP = "test_topup_balance_rollback_and_retry()"
ATOMICITY_FAULT_FUNCTION = b"function topUp("
ATOMICITY_FAULT_BEFORE = (
    b"        token.safeTransferFrom(msg.sender, address(this), _amount);\n"
    b"        emit TopUpDeposited(_bondId, _amount, readyAt);"
)
ATOMICITY_FAULT_AFTER = b"        emit TopUpDeposited(_bondId, _amount, readyAt);"
ATOMICITY_FAULT_DIAGNOSTIC = "N04 topup_refusal: expected token balance, got success"
FAULT_FUNCTION = b"function slashDoubleSign("
FAULT_BEFORE = (
    b"                && !LibCometVote.sameBlockId(voteA, voteB),\n"
    b"            NotDoubleSign()"
)
FAULT_AFTER = b",\n            NotDoubleSign()"
FAULT_TEST = "test_pair_same_block_later_time()"
FAULT_DIAGNOSTIC = "N02 same_block_later_time: expected NotDoubleSign, got success"
SMOKE_TEST = "test_pair_precommit_conflict()"

DISPLACEMENT_FILE = "EtnaRegistryDisplacementCases.t.sol"
DISPLACEMENT_CONTRACT = "EtnaRegistryDisplacementCasesTest"
DISPLACEMENT_SUITE = f"{TEST_ROOT}/{DISPLACEMENT_FILE}:{DISPLACEMENT_CONTRACT}"
DISPLACEMENT_PRIMARY = "test_held_zero_displacement_then_withdraw()"
DISPLACEMENT_OPPOSITE = "test_zero_withdraw_then_vacant_reuse()"
DISPLACEMENT_TESTS = (DISPLACEMENT_PRIMARY, DISPLACEMENT_OPPOSITE)
DISPLACEMENT_SCHEMA = b"etna-registry-displacement-2".ljust(32, b"\0")
DISPLACEMENT_FAULT_FUNCTION = b"function _takeSlot("
DISPLACEMENT_FAULT_BEFORE = b"            displaced.holdsSlot = false;\n"
DISPLACEMENT_FAULT_AFTER = b""
DISPLACEMENT_FAULT_DIAGNOSTIC = "O03 replace: old holdsSlot still set"
DISPLACED_TOPIC = "0x6880ea53ef6a506cdb9366a32d91976e38bb1dc92293b42b33744a8c8ed29a88"

# Pinned Forge's standard test deployment address, corroborated by prior native traces.
TEST_DRIVER = "0x7fa9385be102ac3eac297483dd6233d62b3e1496"
# First CREATE at nonce 1 from the test driver deploys PublicReplayToken.
TOKEN = "0x5615deb798bb3e4dfa0139dfa1b3d433cc23b72f"
SLASH_SELECTOR = bytes.fromhex("f66189c3")
PAIR_RESULT_BYTES = 21 * 32
PROXY = "0x" + "22" * 20
REPORTER = "0x" + "00" * 18 + "4444"
SINK = "0x" + "00" * 18 + "5555"
OWNER_A = "0x" + "aa" * 20
RECEIPT_TOPIC = "0x56d054581a0c654a621e25ad119560579d5348d45a3bb253dee1cddd66a07dcd"
CHECKPOINT_TOPIC = "0x860f60025c4af6e2af507f9d1c36a6a81081a6b4acca489c6904254ddce1caa2"
TRANSFER_TOPIC = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
SLASH_TOPIC = "0x2ba37af98a310ee7f58eada0f1ee56a60eaf088d2a320ab8c63fb2ad4c804330"
INITIALIZED_TOPIC = "0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498"
UPGRADED_TOPIC = "0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b"
OWNERSHIP_TRANSFERRED_TOPIC = "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0"
REGISTERED_TOPIC = "0x911415b5bb55ba3a7ab6186cdf67f36e5964f520ae561e164bf4d4b76732440b"
TOPUP_DEPOSITED_TOPIC = "0x784a6d56e445d4ededf7abef18f427bf7500a6296ef170b71109d09ce6eae57a"
RESULT_FIELDS = {
    "status", "reason", "counterexample", "logs", "decoded_logs", "kind", "traces",
    "labeled_addresses", "duration", "breakpoints", "gas_snapshots",
}
DEPENDENCIES = (
    ("forge-std", "forge-std/"), ("openzeppelin-contracts", "@openzeppelin/contracts/"),
    ("openzeppelin-upgradeable", "@openzeppelin/contracts-upgradeable/"),
    ("optimism", "@optimism/"), ("ds-test", "ds-test/"), ("solady", "@solady/"),
)
TOOLS = ("forge", "solc-0.8.30")
SCENARIOS = {
    "double-sign": (SOLIDITY_FILES[-1], CONTRACT, SMOKE_TEST),
    "lifecycle": (LIFECYCLE_FILE, LIFECYCLE_CONTRACT, LIFECYCLE_TEST),
    "atomicity": (ATOMICITY_FILE, ATOMICITY_CONTRACT, ATOMICITY_REGISTER),
    "displacement": (DISPLACEMENT_FILE, DISPLACEMENT_CONTRACT, DISPLACEMENT_PRIMARY),
}
ATOMICITY_RECEIPT_SCHEMA = b"etna-registry-atomicity-2".ljust(32, b"\0")
ATOMICITY_STEPS = {
    ATOMICITY_REGISTER: ("register_refusal", "approve_retry", "register_retry"),
    ATOMICITY_TOPUP: ("topup_refusal", "fund_retry", "topup_retry", "activate_topup"),
}


def require_hash(path, expected):
    digest = EXEC.sha(path)
    if digest != expected:
        raise ValueError(f"input hash differs: {path.name}")
    return digest


def word(value):
    return value.to_bytes(32, "big")


def hex_bytes(value, size=None):
    return STOCK.hex_field(value, size)


def abi_bytes(value):
    """Canonical length word and padded body of a dynamic ABI bytes/string value."""
    return word(len(value)) + value.ljust((len(value) + 31) // 32 * 32, b"\0")


def vote_tuple(row):
    """Encode the public Vote tuple in ABI declaration order."""
    vote = row["vote"]
    return b"".join((
        word(int(vote["voteType"])), word(int(vote["height"])), word(int(vote["round"])),
        hex_bytes(vote["blockHash"], 32), word(int(vote["partsTotal"])),
        hex_bytes(vote["partsHash"], 32), word(int(vote["timestampSecondsU64"])),
        word(int(vote["timestampNanos"])), word(int(vote["generation"])),
        word(10 * 32), abi_bytes(hex_bytes(row["signature"], 65)),
    ))


def slash_calldata(first, second):
    """Encode literal bond 0 and two named signed tuples for the pinned Registry ABI."""
    first = vote_tuple(first)
    second = vote_tuple(second)
    return SLASH_SELECTOR + word(0) + word(3 * 32) + word(3 * 32 + len(first)) + first + second


def pair_binding(name, calldata):
    """Expected canonical binding of the case identity and both attempted calls."""
    name = abi_bytes(name.encode("ascii"))
    action = abi_bytes(calldata)
    return word(96) + word(96 + len(name)) + word(96 + len(name) + len(action)) + name + action * 2


def address_word(value):
    return hex_bytes(value, 20).rjust(32, b"\0")


def hex_data(value):
    return "0x" + value.hex()


def decode_receipt(log):
    """Decode canonical ABI bytes while rejecting truncation and nonzero padding."""
    data = hex_bytes(log["data"])
    if len(data) < 64 or data[:32] != word(32):
        raise ValueError("invalid receipt offset")
    length = int.from_bytes(data[32:64], "big")
    end = 64 + length
    if len(data) != 64 + ((length + 31) // 32) * 32 or any(data[end:]):
        raise ValueError("invalid receipt length or padding")
    return data[64:end]


def validate_native_logs(logs):
    if type(logs) is not list:
        raise ValueError("missing native Forge logs")
    for log in logs:
        if type(log) is not dict or set(log) != {"address", "topics", "data"}:
            raise ValueError("wrong native Forge log shape")
        hex_bytes(log["address"], 20)
        if log["data"] != "0x":
            hex_bytes(log["data"])
        if type(log["topics"]) is not list or len(log["topics"]) > 4:
            raise ValueError("wrong native Forge topics")
        for topic in log["topics"]:
            hex_bytes(topic, 32)


def require_forge_outcomes(raw, returncode, suite, expected, *, failure=None):
    """Check exact native identities, failure diagnostic and typed ABI receipts."""
    document = STOCK.strict_json(raw.encode())
    if type(document) is not dict or set(document) != {suite}:
        raise ValueError("missing, extra or wrong Forge suite identity")
    envelope = document[suite]
    if (type(envelope) is not dict or set(envelope) - {"duration", "test_results", "warnings"}
            or type(envelope.get("duration")) is not str
            or envelope.get("warnings", []) != [] or type(envelope.get("test_results")) is not dict):
        raise ValueError("wrong Forge suite metadata or compiler warning")
    rows = EXEC.forge_rows(raw)
    if not expected or set(rows) != {suite + "::" + name for name in expected}:
        raise ValueError("missing, extra or wrong Forge leaf identity")
    if returncode != int(failure is not None) or (failure and failure[0] not in expected):
        raise ValueError("unexpected Forge return code or fault identity")

    outcomes = {}
    for leaf, expect in expected.items():
        row = rows[suite + "::" + leaf]
        if (type(row) is not dict or set(row) != RESULT_FIELDS or row["counterexample"] is not None
                or row["decoded_logs"] != [] or type(row["duration"]) is not str):
            raise ValueError(f"wrong Forge leaf metadata: {leaf}")
        kind = row["kind"]
        if (type(kind) is not dict or set(kind) != {"Unit"} or type(kind["Unit"]) is not dict
                or set(kind["Unit"]) != {"gas"} or type(kind["Unit"]["gas"]) is not int
                or kind["Unit"]["gas"] < 0 or row["traces"] != []
                or any(type(row[field]) is not dict for field in
                       ("labeled_addresses", "breakpoints", "gas_snapshots"))):
            raise ValueError(f"wrong Forge unit test metadata: {leaf}")
        validate_native_logs(row["logs"])
        receipts = [log for log in row["logs"] if RECEIPT_TOPIC in log["topics"]]
        if failure and leaf == failure[0]:
            if row["status"] != "Failure" or row["reason"] != failure[1] or receipts:
                raise ValueError(f"wrong Forge fault diagnostic or partial receipt: {leaf}")
            if failure[2]:
                failure[2](row["logs"])
            outcomes[leaf] = dict(status="Failure", reason=row["reason"])
            continue
        if row["status"] != "Success" or row["reason"] is not None:
            raise ValueError(f"unexpected Forge status for {leaf}: {row['reason']}")
        if len(receipts) != 1 or receipts[0] != row["logs"][-1] or receipts[0]["topics"] != [RECEIPT_TOPIC]:
            raise ValueError(f"missing, extra or misplaced receipt: {leaf}")
        if receipts[0]["address"] != TEST_DRIVER:
            raise ValueError(f"wrong native Forge receipt emitter: {leaf}")
        receipt = decode_receipt(receipts[0])
        if callable(expect):
            outcome = expect(receipt, row["logs"][:-1])
        else:
            if receipt != expect or len(row["logs"]) != 1:
                raise ValueError(f"wrong wire/domain receipt: {leaf}")
            outcome = dict(bytes=hex_data(receipt))
        outcomes[leaf] = dict(status="Success", **outcome)
    return outcomes


def require_pair_logs(logs, pre_root, post_root, event):
    """Compare every setup and action log before projecting the pair summary."""
    def checkpoint(index, at, root):
        return dict(address=PROXY, topics=[CHECKPOINT_TOPIC, hex_data(word(index))],
                    data=hex_data(word(at) + word(1) + root))

    def transfer(source, target, amount):
        return dict(address=TOKEN,
                    topics=[TRANSFER_TOPIC, hex_data(address_word(source)), hex_data(address_word(target))],
                    data=hex_data(word(amount)))

    # Third and fourth CREATEs in _setupRegistry deploy the implementation and
    # the template proxy before the proxy code is etched at PROXY.
    implementation = "0xf62849f9a0b5bf2913b396098f7c7019b51a820a"
    proxy_template = "0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9"
    admin = "0x" + "00" * 18 + "3333"
    # _prepare registers the first published PoP, with compressed key prefix 3.
    signer = "0xd2431ca38735c2fd438e2caa23f094191d89675b"
    key_x = bytes.fromhex("cc8704b8a60a0defa3a99a7299f2e9c3fbc395afb04ac078425ef8a1793cc030")
    bond_zero = hex_data(word(0))
    deposit = transfer(OWNER_A, PROXY, 4)
    setup = [
        dict(address=implementation, topics=[INITIALIZED_TOPIC], data=hex_data(word(255))),
        dict(address=proxy_template, topics=[UPGRADED_TOPIC, hex_data(address_word(implementation))], data="0x"),
        dict(address=PROXY, topics=[OWNERSHIP_TRANSFERRED_TOPIC, bond_zero, hex_data(address_word(admin))],
             data="0x"),
        dict(address=PROXY, topics=[INITIALIZED_TOPIC], data=hex_data(word(1))),
        checkpoint(0, 10, pre_root),
        deposit,
        dict(address=PROXY,
             topics=[REGISTERED_TOPIC, bond_zero, hex_data(address_word(OWNER_A)), hex_data(address_word(signer))],
             data=hex_data(word(3) + key_x + word(4) + word(12))),
        deposit,
        dict(address=PROXY, topics=[TOPUP_DEPOSITED_TOPIC, bond_zero], data=hex_data(word(4) + word(14))),
    ]
    action = []
    if event:
        action = [
            checkpoint(1, 13, post_root), transfer(PROXY, REPORTER, 2), transfer(PROXY, SINK, 6),
            dict(address=PROXY, topics=[SLASH_TOPIC, bond_zero, hex_data(address_word(REPORTER))],
                 data=hex_data(b"".join(map(word, (8, 2, event["generation"], event["height"],
                                                  event["round"], event["voteType"]))))),
        ]
    if logs != setup + action:
        raise ValueError("pair receipt: wrong ordered native setup or action logs")
    return [log for log in logs if log["topics"][0] in {CHECKPOINT_TOPIC, TRANSFER_TOPIC, SLASH_TOPIC}]


def pair_receipt(receipt, logs, case, pins, name, calldata):
    body, binding = receipt[:PAIR_RESULT_BYTES], receipt[PAIR_RESULT_BYTES:]
    if binding != pair_binding(name, calldata):
        raise ValueError(f"pair receipt: wrong case identity or ordered call data: {name}")
    effects = pins["effects"]
    pre_root = hex_bytes(effects["preRoot"], 32)
    post_root = hex_bytes(effects["postRoot"], 32)
    fields = [body[i:i + 32] for i in range(0, PAIR_RESULT_BYTES, 32)]
    success = case["result"] == "slash"
    selectors = pins["selectors"]
    result = b"" if success else hex_bytes(selectors[case["result"]], 4)
    repeat = hex_bytes(selectors["NothingToSlash" if success else case["result"]], 4)
    if fields[:5] != [address_word(PROXY), address_word(PROXY), result.ljust(32, b"\0"),
                      repeat.ljust(32, b"\0"), word(case["currentGeneration"])]:
        raise ValueError("pair receipt: exact revert origin, selectors or current generation")
    before, after, replay = fields[5:8]
    if not all(map(any, (before, after))) or (before != after) != success or after != replay:
        raise ValueError("pair receipt: wrong pre/post/repeat raw equality")
    if fields[8:] != [pre_root, post_root if success else pre_root,
                       *map(word, effects["slashed" if success else "before"])]:
        raise ValueError("pair receipt: wrong root/principal/cash words")
    native_logs = require_pair_logs(logs, pre_root, post_root, case.get("event"))
    return dict(case=name, calldata=hex_data(calldata), result=case["result"],
                first=hex_data(result), repeat=hex_data(repeat),
                proxy=PROXY, currentGeneration=case["currentGeneration"],
                beforeState=hex_data(before), afterState=hex_data(after), repeatState=hex_data(replay),
                preRoot=hex_data(fields[8]), postRoot=hex_data(fields[9]),
                effects=[int.from_bytes(x, "big") for x in fields[10:]],
                actionLogs=native_logs)


def lifecycle_binding(step):
    """Exact framing of one observed action, its context and its selected raw state."""
    call = abi_bytes(hex_bytes(step["calldata"]))
    result = abi_bytes(b"" if step["result"] == "0x" else hex_bytes(step["result"]))
    body = b"".join((
        step["name"].encode("ascii").ljust(32, b"\0"), word(step["height"]),
        word(step["snapshot"]), address_word(step["actor"]), address_word(PROXY),
        word(int(step["ok"])), hex_bytes(step["beforeState"], 32), hex_bytes(step["afterState"], 32),
        word(step["logCount"]), word(11 * 32), word(11 * 32 + len(call)), call, result,
    ))
    return word(len(body)) + body


def require_lifecycle_logs(logs, expected):
    if logs != expected:
        raise ValueError("wrong ordered lifecycle action logs")


def lifecycle_receipt(receipt, logs, oracle):
    """Check each full ABI step and identify the first mismatched action."""
    action_logs = oracle["actionLogs"]
    require_lifecycle_logs(logs, oracle["setupLogs"] + action_logs)
    offset = 0
    log_offset = 0
    journal = []
    for step in oracle["journal"]:
        expected = lifecycle_binding(step)
        if receipt[offset:offset + len(expected)] != expected:
            raise ValueError("wrong lifecycle receipt at " + step["name"])
        offset += len(expected)
        end = log_offset + step["logCount"]
        journal.append(step | {"proxy": PROXY, "actionLogs": action_logs[log_offset:end]})
        log_offset = end
    if offset != len(receipt) or log_offset != len(action_logs):
        raise ValueError("extra lifecycle receipt words or unbound action logs")
    return dict(journal=journal)


def lifecycle_failure(oracle):
    def require_activation_trace(logs):
        require_lifecycle_logs(logs, oracle["setupLogs"] + oracle["faultLogs"])

    return LIFECYCLE_TEST, LIFECYCLE_FAULT_DIAGNOSTIC, require_activation_trace


def displacement_binding(step):
    """Canonical version-2 action binding, including explicit pre-action external premises."""
    call = abi_bytes(hex_bytes(step["calldata"]))
    result = abi_bytes(b"" if step["result"] == "0x" else hex_bytes(step["result"]))
    body = b"".join((
        step["name"].encode("ascii").ljust(32, b"\0"), word(step["height"]),
        word(step["snapshot"]), word(step["generation"]), address_word(step["actor"]),
        address_word(step["target"]), word(int(step["ok"])),
        hex_bytes(step["beforeState"], 32), hex_bytes(step["afterState"], 32),
        hex_bytes(step["beforeFullState"], 32), hex_bytes(step["afterFullState"], 32),
        word(step["logCount"]), word(14 * 32), word(14 * 32 + len(call)), call, result,
    ))
    return word(len(body)) + body


def displacement_receipt(receipt, logs, oracle):
    """Compare complete histories, action inputs/outputs and every ordered native log."""
    if logs != oracle["setupLogs"] + oracle["actionLogs"]:
        raise ValueError("wrong ordered displacement trace logs")
    if not receipt.startswith(DISPLACEMENT_SCHEMA):
        raise ValueError("wrong displacement receipt schema")
    offset = len(DISPLACEMENT_SCHEMA)
    log_offset = 0
    journal = []
    for step in oracle["journal"]:
        expected = displacement_binding(step)
        if receipt[offset:offset + len(expected)] != expected:
            raise ValueError("wrong displacement receipt at " + step["name"])
        offset += len(expected)
        end = log_offset + step["logCount"]
        journal.append(step | {"traceLogs": oracle["actionLogs"][log_offset:end]})
        log_offset = end
    if offset != len(receipt) or log_offset != len(oracle["actionLogs"]):
        raise ValueError("extra displacement receipt words or unbound action logs")
    # _commit appends a checkpoint at a new height and overwrites the last
    # index on another write in that same block. Publish those observed rows,
    # rather than projecting the separately pinned typed history verbatim.
    history = []
    for log in logs:
        if not log["topics"] or log["topics"][0] != CHECKPOINT_TOPIC:
            continue
        data = hex_bytes(log["data"])
        if log["address"] != PROXY or len(log["topics"]) != 2 or len(data) != 96:
            raise ValueError("wrong displacement checkpoint history event")
        index = int.from_bytes(hex_bytes(log["topics"][1], 32), "big")
        height = int.from_bytes(data[:32], "big")
        count = int.from_bytes(data[32:64], "big")
        if height >= 1 << 48 or count >= 1 << 48:
            raise ValueError("wrong displacement checkpoint history field width")
        checkpoint = dict(height=height, count=count, root=hex_data(data[64:]))
        if index == len(history) and (not history or height > history[-1]["height"]):
            history.append(checkpoint)
        elif history and index == len(history) - 1 and height == history[-1]["height"]:
            history[-1] = checkpoint
        else:
            raise ValueError("wrong displacement checkpoint history index or height")
    if history != oracle["history"]:
        raise ValueError("wrong displacement checkpoint history")
    return dict(schema="etna-registry-displacement-2", journal=journal,
                history=history, finalCash=oracle["finalCash"])


def displacement_failure(oracle):
    def require_actual_replacement(logs):
        steps = oracle["journal"]
        end = next(i + 1 for i, step in enumerate(steps) if step["name"] == "replace_held_zero")
        count = sum(step["logCount"] for step in steps[:end])
        if logs != oracle["setupLogs"] + oracle["actionLogs"][:count]:
            raise ValueError("wrong ordered displacement fault trace logs")

    return DISPLACEMENT_PRIMARY, DISPLACEMENT_FAULT_DIAGNOSTIC, require_actual_replacement


def require_displacement_oracle(leaves):
    common = ("register_a", "register_b", "topup_a", "activate_early", "activate_a",
              "force_exit_a", "snapshot_uncovered", "confirm_uncovered", "snapshot_covered",
              "confirm_a", "generation_advance", "slash_historical", "withdraw_early")
    tails = {DISPLACEMENT_PRIMARY: ("replace_held_zero", "zero_withdraw"),
             DISPLACEMENT_OPPOSITE: ("zero_withdraw", "replace_vacancy")}
    if set(leaves) != set(DISPLACEMENT_TESTS):
        raise ValueError("wrong frozen displacement leaf inventory")
    for leaf, oracle in leaves.items():
        journal = oracle["journal"]
        if (tuple(step["name"] for step in journal) != common + tails[leaf]
                or sum(step["logCount"] for step in journal) != len(oracle["actionLogs"])
                or oracle["finalCash"] != [83, 83, 8, 2, 7, 0, 6]
                or len(oracle["history"]) != (4 if leaf == DISPLACEMENT_PRIMARY else 6)):
            raise ValueError("wrong frozen displacement schedule, cash or history")
        for step in journal:
            if not step["ok"] and (step["beforeState"] != step["afterState"]
                                   or step["beforeFullState"] != step["afterFullState"]):
                raise ValueError("wrong frozen displacement refusal equality")


def atomicity_binding(step):
    """Exact call, token frame, allowance write and full selected pre/post observations."""
    dynamic = [abi_bytes(b"" if step[field] == "0x" else hex_bytes(step[field]))
               for field in ("calldata", "result", "tokenCalldata")]
    head_size = 17 * 32
    body = b"".join((
        step["name"].encode("ascii").ljust(32, b"\0"), word(step["height"]),
        word(step["snapshot"]), address_word(step["actor"]), address_word(step["target"]),
        word(int(step["ok"])), hex_bytes(step["beforeState"], 32), hex_bytes(step["afterState"], 32),
        word(step["logCount"]), address_word(step["tokenTarget"]), word(int(step["tokenReverted"])),
        *map(word, step["allowanceWrite"]), word(head_size), word(head_size + len(dynamic[0])),
        word(head_size + len(dynamic[0]) + len(dynamic[1])), *dynamic,
    ))
    return word(len(body)) + body


def atomicity_frame_binding(frame):
    index, kind, account, accessor, depth, reverted = frame
    return b"".join((word(index), word(kind), address_word(account), address_word(accessor),
                     word(depth), word(int(reverted))))


def require_topup_witness(receipt, witness):
    """Compare the recorded frame and SSTORE tuples to the frozen fixture oracle."""
    writes = b"".join(
        atomicity_frame_binding(frame) + word(index) + address_word(account) + hex_bytes(slot, 32)
        + word(before) + word(attempted) + word(int(reverted))
        for frame, index, account, slot, before, attempted, reverted in witness["writes"]
    )
    body = b"".join((
        atomicity_frame_binding(witness["delegate"]), atomicity_frame_binding(witness["token"]),
        *map(word, witness["before"]), *map(word, witness["restored"]), word(21 * 32), abi_bytes(writes),
    ))
    expected = word(len(body)) + body
    if not receipt.startswith(expected):
        raise ValueError("wrong atomicity topup_refusal Registry write witness")
    return len(expected), witness


def atomicity_receipt(receipt, logs, oracle):
    """Admit only the independently pinned journal and native trace sequence."""
    action_logs = oracle["actionLogs"]
    if logs != oracle["setupLogs"] + action_logs:
        raise ValueError("wrong ordered atomicity trace logs")
    if not receipt.startswith(ATOMICITY_RECEIPT_SCHEMA):
        raise ValueError("wrong atomicity receipt schema")
    offset = len(ATOMICITY_RECEIPT_SCHEMA)
    log_offset = 0
    journal = []
    for step in oracle["journal"]:
        expected = atomicity_binding(step)
        if receipt[offset:offset + len(expected)] != expected:
            raise ValueError("wrong atomicity receipt at " + step["name"])
        offset += len(expected)
        end = log_offset + step["logCount"]
        observed = step | {"traceLogs": action_logs[log_offset:end]}
        if step["name"] == "topup_refusal":
            length, witness = require_topup_witness(receipt[offset:], oracle["topUpWitness"])
            offset += length
            observed["topUpWitness"] = witness
        journal.append(observed)
        log_offset = end
    if offset != len(receipt) or log_offset != len(action_logs):
        raise ValueError("extra atomicity receipt words or unbound trace logs")
    return dict(journal=journal)


def atomicity_failure(oracle):
    def require_missing_transfer_trace(logs):
        if logs != oracle["setupLogs"] + oracle["faultLogs"]:
            raise ValueError("wrong ordered atomicity fault trace logs")

    return ATOMICITY_TOPUP, ATOMICITY_FAULT_DIAGNOSTIC, require_missing_transfer_trace


def require_topup_context(oracle, refusal):
    """Check the fixture's delegated/resumed context and relative write positions."""
    witness = oracle["topUpWitness"]
    delegate_index, kind, implementation, accessor, depth, reverted = witness["delegate"]
    token_index, token_kind, target, token_accessor, token_depth, token_reverted = witness["token"]
    # Setup etches the constructor proxy's runtime code at REGISTRY. The
    # constructor's exactly pinned Upgraded log names the implementation.
    upgrades = [row["topics"][1] for row in oracle["setupLogs"] if row["topics"][0] == UPGRADED_TOPIC]
    # AccountAccessKind values from the pinned Vm interface: Call=0, DelegateCall=1, Resume=6.
    if (kind != 1 or upgrades != [hex_data(address_word(implementation))]
            or accessor != refusal["actor"] or not reverted
            or token_kind != 0 or target != refusal["tokenTarget"] or token_accessor != PROXY
            or token_depth != depth + 1 or not token_reverted):
        raise ValueError("wrong frozen top-up delegated or nested token context")

    positions, slots, previous = [], set(), []
    for frame, index, storage_account, slot, before, _, write_reverted in witness["writes"]:
        frame_index, frame_kind, account, caller, frame_depth, frame_reverted = frame
        if (frame != witness["delegate"]
                and (frame_index <= delegate_index or frame_kind != 6
                     or (account, caller, frame_depth, frame_reverted) != (implementation, accessor, depth, reverted))):
            raise ValueError("wrong frozen top-up write context")
        if storage_account != PROXY or not write_reverted or not delegate_index <= frame_index < token_index:
            raise ValueError("wrong frozen top-up write origin, revert or token boundary")
        positions.append((frame_index, index))
        slots.add(slot)
        previous.append(before)
    if (len(positions) != 4 or len(slots) != 4 or positions != sorted(set(positions))
            or previous != witness["before"] or previous != witness["restored"]):
        raise ValueError("wrong frozen top-up write count, order or raw words")


def require_atomicity_oracle(leaves):
    if set(leaves) != set(ATOMICITY_STEPS):
        raise ValueError("wrong frozen atomicity leaf inventory")
    for leaf, names in ATOMICITY_STEPS.items():
        oracle = leaves[leaf]
        journal = oracle["journal"]
        if (tuple(step["name"] for step in journal) != names
                or sum(step["logCount"] for step in journal) != len(oracle["actionLogs"])):
            raise ValueError("wrong frozen atomicity journal inventory")
        refusal, external, retry = journal[:3]
        repeated = ("height", "snapshot", "actor", "target", "calldata", "tokenTarget", "tokenCalldata")
        if (any(refusal[field] != retry[field] for field in repeated)
                or refusal["ok"] or not refusal["tokenReverted"] or not retry["ok"]
                or retry["tokenReverted"] or not external["ok"] or external["target"] != TOKEN
                or refusal["beforeState"] != refusal["afterState"]
                or refusal["afterState"] != external["beforeState"]
                or external["beforeState"] == external["afterState"]
                or external["afterState"] != retry["beforeState"]
                or any(external[field] != retry[field] for field in ("height", "snapshot"))):
            raise ValueError("wrong frozen atomicity refusal, context or retry")
        if leaf == ATOMICITY_TOPUP:
            require_topup_context(oracle, refusal)


def solidity_files(scenario):
    return (*SOLIDITY_FILES[:2], SCENARIOS[scenario][0])


def inputs(scenario="double-sign"):
    pins_raw = PIN_PATH.read_bytes()
    pins = STOCK.strict_json(pins_raw)
    if pins["schema"] != "etna-registry-cases-pins-1":
        raise ValueError("wrong Registry case pin schema")
    watched = {ROOT / path: require_hash(ROOT / path, digest)
               for path, digest in pins["inputsSha256"].items()}
    stock_pins, _, stock_watch, stock_oracles = STOCK.native_inputs()
    contracts = EXEC.read_json(MANIFEST_PATH)
    test_sources = {f"solidity/{name}": EXEC.sha(ROOT / "solidity" / name)
                    for name in solidity_files(scenario)}
    boundary, boundary_watch = STOCK.CURRENT_SPEC.historical_workspace_receipt(
        ROOT.parents[2], "registry-cases", scenario, spec_commit=stock_pins["specAuthority"]["commit"],
        implementation_commit=contracts["commit"], manifest_sha256=watched[MANIFEST_PATH],
        input_pins_sha256={
            "registry_cases/pins.json": BASELINE.digest(pins_raw),
            "comet_signed/pins.json": stock_watch[ROOT / "comet_signed/pins.json"],
            "pins.json": watched[ROOT / "pins.json"],
        },
        test_sources_sha256=test_sources,
    )
    votes = STOCK.load_projection((ROOT / "comet_signed/public-votes.json").read_bytes())
    if list(pins["wire"]) != [row["name"] for row in votes["voteCases"]]:
        raise ValueError("wrong frozen wire case sequence")
    expected = {}
    for name, row in zip(pins["domains"], votes["chainDomains"], strict=True):
        expected[f"test_domain_{name}()"] = hex_bytes(row["chain_domain"], 32) + row["chain_id"].encode()
    for row in votes["voteCases"]:
        literal = hex_bytes(row["sign_bytes"])
        if len(literal) != pins["wire"][row["name"]]:
            raise ValueError("wrong frozen wire byte count")
        expected[f'test_wire_{row["name"]}()'] = literal
    if list(pins["pairs"]) != [pair["name"] for pair in votes["votePairs"]]:
        raise ValueError("wrong frozen pair identity sequence")
    by_name = {row["name"]: row for row in votes["voteCases"]}
    for pair in votes["votePairs"]:
        name = pair["name"]
        oracle = pins["pairs"][name]
        if (oracle["a"], oracle["b"], str(oracle["currentGeneration"]), oracle["result"] == "slash") != (
                pair["a"], pair["b"], pair["current_generation"], pair["double_sign"]):
            raise ValueError("published pair disagrees with explicit SPEC oracle")
        calldata = slash_calldata(by_name[oracle["a"]], by_name[oracle["b"]])
        expected[f"test_pair_{name}()"] = (
            lambda receipt, logs, case=oracle, case_name=name, call=calldata:
                pair_receipt(receipt, logs, case, pins, case_name, call)
        )
    partition = Counter(row["result"] for row in pins["pairs"].values())
    if (len(expected) != 42 or len(pins["domains"]) != 5 or len(pins["wire"]) != 23
            or partition != {"slash": 6, "NotDoubleSign": 6, "FutureGeneration": 1, "InvalidSignature": 1}):
        raise ValueError("wrong frozen domain/wire/pair partition")
    authored_paths = [Path(__file__), ROOT / "REGISTRY_CASES.md",
                      ROOT.parent / "tests/test_registry_cases.py"]
    if scenario == "lifecycle":
        lifecycle = pins["lifecycle"]
        journal = lifecycle["journal"]
        if (len(journal) != 16 or len({step["name"] for step in journal}) != 16
                or sum(step["logCount"] for step in journal) != len(lifecycle["actionLogs"])):
            raise ValueError("wrong frozen lifecycle journal inventory")
        expected = {LIFECYCLE_TEST: lambda receipt, logs: lifecycle_receipt(receipt, logs, lifecycle)}
    elif scenario == "displacement":
        leaves = pins["displacement"]
        require_displacement_oracle(leaves)
        expected = {
            leaf: lambda receipt, logs, oracle=oracle: displacement_receipt(receipt, logs, oracle)
            for leaf, oracle in leaves.items()
        }
    elif scenario == "atomicity":
        leaves = pins["atomicity"]
        require_atomicity_oracle(leaves)
        expected = {
            leaf: lambda receipt, logs, oracle=oracle: atomicity_receipt(receipt, logs, oracle)
            for leaf, oracle in leaves.items()
        }
    watched.update({path: EXEC.sha(path) for path in authored_paths})
    watched.update({ROOT / name: digest for name, digest in test_sources.items()})
    watched[PIN_PATH] = BASELINE.digest(pins_raw)
    return pins, expected, watched | stock_watch | boundary_watch, stock_pins, stock_oracles, boundary


def stock_evidence(normal, pins, stock_oracles, wire):
    """Re-parse previously accepted stock Go observations and bind both evidence hashes."""
    summary = normal / "execution.json"
    raw_path = normal / "combined.log"
    record = EXEC.read_json(summary)
    raw = raw_path.read_bytes()
    snapshot = dict(commit=pins["source"]["commit"], files=pins["source"]["files"],
                    status="INPUTS_VERIFIED")
    if (record["phase"] != "normal" or record["timedOut"] is not False
            or record["sourceBefore"] != snapshot or record["sourceAfter"] != snapshot
            or record["combinedOutputSha256"] != BASELINE.digest(raw)
            or record["toolsSha256"] != pins["goToolSha256"]):
        raise ValueError("wrong or stale stock Go evidence")
    STOCK.require_executed_inputs(record, pins)
    outcomes = STOCK.require_go_outcomes(raw, record["returncode"], "normal", stock_oracles)
    if outcomes != record["outcomes"]:
        raise ValueError("stock Go native identity readback differs")
    comparison = {}
    for row in STOCK.parse_events(raw):
        name = row.get("Test", "").removeprefix(STOCK.PARENT + "/")
        if name in wire and row["Action"] == "output" and "OutputType" not in row:
            start = row["Output"].partition("receipt=")[2]
            comparison[f"test_wire_{name}()"] = STOCK.strict_json(start.encode())["signBytes"]
    if len(comparison) != len(wire):
        raise ValueError("missing stock Go byte receipts")
    return comparison, {summary: EXEC.sha(summary), raw_path: BASELINE.digest(raw)}


def source_snapshot(source, manifest):
    verification = BASELINE.verify_source(source, manifest, manifest["commit"])
    if set(EXEC.snapshot(source)) != set(manifest["files"]):
        raise ValueError("private contract snapshot contains extra or missing files")
    return verification


@contextmanager
def private_source_fault(source, manifest, artifact, *, scenario="double-sign"):
    """Restore private bytes and mode after completed or cooperatively interrupted phases."""
    path = source / FAULT_PATH
    mode = stat.S_IMODE(path.stat().st_mode)
    original = path.read_bytes()
    function, before, after = {
        "double-sign": (FAULT_FUNCTION, b"\n" + FAULT_BEFORE, FAULT_AFTER),
        "lifecycle": (LIFECYCLE_FAULT_FUNCTION, LIFECYCLE_FAULT_BEFORE, LIFECYCLE_FAULT_AFTER),
        "atomicity": (ATOMICITY_FAULT_FUNCTION, ATOMICITY_FAULT_BEFORE, ATOMICITY_FAULT_AFTER),
        "displacement": (DISPLACEMENT_FAULT_FUNCTION, DISPLACEMENT_FAULT_BEFORE, DISPLACEMENT_FAULT_AFTER),
    }[scenario]
    if (STOCK.COMET.file_entry(original) != manifest["files"][FAULT_PATH]
            or original.count(function) != 1 or original.count(before) != 1
            or original.find(function) >= original.find(before)):
        raise ValueError("original branch hash or unique fault context differs")
    if scenario != "double-sign" and original.find(before) >= original.find(b"\n    }", original.find(function)):
        raise ValueError("original branch hash or unique fault context differs")
    mutant = original.replace(before, after, 1)
    if mutant == original:
        raise ValueError("contextual source mutation did not apply")
    altered = manifest | {"files": manifest["files"] | {FAULT_PATH: STOCK.COMET.file_entry(mutant)}}
    writable = mode | stat.S_IWUSR
    applied = False
    try:
        path.chmod(writable)
        if path.write_bytes(mutant) != len(mutant):
            raise OSError("short private fault write")
        applied = True
        (artifact / "fault-source.sol").write_bytes(mutant)
        yield altered
    finally:
        try:
            if applied and path.read_bytes() != mutant:
                raise ValueError("private fault bytes drifted before restoration")
        finally:
            try:
                path.chmod(writable)
                if path.write_bytes(original) != len(original):
                    raise OSError("short private restoration write")
            finally:
                path.chmod(mode)
            restored = source_snapshot(source, manifest)
            if stat.S_IMODE(path.stat().st_mode) != mode:
                raise ValueError("private source mode was not restored")
            STOCK.write_json(artifact / "restoration.json",
                             restored | {"originalSha256": BASELINE.digest(original),
                                         "mutantSha256": BASELINE.digest(mutant), "mode": oct(mode)})


def runtime_inputs(runtime_path, pins):
    """Use the existing reviewed routing template only for absolute host input paths."""
    runtime = EXEC.read_json(runtime_path)
    if (runtime["schema"] != "etna-fault-runtime-1" or type(runtime["timeout"]) is not int
            or not 1 <= runtime["timeout"] <= 900):
        raise ValueError("wrong offline Forge routing schema or timeout")
    source = Path(runtime["sources"]["contracts"]).resolve(strict=True)
    template = runtime["forge"]["argv"]
    launcher_args = template[:template.index("--")]
    paths = {}
    names = set(pins["runtime"])
    for i, arg in enumerate(launcher_args):
        if arg != "--read-bind":
            continue
        origin, target = launcher_args[i + 1].split("=", 1)
        name = PurePosixPath(target).name
        if name not in names:
            continue
        if name in paths or not Path(origin).is_absolute():
            raise ValueError("duplicate or relative mapped dependency/tool")
        paths[name] = Path(origin).resolve(strict=True)
    if set(paths) != names or names != set(TOOLS) | {name for name, _ in DEPENDENCIES}:
        raise ValueError("wrong fixed offline tool/dependency inventory")

    lock_path = Path(runtime["forge"]["lock"])
    lock = lock_path.resolve(strict=True)
    writes = [launcher_args[i + 1].split("=", 1)[0]
              for i, arg in enumerate(launcher_args) if arg == "--write-bind"]
    if (not lock_path.is_absolute() or lock_path.is_symlink() or lock.name != ".formal-cache.lock"
            or len(writes) != 1 or lock.parent != Path(writes[0]).resolve(strict=True)
            or not lock.is_file()):
        raise ValueError("wrong physical Forge cache lock")
    tool_hashes = {paths[name]: require_hash(paths[name], pins["runtime"][name]) for name in TOOLS}
    dep_files = {}
    for name, _ in DEPENDENCIES:
        root = paths[name]
        entries = {
            path.relative_to(root).as_posix(): EXEC.sha(path)
            for path in sorted(root.rglob("*.sol")) if path.is_file()
        }
        expected = pins["runtime"][name]
        digest = BASELINE.digest(json.dumps(entries, sort_keys=True, separators=(",", ":")).encode())
        if len(entries) != expected["solidityFiles"] or digest != expected["sha256"]:
            raise ValueError("offline dependency hash differs: " + name)
        if any((root / p).is_symlink() or not (root / p).resolve().is_relative_to(root)
               for p in entries):
            raise ValueError("substituted offline dependency: " + name)
        dep_files[name] = entries
    return source, paths, lock, runtime["timeout"], tool_hashes, dep_files


def public_test_inputs(scenario):
    return {name: ROOT / "solidity" / name for name in solidity_files(scenario)} | {
        "vectors/" + name: ROOT / name
        for name in ("registry_public/registration.json", "comet_signed/public-votes.json")
    }


def stage_inputs(output, source, manifest, paths, dep_files, *, watched, scenario="double-sign"):
    """Copy only pinned source and explicit public test/fixture files."""
    private = output / "private-contracts"
    for name, entry in manifest["files"].items():
        rel = EXEC.safe_relative(name)
        if rel.parts[0] == "testdata":
            raise ValueError("mixed artifact tree is excluded from the Registry runtime")
        target = private / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if entry.get("kind") == "symlink":
            target.symlink_to(entry["target"])
        else:
            shutil.copy2(source / rel, target)
    source_snapshot(private, manifest)

    test_dir = output / "public-tests"
    test_dir.mkdir()
    for name, origin in public_test_inputs(scenario).items():
        target = test_dir / name
        target.parent.mkdir(exist_ok=True, parents=True)
        shutil.copyfile(origin, target)
        require_hash(target, watched[origin])
    dependency_dir = output / "public-dependencies"
    for name, entries in dep_files.items():
        for relative, digest in entries.items():
            target = dependency_dir / name / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(paths[name] / relative, target)
            require_hash(target, digest)
    config = output / "offline-foundry.toml"
    original = (private / "packages/protocol/foundry.toml").read_text()
    config.write_text(EXEC.replace_once(original, "\nffi = true\n", "\nffi = false\n"))
    return private, test_dir, dependency_dir, config


def isolation_command(output, private, tests, dependencies, config, paths, selected, timeout, *,
                      scenario="double-sign"):
    """Rebuild explicit isolated argv. The external routing template cannot inject a command."""
    source = "/tmp/registry-case/source"
    protocol = source + "/packages/protocol"
    test_dir = protocol + "/" + TEST_ROOT
    dep_dir = "/tmp/registry-case/deps"
    work = "/tmp/registry-case/forge"
    tools = "/tmp/registry-case/tools"
    bindings = [(private, source), (tests, test_dir), (config, protocol + "/foundry.toml")]
    bindings += [(paths[name], tools + "/" + name) for name in TOOLS]
    bindings += [(dependencies / name, dep_dir + "/" + name) for name, _ in DEPENDENCIES]
    argv = [sys.executable, "-B", str(ROOT / "run_isolated.py")]
    for origin, target in bindings:
        argv += ["--read-bind", f"{origin}={target}"]
    argv += ["--write-bind", f"{output / 'forge-work'}={work}", "--cwd", protocol,
             "--timeout", str(timeout), "--jail-parent", str(output)]

    remaps = ["src/=contracts/", "test/=test/", "script/=script/"]
    remaps += [remap + "=" + dep_dir + "/" + name + "/" for name, remap in DEPENDENCIES]
    remaps += ["solady/=" + dep_dir + "/solady/",
               "@openzeppelin-upgrades/contracts/=" + dep_dir + "/openzeppelin-upgradeable/",
               "optimism/=" + dep_dir + "/optimism/"]
    env = {
        "PATH": tools + ":/usr/bin:/bin",
        "FOUNDRY_PROFILE": "layer1", "FOUNDRY_SRC": "contracts/layer1/etna",
        "FOUNDRY_TEST": TEST_ROOT, "FOUNDRY_SCRIPT": work + "/empty-scripts",
        "FOUNDRY_OUT": work + "/out", "FOUNDRY_CACHE_PATH": work + "/cache",
        "FOUNDRY_FFI": "false", "FOUNDRY_LIBS": json.dumps([dep_dir]),
        "FOUNDRY_ALLOW_PATHS": json.dumps([dep_dir]), "FOUNDRY_REMAPPINGS": "\n".join(remaps),
    }
    for name, value in env.items():
        argv += ["--env", name + "=" + value]
    pattern = "^(" + "|".join(re.escape(name) for name in selected) + ")$"
    path, contract, _ = SCENARIOS[scenario]
    return argv + ["--", tools + "/forge", "test", "--root", protocol, "--config-path",
                   protocol + "/foundry.toml", "--offline", "--use", tools + "/solc-0.8.30",
                   "--match-path", TEST_ROOT + "/" + path, "--match-contract",
                   "^" + contract + "$", "--match-test", pattern, "--json", "--threads", "2", "-vv"]


def phase(name, output, staged, paths, watch, manifest, expectations, comparison, timeout, failure=None, *,
          scenario="double-sign"):
    private, tests, dependencies, config = staged
    source_before = source_snapshot(private, manifest)
    STOCK.require_stable(watch, "original and staged Registry inputs before Forge")
    directory = output / name
    directory.mkdir()
    command = isolation_command(output, *staged, paths, expectations, timeout, scenario=scenario)
    result = EXEC.execute_logged(command, directory, timeout + 10, directory, 0)
    raw = result["output"]
    record = EXEC.finish_record(result, directory, 0)
    source_after = source_snapshot(private, manifest)
    STOCK.require_stable(watch, "original and staged Registry inputs after Forge")
    record.update(sourceBefore=source_before, sourceAfter=source_after, privateSource=str(private))
    STOCK.write_json(directory / "0-result.json", record)
    if record["timeout"]:
        raise ValueError("Forge timed out")
    source_file, contract, _ = SCENARIOS[scenario]
    suite = f"{TEST_ROOT}/{source_file}:{contract}"
    outcomes = require_forge_outcomes(raw, record["returncode"], suite, expectations, failure=failure)
    common = {key: outcomes[key]["bytes"] for key in comparison if key in outcomes}
    if common != {key: value for key, value in comparison.items() if key in expectations}:
        raise ValueError("stock Go and actual Solidity canonical byte observations differ")
    record.update(outcomes=outcomes, matchingGoWireRows=len(common))
    STOCK.write_json(directory / "0-result.json", record)
    return record


def run(args):
    scenario = args.scenario
    pins, expectations, watch, stock_pins, stock_oracles, boundary = inputs(scenario)
    comparison, go_watch = {}, {}
    if scenario == "double-sign":
        comparison, go_watch = stock_evidence(args.go_normal.resolve(strict=True), stock_pins,
                                              stock_oracles, pins["wire"])
    runtime_path = args.runtime.resolve(strict=True)
    source, paths, lock_path, limit, tool_watch, deps = runtime_inputs(runtime_path, pins)
    timeout = limit if args.timeout is None else args.timeout
    if not 1 <= timeout <= limit:
        raise ValueError("timeout must fall within the reviewed runtime bound")
    manifest = EXEC.read_json(MANIFEST_PATH)
    initial = EXEC.verify_contracts(ROOT.parent, source)
    original_snapshot = EXEC.snapshot(source)
    original_tool_paths = {path: path.resolve(strict=True) for path in tool_watch}
    output = args.output.resolve()
    protected = [ROOT.parents[2], source, lock_path.parent, *paths.values()]
    if any(output == root or output.is_relative_to(root) for root in protected):
        raise ValueError("output overlaps original checkout, source, tools or cache")
    output.mkdir()
    staged = stage_inputs(output, source, manifest, paths, deps, watched=watch, scenario=scenario)
    private, tests, libraries, config = staged
    scratch = output / "forge-work/empty-scripts"
    scratch.mkdir(parents=True)
    watch.update(tool_watch | go_watch | {runtime_path: EXEC.sha(runtime_path), config: EXEC.sha(config)})
    expected_tests = {name: watch[origin] for name, origin in public_test_inputs(scenario).items()}
    watch.update({tests / name: digest for name, digest in expected_tests.items()})
    watch.update({libraries / name: digest for name, digest in EXEC.snapshot(libraries).items()})

    with lock_path.open("rb") as lock:
        EXEC.acquire_lock(lock, timeout)
        lock_id = os.fstat(lock.fileno())
        lock_identity = (lock_id.st_dev, lock_id.st_ino)

        def guards():
            current = lock_path.stat()
            if (current.st_dev, current.st_ino) != lock_identity:
                raise ValueError("physical Forge cache lock changed")
            if any(path.resolve(strict=True) != resolved for path, resolved in original_tool_paths.items()):
                raise ValueError("offline tool path resolution changed")
            if EXEC.snapshot(source) != original_snapshot:
                raise ValueError("staged source baseline changed")
            STOCK.require_stable(watch, "watched Registry inputs")
            if EXEC.snapshot(tests) != expected_tests:
                raise ValueError("staged Registry test inventory differs")
            if any(scratch.iterdir()):
                raise ValueError("offline script directory changed")

        try:
            guards()
            common = (output, staged, paths, watch, manifest)
            if args.smoke:
                leaf = SCENARIOS[scenario][2]
                selected = {leaf: expectations[leaf]}
                result = {"smoke": phase("smoke", *common, selected, comparison, timeout, scenario=scenario)}
            else:
                if scenario == "lifecycle":
                    failure = lifecycle_failure(pins["lifecycle"])
                elif scenario == "displacement":
                    failure = displacement_failure(pins["displacement"][DISPLACEMENT_PRIMARY])
                elif scenario == "atomicity":
                    failure = atomicity_failure(pins["atomicity"][ATOMICITY_TOPUP])
                else:
                    pre_root = hex_bytes(pins["effects"]["preRoot"], 32)
                    post_root = hex_bytes(pins["effects"]["postRoot"], 32)
                    fault_event = pins["pairs"]["precommit_conflict"]["event"]

                    def detect_fault(logs):
                        require_pair_logs(logs, pre_root, post_root, fault_event)

                    failure = (FAULT_TEST, FAULT_DIAGNOSTIC, detect_fault)
                result = {"original": phase("original", *common, expectations, comparison, timeout, scenario=scenario)}
                guards()
                with private_source_fault(private, manifest, output, scenario=scenario) as mutant:
                    result["fault"] = phase("fault", output, staged, paths, watch, mutant,
                                            expectations, comparison, timeout, failure, scenario=scenario)
                guards()
                result["restored"] = phase("restored", *common, expectations, comparison, timeout, scenario=scenario)
                if result["original"]["outcomes"] != result["restored"]["outcomes"]:
                    raise ValueError("original/restored case receipts differ")
        finally:
            guards()
            source_snapshot(private, manifest)

    summary = dict(schema="etna-registry-cases-run-2", status="PASS", scenario=args.scenario,
                   scope="smoke" if args.smoke else "source-control",
                   contractSource=initial, specBoundary=boundary, physicalCacheLock=str(lock_path),
                   lockDevice=lock_identity[0], lockInode=lock_identity[1],
                   inputsSha256={str(path): digest for path, digest in watch.items()
                                 if not path.is_relative_to(libraries)},
                   phases={name: dict(leaves=len(record["outcomes"]), logSha256=record["log_sha256"],
                                      goWireRows=record["matchingGoWireRows"])
                           for name, record in result.items()})
    STOCK.write_json(output / "summary.json", summary)
    print(json.dumps(summary["phases"], sort_keys=True))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", choices=SCENARIOS, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--go-normal", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int)
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args(argv)
    if args.scenario == "double-sign" and args.go_normal is None:
        parser.error("--go-normal is required for double-sign")
    try:
        run(args)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Registry case gate refused: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
