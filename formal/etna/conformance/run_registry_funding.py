"""Audit the fixed historical Registry mock-token journal, from native ABI bytes."""

from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
import re
from pathlib import Path

from boundary_scope import reviewed_boundary
from run_comet_apphash import keccak256

HERE = Path(__file__).resolve().parent
NATIVE_COMMIT = "89f419915de4b73bb57c53bf970f6dea9e8e8c8c"
CLAIM = "funded-forfeiture"
A = int("aa" * 20, 16)
B = int("bb" * 20, 16)
REGISTRY = int("22" * 20, 16)
INBOX = int("11" * 20, 16)
ADMIN, PUBLIC, SINK, PAYEE = 0x3333, 0x4444, 0x5555, 0x6666
DRIVER = int("7fa9385be102ac3eac297483dd6233d62b3e1496", 16)
P = (1 << 256) - (1 << 32) - 977
NO_EXIT = (1 << 48) - 1
ROOT_SLOT = int("46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000", 16)
OWNERS = int("39c9f3adc28a427dc5a3705913196a8ee3e586999e5fd34170cb091706065d00", 16)
CONFIRM = int("25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900", 16)
TOP = int("3a1aea98c955969894fa1164a9cf4fb395d732d0191953a25567edb8a7c00400", 16)
FORFEIT = int("dfeb3c25dc200ebc2d2e4944bf5b28b239af40d34f2491dee100754230b61400", 16)
ERC1967 = int("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", 16)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique(items):
    result = {}
    for name, value in items:
        require(name not in result, "duplicate JSON field " + name)
        result[name] = value
    return result


def document(data):
    return json.loads(data, object_pairs_hook=unique)


def word(n):
    return n.to_bytes(32, "big")


def pack(*values):
    return b"".join(word(v) for v in values)


def uint(data):
    return int.from_bytes(data, "big")


def tag(name):
    return name.encode("ascii").ljust(32, b"\0")


@lru_cache(maxsize=128)
def signature(name):
    return keccak256(name.encode("ascii"))


def call(name, *values):
    return signature(name)[:4] + pack(*values)


def abi_bytes(data):
    return word(len(data)) + data + bytes(-len(data) % 32)


def create_address(nonce):
    # RLP([20-byte creator, nonce]) for the first four nonzero single-byte nonces.
    return uint(keccak256(bytes.fromhex("d694") + DRIVER.to_bytes(20, "big") + bytes([nonce]))[-20:])


TOKEN, INBOX_TEMPLATE, IMPLEMENTATION, PROXY_TEMPLATE = map(create_address, range(1, 5))
ADDRESSES = (A, B, PUBLIC, REGISTRY, SINK, PAYEE, ADMIN, DRIVER, TOKEN, INBOX,
             IMPLEMENTATION, PROXY_TEMPLATE, INBOX_TEMPLATE)
HEADER = tag("etna-registry-funding-1") + pack(DRIVER, TOKEN, INBOX, REGISTRY, IMPLEMENTATION,
                                                PROXY_TEMPLATE, INBOX_TEMPLATE)
INCIDENT = uint(signature("ETNA-Y04-FUNDED-FORFEITURE"))
ORDER = (
    "setup", "mint_a", "approve_a", "mint_b", "approve_b", "mint_public", "approve_public",
    "register_a", "register_b", "authorize", "forfeit_late", "restore_late", "topup_public",
    "restore_public", "topup_a", "mock_generation", "forfeit", "mock_uncovered",
    "confirm_uncovered", "mock_covered", "confirm", "withdraw_early", "withdraw_public",
    "withdraw_a", "retired_key", "approve_payout", "register_fresh_a",
)
REGISTRATIONS = {"register_a": (0, 0), "register_b": (3, 1), "retired_key": (1, 0),
                 "register_fresh_a": (4, 2)}
MINT = {"mint_a": (A, 9), "mint_b": (B, 4), "mint_public": (PUBLIC, 2)}
APPROVE = {"approve_a": (A, 9), "approve_b": (B, 4), "approve_public": (PUBLIC, 1),
           "approve_payout": (A, 4)}
TRANSFERS = {"register_a": (A, REGISTRY, 4), "register_b": (B, REGISTRY, 4),
             "topup_a": (A, REGISTRY, 5), "forfeit": (REGISTRY, SINK, 5),
             "withdraw_a": (REGISTRY, A, 4), "register_fresh_a": (A, REGISTRY, 4)}
ERRORS = {"forfeit_late": "AuthorizationExpired()", "topup_public": "NotBondOwner()",
          "confirm_uncovered": "ExitNotCovered()", "withdraw_early": "WithdrawalNotReady()",
          "withdraw_public": "NotBondOwner()", "retired_key": "KeyAlreadyUsed()"}
MOCKS = {"mock_generation": ("setGeneration(uint48)", 1),
         "mock_uncovered": ("setSnapshot(uint48)", 14), "mock_covered": ("setSnapshot(uint48)", 15)}
RESTORES = ("restore_late", "restore_public")


def require_forfeiture(before, after, event):
    eff, pending, ready, prior_sink = before
    require(all(type(x) is int for x in (*before, *after, *event)), "invalid principal word")
    balance = eff + pending
    penalty = (balance + 1) // 2
    require(event == (balance, penalty), "forfeiture execution balance")
    debit = min(penalty, eff)
    residual = pending - (penalty - debit)
    require(after == (eff - debit, residual, ready if residual else 0, prior_sink + penalty),
            "forfeiture pending debit or payout")


