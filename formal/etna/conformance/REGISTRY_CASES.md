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
adds a bounded cold compile and private artifacts. The runner accepts `double-sign`, `lifecycle` and `atomicity`.

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
The collector compares the complete native log sequence by emitter, ordered
topics and data. Each pair has nine setup events, then either four slash events
or zero refusal events. The targeted source fault requires the same nine setup
and four slash events with the expected diagnostic and no receipt. Summaries
retain the checkpoint, transfer and slash logs in `actionLogs`. Reverted subcalls
are observed with ordered account access frames and raw pre/post storage. Recorded logs are local Forge execution traces
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

## Late token refusal and identical calldata retry

Use the same offline Forge routing configuration. Add `--smoke` to run only
the register refusal, approval and same-block retry.

```sh
python -B formal/etna/conformance/run_registry_cases.py \
  --scenario atomicity --runtime "$forge_runtime" \
  --output "$case_output" --timeout 180
```

At block 11 and Inbox snapshot 7, the second public key has a valid
registration proof, balance 4 and allowance 3. Registry writes a checkpoint
before the token refuses `transferFrom` with `Error("token allowance")`. The
pre/post commitments are equal. The first bond and checkpoint survive,
and the second key, slot, ID and checkpoint are absent until retry. The
same caller approves 4 externally and resubmits the same bytes at block 11. The retry issues bond 1 in slot 1 and observes precisely
`CheckpointWritten`, `Transfer`, `Registered` in that order.

The second test begins with both bonds at block 10. At block 12 and
snapshot 9, the first bond's owner has allowance 4 and balance 0. The
nested token frame records a reverted allowance write from 4 to 0 before
`Error("token balance")` propagates through the Registry call. The allowance
returns to 4 and the full selected state equals the pre-call state.
The test driver mints 4 to the owner and leaves the allowance at 4. The same
caller retries the same top-up at block 12. The retry transfers 4 once and
raises the pending principal and admission value. The neighbor's state,
the target's effective stake, the entry tree and the block-10 checkpoint
stay unchanged through retry. At block 14 actual activation consumes the
pending amount, increases effective stake to 8 and writes checkpoint 1.
The original checkpoint remains readable.

The refusal receipt binds four reverted Registry writes before that token call.

| Registry slot         | Before | Attempted | Restored |
| --------------------- | -----: | --------: | -------: |
| Bond 0 pending amount |      0 |         4 |        0 |
| Bond 0 readiness      |      0 |        14 |        0 |
| Admission leaf 4096   |  16384 |     32768 |    16384 |
| Admission parent 2048 |  16384 |     16385 |    16384 |

The producer records every write to those four raw slot keys across the
action, including the storage account, old and attempted values, revert
flag and positions in the ordered account and storage access arrays. The
collector requires one write per slot in the Registry proxy's delegated
execution, each before the unique nested token call. It binds the observed
delegated and token call frames and the raw values read before and after
recording. The pinned recorder places all four writes in the delegated
context's resume segment after the Inbox call and before the token call. The frame positions
are specific to the pinned Forge fixture. Admission node 1024 retains key 2 from the empty slot, so the
four explicit writes stop at parent 2048. The existing full selected state
commitment still covers the upper nodes and the adjacent leaf.

Atomicity receipts carry schema `etna-registry-atomicity-2`. The top-up
refusal includes the ordered write witness in addition to the existing
action fields. Earlier N04 receipts are historical and fail the current
schema check.

Both leaves use the same ordered raw rollback observer. It covers inherited
Registry words 0–250 and its ERC1967 implementation pointer, the packed
Inbox generation/snapshot, the eight Registry namespace head words, 16 raw
checkpoint words, 18 raw entry words, all 8192 admission cells and the bounded
Merkle nodes covering the fixture's selected leaves and ancestors. It also
covers six selected bond records, slot occupants, owners, confirmations,
pending amounts and readiness, lifetime keys and forfeiture flags, plus seven
actors' token balances and allowances and the token transfer counter. The
journal binds the independently frozen full raw commitment before and after
each action. It also binds each action's VM height, snapshot, caller, target,
calldata, low-level return bytes, nested transfer target and calldata,
reverted flag and allowance-write count and values. The approval and mint
are separately observed token calls between the refusal and retry, at the
same height and snapshot. The pinned SafeERC20/Address path bubbles the
nonempty token error bytes to the Registry proxy. The account recorder
provides frame and storage-access data, while the proxy call supplies the
error bytes.

The register leaf performs a self-call calibration that emits a marker
before reverting. Forge's local log recorder retains that marker and the
failed register's attempted checkpoint. These are reverted execution trace
entries. Both the failed top-up and its nested token call emit zero trace
logs at the selected balance refusal. The exact action order is checked
against the frozen native trace, including the successful retry events.

The guarded source control removes only the actual `topUp` transfer. It
must reach the expected incorrect-success diagnostic and the attempted
deposit event without a corresponding token transfer. The register leaf
still passes in the fault phase. The runner restores the private source
bytes and mode and repeats both positives. The evidence covers the
selected rollback state and the exact-transfer fixture. Token callbacks,
withdrawal custody, gas and full-capacity admission are outside this gate.
