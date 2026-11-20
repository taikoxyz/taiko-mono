# Native evidence lifecycle and committed markers

This component consumes stock CometBFT `0880b4d378f347ab16e54ec677ff50d803f37d62`
and the unchanged public h1000 A/B precommit signatures. It runs local evidence,
state-store and controlled-peer APIs. Synthetic history, header availability,
window boundaries, app version17 and stock default consensus parameters are
explicit inputs. They do not establish an authenticated Etna chain or START-10
application configuration.

Source selection for `evidence-lifecycle` always remains separately
`NOT_EVALUATED`. A successful audited native receipt concerns the named stock
component; it does not turn source selection into execution or protocol proof.
Actual run identities and validation status belong in [REPORT.md](../REPORT.md).

The fixture stages exactly `public_input.go`, `evidence_test.go`, `go.mod`,
`go.sum` and `public-votes.json`. The shared reader hashes the actual input buffer
before decoding. There are no new signing keys, signer duties, sockets or P2P
handshakes. The helper accounting test is selected separately from the four
receipt-producing component cases.

| Case | Actual path and distinction |
| --- | --- |
| `cold-grid` | Six independent fresh DB pairs, heights1900/1901 and time ages3599/3600/3601. Expiry requires both strict bounds; five accept and only1901/3601 expires. A different evidence timestamp is refused against the real historical header before validator lookup. |
| `gossip` | Real `Reactor.Start/AddPeer` with controlled peers: height1900 reaches actual `Send`,1901 reaches the stock old-info callback. Complete envelope bytes and callback arguments bind those decisions. |
| `pending-restart` | Independently build identical Add1000, Update+Save1900/3600 and1901/3601 prefixes. Continuing pending evidence bypasses history checks until its own1902/3602 prune. Reopening the other pair causes `NewPool` to prune immediately at1901/3601. |
| `committed-window` | Actual Update1001 installs a committed marker whose payload is evidence height1000. Real `PruneStates(1000,1001,1001)` removes validator row1000 but retains full1001. Reopened marked checking refuses without historical lookups; an independently unmarked pair actually reaches missing header1000. |

`CheckEvidence` admission writes pending evidence to the DB and adjusts Size;
it does not perform `AddEvidence`'s gossip-list insertion. Cold, continuing,
reopened and committed paths therefore have different cache and history
requirements. A single shared mutable DB cannot substitute for the independent
cold cells or the two identical pending prefixes.

The historical evidence time is1699999900/0, deliberately different from the
signed votes'1700000000/123. The byte auditor rebuilds complete votes, signing
preimages, validator sets, bare duplicate-vote evidence, its oneof envelope and
its EvidenceList separately. The DVE hash covers its bare protobuf. The list
hash is RFC6962 over the bare evidence, while pending storage contains the
oneof envelope. Marker keys use the source's uppercase ASCII height/hash and
marker payloads use the infraction height, not the installation height.

Complete State, consensus parameters and every state/evidence DB row are
checked against Bootstrap/Save/Prune semantics. Error type, reason and full
rendered error text are distinct fields. Stock message enum names, not numeric
aliases, occur in the committed refusal's rendered votes. Header/validator
lookup arrays exclude the separately recorded retained-row setup precheck.

## Worker observations and controls

A callback first demonstrates that the actual broadcast worker has entered its
source path. Before Quit, the fixture records a positive goroutine profile;
after Quit it waits for absence of that worker before closing its databases.
Every returned stack must be nonempty and shorter than the SDK's32-PC capacity.
The auditor derives inventory length, maximum depth and target counts, checks
actual function names, and requires the simultaneous sampling goroutine in a
positive observation. This is a bounded observation under the pinned runtime,
not an unconditional formal join primitive. `BaseService.Wait` and AddPeer's
return are insufficient on their own.

Final Send/overflow/queued-event accounting happens after observed worker exit.
The old-info callback is inside message preparation, so it can precede another
operation in the same iteration. Sampling before exit can miss a later Send.
A private controlled callback/late-return diagnostic tests that real ordering;
its deliberately stale old-order observer is never healthy protocol evidence.
The separately selected `TestEvidencePostExitAccounting` covers the forced
helper window and does not replace that actual gossip-path control.

If first callback startup times out before the worker is observed, the trial
fails. No passing receipt relies on a zero profile in that failure path; final
process cleanup remains necessary. Unexpected panic, timeout, skipped or absent
target, incomplete raw data or unrelated error is INCONCLUSIVE.

The primary private source control changes only `IsEvidenceExpired`'s `&&` to
`||`: cold admission becomes two accepted/four expired, while the other three
business histories retain their meanings. A different independent control
changes the reactor's strict peer-height comparison to equality-inclusive and
must positively observe old-info for peer1900. Missing Send by timeout does not
establish that control. Source bytes, physical file identity and modes are
restored on the same private copy after descendant quiescence.

## Run the real producer

Use caller-provided offline SDK/module inputs and the pre-existing physical
build-cache lock. For example, from `formal/etna/conformance`:

```sh
python -I -S -B run_comet_evidence.py \
  --source "$COMET_SOURCE" --go-root "$GO_ROOT" \
  --module-cache "$MODULE_CACHE" --build-cache "$BUILD_CACHE" \
  --build-lock "$BUILD_LOCK" --workspace-root "$REVIEWED_WORKSPACE" \
  --output "$SMOKE_OUTPUT" --timeout 100 --smoke
```

Use a distinct fresh output for the full normal/control/restored campaign,
replacing `--smoke` with `--smoke-output "$SMOKE_OUTPUT"`. The workspace must
contain the exact three reviewed current documents at their repository paths.
A current source selection does not change the stock native authority pin.

The trusted Python producer invokes the common driver outside the native
namespace; the driver gives each Go command one official offline namespace.
An audited outer packet guards source, tools, paths and modes, and must not
pre-acquire the same cache flock that the driver owns. A second surrounding
restricted namespace can make the nested native launch fail. Split raw runs
and standalone audits never masquerade as a successful full producer launch.
Actual `run_profile` and `require_capture` credit requires their real entrypoints
and truthful actual metadata, not a fabricated sidecar.

Native/isolation/leased-supervisor budgets remain90/100/110seconds per phase.
The outer observer can request cancellation, but it cannot automatically kill
the last quarantined cache-lease owner on loss of supervision. See the shared
[lease contract](COMET_TERMINAL.md#shared-lease-and-cancellation-contract).
Private output is disposable after abrupt interruption; no crash-atomic
multistore or source-restoration guarantee is claimed.

Real networking/trust, authenticated retained history/window installation,
current Etna client/L1/EL behavior, new signatures, guest execution, proving,
deployment and broader R01/P01/K01/Q01 obligations remain separate work.
