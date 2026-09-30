# Frame Transactions: mutual exclusion without charging losing transactions

Research date: **2026-09-30 UTC**. This report evaluates the live EIP text retrieved on that date, not a remembered January proposal. The user-referenced **“Nonce as a Lock: Same-Slot Proposer Races with Frame Transactions” PDF was not supplied**; `inputs/README.md` records that gap. The nonce-lock construction below is our independent reconstruction of the hypothesis, not a review or endorsement of the absent PDF. “Same action” replaces “same slot”: Etna must not use CL slots for assignment or timing.

**Verdict: possible at Ethereum consensus level under the current EIP-8141 draft, with consequential limits.** A shared sender and nonce make alternatives mutually exclusive for inclusion. A terminal `VERIFY` frame can additionally ensure the included transaction completed the intended action, so failed execution cannot burn the shared nonce. That stronger construction is **outside the specified public mempool policy**. Public propagation of general, expensive proof races with the same properties needs policy/specification changes, or a separately established cheap validation construction. Etna should use this as an optional submission optimization with an ordinary public transaction fallback; neither liveness nor proof soundness should depend on a builder accepting it.

## 1. Claim labels, current status, and source discipline

**Proven** below means either a direct proposition of the cited draft or a deductive consequence under its semantics, not that Ethereum has deployed it. **Assumed A-FRAME** means the launch fork implements those semantics faithfully. **Assumed A-BUILDER** means a reachable builder accepts and simulates non-public-policy frame transactions and includes a valid, adequately priced one. **Open** means missing specification, measurements, implementation verification, or an input required for stronger claims.

| Item | Verified observation on 2026-09-30 | Implication |
|---|---|---|
| EIP-8141, “Frame Transaction” | **Draft**, created 2026-01-29; live page retrieved in full, fetch metadata dated 2026-09-28 [S1] | Semantics can still change; pin/review launch revision |
| Target fork | **Hegotá: Scheduled for Inclusion**, listed in EIP-8081 [S2]; ethereum.org also labels it scheduled [S3] | Scheduled does not mean shipped or immutable |
| Fork date | ethereum.org says Q2 2027, “Date not yet confirmed,” and the prose says planning [S3] | Forecast, not an Etna launch guarantee |
| EIP-8250 keyed nonces | Draft; **Considered for Inclusion**, not required [S2, S8] | Separate nonce domains are optional, and do not relax one pending transaction per sender |
| EIP-8272 recent roots | Draft; **Considered for Inclusion**, not required [S2, S9] | Not a solution to an arbitrary mutable shared lock; its slot-based reference interface is not imported into Etna timing |

All source IDs resolve to URLs and retrieval dates in §10. Public discussions are useful for rationale and counterexamples; the current normative text wins when they disagree. In particular, January forum replies say that certain failed approval frames merely revert and that invalidating after a sender frame should not be possible [S4]. The fetched current **Behavior** says every failing `VERIFY` invalidates the transaction, and public-mempool rules separately prohibit later `VERIFY` frames [S1]. Treating the January comments as the current specification gives the wrong answer.

## 2. Exact transaction and validation model

### 2.1 Envelope, authorization, and execution

The fetched EIP-8141 defines type `0x06` and this RLP payload [S1, Payload Encoding]:

```text
[chain_id, nonce, sender, frames, signatures, fees, blob_versioned_hashes]
frames     = [[mode, flags, target, [executionGas, stateGas], value, data], ...]
signatures = [[scheme, signer, msg, signature], ...]
fees       = [max_priority_fee_per_gas, max_fee_per_gas, max_fee_per_blob_gas]
```

The current signature list and two gas dimensions matter; older diagrams of the proposal omit them. There is no mandatory outer EOA signature authorizing the declared sender. Account code grants execution approval, and payer code grants payment. Contract accounts may originate `SENDER` frames: EIP-3607's restriction is not applied to this transaction type [S1, Transaction origination]. Therefore a shared protocol contract account does **not** require competitors to share a private key.

| Mode | Top-level caller | State behavior | Failure consequence |
|---|---|---|---|
| `DEFAULT` (0) | Protocol `ENTRY_POINT` | Ordinary execution | Frame reverts; other frames may proceed |
| `VERIFY` (1) | `ENTRY_POINT` | `STATICCALL` semantics, except protocol `APPROVE` effects | Any revert or exceptional halt makes the **whole transaction invalid** |
| `SENDER` (2) | Declared `tx.sender` | Ordinary execution; execution approval must already exist | Frame reverts; transaction can still be valid and charged |

Source: [S1, Behavior]. `ORIGIN` returns the frame caller throughout call depths, so authorization must not be inferred from traditional `tx.origin` expectations. The maximum frame count is 64 in this draft. Atomic grouping is available only for non-`VERIFY` frames, and failed atomic execution does not itself turn a paid transaction into an invalid one [S1, Constraints, Behavior].

