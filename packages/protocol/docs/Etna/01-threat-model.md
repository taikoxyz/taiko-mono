# Etna threat model

Phase 1 baseline, 2026-09-30. This file defines adversaries and proof obligations, not a claim that Etna already satisfies them. **Proven** means an argument or cited source supports the stated proposition; it does not mean deployed contracts or circuits have been formally verified. **Assumed** names an environmental condition. **Open** identifies a question that must be resolved before implementation readiness.

## Assets and security boundaries

| Asset | Required protection | Failure consequence |
|---|---|---|
| L1 and L2 Bridge ETH and Vault token custody | Only authentic, unspent remote messages authorize transfers | Direct theft or unbacked representations |
| SignalService checkpoints and received-signal cache | Only valid canonical execution roots enter the trusted checkpoint store | A forged root can authenticate an arbitrary bridge message |
| L2 canonical state and transaction order | Deterministic derivation; proof-bound state transition and data | State corruption, double-spend, proof invalidation |
| Soft preconfirmations | Locally checkable evidence, explicit rollback conditions and accountable promises | Users price stale state as final; private forks steal execution opportunities |
| Role collateral and rewards | Conservation, bounded liabilities, no duplicate or self-profitable slashing | Bond theft, unbacked compensation, cartel subsidy |
| Liveness and forced-inclusion queue | No indispensable permissioned actor; bounded work per action | Chain stall, censorship, queue starvation |
| Existing addresses and historic storage | Preserve custody, message statuses, canonical-token maps and signal slots across upgrades | Lost or duplicated withdrawals; destroyed token backing |

**Proven/source:** the current Inbox publishes end-block checkpoints through `saveCheckpoint` (contracts/layer1/core/impl/Inbox.sol:364–370), and current SignalService uses those state roots to verify the remote SignalService account/storage proof (contracts/shared/signal/SignalService.sol:271–295). Source paths in this document are relative to `packages/protocol/` unless otherwise stated.

## Actors and adversary capabilities

Untrusted actors include transaction senders, builders/sequencers, proof producers, proof submitters, availability signers, challengers, relayers, L1 builders/proposers, and any party funding many addresses. A single economic actor may occupy every nominal role and create unlimited addresses. Key possession is not identity independence.

The adversary may delay, reorder, duplicate or selectively relay P2P messages; sign conflicting messages; withhold data or completed proofs; obtain private order flow; front-run or copy public transactions; bribe L1 builders; spam all permissionless interfaces; censor its own L1 blocks; stop its machines; and buy or borrow collateral. It may exploit L1 reorgs and timestamp variation permitted by Ethereum. It cannot be assumed to lose more than its explicitly locked collateral.

The DAO is an upgrade authority, not an incident responder needed for continued operation. **Assumed A-UPGRADE:** deployed code and initial migration are honest; the DAO does not upgrade into malicious code. R1's allowed upgrade ownership necessarily retains this trust boundary. No finite protocol argument can survive an owner replacing the verifier with `return true`.

Protocol-authenticated contract calls (for example only the verifying Inbox may publish an L2 root) are capability boundaries, not a human/operator whitelist. Removing such authentication would violate bridge safety. The design must explain this distinction and remove discretionary operational gates, including inherited ones.

## Assumptions that must never be hidden

- **A-CRYPTO:** hash collision resistance, signature unforgeability and the soundness of the selected ZK verifier/circuit/public-input binding.
- **A-L1:** Ethereum execution validity and eventual finality; no permanent censorship of every honest submission. Bounded liveness additionally needs a stated inclusion/gas budget bound. Ethereum does not guarantee a particular private transaction inclusion time.
- **A-NET:** eventual communication between honest peers. A one-second healthy-network target is not a hard wall-clock guarantee during a partition.
- **A-EXEC:** at least one honest participant can execute/reconstruct the chain, acquire required data and generate the requisite proofs. All-prover shutdown cannot produce a fresh validity proof until some prover returns or enters.
- **A-ECON:** at least one participant finds the bounded recovery action affordable or subsidizes it. Fees/bonds do not imply rational participation at arbitrary gas prices.
- **A-ARCHIVE:** historic execution data needed by a new node remains retrievable, or an explicitly authenticated state/bootstrap procedure is available. Blob retention is finite.
- **A-COMMITTEE (if used):** any honest-stake threshold and synchrony assumptions must be stated numerically, including how membership changes. Permissionless registration is not evidence of an honest quorum.

All of these are assumptions rather than on-chain facts. Safety should fail closed if liveness assumptions fail. Economic deterrence must not be advertised as cryptographic prevention.

## First-class attack: private withholding followed by publication

Concrete baseline trace:

1. The currently accepted preconfer receives transactions and builds `H+1…H+k` privately on a valid parent.
2. Other nodes see only `H`; users transact against stale state, and a successor/prover builds on that view.
3. The preconfer privately gives its branch to a prover or releases it near an L1 landing/handover boundary.
4. If fork choice or L1 acceptance prefers the private branch, public work is discarded; if the protocol waits for that branch forever, the withholder halts liveness.
5. A signature proves authorship of a released block, not when every peer received it. Honest silence and malicious withholding can create the same observation at an isolated node.

**Proven/source:** current Go and Rust preconfirmation paths can defer missing-parent payloads and distinguish unsafe from L1-confirmed state (see the cited client notes). Current whitelisted proposer authorization expressly returns a zero slashing window (contracts/layer1/preconf/impl/PreconfWhitelist.sol:126–140). A blacklist/ejecter is not objective permissionless accountability.

