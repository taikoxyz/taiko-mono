# CometBFT FilePV persistence and signer-handler replay

The persistence scenario exercises stock CometBFT v0.40.0 FilePV source at
`0880b4d378f347ab16e54ec677ff50d803f37d62` with the pinned public vote
projection. An isolated Go test process supplies public signatures and canonical
sign bytes to `saveSigned`. The host verifies the actual published JSON bytes
and mode 0600 under the newly created state directory. A second, separately
supervised Go test process opens those files, hands the same raw bytes to
Comet's JSON decoder and sets the decoded state's path in a fresh FilePV with a
nil private key. The reader binds each actual attempt and reply to that file and
records the complete selected state before and after the call.

The two seeds and their expected writer artifacts are derived from the public
rows and stock encoder before execution.

| Public case     | Height, round, step | Bytes | Disk SHA-256                                                       |
| --------------- | ------------------- | ----: | ------------------------------------------------------------------ |
| `precommit_nil` | 1000, 0, 3          |   319 | `4e9095589653586cf29a7c84c61c247561981e2f8ef5d74e1113342f67183215` |
| `prevote_a_r1`  | 1000, 1, 2          |   487 | `6b1560e11d90e0670101afc0351568cdacab9dbc478e7774ecd411b5dd8037aa` |

- `nil-exact`, `nil-time` and `prevote-exact` reuse the published signature
  and verify it with the published key. The timestamp-only attempt submits
  1700000000/124 and must return 1700000000/123 with the stored sign bytes.
- `prevote-conflict` submits the public B prevote against the stored A prevote.
  `wrong-chain` submits the exact unsigned nil precommit with a different
  chain ID. Both must return the precise conflict error and leave the vote
  unsigned.
- `height-regression`, `round-regression` and `step-regression` require the
  native refusal at the corresponding HRS comparison.
- `missing-sign-bytes` and `missing-signature` remove only the selected
  fields from a copy of the freshly decoded state in memory. The first
  returns the native unsigned refusal. The second exercises the documented
  incomplete-state panic at `CheckHRS`.
- `advance-check` calls only `CheckHRS` at a later rank and records its
  eligibility result. It never requests a signature.

Run from the repository root with the source snapshot, toolchain, offline
caches and shared physical cache lock used by the other Comet runners.

```bash
"$PYTHON" -B formal/etna/conformance/run_comet_filepv.py --scenario persistence \
  --source "$COMET_SOURCE" --go-root "$GO_ROOT" --module-cache "$GO_MODULE_CACHE" \
  --build-cache "$GO_BUILD_CACHE" --build-lock "$GO_BUILD_LOCK" \
  --output "$SMOKE_OUTPUT" --smoke
"$PYTHON" -B formal/etna/conformance/run_comet_filepv.py --scenario persistence \
  --source "$COMET_SOURCE" --go-root "$GO_ROOT" --module-cache "$GO_MODULE_CACHE" \
  --build-cache "$GO_BUILD_CACHE" --build-lock "$GO_BUILD_LOCK" \
  --output "$FULL_OUTPUT" --smoke-output "$SMOKE_OUTPUT"
```

Smoke selects one writer seed and its exact nil replay. The full campaign uses
one private source copy and distinct state directories for original, omit-save
and restored. The fault removes the call to `LastSignState.Save` in
`saveSigned`. Each affected writer must record the published values in memory,
the absent state path and the designated missing-file assertion. A reader
requires a successful writer handoff. The restored writer and reader both
execute again against the original bytes.

The raw Go event logs and their execution records bind two supervised
invocations, selected test identities, public input, effective Go module and
checksum files, and source and tool guards. Both scenarios compile the actual
manifest-verified `file.go`, `signer_requestHandler.go` and `msgs.go` with the
same test adapter in Go named-file mode. Each phase stages the current
private source bytes and binds all nine staged and effective file hashes
before and after each invocation. Handoff records include the writer-owned paths and
hashes read by the host on both sides of the reader. Setup errors, skips,
unrelated panics and timeouts fail evidence admission.

## Signer-handler scenario

`--scenario handler` runs the same writer and loads its state in a separate
reader before calling stock `DefaultValidationRequestHandler` directly.

| Leaf                     | Submitted vote and result                                                                               |
| ------------------------ | ------------------------------------------------------------------------------------------------------- |
| `nil-exact`              | Unsigned nil precommit returns the cached public vote.                                                  |
| `nil-time`               | Nil precommit at 1700000000/124 returns the cached time 1700000000/123.                                 |
| `wrong-chain-retry`      | Wrong-chain nil precommit returns a chain error, then same-chain nil precommit returns the cached vote. |
| `prevote-conflict-retry` | Same-rank B prevote conflicts with the stored A prevote, then A returns the cached vote.                |
| `height-regression`      | Nil precommit at height 999 and round 2 returns the height regression error.                            |
| `round-regression`       | Nil precommit at round 0 against stored A at round 1 returns the round regression error.                |
| `step-regression`        | A prevote at round 0 against the stored nil precommit returns the step regression error.                |
| `prevote-exact`          | Unsigned A prevote returns the cached public vote.                                                      |

Each retry uses a fresh unsigned vote and the same rehydrated FilePV instance
as the preceding refusal. The receipt records the actual serialized request,
its requested and configured chains, and its vote before calling the handler.
The response observation uses the returned protobuf union and its vote under
the configured chain. The receipt also records the post-call request vote
under that chain, the separate Go error, complete HRS and cached bytes, and
the actual disk digest before and after each call. Public verification uses
the returned vote. The host independently checks all these observations,
including the disk bytes handed to the state decoder.

Both refusal types return a `SignedVoteResponse` carrying a value-typed zero
`Vote` and typed error code 0. The zero vote serializes its year-1 timestamp
and empty BlockID. The chain refusal reports `unable to sign vote` in the
response and `want chainID: <request>, got chainID: <configured>` as a separate
Go error. Signer refusals report the same native error in both channels.
Cached votes return both errors nil and verify with the published key.

Use the same commands with `--scenario handler` and fresh output paths.
Handler smoke runs the exact nil leaf. The full run omits only the sign-vote
chain guard in the disposable copy. The wrong-chain request then returns the
verified cached nil vote under the configured chain. Its fresh same-chain
retry still succeeds and the designated failure is emitted after both calls.
The other seven leaves serve as controls. The full run restores the original
source and repeats the writer and all eight handler leaves. Smoke admission
requires the selected scenario and current nine-file footprint.

## Evidence boundary

This exercises file persistence across process exit and selected cached
responses from a new FilePV state object. C01 remains open. The writer starts
with an existing public signature, and the reader uses the state decode tail.
The handler scenario covers synchronous calls with loaded public signatures.
Fresh signing, the private-key loader, transport, timeout and session
authentication, consensus WAL integration, abrupt crashes during the write,
power loss, failover and shared-signer coordination remain outside the
exercised boundary.