The decisive normative clauses are [S1]:

> “Ensure `tx.nonce == state[tx.sender].nonce`” — first processing step, **before any frame**.

> “Execute the frame as a `STATICCALL`, disallowing state manipulation. Only `APPROVE` can modify the state or transaction context in `VERIFY`.”

> “If the frame fails by reverting or halting exceptionally, the transaction is invalid. This unrolls any effects of `APPROVE`.”

> “Increment the sender’s nonce, set `payer = resolved_target`, and collect the transaction’s `max_cost` from `payer`.” — payment approval transition.

The initial equality is evaluated against the state at this transaction's position in the block, after earlier transactions, **not once against the parent block for every transaction**. Otherwise ordinary Ethereum nonce ordering would be impossible. This interpretation is also made explicit by EIP-8141's Replacement and Eviction paragraph: alternatives with the same `(sender, nonce)` have “at most one” inclusion [S1]. A mempool's earlier simulation is not a consensus reservation.

### 2.2 Where “invalid” is decided and what gets paid

| Event | What happens | Who pays |
|---|---|---|
| Wrong current sender nonce, malformed envelope, invalid protocol-validated signature | Invalid before frames; cannot occur in a valid block | No on-chain fee from that transaction; receiver/builder still spent screening resources |
| A `VERIFY` reverts/OOG, including a terminal `VERIFY` | Entire transaction invalid, all effects including nonce/payment rolled back | No included transaction and no Ethereum gas charge; simulation remains a real external cost |
| `SENDER` or `DEFAULT` fails after successful payment approval, with no failing `VERIFY` | Valid transaction with a failed frame; nonce remains consumed | Designated payer pays consumed gas and applicable data/blob fees |
| Atomic group of non-`VERIFY` frames fails | Group state changes roll back; frame receipts record failure/skips | Still charged if the transaction is otherwise valid |
| No payer is established after all frames | Entire transaction invalid | No included transaction fee |
| All required frames succeed | State changes and nonce consumption persist | Payer pays normal fee, with unused-budget/refund rules |

**Proven from [S1, Behavior, APPROVE, Gas Accounting]:** a reverted execution frame is not a costless losing transaction. A valid block cannot contain an invalid transaction, so “included at zero cost” is not the mechanism. A builder discovers dynamic validity by simulation at a proposed ordering position; validators execute/check the block and reject a block containing an invalid frame transaction. Temporary mempool acceptance gives no inclusion guarantee. Under a reorg, the same nonce may be reusable on the replacement canonical branch; mutual exclusion is per canonical history, not across competing L1 forks.

**Payment detail:** the account executing payment-scoped `APPROVE` is the payer. `APPROVE_PAYMENT` requires prior execution approval; the payer needs sufficient ETH. Upfront `max_cost` reserves execution/state gas at the maximum execution fee plus blobs at the block's blob base fee. Final charge is `gas_used × effective_gas_price + blob_gas × blob_base_fee`; unused reserved cost returns to the payer [S1, Gas Accounting]. A third-party sponsor changes who pays; it does not make execution free. Any builder service fee, submission deposit, paid proving work, and network bandwidth are outside this “no gas for invalid losers” claim.

### 2.3 Public mempool policy is a separate constraint

The live EIP explicitly says [S1, Mempool]:

> “Transactions outside these rules may be accepted into a local or private mempool, but must not be propagated through the public mempool.”

The validation prefix ends when a successful frame sets the payer. Public policy bounds signature validation plus prefix execution budgets by **100,000 execution gas**, bounds prefix state budgets by **500,000 state gas**, restricts `SLOAD` to **the declared sender's storage**, prohibits general environment-dependent validation, and says there must be **no `VERIFY` after the prefix** [S1, Mempool constants, Structural Rules, Validation Trace Rules]. An optional canonical expiry verifier is the timestamp exception; arbitrary `TIMESTAMP`, `NUMBER`, `BLOCKHASH`, and `PREVRANDAO` checks remain disallowed in ordinary prefix logic. Helper code and precompiles are callable if their traces introduce no forbidden state/opcode dependencies.

Consequences, proven from those rules:

