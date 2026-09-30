# Withholding accountability: minimum repairs and exact limits

Research date: **2026-09-30**. This is a narrow mechanism comparison, not an adversarial-round report, implementation, or R1–R7 verdict. Inputs read: [requirement ledger](../README.md), [core design](../design/index.html), [roles](../design/roles.html), [accountability](../design/accountability.html), and [feasibility boundary](feasibility.md). No round reports were used. **Proven** below means a deduction from the specified rules and stated premises; **Assumed** names a premise; **Open** marks an unresolved design choice or empirical claim.

## 1. Interpretation first, without adding a harder requirement

**Proven:** the following are different guarantees:

1. **Objective serving accountability:** a signed, reserved promise to make particular bytes available can be challenged; failure to publish those bytes by an included challenge's deadline is slashable by anyone.
2. **Authenticated branch consistency:** a bonded publisher cannot endorse two conflicting blocks under the same accountable identity and branch context without exposing slashable evidence. A properly authorized canonical submission can be one of those endorsements.
3. **Private-fork deterrence:** an economically active participant that privately prepares a competing valid branch and lands it first must incur a penalty, even if it never issued an inconsistent authenticated endorsement and reveals all data at landing.
4. **Historical universal publication:** prove that the data was available to every relevant peer throughout an earlier interval, rather than merely before an objective response deadline.

**Proven:** (1) is achievable by the current challenge mechanism under its explicit inclusion, funding and retention assumptions. Its false-negative rate against intentional *earlier* withholding may be 100%, while its detection of a *missed included deadline* is exact. This is not a contradiction: the two rates measure different predicates. An allowed timeout surrogate must be judged on its expressly chosen predicate, not silently strengthened into (4).

**Proven:** (2) has a useful small extension described below. It does not imply (3), because a different collateral owner can endorse a competing branch. A bare address count does not identify common economic control.

**Open:** whether the brief accepts (1) plus (2), with honest disclosure of private-fork displacement, or requires materially stronger coverage of (3). The ledger does not itself require (4). Conversely, acknowledging the private-fork attack cannot by itself establish that the actual withholding requirement passes. The requirement adjudicator must compare the chosen guarantee with the user's words, including the attack the user wants addressed. This note does not convert that unresolved interpretation into acceptance or a blanket impossibility verdict.

**Recommendation:** retain the strict L1 sequencing choice while terminology remains unresolved. The strongest concrete candidate is **nonexclusive L1 data staging followed by the ordinary atomic data-plus-proof acceptance**, with a provisional minimum public-data age of 360 seconds; see §6.4. This objectively prevents first disclosure at canonical landing without introducing an unproved canonical proposal or external witness gate. Combine it with complete serving covenants for advertised bonded preconfirmations and the authenticated same-owner conflict rule below. Do not represent this as a guarantee that every soft branch wins, or that private computation before timely publication is misconduct.

## 2. Comparison of the smallest candidate changes

| Change | What it establishes | What it leaves open | Strict L1 path / atomic landing |
|---|---|---|---|
| Mandatory serving covenants for protocol preconfirmations; optional witness covenants | Every authenticated advertised data promise has reserved, challengeable liability | An unadvertised private branch may land; a timely response cures the publication duty | Preserved; no hard-path witness requirement |
| Explicit canonical-owner authorization plus receipt-based equivocation | Same accountable owner cannot sign X and authorize a conflicting accepted Y without evidence | Independent owners, including undisclosed common ownership; private preparation without conflicting endorsements | Preserved if authorization is self-service and no external approval is required |
| Mandatory self-funded serving bond for every canonical candidate | No accepted candidate lacks the specifically defined accountable owner and future duty | Atomic landing already publishes its data; this alone adds no evidence of earlier withholding | Potentially preserved; collateral is an objective condition, not an exclusive lease, but it changes the current unbonded path |
| Certificate from any k permissionless keys | k reserved promises, if independently backed | One actor can supply all k keys and copies; no honest-holder conclusion | Preserved only if the proposer can self-supply the conditions; no independence follows |
| Mandatory external availability quorum, without branch exclusivity | Under an honest-online-holder premise, certified data can spread; does not uniquely order branches | Quorum outage/censorship; threshold and membership assumptions; all holders disappearing | Final choice can remain L1, but immediate admission now depends on an external quorum |
| Mandatory ordering quorum with locking | Under a full BFT premise, one certified branch and data-holder availability | Committee failure and recovery semantics | Changes the chosen strict based architecture, even with delayed escape |
| Wait after first complete data+proof reveal | A later decision can examine already published bytes | Earlier withholding, fabricated early timestamps, and the optional-proof race | A second admission stage or duplicated publication needs explicit R7 reconciliation |
| Prior nonexclusive L1 hash/bond notice | An objective commitment time and observable opportunity to challenge | Hash publication is not data publication and does not protect one public branch from another | Not automatically a sequencing committee; additional L1 staging must be justified against the one-landing design |
| Prior nonexclusive **actual L1 data** publication, age checked at atomic acceptance | Complete identical payload has been public on L1 for at least the required interval | Soft forks may still lose; private computation before timely staging remains possible; added publication cost | L1 retains final ordering; the canonical action still carries full data and proof. Literal R7 does not expressly forbid earlier generic data publication |
| Slash every preconfirmation that loses the L1 race | A measurable insurance payout condition | Honest producers can be forced to lose; no proof of withholding | Hard path can stay open, but the insurance is attacker-triggerable and is not a sound misconduct rule |

