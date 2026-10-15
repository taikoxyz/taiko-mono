# Formal Spec Etna Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend #22177's executable Lean specification with fork-aware gas handling and the Etna header commitments in #22189/#22263, then update the original PR #22177.

**Architecture:** Preserve manifest derivation as the first layer. Add a pure, checked header-plan layer over its output, with an immutable L1 state-root lookup and sequential parent commitments. Prove core and header properties in the Lean kernel and retain the existing shared vectors and trust gates.

**Tech Stack:** Lean 4.34.1, Lake, existing Lean standard library, shell CI gates, GitHub CLI.

## Global Constraints

- `ANCHOR_GAS_LIMIT` remains 1,000,000.
- Each block selects its own fork from its final timestamp after validation or inheritance. Activation is inclusive: a timestamp equal to the fork time uses the new fork.
- The per-source block-count limit keeps its existing rule: choose Shasta or Unzen limits from the proposal's landed L1 timestamp.
- Both Etna integer fields are big-endian uint48 values; reject values above `2^48 - 1` rather than truncating them.
- Header-construction errors do not turn a source into a default block, fabricate a root, or reuse a pre-Etna/genesis zero root.
- The model produces candidate transactions before execution.
- Retain all existing public derivation theorems and their non-vacuous witnesses.
- No new dependencies, axioms, proof escape hatches, or changes to the manifest corpus.
- Read `docs/superpowers/specs/2026-10-15-formal-spec-etna-alignment-design.md` for the approved design and exact source revisions. Production code changes stay in `packages/formal-spec`.
- Existing worktree: `/Users/davidcai/.codex/worktrees/formal-spec-etna-alignment/taiko-mono`, branch `codex/formal-spec-etna-alignment`.
- Publish to the original PR #22177 by normally pushing `HEAD:feat/formal-spec-derivation`; refresh its head first and preserve remote updates. Keep its draft status and base `main`; update its description and reference #22189/#22263. Do not create a new PR.
- For commits, retain required hooks and reuse installed tools with `PATH=/Users/davidcai/taiko/taiko-mono/node_modules/.bin:$PATH`.

## File ownership

Task 1 owns the existing core derivation modules, existing proofs/tests and the core section of `Properties.lean`. Task 2 owns new header/encoding modules, header proofs/tests, header properties and import entry points. Task 3 owns README/CI integration and final artifact validation. Implement tasks sequentially, review each task, and do not revert another contributor's work.

### Task 1: Make the existing derivation and proofs fork-aware

**Files:**

- Modify: `packages/formal-spec/TaikoSpec/Derivation/Params.lean`
- Modify: `packages/formal-spec/TaikoSpec/Derivation/Types.lean`
- Modify: `packages/formal-spec/TaikoSpec/Derivation/Validate.lean`
- Modify: `packages/formal-spec/TaikoSpec/Derivation/Derive.lean`
- Modify: `packages/formal-spec/TaikoSpec/Proofs/Source.lean`
- Modify: `packages/formal-spec/TaikoSpec/Proofs/Derive.lean`
- Modify: `packages/formal-spec/TaikoSpec/Properties.lean`
- Test: `packages/formal-spec/Tests/Validation.lean`
- Test: `packages/formal-spec/Tests/Derive.lean`
- Modify existing tests/callers as needed for parameter propagation; preserve their assertions.

**Interfaces:**

- Consumes: existing `ChainParams`, `Parent`, `BlockManifest` and source derivation definitions.
- Produces: `ChainParams.etnaForkTime : Option Nat` (default `none`); `isEtna (c : ChainParams) (timestamp : Nat) : Bool`; `isUnzen (c : ChainParams) (timestamp : Nat) : Bool`; `anchorGasReserve (c : ChainParams) (timestamp : Nat) : Nat`; `effectiveGasLimit (c : ChainParams) (p : Parent) : Nat`; `advance (c : ChainParams) (p : Parent) (b : BlockManifest) : Parent`.
- Propagate `c` to `toDerived` and every rolling-parent fold; keep `DerivedBlock.gasLimit` as manifest gas.

- [ ] **Step 1: Write failing gas/fork regression assertions before changing definitions.** Add cases with expected values under an explicit `{ devnet with etnaForkTime := some 2000 }`: a pre-Etna 31M parent recovers 30M; a 30M Etna parent recovers 30M; genesis retains 30M. A forced/default first Etna block has manifest gas 30M and advances to a parent with header gas 30M; an Etna successor keeps 30M. Include a two-block source crossing activation, and a default timestamp crossing activation even when proposal time precedes it. Assertions follow this shape:

```lean
#guard effectiveGasLimit etnaChain etnaParent == 30_000_000
#guard (advance etnaChain unzenParent firstEtnaManifest).gasLimit == 30_000_000
#guard maxBlocks etnaChain 1999 == UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
```

Define `etnaChain`, parents and manifests using existing test helpers with concrete timestamps/anchors. In the RED version, use existing calls for a behavioral failure where possible; missing new configuration/API can be documented as a missing-feature failure. Run `lake build Tests.Validation Tests.Derive` and record relevant failure output.

