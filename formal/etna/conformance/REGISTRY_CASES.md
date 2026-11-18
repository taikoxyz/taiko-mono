# Etna public Registry cases

Use the reviewed offline Forge routing configuration for the pinned contracts,
tools, dependencies and physical cache lock. Reuse the original accepted normal
N01 run directory containing `combined.log` and `execution.json`.

```sh
python -B formal/etna/conformance/run_registry_cases.py \
  --scenario double-sign --runtime "$forge_runtime" --go-normal "$n01_normal" \
  --output "$case_output" --timeout 180
```

Add `--smoke` for the single actual `test_pair_precommit_conflict()` leaf. Choose a
fresh output directory for each run. The runner rebuilds isolated Forge argv
from fixed settings, with exact selectors, explicit reviewed mounts,
offline compiler selection, FFI disabled, and an empty script directory. It
holds the existing physical cache lock to serialize Forge execution. Each
campaign compiles into a fresh private output and cache and reuses them for its
three phases. The existing shared cache contents are outside the mounts. This
adds a bounded cold compile and private artifacts. The runner accepts `double-sign` and `lifecycle`.

The 42 individually selected tests are five domain cases, 23 canonical byte
cases and 14 actual evidence pairs. Published bytes/domain literals and
`registry_cases/pins.json` specify independent expectations. The raw N01
evidence supplies an additional comparison for all 23 common rows. Both
consumers use the same published fixture provenance.

Each pair starts with a fresh actual Registry and generation premise. Register
at block 10, top up at 12 and submit at 13 with effective 4, pending 4 and ready 14. Authorized evidence pays reporter 2 and sink 6 while preserving lifetime
bond/key/slot identity and the block-10 checkpoint. The event contains the vote
generation. The repeated call refuses `NothingToSlash` and preserves the post
state. The initial refusal partition is six `NotDoubleSign`, one
`FutureGeneration` and one `InvalidSignature`. Each exact refusal is repeated.
The normal and restored phases require all receipts. The guarded removal of
the same-BlockID requirement must reach the one diagnostic on
`same_block_later_time`, with actual checkpoint, payout and slash log traces.

The isolated runner retains exact commands, native Forge JSON, event receipts,
matching Go row counts, byte hashes and private source restoration. Its receipt
collector distinguishes complete values, full suite/leaf identities and exact
failure reasons and the pinned Forge test deployment emitter. Each pair receipt
binds its case name and both actual delegated call inputs to the ordered
signed tuples and bond 0 independently encoded from the named public rows.
The collector also checks ordered Registry/token action logs against their
expected emitters, including the token at the test driver's first CREATE. Reverted subcalls are observed with ordered account access
frames and raw pre/post storage. Recorded logs are local Forge execution traces
and can contain attempted events from a reverted path.

Handled exceptions and completed or cooperatively supervised phases enter
the private-source restoration path. Abrupt termination between supervised
subprocesses or during result collection can retain an unfinished private
snapshot. The canonical source stays outside the write scope, and the
unfinished run emits no PASS summary.

## Internal Solidity fixture

Later scenarios can import `EtnaRegistryCasesBase` and use the same execution
boundary without inheriting an older replay test.