**Proven:** permissionless availability membership and absence of sequencing exclusivity do not by themselves establish strict based liveness. Equally, an availability certificate must not automatically be called an ordering certificate: if signers may truthfully sign both forks, they have not selected the canonical winner. The precise problem with making their signatures mandatory is the added admission dependency.

## 3. Minimal exact mechanism A: enforce the permitted timeout surrogate

### 3.1 Scope and message

**Proposed rule:** distinguish a raw execution-valid candidate from a protocol **bonded preconfirmation**. A raw candidate may be executed and may be submitted canonically. A bonded preconfirmation must carry the authenticated publisher's serving claims, not merely an envelope signature that has no defined slashing meaning. Clients display the distinction explicitly.

For each advertised block, its claims cover every fragment of its complete bounded canonical body and required manifest context. The manifest binds ordered lengths and digests. Parent bodies have their own claims; one claim does not promise an unbounded history. A receiving node must independently possess and execute the complete dependency chain before reporting a valid soft result. Missing data remains UNKNOWN.

Use the existing pre-funded bucket/position scheme and existing EIP-712 duty domain. The current 60-position bound, 32,768-byte fragment bound, at most four fragments for a segment, fixed retention, and separately reserved position balances are sufficient specification machinery. Requiring claims in the gossip envelope does not require an L1 transaction every second. **Open:** the existing 100-TAIKO-per-position, seven-day exposure is expensive; changing duty scope does not resolve that calibration.

**Proposed rule:** witness claims are additional nonexclusive serving covenants, using their own reserves. They are optional for canonical admission. They may be required by a customer's chosen soft-service policy, but that client policy must not be described as an L1 validity rule. The same witness may serve two competing executable branches without equivocating unless it signed an explicit incompatible exclusive promise.

### 3.2 State transitions and liability

The current publication state machine can be retained:

1. Anyone possessing a valid signed claim can open a bounded, funded L1 challenge within its retention window. The clock starts at inclusion, not at an alleged P2P request or signed wall-clock timestamp.
2. The signer **or any other holder** can publish the exact bytes on L1 by the included deadline. A successful publication satisfies all matching covenants whose individual deadlines have not expired. Reward only one publication deposit; settle other matching challenges lazily without an unbounded loop.
3. After the deadline, anyone can settle a missed response. Slash only the reserved position once; use the existing reporter/sink split and refund rules. A reveal after an already missed deadline cannot erase the default.
4. Losing a canonical race does not slash the promise and does not cancel its serving duty. Otherwise a withholder could escape by arranging a different winner, and honest consumers could lose access merely because L1 chose another valid branch.
5. No challenge freezes the accepted head or reserves the right to select its next child. Existing accepted proofs, revisions and historical default records retain their ordinary meanings.

**Proven:** an accuser who already received the data can force a paid public response, but cannot establish a false default if someone responds on time. Conversely, signatures alone cannot force missing bytes into existence. If every holder disappears, the claim can default and its bond can be slashed; the bytes are not recoverable from their digest.