1. A competitor's smart account cannot publicly propagate a generic `VERIFY` that reads a **different** Inbox's `head` or lock mapping. Such a transaction may still be consensus-valid privately.
2. Making the Inbox itself the sender puts its state within the allowed storage scope, but does not remove the validation gas limit or payer rules.
3. Running a substantial ZK verifier during `VERIFY` is consensus-valid if it obeys static semantics and fits consensus gas limits. Public eligibility additionally requires its **whole validation prefix** to fit 100,000 execution gas. Etna has no measured/verifiable proof system establishing that bound; treat this as **open**, not as a safe optimization assumption.
4. A final `VERIFY` after execution is consensus-valid but fails public propagation policy, even if it only inspects frame status and never reads storage.
5. Nodes “should keep at most one pending frame transaction per sender.” Same-nonce alternatives compete as replacements, with the suggested execution-fee bump convention of 10% and the blob pool's own blob-fee replacement conventions [S1, Acceptance Algorithm, Replacement and Eviction]. This is not a fair open auction between all proofs.

The draft has wording that says only canonical paymasters are eligible in one paragraph, then explicitly permits capped non-canonical paymasters elsewhere [S1, Paymasters]. This policy editorial ambiguity is an **open launch-revision check**; the constructions here do not assume a non-canonical public paymaster. Private consensus constructions can use a payer contract with precisely bounded, transaction-bound approval. Ethresear.ch analyses independently emphasize that consensus validity, public propagation, FOCIL eligibility and node state availability are distinct gates [S6, S7]. They do not prove a particular transaction will be included.

## 3. Nonce as a lock: worked construction and limits

### 3.1 Minimal mutual exclusion

Let `I` be the new Etna Inbox, with accepted Etna head `H=900`, and let `R_J` be a dedicated contract account for work item `J`, currently at Ethereum account nonce `1`. Alice and Bob have different proofs advancing the same allowed work item; their envelopes both declare `sender=R_J, nonce=1`. Neither knows a secret key for `R_J`. Its execution-approval entry point is permissionless code recognizing only a constrained Etna frame shape. Each competitor supplies its own consenting, solvent payer.

For the canonical private optimization, anyone may instantiate `R_J` through an objective deterministic factory keyed by `H(chainId, Inbox, revision, actionKind, priorAcceptedHead, workItemId)`. The account's immutable code/parameters restrict it to this work item and action kind; there are no owner-selected competitors or private signing keys. This is an optional additional account, not a replacement Bridge, SignalService or Vault. Its one-time deployment costs and state footprint must be charged to the optimizer, not silently socialized. Different jobs and role actions get different accounts; a global Inbox account nonce must not serialize proving, slashing, entry and exit. An alternative deployment at another address cannot bypass the Inbox's canonical admission rules; it merely loses early nonce exclusion against transactions using `R_J`.

The minimal shape is:

| Frame | Mode / flags | Target | Purpose |
|---|---|---|---|
| 0 | `VERIFY` / `0x2` | `R_J` | Validate complete authorized frame shape, immutable parent/work item, relevant commitments; `APPROVE_EXECUTION` |
| 1 | `VERIFY` / `0x1` | Competitor's payer `P` | Authorize exact envelope and bounded fees; `APPROVE_PAYMENT` |
| 2 | `SENDER` / `0x0` | `I` | `submitBatch(J, parent, data, proof, beneficiary)` |

**Proven mutual exclusion:** before either is included, both can be valid against the same pre-state. If Alice is included, successful payment approval increments `R_J.nonce` to 2. Bob's nonce-1 transaction is now invalid at the first check, so cannot be included later in that block or a descendant block of that history. Ethereum rejects it before proof execution. If Bob comes first the result is symmetric. This provides **at most one included transaction**, not “only one valid transaction in the initial state,” and not “exactly one winner must be included.” Builders retain ordering discretion.

**Counterexample to the stronger naive claim:** Alice uses sufficient validation gas but insufficient execution/state gas for frame 2. It fails, no batch lands, yet her payer's valid transaction consumes nonce 1. Bob's good nonce-1 proof transaction is invalidated. Alice spends the included transaction's fee, not zero. The same pattern works with any missed precondition that makes the execution revert. Repeating at nonce 2 can delay honest parties if the account permits retry. A rule accepting only nonce 1 instead permanently disables this account after the first burn. The proof may still be reusable under a fresh envelope or ordinary submission, but assembly/submission work, latency and replacement access are lost. A nonce lock alone is consequently not a security or liveness defense against deliberate lock burning.

Checking a minimum declared gas limit in frame 0 fixes only the specific deliberately undersized budget. It does **not** prove that arbitrary frame 2 code, future upgrades, external calls, proof inputs, state-dependent charges, or reentrant behavior cannot fail. A public version needs a formal sufficient-precondition and worst-case gas argument for its narrowly fixed execution path, including payment's balance/nonce changes. That argument is **open**, and likely requires expensive proof validation in the prefix. Etna must not count a gas-limit threshold as completed proof of this property.

### 3.2 Strengthened construction: terminal success verification

Add exactly one terminal frame:

| Frame | Mode / flags | Target | Purpose |
|---|---|---|---|
| 3 | `VERIFY` / `0x0` | `R_J` | Assert frame 2 status is success **and** Inbox stored head/work digest equals the exact promised result; return normally, or revert |

**Proven under A-FRAME and correct Etna validation code:** if frame 2 fails, frame 3 sees status 0 and reverts. The whole transaction is invalid, including payment and nonce consumption. A builder cannot include Alice's failed attempt as a valid transaction to burn Bob's lock. If Alice completes the exact transition, frame 3 succeeds and nonce 1 is consumed; Bob becomes invalid before any frames. No expensive proof duplication is necessary: proof verification runs once inside `submitBatch`; the final check verifies its successful, exact state effect. If the terminal frame itself is underfunded, it exceptionally halts and the transaction is invalid. Invalid blob commitments/sidecars also cannot become a successfully included lock burn under the blob validity rules.

The postcondition must test a unique action digest / new head, not merely “the call returned success.” Otherwise a no-op success, fallback selector or caught inner revert can pass while doing no useful work. The approval function must constrain **all** frames, modes, flags, targets, values, selectors, parameter lengths, calldata/proof/data commitments, payer consent, expected parent and terminal postcondition. It must reject extra frames, altered final frames, arbitrary `DELEGATECALL` payloads, calls that create contracts from the shared account, and unrestricted value transfers. Scope flags are not per-operation permissions: approval authorizes **every subsequent `SENDER` frame** [S1, Security Considerations]. Without complete binding, an attacker can append asset movement or change the supposedly protected action.

`VERIFY` cannot be grouped into an atomic batch and cannot be skipped via a failing prior atomic group under this exact non-batched shape [S1, Constraints, Behavior]. The final verifier may not call `APPROVE` with flags zero; it simply checks and returns. `FRAMEPARAM(2, 0x05)` exposes the completed frame's status under the fetched spec. Reading `I`'s post-state is permitted by consensus static execution. There is no transaction interleaving between frame 2 and frame 3; nevertheless all callbacks inside frame 2 must satisfy Etna's normal reentrancy and state-transition rules.

**Cost example (illustrative, not a gas estimate):** suppose successful Alice consumes 600,000 charged gas at 20 gwei and carries two blobs at blob base fee `b` wei. Her payer pays `0.012 ETH + 262,144 × b wei`. Bob's stale nonce transaction incurs zero on-chain gas/blob charge, though he paid to produce his proof. A failed Alice attempt with terminal verification incurs no on-chain charge, but a builder may have executed much of a 600,000-gas simulation without payment. Numeric execution/state budgets must be measured against the deployed fork and verifier; this example establishes fee incidence, not performance.

**Limitation:** frame 3 violates current public-mempool policy. This is a private/direct-builder optimization under A-BUILDER. It does not satisfy a promise that every ordinary public node must relay the race, that every prover gets an equal chance, or that builders provide free simulation. Builders can impose local rate limits, price external services, or decline it. No Ethereum rule makes the resource cost of testing invalid expensive proofs disappear.

### 3.3 Payer, key, and delegation hygiene

- A payer contract can approve only the exact canonical envelope and a bounded total cost, with an authorization from its funder; its funder need not control the shared sender. For default-code EOA sponsorship, the fetched draft reads the payment authorization at **signature index 1** and requires `msg` empty (canonical hash). A custom payer sketch must not accidentally assume default code uses index 0 [S1, Default code].
- Do not implement the shared sender as an EOA whose private key is published. Whoever can issue ordinary EOA transactions or EIP-7702 authorizations can bypass the proposed lock-validation logic or change delegation. Use a contract account, whose allowed entry points are defined by code; ordinary transaction types retain EIP-3607 restrictions [S1, Transaction origination].
- Proxy delegation must preserve validation meaning; a DAO upgrade remains the explicitly permitted upgrade trust assumption. A delegated EOA/helper introduces extra mutable dependencies and is restricted by public-policy EIP-7702 rules. Removing a secret-key dependency is not proof that arbitrary delegation is safe [S1, Validation Trace Rules].
- Account nonce and Etna batch sequence are separate quantities. A deployment may begin at nonce 1, and other permitted account-originating actions could consume/increment it. Read the actual Ethereum nonce; do not infer it from batch height. A dedicated action account reduces coupling but reading an external Inbox in its prefix is a public-policy obstacle.
- Payout identity belongs in the proven statement or another signed, immutable commitment accepted by the Inbox. A builder copying a public proof may relay it but must not rewrite the beneficiary. Payer identity and proof producer identity need not coincide. This is an Etna correctness obligation, not a property supplied by frames.

## 4. Alternative constructions

### A. Shared sequence number in application storage