- [ ] **Step 2: Implement fork predicates and reserve transitions.** The required core definitions are:

```lean
def isEtna (c : ChainParams) (timestamp : Nat) : Bool :=
  match c.etnaForkTime with
  | some t => decide (t ≤ timestamp)
  | none => false

def anchorGasReserve (c : ChainParams) (timestamp : Nat) : Nat :=
  if isEtna c timestamp then 0 else ANCHOR_GAS_LIMIT

def effectiveGasLimit (c : ChainParams) (p : Parent) : Nat :=
  if p.number = 0 then p.gasLimit
  else p.gasLimit - anchorGasReserve c p.timestamp

def advance (c : ChainParams) (p : Parent) (b : BlockManifest) : Parent where
  number := p.number + 1
  timestamp := b.timestamp
  gasLimit := b.gasLimit + anchorGasReserve c b.timestamp
  anchorBlockNumber := b.anchorBlockNumber
```

Implement `isUnzen` with the same optional inclusive timestamp convention. Keep mainnet/Hoodi/devnet Etna unscheduled by default. Correct comments that say every non-genesis header carries an anchor reserve.

- [ ] **Step 3: Propagate parameters and repair existing proofs.** Update all `effectiveGasLimit`, `advance`, `toDerived`, validation and inheritance uses. Preserve public theorem names and their mathematical claims. Add a kernel-checked general round-trip lemma:

```lean
theorem effectiveGasLimit_advance (c : ChainParams) (p : Parent) (b : BlockManifest) :
    effectiveGasLimit c (advance c p b) = b.gasLimit := by
  simp [effectiveGasLimit, advance]
```

Adjust simplification if needed, and reuse this lemma in the rolling-parent gas proof. Add witnesses for both sides of activation.

- [ ] **Step 4: Run focused tests, then `lake build` and the existing vector runner.** Require clean output and all existing shared vectors passing. Record RED/GREEN evidence and self-review for source-order and gas-basis consistency.

- [ ] **Step 5: Commit only Task 1 files** with `feat(formal-spec): make derivation gas limits fork-aware`.

### Task 2: Add checked header plans, executable boundary tests and proofs

**Files:**

- Create: `packages/formal-spec/TaikoSpec/Derivation/Header.lean`
- Create if needed for a focused byte-codec unit: `packages/formal-spec/TaikoSpec/Derivation/ExtraData.lean`
- Create: `packages/formal-spec/TaikoSpec/Proofs/Header.lean`
- Create if needed for focused encoding proofs: `packages/formal-spec/TaikoSpec/Proofs/ExtraData.lean`
- Create: `packages/formal-spec/Tests/Header.lean`
- Create: `packages/formal-spec/Tests/Etna.lean`
- Modify: `packages/formal-spec/TaikoSpec/Properties.lean`
- Modify: `packages/formal-spec/TaikoSpec.lean`
- Modify: `packages/formal-spec/Tests.lean`

**Interfaces:**

- Consumes: Task 1's `isEtna`, `isUnzen`, `anchorGasReserve`, `deriveSources`, normalized `Parent`, and manifest-gas `DerivedBlock`.
- Produces: a 256-bit `Root` type; `HeaderContext` containing base-fee sharing byte, proposal ID and `l1StateRoot : Nat → Option Root`; `HeaderParent` carrying normalized `Parent` and optional beacon root; `HeaderPlan` carrying the derived block, header gas, optional root, encoded extra data and explicit transaction plan; a structured `HeaderError`; pure `buildHeader`, `advanceHeader`, `buildHeaders` and `deriveHeaders`.
- Root may use `Fin (2^256)` (a word with a canonical 32-byte representation), or a fixed-length byte representation. Avoid cryptographic hashing/serialization work outside the approved scope.
- Encode extra data as bytes, not merely a tuple. Provide a decoder used by round-trip properties; genesis anchor decoding returns zero regardless of layout, while non-genesis Etna decoding requires exactly thirteen bytes.
- Represent a system anchor as a tagged plan entry and each manifest transaction as a tagged manifest entry. No signed anchor encoder is required.

- [ ] **Step 1: Write executable header/Etna tests before implementation.** Use concrete fixture values: sharing 50, proposal 7, anchor 123456. Expected Etna bytes are `3200000000000700000001e240`; expected pre-Etna prefix is `32000000000007`. Test maximum uint48 `281474976710655`, and separate overflows at `281474976710656`. Test root selection with distinct root values and a missing lookup, so reuse and fetch cannot be confused. Record the expected missing-feature RED result from `lake build` or `lake env lean Tests/Header.lean`.

Examples of required behavior (adapt names to the cohesive API):

```lean
#guard encodeEtnaExtraData 50 7 123456 ==
  .ok (bytesOfHex "3200000000000700000001e240")
#guard decodeEtnaAnchorBlockNumber 0 [] == some 0
#guard (buildHeader c ctx etnaParent sameAnchorBlock).isOk
#guard (buildHeader c missingRoots unzenParent firstEtnaBlock).isError
```

The finished tests must assert exact error constructors and exact expected roots, not only `isOk`/`isError`. Define fixtures using real pure functions, not mocked implementation methods.