**Assumed:** signature/hash/proof soundness; a funded observer learns the signed claim; conforming responses can be included before the chosen deadline; at least one holder remains online when success is claimed; historical canonical data remains reconstructible. No empirical probability or universal one-second response guarantee follows from these assumptions.

### 3.3 Why mandatory canonical self-bonding is not the missing proof

**Proposed optional extension:** every canonical candidate carries a self-funded authorized owner and a serving covenant for its bounded body. Funding can be open and mechanical, with no incumbent approval or finite ticket supply. This would remove the current entirely unbonded submitter category, if that is desired.

**Proven:** it does not close the first-reveal-at-landing attack. A private producer prepares Y, obtains its own covenant, and lands Y's complete data and proof. If no challenge was visible earlier, no publication deadline was missed. If a challenge is pending and landing constitutes a valid response before its deadline, the duty is satisfied. It makes no difference that the producer is now bonded.

**Proven:** neither an old bucket registration nor a claim's `issuedAt` proves when Y's data was disseminated. A bucket predates a promise, but can be used for data privately prepared later. Requiring many self-controlled owners only multiplies the stated capital cost.

**Open:** if canonical landing should discharge a serving claim, the design must explicitly verify the fragment-to-accepted-manifest relation and preserve the earliest qualifying publication time. A calldata response already has exact hash/length checks. Blob acceptance needs its existing sound body/KZG binding and an exact authenticated fragment relation; an arbitrary caller's assertion that equivalent bytes were published elsewhere is insufficient. Late canonical acceptance must not retroactively forgive an earlier default. This is evidence plumbing, not a historical-gossip oracle.

## 4. Minimal exact mechanism B: canonical receipts can prove a publisher conflict

The current double-sign rule requires two `DutyClaim` signatures. An accountable publisher could sign public X, then authorize conflicting Y for canonical submission without issuing a second duty claim. The accepted proof is evidence of Y's contents, but its identity attribution needs care.

### 4.1 Do not slash a bare beneficiary

**Proven counterexample:** an attacker constructs and proves Y, sets the existing proof-bound `beneficiary` to honest X-publisher Alice, and lands Y. A rule “Alice signed X and Alice is Y's beneficiary, therefore slash Alice” punishes Alice without her authorization. Proof-bound payment routing establishes who receives a payment, not who endorsed a branch. The transaction payer, relay, builder and proof worker likewise need not be the soft publisher.

**Required rule:** identify an **accountable canonical owner** separately from payment beneficiary. Verify its immutable registered key's signature over an exact candidate authorization. A suitable semantic commitment is:

```text
CanonicalAuthorization {
  domain, revision, owner, bucketId, position,
  oldHeadHash, taskHash, orderedBlockCommitment,
  firstL2Number, endL2Number
}
```

The domain binds both chain IDs, Inbox and accountability registry. `taskHash` remains noncircular and binds the complete execution task. The authorization reserves a specified live amount under its recorded terms. Anyone may relay it; only its owner can authenticate it. Payment authorization remains separate. A canonical receipt records the authorization hash and accountable owner that the contract actually verified.

**Proven:** this does not require an independent availability witness or sequencer. Anyone can self-enter, fund and authorize a candidate. **Open:** deciding to require this for every canonical submission changes the current explicitly unbonded path; retaining it as optional only extends accountability for candidates that use it. Neither version establishes identity across owners.

### 4.2 Exact conflict evidence

An evidence submission supplies:

- Alice's authentic funded publisher claim for X, with its `baseHeadHash`, L2 number and block hash;
- an immutable accepted receipt for Y whose `oldHeadHash` equals that same base head;
- Alice's verified canonical authorization of Y; and
- authenticated evidence that Y includes a different block hash at that same L2 number.

The registry checks matching revision, owner and branch context; that the height lies inside Y; distinct block hashes; both applicable evidence windows; and still-reserved liability. Slash each involved reserved position at most once under the existing bounded payout policy. A late receipt does not create liability after an explicitly expired promise; clients must respect evidence windows.