**Construction:** competitors keep their own senders. A `VERIFY` reads `Inbox.nextAction == J`; after approval, a `SENDER` calls the Inbox to advance `nextAction`. Add terminal success verification for lock-burning resistance if required.

**Proven:** consensus `STATICCALL` permits the read, and after one successful transition the others' `VERIFY` reverts, invalidating them. But external Inbox storage in each competitor's validation violates public `SLOAD` policy, and the success suffix also violates public policy. Moving the guard into a normal `SENDER` frame makes it publicly ordinary but losing transactions revert and pay. Moving the Inbox into `tx.sender` restores own-storage access and reduces this alternative to the shared-account design, including one pending transaction per sender. No custom storage lock supplies Ethereum's early nonce-rejection shortcut.

**Verdict:** possible privately without EIP changes; general public propagation needs a policy exception/change, or accepts paid stale execution. A recent-root witness that `J` was available in an earlier state is not a proof that nobody has consumed `J` in the current transaction pre-state.

### B. Explicit protocol claim / compare-and-set frame

**Construction hypothesis:** a hypothetical new frame atomically claims `(protocol, actionId)` as a consensus validity condition; all later claims with the same key are invalid, and only successful protocol execution consumes the claim.

**Proven limit:** EIP-8141 defines `DEFAULT`, `VERIFY`, and `SENDER`, not an application-wide compare-and-set frame. `VERIFY` cannot execute `SSTORE`, and ordinary application writes in `SENDER` retain reverting transaction fees. A key cannot be reserved by `VERIFY` application storage under its static semantics. Shared sender nonce already gives a restricted in-protocol claim, but not atomic consumption conditioned on arbitrary successful execution without the suffix/private tradeoff.

**Verdict:** a **new consensus primitive would require EIP changes**; the current-frame emulation is alternative A or nonce locking. Before advocating a new primitive, specify namespace ownership, expiry, reorg behavior, invalid-simulation cost and mass-invalidation bounds. EIP-8250 gives bounded sets of per-sender keyed nonce sequences, not a universal cross-sender claim [S8]. It still preserves one pending frame transaction per sender and the execution-revert distinction.

### C. Commit-reveal with frames

**Construction:** each competitor pays an ordinary commitment containing `H(action, proofDigest, beneficiary, salt)`; after a seconds-based deadline a deterministic objective election admits one reveal, with a bonded obligation and timeout reassignment.

**Proven/design deduction:** paid commits make Sybil attempts costly and conceal some bidding/proof information, but they do not make losers' **commitments** free. Frame-gating reveals on a shared elected state has the same mutable-state/public-policy restrictions as A; ordinary reveals still pay on a race. The winner can withhold a reveal, so a timeout/bond and recovery remain necessary. No phase may require a committee/admin signature or CL lookahead to resolve it.

**Verdict:** useful only if Etna deliberately wants paid, delayed allocation; it is **not** a solution to zero-cost general races and adds latency and griefable reservations. Reject as the primary propose-with-proof path. It can reduce duplicated proving by paying for an assigned proving service, provided any outsider can still submit a valid proof and recover after objective timeouts.

### D. Execute once, then assert success without a shared sender

**Construction:** each contender submits its own approved/payer-funded transaction, executes `submitBatch` in `SENDER`, and ends with `VERIFY` asserting exact success. When a prior submission advanced the Inbox, stale execution fails and the terminal frame invalidates the entire loser.

**Proven:** same private-consensus success guarantee as §3.2, without sharing an account nonce. Builders may perform expensive losing execution rather than an early nonce mismatch, so the denial-of-service economics are worse. Public mempool still rejects the suffix.

**Verdict:** possible privately under the draft and simplest generic proof-of-concept at the specification level. Shared nonce is an efficiency improvement for early rejection, not the only path to invalid-on-failure semantics.

| Construction | Consensus no gas for stale losers? | Success-conditioned consumption? | Specified public relay? | Etna use |
|---|---|---|---|---|
| Shared nonce, ordinary execution suffix | Yes, after some tx consumes nonce | No; paid revert burns nonce | Possible only if prefix and payer fit policy; one alternative pending | Not a liveness guarantee |
| Shared nonce + terminal `VERIFY` | Yes | Yes, with exact envelope/postcondition binding | **No** | Optional direct-builder optimization |
| Expensive proof validation inside initial `VERIFY` | Yes if prefix enforces current head | Requires sufficient preconditions for all later effects | Only if full prefix fits 100k and state rules; unestablished | Open optimization, not dependency |
| Other senders + shared storage `VERIFY` | Yes | Add terminal guard or complete preconditions | **No**, external mutable storage | Optional private variant |
| New claim frame | Potentially | Only if new semantics define it | Needs new EIP/policy | Rejected dependency |
| Paid commit-reveal | Reveals may be optimized; commits paid | Requires recovery rules | Ordinary paid form yes | Optional service allocation, not race solution |
| Ordinary blob/calldata `submitBatch` | No; stale calls may revert with fees | Atomic successful call only | Ordinary L1 rules | Mandatory liveness fallback |

