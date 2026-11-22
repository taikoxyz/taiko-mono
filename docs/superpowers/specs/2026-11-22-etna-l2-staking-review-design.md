# Etna L2 staking verification design

## Intent and source

Continue the existing verification project against unmerged design PR22425,
commit `69e26df443e9b5a0f05127d4179e4833fc95823c`, based on
`3602629758beb653423a23608fd1960810efcfac`. The direct user continuation
explicitly follows discovery that this draft moves staking and committee
selection to L2. Old groups remain complete at their own source versions.

This is verification tooling, not a protocol implementation or a change to the
normative design. The draft remains outside the existing runtime/product
classifier. Passing a new abstract model cannot promote old runtime receipts.

## Approach

Use a separate `formal/etna/draft_rules` namespace for a finite symbolic model
of the changed state transitions, plus independent source review and behavioral
probes. Retain the existing models, native producers, five accepted document
bundles, claims and source-only ledgers unchanged. Porting old epoch/Registry
models in place would erase their original evidence. Admitting an unmerged
draft into runtime claims would grant unsupported execution credit. Neither is
needed to test the new abstract transition rules.

The model represents already-authenticated anchors and symbolic validated keys.
It does not implement curve validation, signatures, storage/MPT authentication,
EL execution, token transfers, DAO message delivery or actual Comet priority.
Small-unit traces are conditional finite checks, not a proved quotient of the
production token supply or complete protocol state space.

## Selected checks

- Block-start miss counting, penalty and snapshot precede ordinary transactions.
  A block-start penalty affects H+2; transactions in X affect X+3.
- Misses use the parent's live key-to-seat mapping, including seat release/reuse
  and a fallback key that also owns a bond. Failed calls change no call-owned
  state but do not prevent ordinary transactions.
- Candidate selection checks the full stored snapshot height, key/power set
  shape and exact total power, threshold and explicit maximum-uint256 sentinel.
  The origin keys sign the first two blocks; later decisions use each anchor.
- Complete set differences and repeated candidate/fallback switches retain no
  departed key or old-generation pending update.
- A range proof requires its terminal commit and every interior commit whose
  successor has a different key/power set. A power-only change counts; a mode
  label or snapshot change with identical keys/powers does not.

## Evidence and limits

Two independent source reviews inspect committee and penalty/exit interfaces.
A separate verifier freezes source-derived expectations before model execution;
actual guard faults must be detected semantically, with exact restoration.
All execution uses inspected disposable offline copies and existing managed
Python. No package installation, native engine, proof job or live operation.

Record the exceptional verifier-repair identity obligation separately: a repair
that voids a bond issuance must preserve identity or prevent an old canonical-L1
forfeiture authorization from targeting a different issuance. This is not a
confirmed normal-path defect; concrete repair/transport semantics are missing.

The concrete staking/EL/guest implementation, 128-record authentication,
128-to-128 Comet replacement, 30M system-call proving cost, per-block signature
cost, archive retention and operating budgets remain separate obligations.