**Proven:** the existing terminal `endBlockHash/endL2Number` authenticates this predicate only for Y's terminal block. To cover an interior height cheaply, add a bounded ordered block-hash commitment to the circuit-verified statement and task identity, with exact index/height/length binding and a canonical inclusion proof. With at most 60 blocks this can be a fixed padded tree with a bounded path. The circuit must derive every committed hash from the proved execution. An unverified header list attached by a reporter is not sufficient.

**Proven:** merely sharing a parent, having different segment lengths, or carrying a different job/beneficiary is not a conflicting block endorsement. If Y does not reach X's height, this particular evidence is absent. A new canonical base head permits a new provisional branch under the current rule. The mechanism targets the exact same-head overlap, not every later rebase.

### 4.3 What this improves, and what it does not

**Proven:** if an owner promises public X and then authorizes an accepted incompatible Y, the owner cannot avoid the same-owner equivocation rule merely by omitting a second `DutyClaim`. The reporter needs no proof that Y was historically private. This is a direct, useful fix for one active-publisher attack.

**Proven:** this must not be generalized to “X lost, so slash X.” Alice may honestly serve X while unrelated Bob lands Y. Bob's winning transaction supplies no authenticated misconduct by Alice. Slashing Alice on that basis permits an attacker to buy cheap conflicting proofs in order to drain honest soft-service collateral.

**Proven:** Alice can instead use another owner address and its independently funded authorization. The chain cannot infer common ownership solely from signatures or payment direction. Mandatory collateral makes this cost explicit, but a returned bond is a capital cost, not an automatically incurred slash. Deterrence therefore remains **Open** against cross-owner MEV and repeated private proving. This scoped improvement must not be presented as complete private-fork prevention.

## 5. Mandatory witness certificates and the strict-based boundary

### 5.1 Nonexclusive availability is distinct from ordering

**Proposed certificate semantics:** each witness says “I possess these committed bytes and accept the specified response liability.” It may sign several forks. L1 still picks among eligible proof-bearing candidates.

**Proven:** these certificates do not by themselves settle ordering. Under an explicit honest-online-holder assumption and bounded propagation, honest witnesses can spread a certified candidate. If all signers may belong to one actor, a threshold of signatures does not imply that assumption. If one signer being honest is enough, the design still needs a reason the required signer set contains one; permissionless registration alone supplies none.

**Proven counterexample to strict immediate admission:** a new entrant has a correct next proof and complete data. Every required external witness is offline. Ethereum's current proposer is willing to include the action. A contract that rejects it for missing witness signatures has introduced an independent admission dependency, even though the witnesses are nonexclusive and the final transaction order remains L1-selected.

**Open terminology:** a broader “L1 chooses final order among certified candidates” use of based may permit this structure. The currently chosen strict meaning does not. A mechanism comparison should state both facts rather than silently redefining based or claiming that every availability witness is necessarily a BFT sequencer.

### 5.2 Escapes and all holders offline

A timeout escape can allow new self-bonded entrants or certificate-free proof submissions. That restores eventual access under its assumptions, but not immediate independence during the timeout. Bind certificates, soft claims, tasks and accepted receipts to a single L1-authoritative generation. An included recovery transition retires the old generation; delayed old certificates cannot override the recovered head. A certificate may still win *before* recovery if it remains admissible under the old rules.

**Proven:** if all copies of an unaccepted candidate disappear, no certificate or recovery vote reconstructs it. Recovery must either wait for a holder or abandon that soft candidate and rebuild from canonical data. A requirement to preserve the exact unavailable soft suffix would need an additional surviving-copy/publication premise. Soft candidates are already allowed to roll back, so that stronger preservation demand should not be invented.

**Proven:** an immediate full-data-and-proof bypass avoids the quorum's hard liveness dependency. It also allows a privately prepared competing branch through that bypass. A higher, explicitly stated bypass fee could make such admission costly, but it also charges honest recovery during witness outages; it is a price schedule, not evidence of withholding. Its calibration and economic adequacy require separate analysis.

## 6. Delayed selection and prior receipts

### 6.1 Waiting after complete atomic reveal

**Proven:** if the first complete public act contains Y's proof and data, adding a delay after that act does not prove that Y was public earlier. If the first arrival already obtains exclusive priority, the later delay does not protect X from the original private-fork race. If the system instead compares later arrivals, its deterministic selection rule needs specification; “earliest signed timestamp” can be backdated, and hash-based selection can be ground unless a separate premise limits it.