## 5. Attacks on the frame construction

Each trace is a **proven design counterexample** unless explicitly marked assumed; it does not assert a vulnerability in deployed Ethereum.

1. **Nonce burn:** valid prefix → pay → deliberately fail `SENDER` → nonce advances but head does not. Attacker pays one tx; competitors must refresh envelopes. Fix with terminal success verification on the private path; public fallback avoids a shared lock as a liveness prerequisite.
2. **Unbound suffix:** obtain execution approval for a small action → append another `SENDER` frame moving protocol assets. Approval is transaction-wide. Fix by checking every frame and canonical signed/proven commitments, including rejecting arbitrary extra frames [S1, Security Considerations].
3. **No-op postcondition:** final guard checks only status; target returns success without landing the proof. Fix with exact accepted-action digest/head advancement and strict selector binding. Every privileged operation must still perform normal authorization.
4. **Expensive invalid simulation spam:** submit many transaction variants with invalid proofs or underfunded final guards. None can be included/charged, but builders simulate. Attacker pays network/proof-manipulation costs, potentially far below builder computation. Current 100k validation cap/policy protects public nodes by excluding this general construction; private builders must choose their own screening/pricing. Bonds cannot slash a transaction that never left authenticated on-chain evidence.
5. **Replacement capture:** attacker competes under the same sender and bumps fees, using public one-pending-per-sender policy to displace honest variants. There is no fairness guarantee; full-success validation stops useless included burns but not fee competition or censorship. Permissionless ordinary submission must remain available.
6. **Proof theft:** copy proof calldata, change beneficiary, sponsor a winning envelope. Prevent only by proof/authorization binding beneficiary and batch data; signatures whose explicit `msg` does not bind all fields are insufficient. Canonical hash in current draft covers the complete frame list and blob hashes, eliding only the appropriate signature bytes [S1, Signature Hash]. Early discussion using omitted `VERIFY` calldata is obsolete for this fetched revision [S10 versus S1].
7. **Global nonce coupling:** use one race sender for proving, slashing, recovery and unrelated registration. An unrelated valid action invalidates all same-nonce envelopes. Use the per-action `R_J` scope above, prohibit unrelated actions in its complete-frame validation, and treat its nonce as an optional submission optimization, never a scarce right needed for chain progress. Optional EIP-8250 domains do not remove public policy limits and are not required.
8. **Builder monopoly by dependency:** if only selected private builders accept the frame, relying on it excludes honest entrants from liveness. R1 fails under that reliance. Keep direct public `submitBatch` with identical proof/admission rules, and price losing transaction costs as a documented fallback limitation.

## 6. Blobs, proof/data binding, and R7

**Proven source fact:** the fetched EIP-8141 explicitly supports `blob_versioned_hashes`; nonempty hashes make it a blob-carrying transaction, its payer also pays blob fees, `BLOBHASH` returns those hashes in every frame, and active-fork blob limits apply [S1, Blob handling]. Its networking section reuses the blob-sidecar wrapper and cell-proof structure. This is not an assumption that an EIP-4844 envelope can contain frames: it is a **separate frame envelope with explicit blob support**.

Etna can therefore put batch manifests/DA commitments and the valid ZK proof in one `submitBatch` action executed inside one frame transaction. The exact atomic correctness boundary should remain **one Inbox call**: verify proof and current predecessor, validate current-transaction blob hashes or bounded calldata bytes, consume only the preselected forced queue prefix, commit the new head, and publish the checkpoint. Splitting proof verification and commitment across independently revertible frames would weaken that boundary and is unnecessary.

**Required Etna binding (design obligation, not supplied by EIP-8141):** the proof's public statement must commit chain ID, Inbox/version, prior accepted head, new head/state root, block range, canonical byte encoding, DA mode and ordered data commitment, force-queue cutoff/cursor, and beneficiary. For blobs, the circuit/DA relation must prove that the derivation bytes correspond to the same versioned commitments observed through `BLOBHASH`, with canonical padding/lengths and a specified KZG relation. Merely comparing an arbitrary hash of raw bytes to a blob versioned hash is incorrect. For calldata, the Inbox can recompute the prescribed byte commitment and compare the proof statement. Neither signatures nor a final frame manufactures DA from an opaque proof.

