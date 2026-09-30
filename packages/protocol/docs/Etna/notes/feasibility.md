# Feasibility boundary: based sequencing, soft preconfirmations and withholding

Research date: **2026-09-30**. Scope: supporting Phase 2 analysis, not a red-team convergence round, implementation specification or claim that R1–R7 have passed. Inputs: [current system](../00-current-protocol-summary.md), [threat model](../01-threat-model.md), [based boundary](based-sequencing-boundary.md), and the user's requirements. All numerical examples below are illustrative rather than selected Etna parameters.

**Classification convention.** **Proven** marks a deduction with its stated premises or a directly inspected source fact; **Assumed** names an environmental/cryptographic/economic premise; **Open** requires a design decision, measurement or further proof. “Proven” does not mean mechanically verified.

## 1. Recommendation and the exact boundary

**Proven/deduction:** there is no demonstrated impossibility of R1–R7 merely from one-second soft preconfirmations, minute-long proofs, no CL lookahead and strict based sequencing. A valid soft block is an executable signed claim relative to a known parent and L1 view; it need not be irrevocably canonical. An open L1 action carrying data and a valid proof can replace an incompatible soft tail. Healthy-network one-second issuance is a target, not a guarantee during an arbitrary partition. None of those distinctions contradicts the literal R4/R7 acceptance criteria.

**Proven/deduction:** an open proof race does **not** make prior P2P dissemination objectively necessary. If a party's first public protocol act includes both valid data and proof, the contract cannot distinguish a batch privately prepared for three minutes from a batch publicly prepared for three minutes merely by looking at that act. Bonding the submitter does not add this missing evidence.

**Recommendation, conditional on interpretation:** preserve strict based sequencing with an always-open proof-bearing landing action; make soft availability witnesses advisory to canonical admission; and slash precisely defined signed equivocations and missed on-chain publication/response obligations. Describe the resulting soft blocks as provisional execution-valid blocks that can be displaced by L1 ordering. This is a plausible construction direction, **not** a pass declaration for the user's withholding requirement. It is honest only if the design explicitly accepts privately prepared, first-revealed-at-landing branches as a remaining attack and does not call their mere existence a proven slashable offense.

**Open, requiring an architectural choice:** if “make withholding detectable and punishable” means that every damaging private-before-landing fork by an economically active participant must incur an attributable penalty, advisory witnesses are insufficient. Mandatory independent ordering certificates supply a stronger guarantee under honest-quorum assumptions, but create an independent sequencing liveness dependency. An independent committee with a delayed escape is not strictly based under the definition below. A prior canonical L1 order commitment could remove that committee dependency, but may reintroduce the separate proposal-before-proof stage that R7 intends to replace. This is a precise mechanism boundary; it is not a theorem that the user's unstrengthened R1–R7 are inconsistent.

## 2. Definitions that prevent a false impossibility result