**Open R7 compatibility:** publishing data plus proof into a pending candidate set and selecting later might satisfy a looser requirement that *proposals always contain proofs*. It changes the present atomic acceptance transition and may require a second L1 operation or repeat data/proof at final admission. This is different from generic prior data staging, which leaves atomic canonical acceptance intact; see §6.4. Neither should be introduced without disclosing its extra L1 action.

### 6.2 A prior nonexclusive L1 hash/bond notice

**Proven:** a public L1 commitment gives an objective notice time and lets observers challenge a commitment before proof readiness. It need not select a branch: multiple candidates from the same parent can be announced. Therefore it is not automatically an independent sequencing committee or an exclusive lease.

**Proven:** hash publication alone does not supply the body. The producer can still withhold until a challenge or publication deadline. If the body appears before that allowed deadline, there is no default. If landing itself supplies it in time, requiring the earlier hash has not established prior data dissemination.

To guarantee that data is publicly retrievable for a minimum interval **before** canonical selection, a rule must establish the relevant public-data event and enforce that interval. An L1 hash notice plus “nobody complained” does not establish this without an observer/inclusion assumption. Mandatory actual prior publication does establish it under L1 DA assumptions. It adds a data-publication stage and cost, but does not necessarily add an unproved canonical proposal: the canonical action can still carry the complete data and proof atomically. A required independently signed timing certificate substitutes witness honesty/timing and liveness assumptions instead.

**Proven:** a mandatory earlier canonical *ordering* commitment solves a different problem by fixing which branch a later proof must follow. An unavailable chosen body can then hold the head hostage until its specified escape. That is the proposal/selection mechanism the present design deliberately removed; it needs its own all-malicious recovery analysis.

### 6.3 Signed preconfirmation receipts

Receipts are useful evidence of positive statements: an authenticated publisher endorsed a block; a custodian accepted a serving duty; a counterparty acknowledged receipt. They are not proofs of a global negative. A signer-controlled `issuedAt` is not an objective publication timestamp. A third-party receipt may support an honest-witness availability argument, but a contract cannot infer universal earlier dissemination from the mere number of receipts.

**Proven:** making a future duty explicit and checking its L1 deadline is sound even though historical absence is unprovable. Rejecting timeout accountability solely because it cannot prove intent would impose a stronger requirement than the allowed surrogate.

### 6.4 Viable exact construction: nonexclusive actual-data staging

**Proposed rule:** add a permissionless `DataStaging` helper that records actual L1 publication, without updating the Inbox head, reserving a parent, choosing a branch, assigning a worker, promising a reward, or requiring proof of execution. Many competing payloads may be staged. Malformed or execution-invalid payloads receive no canonical status; their publisher merely paid Ethereum to publish bytes.

For blob mode, `stageBlob()` requires a nonzero current-transaction `BLOBHASH(0)` and no unexpected extra blob under the chosen one-blob format. It records the earliest L1 timestamp and block number for that exact versioned hash. A caller-supplied arbitrary hash is not sufficient. Ethereum's blob transaction validity supplies publication at inclusion under A-DA. A later sound execution proof's exact canonical-body-to-KZG/versioned-hash relation binds the accepted payload to the earlier actually published blob. No stage-time execution proof is needed to establish that the bytes existed publicly.

For bounded calldata mode, `stageCalldata(bytes completeBody)` records the exact hash and length of the complete published bytes. Use the existing 32,768-byte calldata-body cap initially. For larger bodies use the blob path, or separately specify bounded chunk staging: the ordered manifest must itself be public and the complete-body publication time is no earlier than the last required fragment and manifest publication. A private ordering manifest cannot be revealed only at acceptance while claiming that an old bag of public fragments was an executable public batch.

**Required context rule:** the staged body must be deterministically decodable under the public versioned format and expose every value needed to reconstruct the candidate's execution/order. If the current body encoding leaves essential origin, parent, timestamps, transaction order or other derivation fields solely in the later statement, publish the corresponding immutable context alongside staging and include it in the staging key. Binding only raw transaction bytes while choosing their order privately later is insufficient. Payment beneficiary and job assignment may remain separate because they do not choose the execution result.