**Timing:** off-chain one-second preconfirmed issuance continues throughout the minute-level proving window. All proof statement inputs must be fixed before proving; binding a future L1 landing timestamp/origin invalidates the premise. The transaction fee envelope and nonce can be refreshed without recomputing an execution proof if they are intentionally excluded from the proof statement; beneficiary, batch contents and fixed origin cannot be silently changed. Frames reduce some submission race costs; they do not accelerate proof generation, publish withheld blocks, select a unique preconf branch, or make forced inclusion automatically work.

**Failure path:** the designated proof producer has no exclusive cryptographic submission right. Another producer may prove the same fixed work or a precisely allowed successor/recovery statement. If a ready proof lands first, stale private frame alternatives become invalid; on the public fallback stale calls can revert and charge gas. A frame lock cannot decide which of two otherwise valid competing L2 histories should win—the Inbox's fork-choice/admission predicate must already define that.

**L1 finality:** a successful Inbox call establishes an accepted L1 state transition in its containing block. Ethereum consensus finality of that block establishes final settlement under the usual consensus/soundness assumptions. A frame success, zero-cost stale rejection, and builder ACK are not Ethereum finality.

**If frames slip:** use a conventional EIP-4844 transaction calling the **same** `submitBatch` with blob commitments plus proof calldata, or an ordinary calldata transaction within explicit size/gas bounds. Data and proof still land atomically in one L1 action; stale losers may pay reverting gas. R7 therefore degrades in economic efficiency, not safety or atomic propose-with-proof semantics. No private builder cooperation, EIP-8250, EIP-8272, or special claim frame belongs in Etna's minimum liveness dependency set. If launch requirements separately insist on zero-cost losers via the public mempool for arbitrary proofs, that stronger condition is **not established** under this draft and must be relaxed or await policy changes.

## 7. Builder and mempool assumptions to state in the design

| Assumption | Needed for | Failure consequence |
|---|---|---|
| A-FRAME: deployed fork matches analyzed invalidation/nonce/blob semantics | Consensus exclusion and terminal-guard proof | Re-review construction; use ordinary path until established |
| A-VALIDATOR: Ethereum rejects blocks containing invalid transactions | Invalid losers pay no on-chain fees | Underlying L1 execution safety fails |
| A-BUILDER: at least one reachable builder accepts outside-policy frames, can obtain sidecars, and prices them acceptably | Practical use of terminal-guard optimization | Use public ordinary transaction; optimization unavailable |
| A-L1: eventual inclusion at adequately funded fees | Any path making progress | No rollup transaction mechanism solves permanent L1 censorship |
| Correct, bounded Inbox proof/admission code and exact frame binding | No lock burns, proof theft or unintended sender actions | Security bug; no source-level EIP argument proves the application correct |
| Adequate data retention/availability and prover access | Prove-with-proof liveness | Frames cannot recover unavailable data |

**Not assumed:** all builders cooperate, all private endpoints are honest, competing proofs receive fair order, public nodes propagate terminal guards, invalid submissions can be slashed without authenticated on-chain evidence, or token bonds pay Ethereum gas directly. A payer may accept ERC20 reimbursement under an application scheme, but L1 fees remain ETH-denominated [S1].

## 8. Resolution of the research question

- **Possible:** zero **on-chain** cost for competing stale transactions, by shared account nonce; current consensus rules also permit success-conditioned whole-transaction invalidation using a final `VERIFY`. The four-frame worked example supplies the construction and its proof.
- **Possible only with changes or an additional proof:** guaranteed support by the specified **public mempool** for a general expensive proof race with terminal success verification. A policy exception needs a credible resource/DoS model; a cheap initial verifier needs a measured sufficient-precondition proof within 100k and all state constraints. Neither is silently assumed.
- **Not supplied by frames:** an exactly-one-winner inclusion guarantee, a fair race, a global proof of gossip availability, a permissionless honest-majority assumption, or zero total economic cost. They provide no exemption from nonce refresh after L1 reorgs.

The PDF remains an **open input**. Once supplied, compare its assumed envelope, nonce transition, `VERIFY` failure semantics, suffix rules, account authority and payer model against this dated report. A conclusion that only says “the loser is invalid because it shares the nonce” is correct for inclusion exclusion but incomplete for successful progress, public propagation and adversarial lock burning.

## 9. Launch review checklist for this dependency

These are concrete engineering evidence gaps, not additional DAO operational powers:

1. Pin the deployed EIP/client revision and replay consensus examples: two same-nonce successes, failed sender with/without terminal `VERIFY`, insufficient terminal gas, same-block ordering, and reorg reuse.
2. Check final envelope/signature/blob-sidecar encoding, default payer signature indexes, execution/state gas dimensions, and all introspection opcodes against that revision.
3. Prove exact validation shape binding and postcondition completeness; ensure no self-call bypass of protected Inbox state transitions. Inspect upgrades and delegated helper targets.
4. Measure real proof verification and calldata/sidecar budgets. Do not claim public propagation if prefix exceeds policy, reads external state, or contains a terminal `VERIFY`.
5. Validate that ordinary public submission has identical canonical admission, proof and beneficiary semantics, and does not require the shared sender nonce lock or private relay access.

