#!/usr/bin/env python3
"""Generate a Safe{Wallet} Transaction Builder batch that repoints the
`recipient()` of one or more `SimpleTokenUnlock` contracts.

`SimpleTokenUnlock.changeRecipient(address)` is guarded by `onlyRecipientOrOwner`,
so the batch must be executed by the Safe that owns the unlock contracts.

The emitted JSON is the format the Safe UI's Transaction Builder app imports
(drag & drop). The `meta.checksum` field is computed with the same algorithm the
Transaction Builder uses, so the UI accepts the file without a mismatch warning.
`pycryptodome` is required for the checksum; without it the file is still emitted
(the Safe UI tolerates a missing checksum) but unsigned.

Usage:
    python3 safe_batch_change_recipient.py \
        --safe 0xSafeThatOwnsTheUnlockContracts \
        --new-recipient 0xNewRecipient \
        --chain-id 1 \
        --out batch.json \
        0xUnlock1 0xUnlock2 ...
"""

import argparse
import json
import sys
import time

TX_BUILDER_VERSION = "1.18.0"

CHANGE_RECIPIENT_METHOD = {
    "inputs": [
        {
            "internalType": "address",
            "name": "_newRecipient",
            "type": "address",
        }
    ],
    "name": "changeRecipient",
    "payable": False,
}


def serialize_json_object(value):
    """Port of the Transaction Builder's `serializeJSONObject`.

    Key order and the trailing comma after every value are load-bearing: the
    Safe UI hashes this exact string, so any deviation changes the checksum.
    """
    if isinstance(value, list):
        return "[{}]".format(",".join(serialize_json_object(v) for v in value))
    if isinstance(value, dict):
        keys = sorted(value.keys())
        acc = "{" + json.dumps(keys, separators=(",", ":"))
        for key in keys:
            acc += "{},".format(serialize_json_object(value[key]))
        return acc + "}"
    return json.dumps(value, separators=(",", ":"))


def calculate_checksum(batch):
    """keccak256 of the serialized batch, with `meta.name` nulled out.

    Mirrors the UI, which computes the checksum before inserting it into `meta`.
    """
    try:
        from Crypto.Hash import keccak
    except ImportError:
        print(
            "warning: pycryptodome not installed, emitting batch without a checksum",
            file=sys.stderr,
        )
        return None

    stripped = dict(batch)
    stripped["meta"] = dict(batch["meta"], name=None)
    stripped["meta"].pop("checksum", None)

    digest = keccak.new(digest_bits=256)
    digest.update(serialize_json_object(stripped).encode())
    return "0x" + digest.hexdigest()


def build_batch(safe, new_recipient, unlock_contracts, chain_id, name, description):
    batch = {
        "version": "1.0",
        "chainId": str(chain_id),
        "createdAt": int(time.time() * 1000),
        "meta": {
            "name": name,
            "description": description,
            "txBuilderVersion": TX_BUILDER_VERSION,
            "createdFromSafeAddress": safe,
            "createdFromOwnerAddress": "",
        },
        "transactions": [
            {
                "to": contract,
                "value": "0",
                "data": None,
                "contractMethod": CHANGE_RECIPIENT_METHOD,
                "contractInputsValues": {"_newRecipient": new_recipient},
            }
            for contract in unlock_contracts
        ],
    }

    checksum = calculate_checksum(batch)
    if checksum is not None:
        batch["meta"]["checksum"] = checksum
    return batch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unlock_contracts", nargs="+", help="SimpleTokenUnlock addresses")
    parser.add_argument("--safe", required=True, help="Safe that owns the unlock contracts")
    parser.add_argument("--new-recipient", required=True, help="New recipient address")
    parser.add_argument("--chain-id", default=1, type=int, help="Chain id (default: 1)")
    parser.add_argument("--out", default="batch.json", help="Output path")
    parser.add_argument("--name", default="SimpleTokenUnlock: changeRecipient")
    parser.add_argument("--description", default=None)
    args = parser.parse_args()

    description = args.description or "Sets recipient() to {} on {} SimpleTokenUnlock contract(s) owned by Safe {}.".format(
        args.new_recipient, len(args.unlock_contracts), args.safe
    )

    batch = build_batch(
        args.safe,
        args.new_recipient,
        args.unlock_contracts,
        args.chain_id,
        args.name,
        description,
    )

    with open(args.out, "w") as handle:
        json.dump(batch, handle, indent=2)

    print("wrote {} ({} transactions)".format(args.out, len(batch["transactions"])))
    print("checksum: {}".format(batch["meta"].get("checksum", "<omitted>")))


if __name__ == "__main__":
    main()
