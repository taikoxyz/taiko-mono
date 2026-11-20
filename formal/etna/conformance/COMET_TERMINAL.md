# Terminal seen-commit reconstruction

This component check uses stock CometBFT `0880b4d378f347ab16e54ec677ff50d803f37d62`
and the unchanged public h1000 signatures in `comet_signed/public-votes.json`.
The source selection `terminal-seen-commit` is separately `NOT_EVALUATED`;
selection does not attest an execution result or deployed Etna implementation.

The native fixture uses `Store.Bootstrap`, `BlockStore.SaveSeenCommit`, actual
close/reopen of separate LevelDB pairs, `consensus.NewState` and `GetRoundState`.
It never starts consensus, a signer, a network peer or a wallet. Each A/B branch
gets an independent reopened BlockStore and a new BlockExecutor, avoiding the
height-keyed seen-commit cache and block-validation cache supplying an earlier
branch's result.

| Public/context case | Constructor | Explicit parent-A verification | Normal synthetic child |
| --- | --- | --- | --- |
| A, signed 3/4 | accepts | accepts | accepts |
| B, signed 3/4 at the same height | accepts | complete BlockID mismatch | same mismatch |
| Seen and fallback commits both absent | exact missing-commit panic | absent | absent |
| Exactly 2/3 signed | exact quorum panic | insufficient power | absent |
| Generation-0 signature under generation-1 state | exact wrapped signature panic | wrong signature | absent |
| Genuine CommitSig moved to ordinal1 | exact wrapped address panic | ordinal address mismatch | absent |

Only the `consensus.NewState` invocation has local panic recovery. The consumer
allows only each selected refusal's exact type, full reason, wrapped class and
actual input context. An arbitrary panic, failed setup, skip, missing target,
compile failure or timeout is INCONCLUSIVE and cannot count as a successful
source-control observation.

Both normal child headers retain parent A. Their LastCommit is obtained from the
actual reconstructed VoteSet, so the B branch cannot silently substitute A.
The child is made by stock `State.MakeBlock`, with empty transactions/evidence
and the actual proposer. Complete state, validator/commit/header/block protobuf,
all vote/signing contexts, raw writer/reopened database rows and child hash/time
are audited against the frozen public input and inspected stock encodings.
Independent behavioral review additionally recovers the public signer and derives
all raw protobuf, Merkle and time relationships separately.

The common driver stages only the fixed reader, selected test file, module/sum
and public JSON. The reader hashes the actual read buffer before decoding.
Staged files and effective module replacement are rechecked before and after
execution; unknown or substituted metadata is rejected against the actual raw
Go events. Smoke runs one A leaf; the full run executes all six leaves, omits
only the stock expected-BlockID comparison in a private source copy, observes the
specific B verification and normal-child differences, restores that same file,
and reruns all leaves. Source files, tools, shared physical cache lock identity
and retained execution inputs must remain unchanged. No dependency fetching is
performed. Go uses a 90-second test timeout, namespace100 and supervisor110.

Use the existing offline SDK/module cache and a pre-existing physical build lock.
Configure paths explicitly; for example, from `formal/etna/conformance`:

```sh
python -I -S -B run_comet_terminal.py \
  --source "$COMET_SOURCE" --go-root "$GO_ROOT" \
  --module-cache "$MODULE_CACHE" --build-cache "$BUILD_CACHE" \
  --build-lock "$BUILD_LOCK" --workspace-root "$REVIEWED_WORKSPACE" \
  --output "$SMOKE_OUTPUT" --smoke
```

Then use a distinct fresh `--output` and `--smoke-output "$SMOKE_OUTPUT"` for
the full run. `REVIEWED_WORKSPACE` must contain the exact current reviewed three
documents, not an automatically upgraded or historical selection. A surrounding
reviewed execution packet pins the Python startup/toolchain, arguments, file
modes and isolation entrypoint before invocation.

The parent IDs are opaque: this corpus contains no matching original parent
block/partset. The unsigned h1001 child is a synthetic component input. These
observations do not establish authenticated DATA-5.4 import, a signed multiheight
chain, crash-atomic multistore installation, an Etna client, L1/EL behavior or
real proof generation. Runtime/deployment obligations remain WAITING.

## Recorded execution boundary

The state fixture uses synthetic app version17 and stock default block/evidence
parameters. The checked behavior is terminal commit reconstruction and binding;
Etna's START-10 configuration values need their own client-level check.

The recorded native runs use one reviewed isolation namespace for Go, followed
by separate readonly runs of the actual canonical collector and an independently
implemented protobuf/signature verifier. All six baseline cases, the private
expected-BlockID control and same-copy restoration, and the different G1-to-G0
fixture-input control have actual raw captures. The input control preserves the
original public signatures and checks that the ordinary auditor rejects its
changed actual context.

The complete `run_profile` and `require_capture` integration is **INCONCLUSIVE**
in this environment: its nested `unshare` was refused before Go started. Those
entrypoints are source reviewed; the split component executions do not count as
a successful run of either entrypoint. Capture metadata retains the commands and
paths that actually ran. No namespace metadata is rewritten to invent such a
launch, and the draft does not claim all producer/runtime gates passed.


## Shared lease and cancellation contract

The common driver uses `leased_execution.py` to inherit the same cache-lock
open file description into its supervisor. That owner retains the lease through
quiescence and delegates descendant cleanup to the unchanged historical
`sensitivity/run.py`; old Registry pins and unleased callers remain unchanged.
Main-thread CLI TERM/INT recording covers staging, native execution, audit and
restoration. Trial schema `etna-comet-boundary-trial-2` independently binds native
status, supervisor status and the actual leased command; worker exit200 cannot
forge the supervisor's cleanup-confirmed success status.

Unexpected supervisor death leaves a surviving caller retaining the lease until
an operator independently confirms writer death/reaping before stopping that
holder and reusing the cache. Abrupt caller death may leave private mutant output
unrestored and unreusable, with no PASS summary. There is no crash-atomic
restoration guarantee or protection against forced death of both holders;
independent quiescence confirmation is required before cache reuse in that case.
Summary publication is the completion point. TERM after the final post-write
check but before the outer cancellation check can leave valid completed evidence
while the CLI reports cancellation, after workers, restoration and checks finish.

The [prefix-repair checks](../REPORT.md#y-prefix-final-review-repairs) exercised the
actual canonical driver/supervisor/cleanup path with disposable dummy writers:
normal/mutant TERM and caller death, lost supervisor, three non-native windows,
reserved child exit and strict capture negatives. Those10 groups passed
independently. They establish that ownership seam, not real shared-Go-cache
concurrency or the full real-Go producer integration, which stays INCONCLUSIVE.