## 10. Sources and retrieval record

Every URL below was retrieved or explicitly checked through live public web tools on **2026-09-30 UTC**. No private Notion, accounts, keys, or deployment APIs were used. EIP source and forum extracts are evidence of what those pages said when fetched; search-engine metadata is not itself normative fork status.

| ID | Source | Use |
|---|---|---|
| S1 | [EIP-8141: Frame Transaction](https://eips.ethereum.org/EIPS/eip-8141) | Primary complete specification: status, envelope, nonce, frame/approval/fee semantics, mempool, blobs, security |
| S2 | [EIP-8081: Hegotá hardfork meta](https://eips.ethereum.org/EIPS/eip-8081) | Primary fork selection states; 8141 SFI, 8250/8272 CFI |
| S3 | [Ethereum.org Hegotá roadmap](https://ethereum.org/en/roadmap/hegota/) | Human-facing scheduled status and expressly provisional timeline; page says last updated August 31, 2026 |
| S4 | [Ethereum Magicians EIP-8141 discussion](https://ethereum-magicians.org/t/eip-8141-frame-transaction/27617) | January rationale and obsolete semantics contrasted with current draft |
| S5 | [Ethereum Magicians later EIP-8141 discussion, page 8](https://ethereum-magicians.org/t/eip-8141-frame-transaction/27617?page=8) and [page 4](https://ethereum-magicians.org/t/eip-8141-frame-transaction/27617?page=4) | Static validation, state reads, atomic batches, paymaster limits; arguments, not authoritative current consensus |
| S6 | [Ethresear.ch: Frame Transactions Through a Statelessness Lens](https://ethresear.ch/t/frame-transactions-through-a-statelessness-lens/24538) | Node state/validation and FOCIL eligibility distinctions; dated research discussion |
| S7 | [Ethresear.ch: Frame Transactions and the Three Gates to Privacy](https://ethresear.ch/t/frame-transactions-and-the-three-gates-to-privacy/24666) | Shared contract sender and own-storage pattern, gas/policy limits, separate inclusion gates |
| S8 | [EIP-8250: Keyed Nonces for Frame Transactions](https://eips.ethereum.org/EIPS/eip-8250) | Optional nonce domains; pre-frame equality and unchanged public one-pending-sender policy |
| S9 | [EIP-8272: Recent Roots for Frame Transactions](https://eips.ethereum.org/EIPS/eip-8272) | Current canonical verifier frame, not an arbitrary shared mutable lock; current draft differs from older search excerpts that changed the envelope |
| S10 | [Ethresear.ch: Encrypted frame transactions](https://ethresear.ch/t/encrypted-frame-transactions/24440) | Search-reviewed older canonical-hash assumption; not relied on for current encoding |

For reproducibility, SHA-256 of the UTF-8 **extracted markdown snapshot** (including a final newline), not raw HTML or a Git commit: S1 `e3b350b9e6501b7bb0fbaf36325dd369b0fb86fbe150df420b878ac1de1a50dd`; S4 `ff89304c4b6485d0fb10c522a67759a7424cac3e1735c742f6e7115ddec8cef4`; S6 `2f00e380ecaff494e79624751bc9eb806f7a964c03772c653713c91337bcff50`. Temporary snapshots were kept only in the session scratchpad, not committed as production or experiment code.


## 11. Integration update: mandatory canonical rent

**Proven/source:** EIP-8141 defines per-frame value as transferred from the sender, permits nonzero value only in SENDER frames, and reverts a frame if that caller lacks the balance [S1, frame fields/Behavior]. Payer fee approval does **not** supply Inbox call value. This distinction matters once Etna charges the round05 candidate's descending-price ETH rent.

**Proposed rule:** at positive rent, competitors use individually controlled, funded sender accounts with the exact action/value authorized. The four-frame shape retains terminal success verification; stale losers invalidate even though their sender nonces differ (alternative §4.D). No common prefunded pool or privileged sponsor is required. At zero rent, the worked shared-sender/nonce construction remains usable with every frame value zero. It proves the nonce-as-lock hypothesis without introducing shared-value theft. Any excess call value is an Inbox credit of its actual calling sender account, withdrawable through that account's own authorization. Ordinary payable public submission is always available and still has paid losing races.

**Assumed/Open:** deployed account authorization, value balance, exact frame binding and launch EIP semantics require conformance testing. No smart account has been implemented here. These funding restrictions do not change the consensus verdict or make the terminal-VERIFY shape eligible for the public mempool.
