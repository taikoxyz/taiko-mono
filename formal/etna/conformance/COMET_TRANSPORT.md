# Stock cached signer transport

W05 exercises the stock CometBFT v0.40.0 signer over owned in-memory Pipes.
The source manifest pins commit `0880b4d378f347ab16e54ec677ff50d803f37d62`.
The current Etna document bundle selects the bounded framed-transport claim.
The component evidence covers the typed-refusal and transport-failure split
described in SYNC-9-11 and cached HRS behavior exercised through SYNC-9-13.

The native path passes through `RetrySignerClient.SignVote`,
`SignerClient.SignVote`, `SignerListenerEndpoint`, stock `protoio` framing,
`SignerServer`, `DefaultValidationRequestHandler` and a disk-decoded
`FilePV`. A finite listener and one finite SocketDialer per Pipe deliver
connections to the stock endpoints. The test uses the existing public
projection and disk state bytes. It accepts exact cached nil precommits,
cached prevotes and one same-rank conflicting prevote. The validator's
private-key field stays nil. A request guard checks the received stock
framed request, matching HRS, vote type, empty signature and extensions,
and the absence of a block ID for a precommit.

## Episodes

| Episode | Observable result |
| --- | --- |
| `nil-exact` | The client receives the original cached nil precommit and verifies its public signature. This is the smoke. |
| `nil-time` | The handler and final client vote restore the cached timestamp and signature. |
| `prevote-exact` | The same path returns the original cached prevote with a nonempty block ID. |
| `wrong-chain-retry` and `prevote-conflict-retry` | The first call returns an explicit typed refusal after one attempt. A second caller-initiated call succeeds over the same Pipe. |
| `wrong-union` | A different actual response union produces the wrapped required-response error after a one-attempt configured limit. |
| `wrong-union-retry` | The stock retry consumes the next cached response on the same Pipe. |
| `truncated-retry` | The stock handler produces its full reply. The open Pipe delivers its prefix and reaches the actual read deadline. The listener drops the connection and the retry uses a second owned Pipe and server. |
| `transport-exhausted` | Three silent replies from three stock handlers hit the actual three-attempt transport bound. |
| `cancel` | After one real read timeout, the test observes the stock retry sleep, calls the stock Close method and joins the aborted caller and the owned services. |

The profile configures a 200 ms client read/write deadline and accept wait,
a three-second server deadline, and a 20 ms retry sleep. The cancellation
episode uses a two-second retry sleep to observe the wait before Close.
Listener startup produces a one-hour heartbeat interval, which keeps
scheduled pings outside these episodes. The ten episodes each permit at
most three total SignVote attempts, including any caller-initiated recovery.
The truncated-reply case keeps the old peer open until the deadline. A
replacement pre-owned server supplies the next connection. This covers
the client's timeout-driven reconnection. EOF handling, server-side
reconnection, periodic heartbeat behavior and the production five-second
timeout latency remain outside the measured profile.

Receipts bind exact request frames at both Pipe ends, the full stock handler
result, the framed reply offered by the stock writer, the bytes sent and read,
the decoded union or observed read error, the caller-visible error/vote,
public signature verification, and before/after FilePV HRS and disk state.
Per-phase Go runtime events bind the native producer identity, each receipt
size and digest, and exact test lifecycles. The collector hashes and decodes
the same opened receipt bytes. It validates all observations against
independent public-input expectations and checks the original disk bytes,
inode and metadata again from the host.

## Running the bounded profile

Use the managed Python interpreter with `-B`, the pinned existing Go toolchain,
a previously verified stock tree with read-only modes, the existing offline
module/build caches and physical cache lock, and the exact reviewed workspace
documents. Supply `--source`, `--workspace-root`, `--go-root`, `--module-cache`,
`--build-cache`, `--build-lock`, `--expected-cache-identity`,
`--expected-lock-identity` and `--output`. Select `--phase smoke` first.
Use the same inputs and output directory for `original`, `refusal-branch`
and `restored`. Each phase has a 90-second native, 100-second isolation
and 110-second supervisor deadline. Use a 120-second outer limit per phase.

The refusal-branch variation opens the real stock retry branch, causing both
typed refusals to produce exactly one extra on-wire attempt. The remaining
calls stay positive. An alternate `client-assignment` variation preserves
the stock handler and wire bytes while dropping the signature assignment at
the consumer. Run it in a separate smoke/original/variation/restored
campaign. Both variants require exact ordinary-observer rejections and
complete evidence about the changed behavior. Restoration rereads the
same private copy and reproduces the original receipt bytes.

The runner uses offline module resolution, read-only source, SDK, module
cache and generated module files, and disposable outputs plus the locked
build cache. Each run preserves its combined native log and execution
record. The test validates cached component behavior with public fixtures.
Etna's trust gate, authenticated sessions, trusted reconnect, supervision
and WAL restart under SYNC-9-12 and SYNC-9-14, failover and fresh-signature
persistence require their own evidence.