- [ ] **Step 2: Implement byte encoding and checked header construction.** Use a pure big-endian fixed-width integer encoder, reusable by seven/thirteen-byte layouts, with an explicitly proved valid-domain decoder law. Etna checks both integer fields before encoding. Pre-Etna preserves the existing encoder's low-six-byte behavior, and agrees with event IDs on the uint48 domain.

Header root selection is exactly:

```text
if child is Etna:
    if parent is Etna AND parent.number != 0 AND child.anchor == parent.anchor:
        require present, nonzero parent root; reuse it
    else:
        require present, nonzero L1 state root for child.anchor
else if child is Unzen:
    present zero root
else:
    absent root
```

Header gas is `block.gasLimit + anchorGasReserve c block.timestamp`. Etna's candidate transaction plan is the manifest list with no system entry. Earlier blocks have one leading system entry. Build the root and extra data after manifest inheritance/validation. Use structured errors for missing/zero parent root, missing/zero L1 root and integer overflow. A whole-proposal constructor propagates any error instead of returning partial success or converting it into a default source.

- [ ] **Step 3: Add general Lean proofs and concrete witnesses.** Prove successful Etna construction gives a nonzero root, correct layout length, no system transaction and unchanged candidate manifest order. Prove byte encoding/decoding round-trips for every in-range uint48 and rejects overflow. Prove successful header construction preserves core fields and manifest gas when the header becomes the next parent.

For authenticated root correspondence, use a total canonical L1 history in the theorem and require that successful partial lookups agree with it and that the initial non-genesis Etna parent commits to its anchor's canonical root. This permits executable root reuse even when the partial lookup lacks the parent's anchor. Prove correspondence is preserved by `advanceHeader`, and across successful sequential `buildHeaders`; expose reviewed statements in `Properties.lean`. Do not assume the desired theorem as a field, use opaque proof shortcuts, or prove only concrete fixture instances.

- [ ] **Step 4: Complete boundary and error coverage.** Exercise first Etna children of Unzen parents, Etna-at-genesis, forced/default inherited anchors, changed anchors, source-internal and cross-source transitions, exact activation, default timestamps crossing activation, and proposal-time block limits. Check a second block consumes the first block's commitment, including when only the first anchor's L1 root is available. Check whole-proposal error propagation. Check empty/nonempty Etna candidate lists without special golden-touch handling; state that sender authentication/execution is outside this RLP-item model.

- [ ] **Step 5: Import every new definition/proof/test through the existing entry points.** Run `lake build`, the existing vector runner, `lake exe checkaxioms`, `bash scripts/gate.sh`, and `lake env leanchecker TaikoSpec`. Require no warnings, no forbidden proof constructs, only existing allowed axioms, and all original vector cases passing.

- [ ] **Step 6: Self-review and commit Task 2 files** with `feat(formal-spec): specify Etna header commitments`.

### Task 3: Document coverage, verify the integrated package and prepare publication

**Files:**

- Modify: `packages/formal-spec/README.md`
- Modify only if new imports are insufficient: `.github/workflows/formal-spec--test.yml`
- Review: all changed Lean modules and public properties against the approved spec.

**Interfaces:**

- Consumes: the executable model/proofs from Tasks 1 and 2 and their exact test output.
- Produces: accurate README, full fresh acceptance results, a clean tracked diff and a reviewable draft-PR body.

- [ ] **Step 1: Update README prose.** Describe Shasta/Unzen/Etna derivation, checked header-plan outputs, root inheritance, gas basis, layout and errors. Replace the old blanket exclusion of payload attributes with the exact covered fields and remaining boundary. Keep the trust distinction between model proofs, tested implementation correspondence and authenticated input assumptions. Add new modules to the layout table and update follow-ups without claiming full payload/execution verification.

- [ ] **Step 2: Run the complete package acceptance sequence once on the final code.** Commands, from `packages/formal-spec`:

```bash
lake build
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json
lake exe checkaxioms
bash scripts/gate.sh
lake env leanchecker TaikoSpec
```

Check each exit status and record the vector count, declaration count and kernel replay result. Also run `git diff --check` and the repository Prettier check for modified Markdown/YAML. Do not add a workflow job when the existing build, test imports and umbrella imports already cover the extension.

- [ ] **Step 3: Commit the documentation integration** with `docs(formal-spec): document Etna coverage and trust boundary`. Supply task report and exact validation output for task review.

- [ ] **Step 4: After task reviews and whole-branch review pass, update #22177.** Refresh `main` and the current #22177 head; verify the remote head is still an ancestor before publishing, and integrate any concrete remote updates without force-pushing. Verify mergeability and rerun affected verification for any integration changes. Push normally with `git push origin HEAD:feat/formal-spec-derivation`, then update #22177 using `gh pr edit 22177 --repo taikoxyz/taiko-mono --title 'feat(repo): specify Shasta, Unzen and Etna derivation in Lean' --body-file <prepared-file>`. Preserve its existing draft status and base. The body describes the final model, references #22189/#22263, includes the trust boundary and verified commands, and makes no unverified claim that clients ran new shared header vectors. Preserve the managed worktree for review iterations. Do not create a new PR.