Every canonical `submitSegment` then:

1. Still carries the **full identical** blob/body and the complete valid ZK proof in its one atomic canonical action.
2. Authenticates a staging receipt for that exact payload/context and requires `block.timestamp >= firstPublishedAt + W`, provisionally `W = 360 seconds`.
3. Requires the publication receipt to be within a specified usable DA horizon, in addition to the existing fixed-origin freshness checks.
4. Runs all existing head, force-prefix, proof, checkpoint and payment checks. A staging receipt supplies no ordering priority; the first valid canonical L1 action still wins.

**Proven under A-DA/A-L1/A-CRYPTO:** an accepted candidate cannot first disclose its full execution payload at canonical landing. It necessarily has an actual authenticated prior L1 data-publication event at least W seconds earlier. The contract enforces that predicate directly, rather than trying to prove prior P2P nonreceipt. Privately creating a proof beforehand does not bypass the age check.

**Proven:** this construction keeps the canonical transition atomic. It has no accepted unproved state, proposal ID that reserves the head, privileged proposer, assigned prover, or later proof that merely upgrades an earlier canonical proposal. The literal R7 requirement is that one canonical action carries the full data and proof; it does not expressly require that these bytes never appeared elsewhere before that action. Accordingly, treating staging as automatically forbidden would add the stronger requirement “first publication must be canonical landing.” The cost of an additional generic DA action must nevertheless be prominent. The current draft's prose and interface need revision; this is not an already implemented property.

**Proven:** strict L1 final sequencing and immediate independence from external committees are preserved. Any entrant can stage and later submit; no incumbent can veto its staging. A complete but too-young payload is ineligible under a deterministic public-data rule, not waiting for a private sequencer lease or fresh independent signature. This is a nonexclusive validity/maturity condition. If “strict based” were separately defined to prohibit *all* minimum data ages, that extra restriction would reject it; the stated definition prohibiting external certificate/lease dependence does not by itself do so.

**Assumed timing budget:** W=360 seconds allows a provisional 60 seconds for notice/retrieval, 180 seconds for proving that same fully public candidate, and 120 seconds of margin. A 120-second age would prevent first reveal at landing but remain shorter than the draft's 180-second proof target. If public proof readiness before eligibility is the goal, choose W at least as large as measured retrieval plus proving; these bounds remain assumptions pending benchmarks. The existing inclusion bound applies only after a final transaction is eligible, so the 120-second margin must not be called a guarantee that a transaction is included before its maturity. This ensures opportunity to have a proof ready, not that an honest entrant wins L1 ordering or that its different X branch lands.

**Timing example, not a guarantee:** an honest publisher seals a 60-second soft segment at t=60, stages it then, and starts a 180-second proof. Its proof is ready at t=240 and data becomes age-eligible at t=420. With prompt L1 inclusion, canonical landing occurs around seven to eight minutes after the original base time. If staging instead takes the full assumed 120 seconds to be included and final inclusion takes another 120, the same schedule can land around t=660, approximately eleven minutes. A provisional origin TTL of 900 seconds provides margin; the draft's 600-second TTL needs revision. One-second locally executed soft candidates continue before canonical selection; they do not wait W to be issued. Minimum age is measured in seconds, independent of 12/6/4/2-second slots and without CL lookahead.

**Required job adjustment:** a worker accepting freshly staged work cannot be expected to land it within the current fixed 300-second deadline when W=360. Require an authenticated staging receipt at acceptance and set `deadline = max(acceptedAt + 300, eligibleAt + 120)` under the existing inclusion assumption, or adopt an explicitly equivalent longer window. Apply the enlarged origin TTL to the acceptance freshness check. Keep immutable parent-consumption/revision-retirement cancellation and historical-default semantics. Do not slash a worker for a maturity barrier built into the protocol itself.