def require_transfers(name, actual):
    expected = [TRANSFERS[name]] if name in TRANSFERS else []
    require(actual == expected and all(type(x) is int for row in actual for x in row),
            name + " token route")


def clock(name):
    if name == "forfeit_late":
        return 15, 1061
    if name in ("authorize", "topup_public", "topup_a", *RESTORES):
        return 12, 1000
    if name in ("mock_generation", "forfeit"):
        return 15, 1060
    if name in ("mock_uncovered", "confirm_uncovered", "mock_covered", "confirm"):
        return 16, 1060
    if name == "withdraw_early":
        return 17, 1060
    if name in ("withdraw_public", "withdraw_a"):
        return 18, 1060
    if name in ("retired_key", "approve_payout", "register_fresh_a"):
        return 19, 1060
    return 10, 1000


def actor(name):
    if name in ("forfeit", "forfeit_late", "authorize"):
        return ADMIN
    if name in ("topup_public", "withdraw_public", "confirm", "confirm_uncovered"):
        return PUBLIC
    if name in ("retired_key", "register_b"):
        return B
    if name in ("register_a", "register_fresh_a", "withdraw_early", "withdraw_a", "topup_a"):
        return A
    if name in APPROVE:
        return APPROVE[name][0]
    if name in RESTORES:
        return 0
    return DRIVER


def return_bytes(name):
    if name in ERRORS:
        return call(ERRORS[name])
    if name in APPROVE:
        return word(1)
    if name in REGISTRATIONS:
        return word(REGISTRATIONS[name][1])
    return b""


def require_attempt(name, caller, generation, timestamp, ok, output):
    require(name in ORDER, "unknown attempt")
    index = ORDER.index(name)
    require(type(generation) is int and generation == int(index > ORDER.index("mock_generation")),
            name + " mock generation")
    require(type(caller) is int and caller == actor(name), name + " actor")
    require(type(timestamp) is int and timestamp == clock(name)[1], name + " timestamp")
    reason = {"withdraw_public": "public withdrawal", "forfeit_late": "deadline"}.get(name, name)
    require(ok is (name not in ERRORS) and type(output) is bytes and output == return_bytes(name),
            reason + " outcome")


class TupleABI:
    """Consume the canonical contiguous dynamic tails of one tuple."""
    def __init__(self, data, size):
        require(len(data) >= size * 32 and len(data) % 32 == 0, "truncated ABI head")
        self.data = data
        self.head = tuple(uint(data[i:i+32]) for i in range(0, size*32, 32))
        self.pos = size * 32

    def tail(self, index, decoder):
        require(self.head[index] == self.pos, "noncanonical ABI tail offset")
        value, length = decoder(self.data[self.pos:])
        require(length <= len(self.data) - self.pos, "truncated ABI tail")
        self.pos += length
        return value


def blob(data):
    require(len(data) >= 32, "absent ABI length")
    n = uint(data[:32])
    end = 32 + (n + 31) // 32 * 32
    require(end <= len(data) and not any(data[32+n:end]), "ABI byte length or padding")
    return data[32:32+n], end


def array(data, decode, limit):
    require(len(data) >= 32, "absent ABI array")
    n = uint(data[:32])
    require(n <= limit, "ABI array count")
    body = TupleABI(data[32:], n)
    items = [body.tail(i, decode) for i in range(n)]
    return items, 32 + body.pos


def scalars(data, width, limit):
    require(len(data) >= 32, "absent ABI array")
    n = uint(data[:32])
    require(n <= limit, "ABI scalar count")
    size = 32 + n * width * 32
    require(size <= len(data), "truncated ABI scalar array")
    values = [uint(data[i:i+32]) for i in range(32, size, 32)]
    return [tuple(values[i:i+width]) for i in range(0, len(values), width)], size


def decode_log(data):
    item = TupleABI(data, 3)
    topics = item.tail(0, lambda b: scalars(b, 1, 4))
    payload = item.tail(1, blob)
    return (item.head[2], tuple(x for (x,) in topics), payload), item.pos


@dataclass(frozen=True)
class Frame:
    kind: int
    account: int
    accessor: int
    initialized: int
    old_balance: int
    new_balance: int
    code: bytes
    data: bytes
    reverted: int
    storage: list
    depth: int


def decode_frame(data):
    t = TupleABI(data, 14)
    h = t.head
    require(h[:2] == (0, 1) and h[2] < 11 and h[3] < 2**160 and h[4] < 2**160
            and h[5] in (0, 1) and h[9] == 0 and h[11] in (0, 1) and h[13] < 2**64,
            "native account frame field")
    code, calldata = t.tail(8, blob), t.tail(10, blob)
    storage = t.tail(12, lambda b: scalars(b, 6, 4096))
    for address, _, write, _, _, reverted in storage:
        require(address < 2**160 and write in (0, 1) and reverted in (0, 1), "storage field")
    return Frame(*h[2:8], code, calldata, h[11], storage, h[13]), t.pos


@dataclass(frozen=True)
class Step:
    kind: int
    name: str
    height: int
    timestamp: int
    actor: int
    target: int
    ok: bool
    input: bytes
    output: bytes
    before: tuple
    after: tuple
    before_digest: int
    after_digest: int
    logs: list
    frames: list


