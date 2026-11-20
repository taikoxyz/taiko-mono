# M03: signer and app crash recovery

Two focused models extend this project: [`EtnaSignerCrash.tla`](EtnaSignerCrash.tla)
and [`EtnaAppCrash.tla`](EtnaAppCrash.tla). They are not a Cartesian product or a
proof of transitive composition with the L1 trust model. Existing models, 63
configurations and the runner remain unchanged. No actual client implementation
or production crash test is performed.

## Sources and durability contract

Etna source is SPEC at `d18357214fab30ea512ae9858a11699806d72ba1`, especially
CONS-3.1-8/9, RECOV-8.2-1..6 and SYNC-9-10..14. CometBFT v0.40.0 resolves to
`0880b4d378f347ab16e54ec677ff50d803f37d62`:

- [`privval/file.go`](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/privval/file.go): CheckHRS, same-step reuse, saveSigned before signature return.
- [`state/execution.go`](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/state/execution.go): FinalizeBlock, saved response, Commit, saved Comet state.
- [`consensus/replay.go`](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/consensus/replay.go): Info/InitChain, replay height checks, real versus saved-response mock replay.
- [`libs/tempfile/tempfile.go`](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/libs/tempfile/tempfile.go): temporary-file synchronous write and rename; parent-directory fsync is not established.

A completed durable write is assumed to survive a **process crash**. Arbitrary
host power loss, directory-entry durability, filesystem rollback/corruption,
cloned signer storage, multiple key owners and adversarial access to private
signing memory are outside these models. In particular, they do not prove power
loss durability from the atomic-file helper.

## Signer model

One serialized state owner serves two generation-bound domains. Slots 1..2
abstract lexicographic height/round/step order; different payloads include nil
votes. Signature tokens may have one or two computation variants so exact reuse
is distinguished from fresh computation. Timestamp-only canonicalization and
non-consensus vote-extension signatures are abstracted.

| State/action                  | Boundary                                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `Request`                     | Captures caller domain/slot/payload independently, then computes a private pending signature or selects the exact stored retry |
| `Persist`                     | Writes per-domain HRS, message and signature as one durable record                                                             |
| `Expose`                      | Returns/enqueues the signature only after checking current app trust/domain and persistence                                    |
| `Deliver`                     | Network delivers an already exposed signature, potentially after later crashes or recovery                                     |
| `Crash`/`Restart`             | Drops volatile work/trust/connection, reloads operational generation knowledge from its durable floor                          |
| `AuthenticateTrust`/`Connect` | Fresh session trust precedes reconnection; current app reply is checked on requests and exposure                               |
| `MarkUncertain`               | Stops signing when latest signer state cannot be trusted; no automatic deletion/reset cure                                     |

`writes` records actual persisted values; `returned`, `network` and `delivered`
are independent external observations. Invariants compare requested versus
computed/exposed identities, require every exposed record to have been durable,
require current durable HRS to dominate prior returns, and prevent two different
messages/signatures at the same domain/slot. A delayed delivery of an older
already returned signature is not newly signing after recovery.

`AuthenticateRecovery` is the **completion** of authenticated recovery, not an
in-flight check. The chosen interface realizes RECOV-8.2-5 by publishing a durable
monotone generation floor before completed knowledge can be forgotten. In-flight
checking that crashes before this event has not completed authentication. This
floor is an explicit implementation obligation, not a feature proved from
FilePV HRS files. Per-domain HRS alone is insufficient.

Recovery authentication may interrupt computed or persisted old-domain work: it
cancels that pending work and disconnects the old session. `Expose` independently
checks current trust/domain at the actual external-return boundary. The model
does not avoid the race by forbidding recovery during signing. How a real signer
implements cancellation/fencing is a refinement/interface obligation, not code
verified here. The `everFloor` observer never enables an operational action.

A genuine replay witness retains the actual nonempty durable record captured at
a crash during the persisted-before-return phase. A post-restart retry must
return that exact record; merely retrying a newly signed record after an unrelated
earlier crash does not satisfy it.

### Checked signer profiles and incomplete wider experiments

All action types, crashes, both domains and network delivery remain enabled.
Only finite payload/rank/signature-value domains differ:

| Default baseline                | Slots | Payloads | Signature variants |
| ------------------------------- | ----- | -------- | ------------------ |
| `signer-crash-baseline-small`   | 1     | A/B/Nil  | 0,1                |
| `signer-crash-baseline-domains` | 1,2   | A/B      | 0                  |

The second profile checks deeper HRS ordering with one signature variant; the
first checks payload/variant breadth at one rank. Exhausting them does not prove
the combined wider product. Both domains retain separate records in both cases.