**Proven/information argument:** take execution X where an operator broadcasts data but an adversarial network drops it, and execution Y where that operator never broadcasts. Before an authenticated response reaches L1, an L1 contract sees identical state in X and Y. A deterministic slashing rule cannot distinguish malicious withholding from that network failure. Therefore Etna may slash a missed, voluntarily bonded publication/response obligation, but cannot prove the mental act of withholding or promise zero false positives under arbitrary censorship.

Required design response:

- Define the precise signed availability/publishing promise and its expiry, with replay protection and an objective challenge/response record.
- Define what a node does on missing data: refuse soft confirmation, fetch bounded dependencies, stop extending unsafe state, and use an objective recovery path. Never synthesize a missing parent.
- Define whether a late branch remains eligible, and why privately created blocks cannot displace an already accepted public branch under the claimed assumptions.
- Bound all outstanding exposure by reserved collateral; include acquisition, reveal and evidence gas costs.
- Quantify detection only under explicit sampling/independence assumptions. For independent samples hitting an unavailable fraction `f`, false-negative probability is `(1-f)^k`; selective serving/adaptive availability invalidates that simple model. If every observer colludes, detection can be zero.
- Treat a response timeout as an objective service failure. Under a stated L1 inclusion bound it can have zero false positives for complying honest actors; without that bound the worst-case false-positive rate is 100%, not an invented small empirical percentage.

## Requirement-by-requirement falsification plan

| Requirement | Adversarial test |
|---|---|
| R1 | Leave DAO silent; remove every current operator; attempt fresh entry and recovery. Enumerate inherited owner/pauser/mint/resolver gates. Separate upgrade trust from operational dependence. |
| R2 | Replay old withdrawals; change syncer/router implementation; collide storage; substitute a root or remote service; test cross-version cache behavior and wrapper mint authority. |
| R3 | Set each role population to offline and then malicious. Require a transition or an explicit assumption-bound halt, not a trusted replacement operator. |
| R4 | Delay parents, execution, signatures and proofs; measure issuance vs receipt vs execution latency. Break an unconditional one-second claim with a partition. |
| R5 | Change L1 intervals to 6, 4 and 2 seconds; remove every lookahead provider; inspect all deadlines and assignments for hidden constants. |
| R6 | Split stake across addresses, self-challenge, duplicate evidence, exit before evidence arrives, censor honest responses, claim more liability than collateral, bribe reward recipients. |
| R7 | Withhold a proof mid-window; release a stale proof; front-run its reward; change forced-queue tail while proof is computed; exhaust blob retention/transaction gas; submit proof without available data. |

## Additional concrete attack families

1. **Root substitution:** proof verifies execution but omits chain ID, inbox address, revision, old head, new root, data commitment or force-queue cursor from public inputs.
2. **DA/proof mismatch:** prove data A but publish blob B; accept a blob hash without binding the actual derived byte stream; make recovery data economically impossible to reveal.
3. **Forced-inclusion invalidation:** make every new force request change an in-flight statement; attackers invalidate minute-long proofs at second-level cost.
4. **Timeout split:** two public branches claim the same head after a timeout; late quorum certificates conflict with permissionless recovery.
5. **Exit race:** collateral leaves before a hidden signed promise becomes challengeable; one bond backs many simultaneously slashable duties.
6. **Self-slash arbitrage:** challenger, responder and reporter are one actor; compensation creates profit exceeding burned collateral or returns all punishment.
7. **Proof laundering:** public proof copied with a different beneficiary; cheap grief submissions reserve a unique right without delivering.
8. **Monopoly by Sybil:** per-address caps or cooldowns are evaded at linear or zero identity cost. Attribute guarantees to capital/time costs, never distinct addresses.
9. **Governance-in-disguise:** an owner-only pauser, resolver update, token mint, emergency recovery or oracle quietly remains necessary.
10. **Shared-storage migration:** an implementation change shifts inherited fields, clears a signal cache without corresponding checkpoint policy, or exposes a historical admin selector through a fork router.

## Open baseline questions

Live deployment addresses, owners, verifier wiring and parameter values were not authenticated from the initial source checkout. The baseline describes code, not a live-state audit. The referenced nonce-lock PDF has not been supplied. External EIP/fork claims belong in the Phase 2 survey with retrieval dates, not in this threat model as remembered facts.

## Anchor-removal extension — 2026-10-01

The revised design removes signed anchor transactions. Its additional attack surfaces are authenticated header equality, canonical EIP-4788/2935 code and build/import/prover parity, transient timestamp-ring expiry, durable origin pins, header-preimage parsing, first-block legacy writer retirement and old consumer assumptions. [Checkpoint persistence](design/checkpoints.html) and [migration](design/migration.html#legacy-writer-gate) specify the predicates. A mere nonzero L2 header field is not provenance; a matching full L1 origin is required. An ordinary caller cannot supply the pinned hash, impersonate the standard system caller, overwrite an existing conflicting checkpoint or use the L2 extension on L1.

The concrete long-backlog attack queues a fixed-timestamp reveal, waits for a modulo8191 overwrite and makes the eventual execution revert. The fixed-calldata current-origin pin survives that delay, and its later header reveal has no expiry. This closes checkpoint acquisition's transient deadline, not arbitrary bridge proof-size, fee, archive or finality constraints. Historical permanent Anchor data remains stored but ceases updating; consumers must stop treating its getters/events as a current-origin oracle. New system contracts are not new Bridge, SignalService or Vault addresses.
