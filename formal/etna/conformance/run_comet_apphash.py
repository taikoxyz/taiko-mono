"""Offline verifier for public Etna validator commitments and stock store rows."""
import argparse
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
PROGRAMS = HERE / "comet_handover" / "apphash" / "programs.json"
PROJECTION = HERE / "comet_signed" / "public-votes.json"
PROGRAM_SHA = "f07652a9735be14eeac8b708d7e611bf1489cc5ce8bf9d224f73435c545975f9"
PROJECTION_SHA = "34932f8ddf991ae41eb1be94c873e99524f51cf96d427faed4a1bfc443dc960e"
MASK = (1 << 64) - 1
# Rotation offsets indexed by x + 5*y in Keccak-f[1600].
ROTATIONS = (0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39,
             41, 45, 15, 21, 8, 18, 2, 61, 56, 14)
ROUND_CONSTANTS = (
    0x1, 0x8082, 0x800000000000808A, 0x8000000080008000,
    0x808B, 0x80000001, 0x8000000080008081, 0x8000000000008009,
    0x8A, 0x88, 0x80008009, 0x8000000A, 0x8000808B, 0x800000000000008B,
    0x8000000000008089, 0x8000000000008003, 0x8000000000008002,
    0x8000000000000080, 0x800A, 0x800000008000000A, 0x8000000080008081,
    0x8000000000008080, 0x80000001, 0x8000000080008008,
)


def rotate(value, count):
    return ((value << count) | (value >> (64 - count))) & MASK


def keccak256(data):
    """Legacy Keccak-256 with a 136-byte rate and the original suffix."""
    padded = bytearray(data)
    padded.append(1)
    padded.extend(bytes(-len(padded) % 136))
    padded[-1] |= 0x80
    lanes = [0] * 25
    for offset in range(0, len(padded), 136):
        for i in range(17):
            begin = offset + 8 * i
            lanes[i] ^= int.from_bytes(padded[begin:begin + 8], "little")
        for rc in ROUND_CONSTANTS:
            columns = [lanes[x] ^ lanes[x+5] ^ lanes[x+10] ^ lanes[x+15] ^ lanes[x+20]
                       for x in range(5)]
            scrambled = [0] * 25
            for y in range(5):
                for x in range(5):
                    i = x + 5*y
                    delta = columns[(x-1) % 5] ^ rotate(columns[(x+1) % 5], 1)
                    new_y = (2*x + 3*y) % 5
                    scrambled[y + 5*new_y] = rotate(lanes[i] ^ delta, ROTATIONS[i])
            for y in range(5):
                row = scrambled[y*5:y*5+5]
                for x in range(5):
                    lanes[y*5+x] = row[x] ^ (~row[(x+1) % 5] & row[(x+2) % 5])
            lanes[0] ^= rc
    return b"".join(x.to_bytes(8, "little") for x in lanes[:4])