The predecessor module hash was
`7c86c43e5d10a64cf101d3c61d6ed47d7ec0212c7c59ae11266bd8ff12b957cf`.
The salt-parameterized module hash is
`c948786960d3dd5af381c653f3c0c28795291b19d3b96e660efa8825f6d93c4a`.
Before the split, the two-slot, two-variant profile exceeded 45 seconds with both
three payloads and two payloads. Last reported progress at about 3 seconds was,
respectively, 284,952 generated / 98,889 distinct / 45,992 queued and 325,180 /
99,329 / 40,959. These are **not final counts at timeout**; no final counts were
returned. Those larger products remain **INCONCLUSIVE**, not green.

Reproducible wider parameters and the exact observed incomplete-progress details
are retained under [`experiments/`](experiments/signer-wide-progress.txt), outside
the default configuration suite. The predecessor fixed salts to 0..1; the
current wider configurations explicitly set the same domain to `{0,1}`. Runtime
and whether a 45-second budget suffices depend on the host. For manual bounded
reproduction, run TLC with the desired experiment configuration and an external
state directory, for example:

```sh
timeout 45s java -Xmx512m -XX:+UseParallelGC -cp "$TLA2TOOLS_JAR" tlc2.TLC \
  -workers 1 -seed 1 -metadir "$TLC_OUTPUT_DIR/wide-three" \
  -config formal/etna/experiments/signer-wide-three-payloads.cfg \
  formal/etna/EtnaSignerCrash.tla
```

Controls intentionally expose before write, roll back HRS on crash, forget the
authenticated generation floor, reconnect before trust, accept conflicting retries
or substitute another payload for the caller's request. Positive witnesses cover
before-write crash, after-write/before-return crash, genuine durable retry,
generation-fence reload and uncertainty stopping signing. Controls are model
mutations, not demonstrated protocol defects.

## App model

The app model uses one or two sequential blocks, with actual initial height 1 or 5. Count 0 is the app/Comet uncommitted sentinel, not the numerical height of the
EL origin. The origin hash stays fixed across InitChain calls, even when EL is
already ahead. Blocks and response identities are symbolic, not real EVM/STF or
Comet execution.

Durable stores are distinct: block store, EL flushed effects, FinalizeBlock
response store, app completed-Commit marker and Comet state. Transitions are:

```text
StoreBlock → Finalize effects → Return FinalizeBlock → Save response
    → write durable app Commit → return Commit reply → save Comet state
```

`FlushEL` is a separate transition. Commit's durable marker requires the needed
EL state to have become durable first; an acknowledgment cannot invent that
storage guarantee. Commit may be completed durably while its reply is lost.
The external commit-receipt observer captures actual durable effects at the
write, and independent effect counters/state identities catch repeated execution.
Full response observations include validator updates and fixed transaction results,
not merely the app hash.

The `Crash` transition is an **aggregate process-crash abstraction**: app/Comet
volatile work and EL's unflushed effects are lost together, while each completed
durable write survives. It does not independently schedule failures of all three
processes or prove their product. Durable-EL-ahead-of-app replay is still explored.

### Handshake and the known high-initial-height stop

Info advertises only completed durable Commit, with the corresponding EL identity.
An app behind the stored block is replayed through the real app; repeated
FinalizeBlock must reproduce the complete response without applying effects
twice. If app Commit already completed while Comet state is behind, saved-response
mock replay is legitimate and performs **no real app Commit**. A read-unavailable
saved response stops the handshake; guessing it is not accepted. Read availability
is separate from loss/corruption of durable data.

With `initial_height=5`, the first stored block has actual height 5 while stock
Comet state still reports 0. A crash before saving that first Comet state reaches
`storeHeight > stateHeight+1`, and restart stops regardless of Info's app height.
This is the explicit CONS-3.1-9 limitation, not a newly discovered protocol bug.
It is a positive expected-stop witness, not silently excluded from a claim of
universal automatic recovery. Restarting without changing those stores reaches
the same stop; no database surgery or automatic cure is invented. Once the first
block has completed normally, later block crash/replay paths are also checked.

App controls advertise finalized-but-uncommitted Info, replay a different response,
repeat EL effects, complete Commit before EL durability, mock without a readable
saved response or bypass stock's initial-height gap check. Positive witnesses
show EL-durable-before-app-Commit crash, durable-Commit-before-reply crash, mock
replay and the known initial-height stop.

## Running and interpretation

The shared runner discovers only `configs/*.cfg`; experiments are excluded.
Use its existing command and `--case` arguments to select M03 cases. Normal runs
must exhaust their graphs. Controls/witnesses must produce their exact named
invariant, not a parser error, runtime exception or timeout. No fairness or
unconditional recovery/liveness theorem is claimed.

The source conditions, successful-write retention, serialized key owner, durable
generation-authentication interface and abstract deterministic block/response
identities remain assumptions or implementation obligations. Storage media
failures, HRS/key copies, power loss, complete ABCI methods/versions, actual
client behavior and cross-module equivalence are not established by these runs.