**Proven/source:** the original [based-rollup definition](https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016) permits the next L1 proposer, collaborating with L1 builders/searchers, to permissionlessly include the next rollup block in the next L1 block. Its simplicity discussion excludes external PoS sequencing consensus. That source and the [2026 hybrid discussion](https://ethresear.ch/t/combining-preconfirmations-with-based-rollups-for-synchronous-composability/23863) were retrieved live by the parent research task on 2026-09-30 and are recorded in [the boundary note](based-sequencing-boundary.md). This supporting agent's independent direct HTTP retry was blocked by the environment network policy; it does not claim an additional independent retrieval.

**Definitions used in the arguments:**

| Term | Precise meaning |
|---|---|
| Strictly based admission | A ready valid next-batch proof/data action can be included by any current L1 proposer without obtaining a fresh independent committee signature or waiting for an exclusive external sequencer lease to expire. |
| Locally valid soft block | Complete signed payload, known valid parent, eligible soft signer under the node's named L1 registry view, valid timestamp/anchor fields, and matching reexecution result. It may cease to be canonical when L1 selects another branch. |
| Soft availability certificate | Signed claims that named witnesses possess and will serve specified committed data. A certificate does not replace local execution and, in the advisory construction, does not constrain canonical L1 ordering. |
| Canonical ordering certificate | A quorum commitment that the contract requires before accepting a new canonical branch. This is a sequencing authority, even if membership is permissionless. |
| Withholding intent | The unobservable decision not to disseminate data that the actor possesses. |
| Objective publication failure | Failure to answer an authenticated, bounded publication obligation by an L1-observed deadline. This is slashable without proving intent. |
| Proof readiness | The proof and DA payload already exist and match the currently admitted parent. Strict basedness cannot make minute-long proof computation instantaneous. |

**Proven/deduction:** a node lacking a parent cannot immediately execute a child. “Immediately and locally” must mean validation as soon as the node has the bounded necessary data and execution completes, without waiting for L1 landing. Labeling a missing-parent payload “not yet checkable” respects that requirement more accurately than calling it valid or invalid.

**Proven/source:** the current source separates proposal admission from proof acceptance: `packages/protocol/contracts/layer1/core/impl/Inbox.sol:577–623` constructs proposal metadata and invokes a proposer checker; `:342–350` checks continuity and proposal commitments; `:364–398` publishes the checkpoint and verifies the proof atomically. `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:136–140` selects the allowed proposer and expressly disables its slashing window. These paths were spot-checked directly for this note.

## 3. Exact assumptions

| Name | Assumed condition | Needed for |
|---|---|---|
| F-CRYPTO | Signature unforgeability, collision resistance, sound ZK verifier and correctly bound execution program | All safety statements |
| F-L1-SAFE | Ethereum execution validity and eventual finality, with explicitly handled reorgs | Canonical state and bridge roots |
| F-L1-INCLUDE(ΔL) | After stabilization, an adequately priced bounded transaction that remains valid can be included within ΔL seconds | A finite response deadline and bounded recovery latency |
| F-NET(ΔN) | After stabilization, honest peers receive available data within ΔN seconds | Healthy one-second issuance/receipt target, witness dissemination |
| F-EXEC | Honest nodes can execute the chosen block gas limit within the advertised validation latency | Honest local execution-valid preconfirmation |
| F-PROVE(TP) | Some entrant can acquire the data and produce the mandatory proof within TP seconds at a sustainable cost | Minute-level landing and prover replacement |
| F-FUND | At least one honest actor can finance required gas, collateral and proving costs | Economically executable permissionless recovery |
| F-ARCHIVE | Required historical state/data can be reconstructed or authenticated | Fresh node/prover entry |
| F-Q, only with committees | Less than one third of active voting weight is Byzantine, honest votes follow a correct locking protocol, membership transitions preserve its safety, and sufficient honest weight is online | BFT ordering/availability guarantees |
| F-UPGRADE | Honest initial migration and no later malicious upgrade | Any design with DAO-owned upgradeability |

**Proven/deduction:** F-L1-INCLUDE applies only while a transaction remains valid. An honest proof invalidated by an earlier competing batch is not protected by this assumption. “Ethereum eventually includes honest transactions” is therefore not a proof that an honest branch eventually wins an unrestricted moving-parent race.

**Proven/deduction:** no one-second safety/finality or unconditional participation claim follows from these assumptions. All proof producers can stop; the chain then cannot produce a new validity proof until one returns or a new participant enters. Permissionless replacement is a mechanism; actual available computation is an assumption.

## 4. Candidate A: strict based admission with a soft service layer

### 4.1 Construction sketch

**Proposed mechanism; security arguments below are conditional:** a permissionless registry admits bonded soft publishers and optional availability witnesses. Assignment uses a finalized L1 registry snapshot and a seconds-based schedule without validator lookahead. Its authority applies to the advertised soft service, not to who may land a proof. The precise unbiased assignment and economic concentration controls remain **open**.

A publisher signs a domain-separated envelope binding chain ID, revision, parent, L2 height, timestamp, execution result, data commitment and service round. Nodes request complete data, authenticate the named soft right, execute the block and label it provisional. Witnesses may sign data-possession/service obligations and gossip the data. An L1 participant may submit any proof/data batch extending the canonical L1 head and satisfying immutable forced-inclusion obligations; a soft certificate is not required. Only accepted proof roots reach SignalService. A failed soft service cannot stop canonical admission.

**Proven/deduction:** this construction has a clean role-failure distinction. If all soft publishers/witnesses disappear, soft one-second service disappears until permissionless entry restores it; canonical proof-bearing admission remains open. If all proof producers disappear, canonical progression stops under F-PROVE's failure. If every incumbent role is malicious, correctness still depends on proof soundness, but availability and progress need a new funded honest entrant. It does not require DAO action.

### 4.2 What can be slashed honestly

**Proposed, objectively checkable obligations:**

- Two signed incompatible promises for the same explicit `(chain, revision, serviceRound, height, parent)` domain: signature evidence proves equivocation.
- A signed commitment to serve a bounded blob or chunk, followed by a funded L1 challenge and no matching L1 response by a fixed timestamp: contract state proves a missed response duty.
- An voluntarily accepted proof-service job with a frozen parent/input commitment and deadline, whose result is not delivered according to the agreed objective conditions: contract state proves a service breach. The duty must explicitly handle a third party making its job stale, or an honest provider can be slashed for an event it cannot prevent.

**Open:** an actual design must specify escrow accounting, maximum simultaneous liability, challenge deposits, response bytes/gas, permitted third-party responses, replay domains, payouts and withdrawal delays. These sketches alone do not satisfy R6's implementation bar.

**Proven/deduction:** a publication challenge does not establish when data was first made available. A response before the deadline establishes availability by the response, not prior honest gossip. Anyone able to relay a matching response should be permitted to do so: otherwise censoring one account creates needless false slashes.

### 4.3 Detection and error rates

**Proven under stated premises:** if F-L1-INCLUDE and F-NET hold, a compliant bonded party detects the challenge, possesses the committed data, can fund publication, and the response deadline exceeds detection plus publication inclusion and a specified margin, then a correctly implemented timeout rule has zero false positives **within those premises**. Dropping any required bound permits a worst-case false-positive rate of 100%; no empirical percentage can be inferred from this reasoning.

**Proven/deduction:** a persistent unavailable claim is detected with probability one only if at least one funded honest challenger sees the claim, requests the relevant committed material and can get the challenge included. If all observers collude or nobody can afford the challenge, detection can be zero. The worst-case false-negative rate for “withhold, then reveal before the challenge deadline” is 100%. Its response is protocol compliance with that particular deadline, even if users or provers already suffered a rollback.

**Assumed sampling model:** for k independent nonadaptive samples, each hitting an unavailable fraction f, the probability of missing it is `(1-f)^k`. Adaptive selective serving or correlated witnesses invalidates this model. Stake-weighted quorum signatures do not establish independent observations merely because they come from different addresses.

### 4.4 Concrete trace A1: private branch wins despite honest advisory witnesses

**Preconditions:** open competing branches; 180-second proof latency; witnesses are advisory; no earlier canonical L1 commitment fixes the soft branch. Assume both proofs are sound.

1. At t=0 canonical head is H. Honest publisher P publicly builds a transaction-rich branch X and obtains honest availability receipts.
2. Attacker M privately builds Y from H, omitting X's unforced transactions. M gives Y only to its own prover.
3. At t=180 M lands Y with complete DA and a valid proof before X lands.
4. X's proof no longer extends the canonical head; X's soft blocks roll back. Every honest witness truthfully possessed X and may have served it perfectly.
5. M answers any subsequent challenge for Y using the data it has just published. No contradictory signed obligation is required for M to win.

**Cost/gain:** one valid private proof, DA and inclusion payment; gain can be ordering/MEV or competitors' lost proving cost. M may be an active provider under a different address; permissionless identity rules do not establish common economic ownership. **Requirement effect:** does not by itself falsify R4 or R7, which permit soft confirmations. It falsifies any claimed guarantee that advisory witnesses prevent or necessarily punish private-fork displacement. Under a strict interpretation of the user's withholding mandate, this is a blocking gap.

### 4.5 Concrete trace A2: slash-the-soft-publisher compensation becomes griefing

**Preconditions:** try to fix A1 by slashing P whenever any canonical branch differs from P's publicly promised branch.

1. P honestly broadcasts X and funds its proof.
2. M prepares cheap branch Y and lands it first.
3. The global “promise not canonical” predicate slashes P even though P neither equivocated nor withheld.
4. M repeats against new providers, or does so through a fresh address every round.

**Cost/gain:** the cheaper proof/landing cost versus the value of the forced provider loss; indirect gain includes excluding competitors. **Requirement effect:** R6's accountability is not evidence of P's misconduct; R1 entry may remain syntactically open while the service is economically unsustainable. Calling the bond “insurance” makes its terms honest, but does not prove adequate bond pricing or prevent adversarial exhaustion. **Open:** a limited, explicitly priced insurance market could still be useful, but is not a free repair.

### 4.6 Concrete trace A3: cheap empty-proof grinding

**Preconditions:** each batch may choose an arbitrary optional transaction list; its statement binds the current parent; empty/simple batches are much cheaper to prove than transaction-rich batches.

1. Honest prover starts a 180-second proof for X from H.
2. M computes a minimal valid branch in 10 seconds and lands it from H.
3. Honest prover restarts from the new head; M repeats at each cheaper interval.
4. Canonical L2 height advances, but the honest optional transaction set never lands.

**Cost/gain:** repeated cheap proofs and L1 fees; gain is censorship, resource advantage or MEV. **Requirement effect:** this is not automatically a total liveness halt—the attacker is advancing the chain. It defeats an argument that open proof access alone guarantees honest proof success or ordinary mempool inclusion. Per-address cooldowns are Sybil-bypassable. A per-batch fixed reward may subsidize the attack. Frame transaction validity checks may save stale transaction gas but do not refund discarded proving work.

## 5. Forced inclusion can survive the open race

**Proposed mechanism with a useful proof obligation:** when batch N lands, the contract records the L1-visible forced queue tail/commitment and an eligibility cutoff for its successor N+1. Every valid child proof must execute a bounded due FIFO prefix derived from that **immutable parent-created snapshot** before optional transactions. Enqueues that arrive while N+1 is being proved belong to a later snapshot and cannot change N+1's statement. The snapshot is ancillary successor job metadata; the ordinary batch N data and proof still land together. This does not require a separate commitment to the optional contents of N+1.

**Proven/deduction:** if all valid successors of a parent must execute the same due forced prefix, it does not matter which competing branch wins for inclusion of that prefix. An empty grinding winner cannot skip required expensive forced work. Current-source due FIFO checking is at `packages/protocol/contracts/layer1/core/impl/Inbox.sol:650–673`, but it reads landing-time timestamps; copying it unchanged into a precomputed proof statement would create a moving-input problem. The snapshot modification is a design direction, not an assertion that current code implements it.

**Assumed/open liveness bound:** there must be finite service capacity, bounded admissible work per queue entry, funded proof/DA cost, continued canonical advancement, and a congestion assumption. An enqueue just missing a snapshot waits through the current job and a subsequent snapshot. Queue admission cannot promise a uniform delay while adversaries purchase unbounded earlier work. Protocol parameters need a bound in seconds/jobs under a specified backlog and fee budget; “576 seconds” copied from today's code would not prove one.

**Proven/deduction:** forcing every user transaction through L1 before any preconfirmation would also reduce ordering ambiguity, but would move ordinary transaction latency back to L1 and add L1 DA cost for all traffic. One-second empty blocks between L1 arrivals would not substantiate an attractive one-second user experience. This is a rejected tradeoff to disclose, not an impossibility proof or a recommended way to satisfy R4 on paper.

## 6. Candidate B: canonical BFT sequencing with a timeout escape

### 6.1 Construction and benefits

**Proposed mechanism:** bonded membership is open. A properly specified BFT protocol produces quorum certificates for a common soft sequence, using timeouts measured in seconds and no CL lookahead. Honest signers execute and retain the data before voting, and gossip their votes/data. L1 admits a proof-bearing batch only when its sequence carries a valid canonical quorum certificate. Any prover may execute/prove the certified batch. A timeout escape eventually advances a contract generation and permits certificate-free recovery.

**Proven under F-Q and a correct BFT locking rule:** a quorum intersection contains honest voting weight, so incompatible committed branches cannot both be certified; at least one honest certified-data holder can disseminate the branch under F-NET. A producer that sends only to a quorum has not successfully kept the branch private from all honest peers under those premises. Exact bounds depend on dissemination and the availability obligation. A raw 2/3 signature threshold without a view-change/locking protocol does not prove BFT safety.

**Proven/deduction:** permissionless committee entry can satisfy the no-whitelist part of R1. It does not preserve strict based sequencing: an L1 proposer with valid data and proof is refused while the required certificate is absent. A timeout escape reduces the dependence's duration but does not erase it. This may be a reasonable design if the user permits an independent permissionless sequencer; it must be named accurately.

### 6.2 Concrete trace B1: unavailable quorum gates an otherwise ready L1 batch

**Preconditions:** certificates required; recovery allowed after 600 seconds.

1. Canonical head H is established; a permissionless prover has a valid next proof and public data at t=180.
2. Committee voting weight needed for a quorum goes offline, or simply declines this branch.
3. Every L1 proposer must reject the ready batch until t=600 or until a certificate appears.
4. A recovery action becomes possible at t=600, subject to L1 inclusion and proof suitability.

**Cost/gain:** temporary committee outage or sufficient committee control; gain is at least the interval's censorship or outage. **Requirement effect:** violates the strict basedness interpretation for t in [180,600), even if eventual R1 liveness is restored without the DAO. This is an architectural mismatch, not a proof that a permissionless BFT rollup is unsafe.

### 6.3 Concrete trace B2: late certificate crosses recovery

**Preconditions:** escape and certificates are not bound to a contract generation with disjoint admission rules.

1. A quorum signs X, but X's certificate or proof is delayed. Other nodes treat X as soft confirmed.
2. After the escape timeout, a party lands certificate-free Y from the same canonical parent.
3. The certificate for X is revealed later. If L1 still accepts it against old conditions, canonical admission conflicts. If L1 rejects it, X's soft confirmations roll back.

**Cost/gain:** delay/censor one path long enough to trigger recovery; gain is reorgs or invalidated proving work. **Requirement effect:** no automatic violation if clients explicitly treat these confirmations as revocable through recovery and proofs bind the active generation. It violates a false claim of unconditional BFT soft finality or any bridge path using an uncertified/unproven root. **Required repair direction:** one objective L1 generation/head decides admission; old-generation proofs are stale. The user-facing finality statement must explain escape-driven rollback.

### 6.4 Concrete trace B3: anti-monopoly by address cap

**Preconditions:** maximum voting weight or winning turns are capped per registered address, while entry is permissionless and identities are not linked.

1. A capital-rich actor splits one economic position over 100 keys.
2. It registers each key and obeys every individual cap/cooldown.
3. Its aggregate chance/weight remains dominant, or increases if weights are concave per address.

**Cost/gain:** per-key registration and minimum bonds; gain is committee/sequencing capture. **Requirement effect:** falsifies any R6 monopoly-deterrence argument based only on per-address caps. Rotation can spread opportunities per unit of collateral; it cannot prove distinct ownership. **Open:** the acceptable concentration assumption, nonrefundable competition costs, capital lock duration, delegation rules and reward design must be chosen explicitly.

## 7. What is actually impossible, and what is not

| Claim | Result and argument |
|---|---|
| Distinguish intent to withhold from identical network censorship using only the eventual L1 record | **Proven impossible:** identical on-chain transcripts produce identical deterministic judgments. Slash missed duties, not unobservable intent. |
| Never slash a compliant responder under arbitrary L1 censorship while also always slashing silent responders after a finite timeout | **Proven impossible:** the contract cannot distinguish a censored valid response from no response. An inclusion assumption or a weaker guarantee is necessary. |
| Advisory witnesses alone prevent every private canonical branch | **Proven false:** trace A1 has truthful honest witnesses and still accepts the competing branch. |
| Mandatory independent sequencing certificates plus delayed escape provide strict immediate L1 sequencing authority | **Proven false under the stated definition:** trace B1 contains a ready valid proof that the L1 proposer cannot include without waiting. |
| Anonymous per-address caps guarantee independent economic operators | **Proven false:** trace B3. Resource-proportional competition and explicit concentration assumptions remain possible. |
| One-second execution-valid soft blocks plus minute-long atomic proof landing require lookahead | **Not established:** soft service authority can be separate from L1 landing authority, at the cost of explicit rollback risk. |
| R1–R7 themselves are mutually inconsistent | **Not established:** their literal acceptance criteria do not require irrevocable one-second ordering or zero-error withholding detection. The intended strength of the withholding/based promises remains the decisive interpretation. |

## 8. Advice to the design author

**Recommendation:** do not silently strengthen “soft” into final, and do not silently weaken “withholding accountability” into a claim that all private forks are punished. Choose and write the exact guarantee before claiming a gate passes.

1. If strict basedness is retained, use advisory soft-service certificates, unconditional public proof admission, parent-frozen forced work and strictly attributable slashes. Disclose A1/A2/A3 and use a conditional availability/service guarantee. Evaluate whether the user's withholding requirement accepts that risk.
2. If canonical preconfirmation ordering is the priority and an independent committee is acceptable, specify a full BFT locking/membership/timeout protocol, a quorum availability premise and one L1-authoritative recovery generation. Describe it as permissionless committee sequencing with an L1 escape, not as strict inherited L1 sequencing liveness.
3. Treat Frame Transactions as a submission-cost mechanism subject to the separate research verdict. They do not provide global gossip timestamps, economic actor identity, discarded-proof reimbursement or a canonical choice among off-chain branches.
4. Do not publish a negative verdict until the exact disputed guarantee is resolved. If the required guarantee is universal pre-landing accountability while retaining open L1 branch admission and no earlier canonical commitment, the indistinguishability/private-submitter argument above identifies the extra impossible combination. The smallest relaxation is to accept objective service-failure accountability and explicit soft rollback, or to permit a canonical ordering commitment/committee.

**Open:** this note does not choose final parameters, prove economics, specify all role lifecycles, or replace full adversarial rounds. It supplies concrete falsification targets and separates ordinary assumptions from a real information/admission boundary.