def decode_step(data, expected):
    require(data[:32] == word(32), "invalid Step root")
    item = TupleABI(data[32:], 203)
    h = item.head
    require(word(h[1]) == tag(expected) and h[6] in (0, 1), "journal step order/name/status")
    offered, returned = item.tail(7, blob), item.tail(8, blob)
    logs = item.tail(201, lambda b: array(b, decode_log, 12))
    frames = item.tail(202, lambda b: array(b, decode_frame, 512))
    require(32 + item.pos == len(data), "trailing Step data")
    return Step(h[0], expected, *h[2:6], bool(h[6]), offered, returned,
                h[9:104], h[104:199], h[199], h[200], logs, frames)


def public_inputs():
    raw = (HERE / "registry_public/registration.json").read_bytes()
    require(digest(raw) == "e441ece5cd83e70c2008da00b144f3411a1009dda3e18ce8cda9a4bebb208cdf",
            "public registration input hash")
    return document(raw)


def offered(name, public):
    if name in REGISTRATIONS:
        row = public["register_digests"][REGISTRATIONS[name][0]]
        key = abi_bytes(bytes.fromhex(row["key"][2:]))
        sig = abi_bytes(bytes.fromhex(row["pop_sig"][2:]))
        return REGISTRY, call("register(bytes,uint256,bytes)", 96, 4, 96 + len(key)) + key + sig
    if name in ("authorize", "forfeit", "forfeit_late"):
        key = int(public["keys"][0]["entry_key"], 16)
        return REGISTRY, call("forfeit(uint256,bytes32,bytes32,uint256)", 0, key, INCIDENT, 1060)
    if name in APPROVE:
        return TOKEN, call("approve(address,uint256)", REGISTRY, APPROVE[name][1])
    if name in MINT:
        return TOKEN, call("mint(address,uint256)", *MINT[name])
    if name in MOCKS:
        method, value = MOCKS[name]
        return INBOX, call(method, value)
    if name in RESTORES:
        return 0, b""
    if name in ("topup_public", "topup_a"):
        return REGISTRY, call("topUp(uint256,uint256)", 0, 1 if name == "topup_public" else 5)
    if name.startswith("confirm"):
        return REGISTRY, call("confirmExit(uint256)", 0)
    if name.startswith("withdraw"):
        return REGISTRY, call("withdraw(uint256,address)", 0, PAYEE if name == "withdraw_public" else A)
    require(name == "setup", "unknown offer")
    return REGISTRY, call("init(address)", ADMIN)


def event(emitter, name, indexed=(), values=()):
    return emitter, (uint(signature(name)), *indexed), pack(*values)


def admission(w, slot, value):
    """Update the compact raw minimum index, including its unwritten-zero sentinel."""
    node = 4096 + slot
    key = value * 4096 + slot
    level = 0
    while node:
        position = 37 if node == 4097 else 24 + level
        if (w[position] or (node << level) - 4096) == key:
            break
        w[position] = key
        if node == 1:
            break
        sibling = node ^ 1
        stored = w[37 if sibling == 4097 else 24] if sibling in (4096, 4097) else 0
        key = min(key, stored or (sibling << level) - 4096)
        node >>= 1
        level += 1


def commit_entry(w, slot, entry, height):
    w[13+slot*3:16+slot*3] = entry
    x, eff, packed = entry
    leaf = keccak256(tag("ETNA_REG_ENTRY_V1") + pack(slot, packed & 255, x, eff,
                                                    (packed >> 8) & NO_EXIT, packed >> 56))
    w[19+slot] = uint(leaf)
    if w[1] == 2:
        w[21] = uint(keccak256(pack(w[19], w[20])))
    w[3] = w[19] if w[1] == 1 else w[21]
    if not w[0] or w[5 + 2*(w[0]-1)] & NO_EXIT != height:
        w[0] += 1
    index = w[0] - 1
    w[5+2*index:7+2*index] = (height | w[1] << 48, w[3])
    return event(REGISTRY, "CheckpointWritten(uint256,uint48,uint48,bytes32)", (index,),
                 (height, w[1], w[3]))


