# H02: unsigned weighted consecutive stock Comet transitions

This lane exercises actual `state.MakeGenesisState`, private `state.updateState`
and `State.MakeBlock` from stock CometBFT v0.40.0 commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. A generated, byte-pinned bridge
only forwards arguments to `updateState`; a separate Go module imports production
`state`, so upstream test-package key-generation globals are not compiled.

The initial global height is 11. Public points A=B, B=-B and C=2B are the same
unsigned Ed25519 points used by the existing Bootstrap lane. Genesis A3/B1 has
current A(-1)/B(1), stored proposer A; next A(2)/B(-2), stored proposer B. The
second-round tie selects B by ascending address. There is no private key input.

Five chains each execute heights 11 through 16 from their actual previous result:

| Program     | Updates                       | Final activation |
| ----------- | ----------------------------- | ---------------- |
| unchanged   | none                          | genesis          |
| unequal     | at 11: A1/B3                  | 13               |
| add-remove  | at 11: B0/C2, retaining A3    | 13               |
| replacement | at 11: A0/B0/C4               | 13               |
| overlapping | at 11: A1/B3; at 12: A2/B1/C1 | 13 then 14       |

`literals.json` was frozen **before native execution**. `derive_literals.py` is an
independent pure integer and protobuf/Merkle calculation, never run by the native
runner. It does not import Comet, run a Go operation, or use actual output. The
reviewed source rules are power-descending/address-ascending ordering, floor mean
for signed priority centering, address tie-breaking, and newcomer priority from
updated total power **before removal**. Observations include the entire stored
proposer object, which can differ from the member with highest final priority.
Negative floor division gives a nonzero sum in the overlapping program. These
small powers do not reach rescaling or integer clipping; those remain outside
this result.

Each leaf returns genesis plus six actual successor observations, ordered members
and exact public identities/powers/priorities/proposer for last/current/next,
change height, and the actual MakeBlock current/next validator hash projection.
The independent hash encoder uses SimpleValidator protobuf bytes and simple
Merkle splitting; it does not call ValidatorSet.Hash as its expected-value oracle.
The adapter checks every prior serialized state after every later transition,
as well as update/header/response input immutability and the transition count.
Unexported cached total power and key-type flags are not independently inspected.

The header projection uses an empty unsigned structural Commit. Initial time is
fixed genesis time; later MakeBlock median time is zero because there are no
commit votes. updateState receives explicit monotonic header times. These calls
intentionally bypass block/commit admission: this is not a valid signed history,
full ApplyBlock, round-lock, >2/3 voting, registry derivation, P2P, or liveness
experiment. Genesis and ABCI updates are selected public inputs, not authenticated
Etna committee calculations.

Two separate faults change the actual private `state/execution.go`: omit the
priority increment; install updated next validators as current one height early.
All five leaves must produce the exact full separately frozen faulty observation
and only the named semantic mismatch. Each fault is actually restored on the
same private source tree and all five original leaves rerun. A compilation error,
missing transition, missing/duplicate/skipped leaf, extra diagnostic or wrong
failure does not qualify.

The existing source manifest checks all 1,659 original files. The exact generated
bridge adds one separately pinned file to a derived manifest; both are checked
before/after every run. Adapter/literal/module/generated modfile and Go tool
hashes are guarded before/after. Execution reuses `run_isolated.py`, the existing
sensitivity supervisor, the canonical shared Go cache and lock. Network/downloads,
original home/Git/credentials and writable source bindings are absent. Source
faults and reports are disposable private output artifacts, never production edits.

Example (all variable locations are operator-supplied):

```sh
"$PYTHON" -B formal/etna/conformance/run_comet_handover.py \
  --source "$COMET_SOURCE" --go-root "$GO_SDK" \
  --module-cache "$GO_MODULE_CACHE" --build-cache "$GO_BUILD_CACHE" \
  --build-lock "$GO_BUILD_LOCK" --output "$FRESH_OUTPUT"
```

Strongest false-green concern: expected states could share production operations,
or a missing intermediate transition could silently count as success. Independent
pre-execution arithmetic review, complete ordered observations, immutable retained
inputs and exact source-fault receipts address that bounded concern. Sensitivity
to author-selected faults does not prove absence of other defects. Independent
behavior verification chooses an additional source challenge. K02 remains open
outside these selected arithmetic/activation observations.