def integer(value, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError("integer outside its encoded range")
    return value


def hex_bytes(value, size):
    if type(value) is not str or len(value) != 2 * size or not re.fullmatch("[0-9a-f]+", value):
        raise ValueError("expected canonical lower-case hexadecimal")
    return bytes.fromhex(value)


def validated_set(view):
    if type(view) is not dict or set(view) not in (
            {"members", "proposer"}, {"members", "proposer", "merkle"}):
        raise ValueError("unexpected validator set fields")
    members = view["members"]
    if type(members) is not list or not members:
        raise ValueError("empty or invalid validator set")
    integer(view["proposer"], 0, len(members)-1)
    addresses, keys = set(), set()
    for m in members:
        if type(m) is not dict or set(m) != {"key", "address", "power", "priority"}:
            raise ValueError("unexpected validator member fields")
        key = hex_bytes(m["key"], 33)
        address = hex_bytes(m["address"], 20)
        if key[0] not in (2, 3) or key in keys or address in addresses:
            raise ValueError("invalid public membership")
        keys.add(key)
        addresses.add(address)
        integer(m["power"], 1, (1 << 63) - 1)
        integer(m["priority"], -(1 << 63), (1 << 63) - 1)
    return members


def word(n):
    return n.to_bytes(32, "big", signed=n < 0)


def array_tail(view):
    members = validated_set(view)
    chunks = [word(len(members))]
    for m in members:
        key = bytes.fromhex(m["key"])
        chunks.extend((word(key[0]), key[1:], word(m["power"]), word(m["priority"])))
    return b"".join(chunks)


def encode_commitment(height, el_hash, current, next_set):
    integer(height, 0, (1 << 64)-1)
    el = hex_bytes(el_hash, 32)
    current_bytes, next_bytes = array_tail(current), array_tail(next_set)
    head_size = 6 * 32
    val = b"".join((b"ETNA_VAL_STATE_V1".ljust(32, b"\0"), word(height),
                    word(head_size), word(current["proposer"]), word(head_size + len(current_bytes)),
                    word(next_set["proposer"]), current_bytes, next_bytes))
    val_hash = keccak256(val)
    app = b"ETNA_APP_HASH_V1".ljust(32, b"\0") + el + val_hash
    return {"height": height, "el": el_hash, "val_bytes": val.hex(), "val_hash": val_hash.hex(),
            "app_bytes": app.hex(), "app_hash": keccak256(app).hex()}


def varint(n):
    n &= MASK
    encoded = bytearray()
    while n >= 128:
        encoded.append((n & 127) | 128)
        n >>= 7
    encoded.append(n)
    return bytes(encoded)


def blob(field, value):
    return varint(field * 8 + 2) + varint(len(value)) + value


def number(field, value):
    return varint(field * 8) + varint(value) if value else b""


def public_key(member):
    return blob(5, bytes.fromhex(member["key"]))


def merkle(items):
    if not items:
        return hashlib.sha256(b"").digest()
    if len(items) == 1:
        return hashlib.sha256(b"\x00" + items[0]).digest()
    split = 1 << ((len(items)-1).bit_length()-1)
    return hashlib.sha256(b"\x01" + merkle(items[:split]) + merkle(items[split:])).digest()


def validator_merkle(view):
    items = [blob(1, public_key(m)) + number(2, m["power"]) for m in validated_set(view)]
    return merkle(items).hex()


def validator_info(stored, change_height):
    integer(change_height, 1, (1 << 63)-1)
    payload = b""
    if stored is not None:
        elements = [blob(1, bytes.fromhex(m["address"])) + blob(2, public_key(m)) +
                    number(3, m["power"]) + number(4, m["priority"]) for m in validated_set(stored)]
        encoded = b"".join(blob(1, item) for item in elements) + blob(2, elements[stored["proposer"]])
        payload = blob(1, encoded)
    return (payload + number(2, change_height)).hex()


def read_json(raw):
    def unique(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate receipt or fixture key: " + key)
            result[key] = value
        return result
    def invalid(token):
        raise ValueError("nonintegral receipt or fixture number: " + token)
    return json.loads(raw, object_pairs_hook=unique, parse_constant=invalid, parse_float=invalid)


def require_receipt(actual, expected, path="$"):
    if type(actual) is not type(expected):
        raise ValueError("receipt type mismatch at " + path)
    if isinstance(expected, dict):
        if actual.keys() != expected.keys():
            raise ValueError("receipt fields differ at " + path)
        for key, value in expected.items():
            require_receipt(actual[key], value, path + "." + key)
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            raise ValueError("receipt length mismatch at " + path)
        for index, value in enumerate(expected):
            require_receipt(actual[index], value, f"{path}[{index}]")
    elif actual != expected:
        raise ValueError("receipt value mismatch at " + path)


def read_pinned(path, digest):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError("fixture digest mismatch: " + path.name)
    return read_json(raw)


def public_inputs():
    fixture = read_pinned(PROJECTION, PROJECTION_SHA)
    spectators = {row["name"]: row for row in fixture["spectators"]}
    points = {"A": (fixture["voteKey"]["public_key"][2:], fixture["voteKey"]["signer"][2:])}
    for name, original in (("B", "a2"), ("C", "a3"), ("H", "a4")):
        point = spectators[original]
        points[name] = point["public_key"][2:], point["ck_addr"][2:]
    cases = read_pinned(PROGRAMS, PROGRAM_SHA)["cases"]
    return fixture, points, cases


def normalize(values):
    total = sum(power for power, _ in values.values())
    priorities = [q for _, q in values.values()]
    window = 2 * total
    divisor = max(1, (max(priorities)-min(priorities)+window-1) // window)
    scaled = {k: ((-1 if q < 0 else 1) * (abs(q) // divisor)) for k, (_, q) in values.items()}
    mean = sum(scaled.values()) // len(scaled)
    return {k: (p, scaled[k]-mean) for k, (p, _) in values.items()}


def apply_updates(values, updates):
    if not updates:
        return values
    before_removal = sum(p for p, _ in values.values())
    for name, power in updates.items():
        if power:
            before_removal += power - values.get(name, (0, 0))[0]
    newcomer = -(before_removal + before_removal // 8)
    changed = dict(values)
    for name, power in updates.items():
        if power:
            changed[name] = (power, values.get(name, (0, newcomer))[1])
        else:
            del changed[name]
    return normalize(changed)


def elect(values, points, count=1):
    """One stock IncrementProposerPriority call on the bounded fixture inputs."""
    integer(count, 1, 16)
    result = normalize(values)
    total = sum(p for p, _ in result.values())
    for _ in range(count):
        result = {name: (p, q+p) for name, (p, q) in result.items()}
        winner = min(result, key=lambda name: (-result[name][1], points[name][1]))
        p, q = result[winner]
        result[winner] = (p, q-total)
    return result, winner


def set_view(elected, points):
    values, proposer = elected
    ordered = sorted(values, key=lambda name: (-values[name][0], points[name][1]))
    members = [{"key": points[k][0], "address": points[k][1], "power": values[k][0],
                "priority": values[k][1]} for k in ordered]
    view = {"members": members, "proposer": ordered.index(proposer)}
    view["merkle"] = validator_merkle(view)
    return view


def expected_states(program, points):
    initial = program["initial_height"]
    current = elect({name: (power, 0) for name, power in program["genesis"].items()}, points)
    next_set = elect(current[0], points)
    sets = {initial: current, initial+1: next_set}
    changes = {initial: initial, initial+1: initial}
    for height in range(initial, program["last_height"]+1):
        updates = program["updates"].get(str(height), {})
        next_set = elect(apply_updates(next_set[0], updates), points)
        sets[height+2] = next_set
        changes[height+2] = height+2 if updates else changes[height+1]
    return sets, changes


def expected_row(height, sets, changes, points):
    change = changes[height]
    full = set_view(sets[height], points) if change == height else None
    stored = sets[change]
    loaded = stored if full else elect(stored[0], points, height-change)
    return {"height": height, "change": change, "raw": validator_info(full, change),
            "stored": full, "loaded": set_view(loaded, points)}


def fixture_commitment(program, points, sets, height):
    el = hashlib.sha256(f"etna-apphash fixture {program['generation']}:{height}".encode()).hexdigest()
    return encode_commitment(height, el, set_view(sets[height+1], points), set_view(sets[height+2], points))


def verify_projection(receipt):
    """Verify the closed, passive public validator-state projection."""
    _, points, programs = public_inputs()
    if type(receipt) is not dict:
        raise ValueError("receipt must be an object")
    name = receipt.get("program")
    if type(name) is not str or name not in programs:
        raise ValueError("receipt program is unknown")
    program = programs[name]
    sets, changes = expected_states(program, points)
    initial, end = program["initial_height"], program["last_height"]
    observations = []
    for height in range(initial-1, end+1):
        observations.append({"height": height, "current": set_view(sets[height+1], points),
                             "next": set_view(sets[height+2], points),
                             "commitment": fixture_commitment(program, points, sets, height)})
    expected = {"schema": "etna-apphash-projection-1", "program": name,
                "program_sha256": PROGRAM_SHA, "projection_sha256": PROJECTION_SHA,
                "observations": observations,
                "rows": [expected_row(h, sets, changes, points) for h in range(initial, end+3)]}
    require_receipt(receipt, expected)

def validator_proto(view):
    if view is None:
        return b""
    elements = [blob(1, bytes.fromhex(m["address"])) + blob(2, public_key(m)) +
                number(3, m["power"]) + number(4, m["priority"]) for m in view["members"]]
    return b"".join(blob(1, m) for m in elements) + blob(2, elements[view["proposer"]])


# Stock defaults of the pinned source, with explicit synthetic Info AppVersion=1.
# These are component fixtures, not the Etna generator's complete parameter set.
VERSION = number(1, 11) + number(2, 1)
BLOCK_PARAMS = number(1, 55600190) + number(2, -1)
PARAMS = (blob(1, BLOCK_PARAMS) + blob(2, number(1, 100000) + blob(2, number(1, 172800)) + number(3, 1048576)) +
          blob(3, blob(1, b"secp256k1eth")) + blob(4, number(1, 1)) + blob(5, b"") + blob(6, b""))
EMPTY_ID = blob(2, b"")
TX = b"public-apphash-fixture"


def frame_program(name):
    import copy
    fixture, points, programs = public_inputs()
    program = programs[name]
    sets, changes = expected_states(program, points)
    initial, end = program["initial_height"], program["last_height"]
    chain = next(d["chain_id"] for d in fixture["chainDomains"]
                 if d["generation"] == program["generation"] and d["inbox"] == fixture["deployment"]["inbox"])
    views = {h: set_view(v, points) for h, v in sets.items()}
    commitment = {h: fixture_commitment(program, points, sets, h) for h in range(initial-1, end+1)}
    frames, states, headers = {}, {}, {}

    def state_bytes(h, markers=None):
        genesis = h == initial-1
        result_hash = b"" if genesis else merkle([b""])
        changed, params_changed = markers or (changes[h+2], initial)
        return (blob(1, blob(1, VERSION) + blob(2, b"0.39.0")) + blob(2, chain.encode()) +
                number(3, 0 if genesis else h) + blob(4, EMPTY_ID if genesis else frames[h][1]) +
                blob(5, number(1, 1700000000+initial+max(0, h-initial))) +
                blob(6, validator_proto(views[h+2])) + blob(7, validator_proto(views[h+1])) +
                (b"" if genesis else blob(8, validator_proto(views[h]))) + number(9, changed) +
                blob(10, PARAMS) + number(11, params_changed) + (blob(12, result_hash) if result_hash else b"") +
                blob(13, bytes.fromhex(commitment[h]["app_hash"])) + number(14, initial))

    def header_bytes(h, app=None):
        first = h == initial
        c = commitment[h-1]
        app = bytes.fromhex(c["app_hash"]) if app is None else app
        # Non-nullable protobuf messages are emitted even when empty.
        fields = [VERSION, chain.encode(), h, number(1, 1700000000+initial+h-initial),
                  EMPTY_ID if first else frames[h-1][1],
                  merkle([]) if first else b"", merkle([hashlib.sha256(TX).digest()]) if first else b"",
                  bytes.fromhex(views[h]["merkle"]), bytes.fromhex(views[h+1]["merkle"]),
                  hashlib.sha256(BLOCK_PARAMS).digest(), app, b"" if first else merkle([b""]),
                  merkle([]) if first else b"", bytes.fromhex(views[h]["members"][views[h]["proposer"]]["address"])]
        payload = blob(1, fields[0])+blob(2, fields[1])+number(3,h)+blob(4,fields[3])+blob(5,fields[4])
        payload += b"".join(blob(i, fields[i-1]) for i in range(6,15) if fields[i-1])
        hash_inputs = [fields[0], blob(1,fields[1]), number(1,h), fields[3], fields[4]]
        hash_inputs += [blob(1,v) if v else b"" for v in fields[5:]]
        return payload, merkle(hash_inputs)

    def block_bytes(header):
        return blob(1,header)+blob(2,blob(1,TX))+blob(3,b"")+blob(4,blob(3,EMPTY_ID))

    for h in range(initial,end+1):
        header, hh = header_bytes(h)
        headers[h] = header
        part = merkle([block_bytes(header)]) if h == initial else hashlib.sha256(b"synthetic-state-input-part"+header).digest()
        bid = blob(1,hh)+blob(2,number(1,1)+blob(2,part))
        frames[h] = (header,bid)
        states[h] = state_bytes(h)
    states[initial-1] = state_bytes(initial-1)
    validation=[]
    for case in ("matching","current-priority","next-priority","current-proposer","next-proposer","height","el"):
        a,b=copy.deepcopy(views[initial]),copy.deepcopy(views[initial+1])
        h=initial-1
        if case=="current-priority": a["members"][0]["priority"]+=1
        elif case=="next-priority": b["members"][0]["priority"]+=1
        elif case=="current-proposer": a["proposer"]=(a["proposer"]+1)%len(a["members"])
        elif case=="next-proposer": b["proposer"]=(b["proposer"]+1)%len(b["members"])
        elif case=="height": h+=1
        el=hashlib.sha256(f"etna-apphash fixture {program['generation']}:{h}".encode()).digest()
        if case=="el": el=bytes([el[0]^1])+el[1:]
        c=encode_commitment(h,el.hex(),a,b)
        header,_=header_bytes(initial,bytes.fromhex(c["app_hash"]))
        error="" if case=="matching" else ("wrong Block.Header.AppHash.  Expected "+commitment[initial-1]["app_hash"].upper()+", got "+c["app_hash"].upper())
        validation.append(dict(name=case,commitment=c,header=header.hex(),block=block_bytes(header).hex(),error=error))
    checkpoint=None
    h=program["checkpoint"]
    if h:
        marks=(h+2,h+1)
        boot_changes=dict(changes)
        for n in range(h,h+3): boot_changes[n]=n
        for n in range(h+3,end+3): boot_changes[n]=h+2
        checkpoint=dict(pre_state=states[h-1].hex(),derived_state=states[h].hex(),running_state=states[h].hex(),
                        bootstrapped=state_bytes(h,marks).hex(),
                        continued=[dict(height=i,running=states[i].hex(),reopened=state_bytes(i,marks).hex(),
                                        input=[v.hex() for v in frames[i]],resumed_input=[v.hex() for v in frames[i]]) for i in range(h+1,end+1)],
                        final=state_bytes(end,marks).hex(),
                        boot_rows=[expected_row(i,sets,boot_changes,points) for i in range(h,h+3)],
                        final_rows=[expected_row(i,sets,boot_changes,points) for i in range(h+3,end+3)])
    return dict(schema="etna-stock-apphash-frames-1",program=name,program_sha256=PROGRAM_SHA,projection_sha256=PROJECTION_SHA,
                genesis=states[initial-1].hex(),trace=[dict(height=h,input=[v.hex() for v in frames[h]],state=states[h].hex()) for h in range(initial,end+1)],
                reopened=states[end].hex(),checkpoint=checkpoint,initial_validation=validation)


def verify_frames(receipt):
    if (type(receipt) is not dict or type(receipt.get("program")) is not str
            or receipt["program"] not in public_inputs()[2]):
        raise ValueError("receipt frame program is unknown")
    require_receipt(receipt,frame_program(receipt["program"]))


def verify_directory(directory):
    directory=Path(directory)
    names={name+suffix+".json" for name in public_inputs()[2] for suffix in ("","-frames")}
    if {p.name for p in directory.iterdir()}!=names or any(p.is_symlink() for p in directory.iterdir()):
        raise ValueError("missing/extra native receipts")
    raw = {n: (directory/n).read_bytes() for n in sorted(names)}
    for name in sorted(public_inputs()[2]):
        for suffix, verifier in (("", verify_projection), ("-frames", verify_frames)):
            receipt = read_json(raw[name+suffix+".json"])
            if type(receipt) is not dict or receipt.get("program") != name:
                raise ValueError("receipt filename and selected program differ")
            verifier(receipt)
    return {n:dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest()) for n,data in raw.items()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    if args.receipt.is_dir():
        print(json.dumps(verify_directory(args.receipt),sort_keys=True))
    else:
        receipt=read_json(args.receipt.read_bytes())
        if type(receipt) is not dict:
            raise ValueError("receipt must be an object")
        (verify_frames if receipt.get("schema")=="etna-stock-apphash-frames-1" else verify_projection)(receipt)