**DA expiry rule:** for blob staging choose a maximum eligible staging age `H_stage` that is comfortably shorter than the launch network's guaranteed usable blob-retention window, with an explicit availability/retrieval margin. Verify the launch fork's actual bound; do not equate a particular block count with constant seconds. A provisional 900-second staging eligibility horizon can align with the enlarged origin-age bound, subject to checking the interaction. If a prior receipt is too old, anyone republishes the same blob and starts a fresh W-second notice interval. Thus a sole immutable `firstPublishedAt` value is insufficient for indefinite operation: store the first eligible publication for a bounded generation/window, or a bounded historic receipt identified by its publication block. Do not let arbitrary repeated publication reset another participant's usable earlier receipt. The final action republishes data for the new canonical history regardless. Retain sufficient old publication timestamps through outstanding publication-duty evidence windows; receipt expiry for new canonical admission must not erase historical slash/defense evidence.

**Proven recovery:** if all old holders and publishers stop after staging, an entrant can retrieve their staged bytes while retained and optionally prove them, or stage a different candidate from canonical data. No staged candidate locks the head. After the minimum age and proof production the entrant can land without anyone's vote. If all staged copies have expired or disappeared, rebuild from retained canonical data. The rule does not guarantee retrieval without A-DA/A-ARCHIVE, but an unavailable unproved candidate cannot make recovery wait forever. Stale proofs remain stale after canonical parent consumption.

**Costs and remaining limits:** every accepted payload incurs staging plus full republication at acceptance—normally two blob inclusions or duplicate calldata bytes, and extra helper state/transaction overhead. Unsuccessful competitors also pay for their staged data. Bound helper writes, fees and receipt retention; permissionless junk staging must buy its L1 resource use and cannot create an unbounded scan. Blob fee spikes, stage inclusion, origin expiry and proof latency can require resealing/reproving. Stage all execution-affecting inputs before their proof is computed; new force requests must retain the existing parent-frozen semantics. **Open:** benchmark sustainable economics and retention machinery. Private computation before timely staging, valid soft forks losing, and wasted competing proofs remain possible; this mechanism establishes a public-data lead, not a unique soft order or universal MEV deterrence.

### 6.5 Add an absolute publication deadline for advertised payloads

Mandatory age rejects unstaged canonical candidates but does not itself slash a producer that advertises unavailable data and never lands. The serving covenants in §3 address that case. A further objective covenant can eliminate the particular “reveal just before a later challenge deadline” escape:

**Proposed rule:** an authenticated publisher signs an exact staging-key obligation backed by a reserved position: `publishBy = issuedAt + 240 seconds`, with `issuedAt` constrained to the existing recorded bucket issuance window. Success means a qualifying matching staging receipt exists at or before `publishBy`. At `now > publishBy`, anyone presents the signature and proves default from the immutable receipt time or its absence. A late matching publication does not cure this earlier default. Apply the same bounded slash, reporter/sink split, evidence window and strict-before-release settlement rules. A third party's timely staging may satisfy the duty because the obligation is to ensure public data, not prove personal storage.

**Proven:** the registry's issuance window limits the possible signed deadline, but still does not prove actual signing time. This is an explicit publication-by obligation, not a claim that universal P2P delivery occurred at `issuedAt`. Honest false-default analysis needs adequate notice, data possession, funding and inclusion bounds. A maximum 60-second issuance interval plus 240-second publication allowance is not itself a measured SLA.

**Required binding detail:** the exact publication key must be known when the promise is signed. This is simple for a sealed segment's complete versioned blob hash, or for a bounded block/fragment promised in calldata by hash and length. It is **not** automatic for an early one-second block later packed into a not-yet-known segment blob. A block's keccak digest is not a blob versioned hash. Crediting that block from a staged blob requires an authenticated data-membership/binding mechanism, recorded within the promised deadline; a caller's claimed membership or a single unrelated KZG opening is insufficient. The existing final execution proof can certify the relationship, but if that proof arrives after the publication-by deadline it must not retroactively supply missing timely evidence. A clean first version can apply the absolute deadline to sealed segment promises and retain §3 challenges for earlier block claims, or require bounded direct calldata publication for their exact keys. Specify and price the chosen path before claiming coverage of every one-second promise.

**Proven:** with that binding complete, the conjunction is stronger than either component alone: every canonical candidate had at least W seconds of authenticated prior public data, and every accepted signed publication-by duty can be objectively slashed even if data appears late. No witness quorum, false attribution of a third party's fork, or proof of universal historical absence is needed. **Open:** whether its cost and exact advertised-payload scope satisfy the user's practical target; this is a genuine candidate under literal R1–R7, not a demonstrated need to relax them.