| Helper or state                                                                                                                                      | Contract                                                                                                                                                                                                                                                                             |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `_setupRegistry(generation)`                                                                                                                         | Places initialized, unlocked Inbox code at `INBOX`, constructs the actual Registry and ERC1967 proxy, and calls `init`. Sets L1 1, L2 167001, min stake 4, delays 2, bounty 2500 bps and block 10.                                                                                   |
| `registry`, `token`, `inbox`, `implementation`                                                                                                       | Actual proxy, reused exact-transfer token, controllable Inbox and actual implementation address. Change height with `VM.roll`; use `inbox.setGeneration` or `inbox.setSnapshot` for explicit external premises.                                                                      |
| `_publicPoP(row)`                                                                                                                                    | Reads and checks a published `PublicPoP` with owner, signer, prefix, X, lifetime entry key, compressed key and registration proof. Rows are zero-based, grouped by point with two owners.                                                                                            |
| `_fund(owner, balance, allowance)`, `_register(pop, amount)`                                                                                         | Mints test token and sets allowance through the fixture token, then optionally uses the public PoP through the actual Registry ABI. No implicit funding or approvals in setup.                                                                                                       |
| `_callRegistry(actor, calldata)`                                                                                                                     | Low-level proxy call with exact return bytes, captured `Vm.Log[]` and ordered `Vm.AccountAccess[]`. Captures only the action.                                                                                                                                                        |
| `_registryFrame(result, actor, calldata)`, `_requireRefusal(result, errorBytes, beforeDigest, afterDigest, traceEvents)`                             | Checks the proxy and delegated implementation with the inherited actor, returning the proxy address and observed delegated calldata. The refusal helper checks exact error bytes, raw equality and supplied trace logs. Nested token failure needs an additional access-frame check. |
| `_stateDigest()`                                                                                                                                     | Reads all 8192 admission cells plus bounded namespace, bond, entry, checkpoint, tree, Inbox and token words. Covers six public keys, slots and bonds, eight checkpoints, and the named test actors. Extending those dimensions requires extending the observer.                      |
| `_raw(slot)`, `_mapSlot(base, key)`, `_rawMap(base, key)`                                                                                            | Read fixed storage layout independently of getters. Namespace bases `R`, `OWNERS`, `CONFIRM`, `TOP` and `FORFEIT` are available to child contracts.                                                                                                                                  |
| `_balance(actor)`, `_allowance(actor)`, `_transfers()`                                                                                               | Read raw token balances, Registry allowances and transfer counter.                                                                                                                                                                                                                   |
| `_leaf(slot, entry)`, `_requireEntry(base, entry)`, `_requireCheckpoint(index, block, count, root)`                                                  | Compute the spec entry leaf independently and compare caller-supplied literals to actual raw entry or checkpoint words. The checkpoint helper also checks the read-only ABI.                                                                                                         |
| `_event(emitter, topics, data)`, `_checkpointEvent(index, block, count, root)`, `_transferEvent(from, to, amount)`, `_requireEvents(logs, expected)` | Check exact order, emitter, topics and ABI payload.                                                                                                                                                                                                                                  |
| `RegistryCaseReceipt(bytes)`                                                                                                                         | The test emits typed evidence after all assertions. The Python collector decodes the native log.                                                                                                                                                                                     |

The Registry gate exercises signed evidence with published public inputs,
the pinned historical contracts and fixture prerequisites. It leaves real Inbox
recovery, production token behavior, deployment and full 4096-slot capacity open.
The source control is a separately attributed validation case.

## Ordinary exit, withdrawal and slot reuse

Run the same offline Forge configuration without a Go execution directory.

```sh
python -B formal/etna/conformance/run_registry_cases.py \
  --scenario lifecycle --runtime "$forge_runtime" \
  --output "$case_output" --timeout 180
```

The single actual test registers two distinct published keys at block 10.
It deposits a top-up at 12, requests exit at 13 with exit effective at 15,
and refuses activation at its exact readiness block 14. Snapshot 14 refuses
confirmation at 16. Snapshot 15 confirms at the same height. Withdrawal at 17
refuses and withdrawal at 18 pays effective 4 plus pending 4. The retired
key remains registered after withdrawal, including when its alternate owner
presents an otherwise valid published PoP.

A distinct key registers at 20 as bond 2 in vacant slot 0. Bond 1 remains in
slot 1. The entry count stays 2 and the historical block-18 checkpoint retains
the nonzero root over the hashed all-zero entry in slot 0 and the surviving
slot 1. The second cycle requests exit at 23, confirms at 26 with snapshot
25, and withdraws at 28 for 4. Deposits total 16, payouts 12 and vault principal 4. The query surface and pinned raw words distinguish IDs 0 and 2 from their
shared slot 0 and check both retired keys and the surviving bond.

The exact Forge suite and leaf emit a final journal of 16 ordered actions.
The receipt binds each actual EVM block height, Inbox snapshot, inherited
delegated caller, proxy, delegated calldata, raw return bytes, trace count
and pre/post raw state commitments. The state commitment covers six historical
checkpoint records, both entries, the Merkle nodes, both slot-to-bond
mappings, the affected admission path, all three selected bonds and lifetime
key mappings, principal/owner/confirmation/top-up fields and the token ledger.
On refusal the wider fixture digest additionally checks rollback across all
8192 admission cells and the bounded fixture storage. The collector compares
the entire typed journal and all native logs to the frozen independent oracle.

The private-source control removes the exit guard only from
`activateTopUp`. It must reach the exact activation error diagnostic and the
unexpected checkpoint and activation event, then restore source bytes and
mode and repeat the full positive. `--smoke` selects the same single positive
without mutation. The gate uses an initialized/unlocked Inbox fixture and
exact-transfer test token. Full 4096-slot capacity, deployment, production
token behavior and other lifecycle products remain open.
