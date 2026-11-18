# CometBFT FilePV persistence and cached replay

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
invocations, selected test identities, actual staged stock `file.go` and
adapter hashes, public input, effective Go module and checksum files, and
source and tool guards. Handoff records include the writer-owned paths and
hashes read by the host on both sides of the reader. Setup errors, skips,
unrelated panics and timeouts fail evidence admission.

This exercises file persistence across process exit and selected cached
responses from a new FilePV state object. C01 remains open. The writer starts
with an existing public signature, and the reader uses the state decode tail.
Fresh signing, the private-key loader, consensus WAL integration, abrupt
crashes during the write, power loss, failover and shared-signer coordination
remain outside the exercised boundary.
