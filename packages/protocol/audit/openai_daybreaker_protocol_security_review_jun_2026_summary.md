# OpenAI Day Breaker (Codex) Review — Pre-Mainnet Triage Summary

Concise triage of the OpenAI Day Breaker / Codex Security scan
([full report](./openai_daybreaker_protocol_security_review_jun_2026.md), 9 findings:
5 high / 4 medium).

**Important:** the scan ran against revision `32abaf74…`, which is **not** in this
branch's history. Every finding below was **re-verified against the current branch
code** (`packages/protocol/contracts`). Two of the five "high" findings are already
fixed here; the line references are from the current files.

## TL;DR

- **Fix before mainnet:** 2 confirmed missing checks in the preconf `LookaheadSlasher`
  path (#4, #5) + review the related reference-timestamp convention (#1). These gate
  **enabling URC-based preconfirmation slashing**.
- **Already fixed on this branch:** forced-inclusion consumption (#2) and permissionless
  proving fallback (#9). No action — keep regression tests.
- **Deployment/config gate, not a code change:** SGX enclave-identity enforcement (#3).
- **Decisions to confirm (lower urgency):** TaikoToken delegation hook (#8, real residual
  code fix), ejecter role split (#6), Anchor golden-touch trust boundary (#7, by design).

## Fix before mainnet — confirmed real bugs (preconf slashing)

These all live in the URC/preconf slashing surface. They produce **false slashing of
honest operators' collateral**, so they must be fixed before URC-based preconf slashing
is turned on. (Note: the whitelist preconfer path does not slash today —
`PreconfWhitelist.checkProposer` returns `0` — so the live blast radius depends on which
preconf mode mainnet launches with.)

| # | Severity | Issue | Location (current branch) |
|---|---|---|---|
| 4 | High | **`proposerLookaheadRoot` is never anchored to the beacon state.** The struct field `proposerLookaheadRootProof` is declared but **never read** anywhere; `validatorIndexProof` is verified against a *caller-supplied* `proposerLookaheadRoot`, so a forged proposer assignment passes. Confirmed: the field has exactly one occurrence in the whole contracts tree (its declaration). | `layer1/preconf/libs/LibEIP4788.sol:29-31`, `:92-100`, `:102-111` |
| 5 | High | **Missing lower bound on the chosen lookahead slot index.** Validation only enforces `slotTimestamp ≤ selected.timestamp` and `slotTimestamp ≥ epochStart`. An attacker can point an *earlier* slot's timestamp at a *later* slot index → `lookaheadSlot.timestamp != slotTimestamp` → the code wrongly takes the missing-operator branch and slashes. Add a lower-bound check (`> previous slot timestamp`) or derive the index from the timestamp. | `layer1/preconf/impl/LookaheadSlasher.sol:119-127` and branch at `:65-80` |
| 1 | High | **Likely reference-timestamp convention mismatch.** The slasher passes `previousEpochTimestamp − 2·SECONDS_IN_SLOT` into `isLookaheadOperatorValid`, which forwards it **unadjusted** to `_validateLookaheadOperator` — and that helper subtracts a further `2·SECONDS_IN_EPOCH`. When the lookahead was *posted*, the operator was validated at `nextEpoch − 2·epochs`. These don't line up, so eligibility can be checked at the wrong historical instant. Confirm the intended reference and add epoch-boundary tests. | `LookaheadSlasher.sol:234-241` vs `LookaheadStore.sol:345-360`, `:501-519` |

## Already fixed on this branch — verify only

| # | Severity (report) | Status | Evidence |
|---|---|---|---|
| 2 | High | **Fixed.** Forced inclusions are consumed again: `_validateProposeInput` no longer rejects `numForcedInclusions`, and `_consumeForcedInclusions` now *requires* all due entries be processed (`UnprocessedForcedInclusionIsDue`). | `Inbox.sol:713-715`, `:597-608` |
| 9 | Medium | **Fixed.** `_checkProver` now takes `proposalAge`; a non-whitelisted prover is allowed once `proposalAge > permissionlessProvingDelay`, even with `proverCount > 0`. | `Inbox.sol:274`, `:722-738` |

Keep the report's suggested regression tests for both (forced-inclusion head advancement;
non-whitelisted prove-after-delay) so these don't regress.

## Deployment / configuration gate (no code change required)

| # | Severity | Item | Notes |
|---|---|---|---|
| 3 | High | **SGX enclave-identity (`MRENCLAVE`/`MRSIGNER`) checks are optional and off by default.** `checkLocalEnclaveReport` defaults to `false` and `registerInstance` is now **fully permissionless** (the old `registrar` gate is gone). | `AutomataDcapV3Attestation.sol:37`, `:407-411`; `SgxVerifier.sol:113-124`. Mainnet **must**: enable `toggleLocalReportCheck`, populate `trustedUserMrEnclave`/`trustedUserMrSigner`, and rely on multi-proof composition so a single compromised SGX branch can't finalize alone. Consider failing closed in code (reject registration when the check is off / allowlists empty) as defense-in-depth. |

## Decisions to confirm (lower urgency)

| # | Severity | Item | Recommendation |
|---|---|---|---|
| 8 | Medium | **`delegateBySig` bypasses the non-voting-account guard.** Only `delegate(address)` is overridden; `delegateBySig`/the internal `_delegate` hook are not, so third-party votes can still be checkpointed onto a non-voting account. `getPastTotalSupply` then subtracts `super.getPastVotes` (raw delegated votes), lowering the governance quorum denominator below intent. The current `getPastVotes` override (returns 0 for non-voting accounts) does **not** close this. | Enforce the invariant on the shared `_delegate` hook (covers both paths), or subtract only the accounts' own balances in `getPastTotalSupply`. `TaikoToken.sol:83-90`, `:118-125` |
| 6 | Medium | **Ejecter can also add operators.** `addOperator` and `removeOperator` share `onlyOwnerOrEjecter`. If ejecter is meant to be removal-only, split admission/removal into distinct roles. Bounded by `OPERATOR_CHANGE_DELAY` and trusted ejecter assignment. | `PreconfWhitelist.sol:94-103` |
| 7 | Medium | **Golden-touch can write Anchor checkpoints.** The signer key is public **by design**; anchor-tx correctness is enforced by derivation/proving, and L2 checkpoints are unsafe until proven on L1. Treat as accepted design — document the trust boundary and confirm no bridge/signal consumer trusts an unproven checkpoint. | `Anchor.sol:115-118`, `:154-173` |

## Out of scope / no issue

The scan reported **no issues** in bridge/SignalService message handling, ERC20/721/1155
vaults and bridged tokens, resolvers/controllers/fork-routers, and the ZK verifier
wrappers (RISC0/SP1 flagged only as deployment-config trust, not a bug). No action.