def advance(name, before, public):
    """Compute every selected post-word and the exact log sequence from the declared offer."""
    w = list(before)
    logs = []
    height = clock(name)[0]
    if name == "setup":
        logs = [
            event(IMPLEMENTATION, "Initialized(uint8)", values=(255,)),
            event(PROXY_TEMPLATE, "Upgraded(address)", (IMPLEMENTATION,)),
            event(REGISTRY, "OwnershipTransferred(address,address)", (0, ADMIN)),
            event(REGISTRY, "Initialized(uint8)", values=(1,)),
        ]
    elif name in MINT:
        whom, amount = MINT[name]
        w[68 + 2 * ADDRESSES.index(whom)] += amount
    elif name in APPROVE:
        whom, amount = APPROVE[name]
        w[69 + 2 * ADDRESSES.index(whom)] = amount
    elif name in MOCKS:
        w[4] = 1 if name == "mock_generation" else 1 | MOCKS[name][1] << 48
    elif name in REGISTRATIONS and name not in ERRORS:
        row, bond = REGISTRATIONS[name]
        key = public["keys"][row//2]
        slot = 1 if bond == 1 else 0
        x, prefix = int(key["ck_x"], 16), int(key["ck_prefix"])
        packed = prefix | (height + 2) << 8 | NO_EXIT << 56
        base = 38 + 10*bond
        w[1] = max(w[1], slot + 1)
        w[2] += 1
        w[22+slot] = bond + 1
        w[base:base+5] = (x, 4, packed, slot | (1 << 16), actor(name))
        w[base+8] = bond + 1
        admission(w, slot, 4)
        logs.append(commit_entry(w, slot, (x, 4, packed), height))
    elif name == "topup_a":
        w[44:46] = (5, 14)
        admission(w, 0, 9)
    elif name == "forfeit":
        w[39] = 0
        w[40] = (w[40] & ((1 << 56) - 1)) | height << 56
        w[44], w[47] = 4, 1
        admission(w, 0, 4)
        logs.append(commit_entry(w, 0, w[38:41], height))
    elif name == "confirm":
        w[43] = height
        logs.append(event(REGISTRY, "ExitConfirmed(uint256,uint256)", (0,), (height,)))
    elif name == "withdraw_a":
        w[22], w[41] = 0, 1 << 24
        w[42:46] = (0, 0, 0, 0)
        admission(w, 0, 0)
        logs.append(commit_entry(w, 0, (0, 0, 0), height))
    if name in TRANSFERS:
        sender, recipient, amount = TRANSFERS[name]
        src = 68 + 2*ADDRESSES.index(sender)
        dst = 68 + 2*ADDRESSES.index(recipient)
        w[src] -= amount
        w[dst] += amount
        if sender != REGISTRY:
            w[src+1] -= amount
        w[94] += 1
        logs.append(event(TOKEN, "Transfer(address,address,uint256)", (sender, recipient), (amount,)))
        if name in REGISTRATIONS:
            logs.append(event(REGISTRY, "Registered(uint256,address,address,uint8,bytes32,uint256,uint48)",
                              (bond, actor(name), int(key["ck_addr"], 16)), (prefix, x, 4, height+2)))
        elif name == "topup_a":
            logs.append(event(REGISTRY, "TopUpDeposited(uint256,uint256,uint48)", (0,), (5, 14)))
        elif name == "forfeit":
            key = int(public["keys"][0]["entry_key"], 16)
            logs.append(event(REGISTRY, "Forfeited(uint256,bytes32,bytes32,uint256,uint256)",
                              (0, key), (INCIDENT, 9, 5)))
        else:
            logs.append(event(REGISTRY, "StakeWithdrawn(uint256,address,uint256)", (0, A), (4,)))
    return tuple(w), logs


@lru_cache(maxsize=20)
def wide_prefix(installed, inbox, lengths, checkpoints, entries, index, tree):
    # The inherited _stateDigest() order includes all raw admission cells, even unused zeros.
    h = bytes(32)
    legacy = {0: 1, 51: ADMIN, 201: 1 << 8} if installed else {}
    for i in range(251):
        h = keccak256(h + word(legacy.get(i, 0)))
    h = keccak256(h + pack(IMPLEMENTATION if installed else 0, inbox))
    nonzero = {4096 >> i: value for i, value in enumerate(index[:13])}
    nonzero[4097] = index[13]
    for value in (*lengths[:2], 0, 0, 0, 0, 0, lengths[2], *checkpoints, *([0] * 8),
                  *entries, *([0] * 12)):
        h = keccak256(h + word(value))
    for i in range(8192):
        h = keccak256(h + word(nonzero.get(i, 0)))
    for level in range(13):
        for i in range(max(8 >> level, 1)):
            value = tree[i] if level == 0 and i < 2 else tree[2] if level == 1 and i == 0 else 0
            h = keccak256(h + word(value))
    return h


@lru_cache(maxsize=24)
def wide(w, installed):
    h = wide_prefix(installed, w[4], w[:3], w[5:13], w[13:19], w[24:38], w[19:22])
    for i in range(6):
        block = w[38+i*10:48+i*10] if i < 3 else (0,)*10
        for value in block[:4]:
            h = keccak256(h + word(value))
        slot = w[22+i] if i < 2 else 0
        h = keccak256(h + pack(slot, *block[4:]))
    for account in (A, B, PUBLIC, SINK, PAYEE, REGISTRY, ADMIN):
        index = 68 + 2*ADDRESSES.index(account)
        h = keccak256(h + pack(*w[index:index+2]))
    return uint(keccak256(h + word(w[94])))


@lru_cache(maxsize=256)
def location(*keys):
    return uint(keccak256(pack(*keys)))


def storage_view(w, public, installed):
    r = ROOT_SLOT
    result = {}
    def slots(account, start, values):
        result.update({(account, start+i): v for i, v in enumerate(values)})
    if installed:
        for slot, value in ((ERC1967, IMPLEMENTATION), (0, 1), (51, ADMIN), (201, 1 << 8)):
            slots(REGISTRY, slot, (value,))
    slots(INBOX, 0, (w[4],))
    slots(REGISTRY, 101, (0,))
    for i in range(1, 13):
        slots(REGISTRY, location((4096 >> i) ^ 1, r+3), (0,))
    slots(REGISTRY, r, w[:2])
    slots(REGISTRY, r+7, (w[2],))
    slots(REGISTRY, location(r), w[5:13])
    slots(REGISTRY, location(r+1), w[13:19])
    for offset, keys, values in ((2, (0, 1, 1 << 32), w[19:22]), (5, (0, 1), w[22:24]),
                                 (3, (*(4096 >> i for i in range(13)), 4097), w[24:38])):
        for key, value in zip(keys, values, strict=True):
            slots(REGISTRY, location(key, r+offset), (value,))
    for i in range(3):
        part = w[38+10*i:48+10*i]
        key = public["keys"][i]
        slots(REGISTRY, location(i, r+6), part[:4])
        slots(REGISTRY, location(i, OWNERS), part[4:5])
        slots(REGISTRY, location(i, CONFIRM), part[5:6])
        slots(REGISTRY, location(i, TOP), part[6:8])
        slots(REGISTRY, location(int(key["ck_addr"], 16), r+4), part[8:9])
        slots(REGISTRY, location(int(key["entry_key"], 16), FORFEIT), part[9:10])
    for i, account in enumerate(ADDRESSES):
        slots(TOKEN, location(account, 0), w[68+2*i:69+2*i])
        slots(TOKEN, location(REGISTRY, location(account, 1)), w[69+2*i:70+2*i])
    slots(TOKEN, 2, w[94:95])
    return result


def deployment(frame, pins):
    identities = {TOKEN: "token", INBOX_TEMPLATE: "inbox", IMPLEMENTATION: "implementation",
                  PROXY_TEMPLATE: "proxy"}
    require(frame.account in identities, "unmodeled CREATE")
    ctor = b""
    if frame.account == IMPLEMENTATION:
        ctor = pack(TOKEN, 4, 2, 2, 2, 2500, SINK, 167001, INBOX, 5000)
    elif frame.account == PROXY_TEMPLATE:
        ctor = pack(IMPLEMENTATION, 64, 0)
    require(frame.data.endswith(ctor), "constructor configuration")
    init = frame.data[:len(frame.data)-len(ctor)]
    runtime = bytearray(frame.code)
    if frame.account == IMPLEMENTATION:
        # solc immutableReferences for the pinned Registry artifact, in declaration order.
        fields = [
            (0, (896,)), (IMPLEMENTATION, (4693, 4757, 5360, 5424, 5543)),
            (TOKEN, (2710, 3498, 7071, 8373, 10542, 10637, 11687)),
            (4, (1347, 6514)), (2, (1398, 6869, 8253)), (2, (1145, 6054)),
            (2, (2176, 3010)), (2500, (1265, 10482)), (SINK, (2322, 10586, 11721)),
            (5000, (2761, 11362)), (167001, (2247, 10053)),
            (INBOX, (2659, 4999, 8522, 8766, 9207, 9570, 10100, 10867, 12131)),
        ]
        for value, offsets in fields:
            for offset in offsets:
                require(runtime[offset:offset+32] == word(value), "deployed immutable configuration")
                runtime[offset:offset+32] = bytes(32)
    require([digest(init), digest(runtime)] == pins["bytecode"][identities[frame.account]],
            "pinned compiled deployment code")


def app_calls(step, public):
    """Model the recorder's ordered calls, code probes and resumed storage contexts."""
    name = step.name
    cheatcode = uint(signature("hevm cheat code")[-20:])
    probe = (8, cheatcode, DRIVER, b"")
    resume = (6, IMPLEMENTATION, step.actor, b"")
    if name in RESTORES or name == "authorize":
        return []
    if name == "setup":
        # Solidity probes code before high-level void calls and copies both template runtimes.
        calls = [
            probe, probe, probe,  # chainId, roll, warp
            (4, TOKEN, DRIVER, None), (4, INBOX_TEMPLATE, DRIVER, None),
            (8, INBOX_TEMPLATE, DRIVER, b""), (10, INBOX_TEMPLATE, DRIVER, b""), probe,
            (8, INBOX, DRIVER, b""), (0, INBOX, DRIVER, call("setGeneration(uint48)", 0)),
            (4, IMPLEMENTATION, DRIVER, None), (8, INBOX, IMPLEMENTATION, b""),
            (4, PROXY_TEMPLATE, DRIVER, None), (8, IMPLEMENTATION, PROXY_TEMPLATE, b""),
            (6, PROXY_TEMPLATE, DRIVER, b""), (8, PROXY_TEMPLATE, DRIVER, b""),
            (10, PROXY_TEMPLATE, DRIVER, b""), probe, probe,  # etch, store
            (8, REGISTRY, DRIVER, b""), (0, REGISTRY, DRIVER, step.input),
            (1, IMPLEMENTATION, DRIVER, step.input),
        ]
        for method in ("owner", "inbox", "l2ChainId", "token", "minStake", "activationDelay",
                       "exitDelay", "withdrawalDelay", "slashBountyBps", "slashSink", "forfeitBps"):
            data = call(method + "()")
            calls.extend(((3, REGISTRY, DRIVER, data), (1, IMPLEMENTATION, DRIVER, data)))
        for method in ("isInitialized", "inNonReentrant", "recoveryGeneration"):
            calls.append((3, INBOX, DRIVER, call(method + "()")))
        return calls
    calls = [probe, (0, step.target, step.actor, step.input)]  # prank then the actual offer
    if step.target != REGISTRY:
        return calls
    calls.extend(((1, IMPLEMENTATION, step.actor, step.input),
                  (3, INBOX, REGISTRY, call("inNonReentrant()"))))
    if name in REGISTRATIONS:
        row = public["register_digests"][REGISTRATIONS[name][0]]
        x = int(row["key"][4:], 16)
        calls.append((3, 5, REGISTRY, pack(32, 32, 32, (pow(x, 3, P) + 7) % P, (P+1)//4, P)))
        sig = bytes.fromhex(row["pop_sig"][2:])
        calls.append((3, 1, REGISTRY, pack(int(row["digest"], 16), sig[64]+27) + sig[:64]))
    if name in ("forfeit", "forfeit_late", "confirm_uncovered", "confirm"):
        calls.append((3, INBOX, REGISTRY, call("isInitialized()")))
    if name != "forfeit_late":
        calls.append(resume)
    if name in ("confirm_uncovered", "confirm"):
        calls.append((3, INBOX, REGISTRY, call("activeCommitteeSnapshot()")))
        if name == "confirm":
            calls.append(resume)
    if name in TRANSFERS:
        frm, to, amount = TRANSFERS[name]
        data = (call("transfer(address,uint256)", to, amount) if frm == REGISTRY
                else call("transferFrom(address,address,uint256)", frm, to, amount))
        calls.append((0, TOKEN, REGISTRY, data))
    return calls


def token_writes(step):
    """The mock token writes allowance, debit, credit, counter in Solidity source order."""
    name = step.name
    if name in MINT:
        return [location(MINT[name][0], 0)]
    if name in APPROVE:
        return [location(REGISTRY, location(APPROVE[name][0], 1))]
    if name in TRANSFERS:
        sender, recipient, _ = TRANSFERS[name]
        prefix = [] if sender == REGISTRY else [location(REGISTRY, location(sender, 1))]
        return [*prefix, location(sender, 0), location(recipient, 0), 2]
    return []


def expected_stores(step, before, after):
    """All per-slot assignments, including packed intermediate values and no-op SSTOREs."""
    result = {key: [value] for key, value in after.items() if before.get(key, 0) != value}
    if step.name == "setup":
        result[REGISTRY, 0] = [1, 0x101, 1]  # initializer state transitions
        result[REGISTRY, 101] = [0]  # Ownable2Step clears pendingOwner
        result[INBOX, 0] = [0]
    elif step.name in ("forfeit", "withdraw_a"):
        bond = location(0, ROOT_SLOT+6)
        slot = location(ROOT_SLOT+1)
        # _save copies the X word even when the key is retained. Withdrawal stores zero
        # effective stake in the historical bond and in the now-empty physical entry.
        offset = 0 if step.name == "forfeit" else 1
        for base in (bond, slot):
            key = REGISTRY, base + offset
            result[key] = [after[key]]
        if step.name == "withdraw_a":
            result[REGISTRY, bond+3] = [before[REGISTRY, bond+3] | 1 << 24, after[REGISTRY, bond+3]]
    return result


def audit_storage(step, public):
    """Reconcile ordered SSTOREs with the independently calculated balances and storage."""
    setup = step.name == "setup"
    before = storage_view(step.before, public, not setup)
    after = storage_view(step.after, public, True)
    if setup:
        after[IMPLEMENTATION, 0] = 255
        after[PROXY_TEMPLATE, ERC1967] = IMPLEMENTATION
        # vm.store, outside SSTORE instrumentation, seeds the proxy implementation before init.
        before[REGISTRY, ERC1967] = IMPLEMENTATION
    expected = expected_stores(step, before, after)
    state = before.copy()
    observed = {}
    for frame in step.frames:
        for account, slot, write, previous, new, reverted in frame.storage:
            key = account, slot
            require(account in (REGISTRY, INBOX, TOKEN, IMPLEMENTATION, PROXY_TEMPLATE, DRIVER),
                    "unmodeled storage account")
            require(reverted == frame.reverted, "storage revert context")
            if not write:
                require(key in after and previous == new == state.get(key, 0),
                        f"{step.name} storage read at {account:#x} slot {slot:#x}")
                continue
            require(step.ok and not reverted, "unexpected reverted write")
            require(key in after, "unmodeled storage write")
            require(state.get(key, 0) == previous, f"{step.name} storage previous value at {slot:#x}")
            require(key in expected, "write outside selected operation")
            observed.setdefault(key, []).append(new)
            state[key] = new
    require(observed == expected, step.name + " incomplete or unexpected storage assignments")
    require(all(state.get(k, 0) == v for k, v in after.items()), step.name + " missing storage write")


def storage_operations(step, frame):
    """Exact token instructions, proxy slot loads, public getters and pure-call frames."""
    entries = [(slot, write) for _, slot, write, _, _, _ in frame.storage]
    if frame.account == TOKEN and frame.kind == 0:
        stores = token_writes(step)
        if step.name in MINT:
            expected = [(stores[0], 0), (stores[0], 1)]
        elif step.name in APPROVE:
            expected = [(stores[0], 1)]
        else:
            expected = []
            for key in stores:
                # transferFrom checks and decrements allowance; _move checks and debits its sender.
                if key in stores[:-2]:
                    expected.append((key, 0))
                expected.extend(((key, 0), (key, 1)))
        require(entries == expected, step.name + " token storage instruction order")
    elif frame.account == REGISTRY and frame.kind in (0, 3):
        require(entries == [(ERC1967, 0)], step.name + " proxy implementation load")
    elif frame.account == INBOX and frame.kind in (0, 3):
        if frame.kind == 0:
            expected = [(0, 0), (0, 1)]
        else:
            getters = (call("recoveryGeneration()"), call("activeCommitteeSnapshot()"))
            expected = [(0, 0)] if frame.data in getters else []
        require(entries == expected, step.name + " Inbox storage access")
    elif frame.kind in (8, 10) or frame.account in (1, 5):
        require(not entries, step.name + " code read or precompile storage")
    elif frame.kind == 1 and step.name != "setup":
        expected = [(51, 0)] if step.name in ("forfeit", "forfeit_late") else []
        require(entries == expected, step.name + " delegated access before checking Inbox")
    elif frame.kind == 1 and step.name == "setup" and frame.data != call("init(address)", ADMIN):
        expected = [(51, 0)] if frame.data == call("owner()") else []
        require(entries == expected, "setup immutable getter storage")


def audit_frames(step, public, pins):
    expected = app_calls(step, public)
    require(len(expected) == len(step.frames), step.name + " frame count")
    layout = pins["storageGeometry"][step.name]
    require(len(layout) == len(expected), step.name + " storage geometry frame count")
    for index, (frame, binding) in enumerate(zip(step.frames, expected, strict=True)):
        kind, account, accessor, calldata = binding
        require((frame.kind, frame.account, frame.accessor) == (kind, account, accessor),
                step.name + " frame kind, account or caller")
        # The recorder represents an inherited DELEGATECALL/Resume caller as the original actor.
        depth = 1
        if ((account == IMPLEMENTATION and kind in (1, 6)) or accessor in (IMPLEMENTATION, PROXY_TEMPLATE)):
            depth = 2
        elif accessor == REGISTRY:
            depth = 3
        require(frame.depth == depth and frame.initialized == int(account not in (1, 5))
                and frame.old_balance == frame.new_balance == 0, step.name + " frame depth/account status")
        require(frame.reverted == int(not step.ok and kind != 8), step.name + " reverted frame")
        if kind == 4:
            deployment(frame, pins)
        else:
            require(not frame.code and frame.data == calldata, step.name + " frame data")
        accesses = tuple((row[1], row[2]) for row in frame.storage)
        require(accesses == layout[index], f"{step.name} frame {index} storage access order")
        storage_operations(step, frame)
        if frame.storage:
            # Delegate execution and its Resume rows operate in proxy storage.
            owner = REGISTRY if account == IMPLEMENTATION and kind in (1, 6) else account
            require(kind in (0, 1, 3, 4, 6) and all(row[0] == owner for row in frame.storage),
                    step.name + " storage frame owner")
    audit_storage(step, public)


PINS_HASH = "f1db7eda8a1da801a30f8f5ba8d88291027412c3460b000da41c924ad2af4b7a"


def storage_geometry(pins):
    """Decode only the reviewed compiler/recorder's ordered slot and access-mode projection."""
    layout = pins["storageGeometry"]
    require(type(layout) is dict and layout.keys() == {"schema", "provenance", "steps"}
            and layout["schema"] == "etna-registry-storage-access-1", "storage geometry schema")
    sources = pins["sourceFiles"]
    protocol = "source/packages/protocol/"
    expected_origin = {
        "nativeCommit": NATIVE_COMMIT,
        "fixtureSha256": sources[protocol+"test/layer1/etna/conformance/EtnaRegistryFundingReplay.t.sol"],
        "registrySha256": sources[protocol+"contracts/layer1/etna/impl/EtnaStakingRegistry.sol"],
        "forgeSha256": sources["tools/forge"], "solcSha256": sources["tools/solc-0.8.30"],
        "journalSha256": "84ea1c07429076233a9997c1d7dd08049634058941f17abf76b5185975e2df29",
        "forgeJsonSha256": "c6cec81a7dddd9c0de8d47d5a9b319aa9225b514e94c83ea690c037fd0106b6d",
    }
    require(layout["provenance"] == expected_origin, "storage geometry origin")
    steps = layout["steps"]
    require(type(steps) is list and len(steps) == len(ORDER), "storage geometry step count")
    result = {}
    frames_seen = rows_seen = 0
    for name, step in zip(ORDER, steps, strict=True):
        require(type(step) is dict and step.keys() == {"name", "frames"} and step["name"] == name,
                "storage geometry step identity")
        frames = step["frames"]
        require(type(frames) is list and len(frames) <= 152-frames_seen, "storage geometry frames")
        frames_seen += len(frames)
        frame_slots = []
        for rows in frames:
            require(type(rows) is list and len(rows) <= 502-rows_seen, "storage geometry rows")
            rows_seen += len(rows)
            slots = []
            for row in rows:
                require(type(row) is list and len(row) == 2 and type(row[0]) is str
                        and re.fullmatch(r"0x[0-9a-f]{64}", row[0]) and type(row[1]) is bool,
                        "storage geometry slot or access mode")
                slots.append((int(row[0], 16), int(row[1])))
            frame_slots.append(tuple(slots))
        result[name] = tuple(frame_slots)
    require((frames_seen, rows_seen) == (152, 502), "storage geometry inventory is incomplete")
    return result


def read_pins():
    raw = (HERE / "registry_funding/pins.json").read_bytes()
    require(digest(raw) == PINS_HASH, "Registry funding pins hash")
    pins = document(raw)
    fields = {"schema", "nativeCommit", "claim", "manifestSha256", "publicRows", "cwd", "forgeArgv",
              "environment", "sourceFiles", "bytecode", "storageGeometry"}
    require(type(pins) is dict and pins.keys() == fields and pins["schema"] == "etna-registry-funding-pins-1"
            and pins["nativeCommit"] == NATIVE_COMMIT and pins["claim"] == CLAIM, "funding pins schema")
    pins["storageGeometry"] = storage_geometry(pins)
    return pins


def _audit(receipt):
    require(type(receipt) is bytes and len(receipt) <= 2*1024*1024 and receipt.startswith(HEADER),
            "funding deployment header")
    public = public_inputs()
    pins = read_pins()
    current = (0,)*95
    pos = len(HEADER)
    all_logs = []
    allocated = 0
    for name in ORDER:
        require(pos + 32 <= len(receipt), "missing journal step " + name)
        length = uint(receipt[pos:pos+32])
        pos += 32
        require(length > 0 and length % 32 == 0 and pos + length <= len(receipt), "journal length")
        s = decode_step(receipt[pos:pos+length], name)
        pos += length
        kind = 3 if name == "setup" else 1 if name == "authorize" else 2 if name in RESTORES else 0
        require(s.kind == kind and (s.height, s.timestamp) == clock(name), name + " kind or clock")
        require((s.target, s.input) == offered(name, public), name + " offered call")
        require_attempt(name, s.actor, s.before[4] & NO_EXIT, s.timestamp, s.ok, s.output)
        require(s.before == current, name + " complete pre-state")
        current, logs = advance(name, current, public)
        require(s.logs == logs, name + " ordered event identity or data")
        if name == "forfeit":
            event_data = logs[-1][2]
            require_forfeiture((s.before[39], s.before[44], s.before[45], s.before[76]),
                               (s.after[39], s.after[44], s.after[45], s.after[76]),
                               (uint(event_data[32:64]), uint(event_data[64:])))
        require(s.after == current, name + " complete post-state")
        transfer_id = uint(signature("Transfer(address,address,uint256)"))
        routes = [(topics[1], topics[2], uint(data)) for addr, topics, data in s.logs
                  if addr == TOKEN and topics[0] == transfer_id]
        require_transfers(name, routes)
        if name in MINT:
            allocated += MINT[name][1]
        require(sum(s.after[68:94:2]) == allocated, name + " closed token allocation")
        require(s.after[74] == sum(s.after[i] + s.after[i+5] for i in (39, 49, 59)),
                name + " per-bond principal backing")
        if name in ERRORS or kind or name == "forfeit":
            require(s.before_digest == wide(s.before, name != "setup") and
                    s.after_digest == wide(s.after, True), name + " full storage digest")
        else:
            require(not (s.before_digest or s.after_digest), name + " unexpected digest")
        audit_frames(s, public, pins)
        all_logs.extend(s.logs)
    require(pos == len(receipt), "trailing funding journal data")
    return {"steps": len(ORDER), "allocations": 3, "totalAllocated": allocated,
            "transfers": current[94], "sink": current[76], "ownerPayout": 4,
            "finalRegistryBalance": current[74], "bondPrincipal": [
                current[i] + current[i+5] for i in (39, 49, 59)],
            "receiptSha256": digest(receipt)}, all_logs


def audit_journal(receipt: bytes) -> dict:
    """Check the full ABI journal against the one fixed funded-forfeiture lifecycle."""
    return _audit(receipt)[0]


def reviewed_source(workspace_root):
    return reviewed_boundary(workspace_root, CLAIM)


def current_receipt(workspace_root: Path, raw: bytes, *, execution: bytes, stderr: bytes):
    """Attribute a trusted same-run native capture after checking its complete local journal."""
    from run_registry_cases import require_forge_outcomes

    require(all(type(x) is bytes for x in (raw, execution, stderr)), "native capture bytes required")
    selected, pins = reviewed_source(workspace_root), read_pins()
    record = document(execution)
    expected = {"schema": "etna-registry-funding-execution-1", "claim": CLAIM,
                "nativeCommit": NATIVE_COMMIT, "forgeArgv": pins["forgeArgv"],
                "environment": pins["environment"], "sourceFiles": pins["sourceFiles"],
                "cwd": pins["cwd"], "returncode": 0, "timedOut": False,
                "stdoutSha256": digest(raw), "stderrSha256": digest(stderr)}
    require(type(record) is dict and record == expected and type(record["returncode"]) is int
            and record["timedOut"] is False, "funding capture provenance/status")
    require(not stderr, "unexpected native stderr")
    leaf = "test_funded_forfeiture_and_reuse()"
    suite = "test/layer1/etna/conformance/EtnaRegistryFundingReplay.t.sol:EtnaRegistryFundingReplayTest"

    decoded = document(raw)
    require(isinstance(decoded, dict) and set(decoded) == {suite}, "wrong funding Forge suite")
    body = decoded[suite]
    require(isinstance(body, dict) and set(body) == {"duration", "test_results", "warnings"}
            and isinstance(body["test_results"], dict) and set(body["test_results"]) == {leaf},
            "wrong funding Forge test inventory")
    row = body["test_results"][leaf]
    require(isinstance(row, dict)
            and all(row.get(field) == {} for field in ("labeled_addresses", "gas_snapshots", "breakpoints")),
            "unexpected native test metadata")

    def compare(receipt, logs):
        evidence, inner = _audit(receipt)
        native = [dict(address=f"0x{addr:040x}", topics=[f"0x{n:064x}" for n in topics],
                       data="0x"+data.hex()) for addr, topics, data in inner]
        require(logs == native, "outer/inner native event disagreement")
        return evidence

    outcome = require_forge_outcomes(raw.decode(), 0, suite, {leaf: compare})[leaf]
    return {"source": selected, "nativeCommit": NATIVE_COMMIT, "execution": "EVALUATED",
            "stdoutSha256": digest(raw), **outcome}