## 7. Canonical-only penalties and safe recovery

**Proven:** “slash only when the unavailable claim later becomes canonical” misses a malicious advertised branch that never lands. “Cancel all claims once another branch lands” lets an attacker erase already accepted service obligations. Neither is an adequate replacement for independently timed signed duties.

**Recommended recovery rule:** keep serving defaults independent of canonical success; use canonical receipts only as authenticated content evidence when the accountable owner explicitly authorized them. Never punish an honest claimant merely because a different actor's valid proof wins.

Under total incumbent failure:

1. Stop accepting unavailable candidates as locally executed preconfirmations; retain existing signatures and open valid funded challenges where possible.
2. Permit any new funded prover/publisher to enter and obtain the accepted canonical state and its published data under the ordinary archive assumption.
3. Build and prove a successor using the parent-frozen forced prefix. Do not inherit an unavailable soft suffix or wait for the failed service's consent.
4. Slash independently established expired serving duties. Do not waive them merely because recovery consumed the parent; do not slash nondefaulting honest duties merely because recovery selected another branch.
5. After canonical recovery, an old proof naming the consumed parent is stale. No old signature, witness certificate or publication challenge can resurrect it.

**Proven:** this prevents the missing soft branch from locking recovery and prevents the attacker from using recovery to impose an automatic “you lost” slash on an honest publisher. It does **not** prevent a complete private proof from winning before recovery's transaction, nor does it refund discarded proving work. Existing forced-prefix rules constrain transaction censorship even in that race, but do not protect discretionary soft order. Calling the residual race impossible to exploit would overstate the repair.

## 8. Scoped impossibility and smallest relaxation

**Proven under the stated transcript model:** consider two histories with identical canonical data/proof, identical authenticated promises, identical registry balances and no missed public deadline. In one, Y's producer honestly disseminated Y earlier; in the other, it privately prepared Y and first revealed it at landing. If no trusted earlier publication fact distinguishes the histories, the deterministic on-chain slashing decision is identical. Mandatory bonds do not change that information boundary. This proves only the inability to distinguish that historical predicate from those inputs; it does not prove that R1–R7 are inconsistent.

**Proven:** with a finite response timeout, a censored honest response and a never-sent response may likewise leave identical L1 histories. Objective service default is still definable; zero false attribution of *malice* under arbitrary censorship is not. The existing bounded-inclusion premise is the appropriate declared condition, not a hidden unconditional guarantee.

The smallest choices are therefore:

- **If a mandatory minimum pre-landing public-data interval is acceptable:** implement the nonexclusive actual-data staging rule in §6.4 and keep full data plus proof in the one canonical action. Add the correctly bound publication-by covenant in §6.5 where advertised withholding must incur a slash. This prevents the first-reveal-at-landing gap through an objective eligibility rule and punishes explicit missed publication deadlines. It can satisfy the literal constraints without changing who finally sequences, while imposing substantial extra DA cost. Do not confuse it with the separate unproved canonical proposal it replaces. This is the preferred concrete alternative to investigate before any negative verdict.
- **If the allowed timeout surrogate is the required guarantee:** use mechanism A and the authenticated same-owner extension B. State the exact measurable duties, detection premises and residual cross-owner/private-fork race. No change to one-second soft production, CL independence, existing bridge addresses, or atomic canonical DA+proof is needed. This is a viable mechanism direction; economics and implementation remain unverified.
- **If the required attack guarantee includes every damaging private fork:** the present always-open first-reveal-at-landing path does not meet it, even after mandatory self-bonding. Actual-data staging removes that first-reveal path but does not make every soft reorganization slashable. If the requirement additionally prohibits ordinary competing public branches or private computation before a timely stage, identify that stronger predicate explicitly. An enforceable ordering rule or a semantic relaxation may then be necessary; that stronger requirement must not be inferred from a generic request for withholding accountability.

**Open adjudication:** a reviewer may accept or reject the first choice only against the actual requested withholding coverage. Do not mark R6 fully passed merely because an incomplete mechanism has a disclaimer, and do not mark the entire brief impossible by replacing its permitted timeout surrogate with universal historical nonavailability proof. Strong anti-monopoly economics is a separate remaining R6 question and is not solved by this note.
