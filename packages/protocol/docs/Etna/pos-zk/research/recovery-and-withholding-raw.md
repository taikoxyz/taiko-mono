# Recovery and Withholding — Raw Research (Mode A / Mode B input)

Status: **raw research, not a specification** · Date: 2026-10-05 (Asia/Singapore) · All external
retrieval dates are **2026-10-05** unless a row says otherwise · Author: research sub-agent (Task 1–7 brief)

Scope: evidence for the Etna PoS+ZK decision on whether **Mode A** (never invalidate PoS-finalised
history; halt safely) is feasible, and what published mechanisms exist for **Mode B** (an authorised
L1 recovery path). This file is *input* to the decision, not the decision.

## Headline findings (this agent's view — reasoning, not a source claim)

| # | Finding | Where |
|---|---------|-------|
| H1 | No reviewed protocol treats "no certificate within T" as evidence that no certificate exists. Timeouts rotate rounds/views or halt; the lock/locked-QC state plus slashing is what protects a decision already taken | §1.5, §7 |
| H2 | "Finalized" has never implied "retrievable": Ethereum prunes blob data at ~18 days and history at 14,299 epochs, and its own sync path depends on trusted weak-subjectivity checkpoints | §2.1–2.3 |
| H3 | The strongest counterexample to Mode A is certified-but-unavailable data: a quorum can sign a block whose data no holder is obliged or incentivised to keep, and D5 then makes it unprovable and unsettleable while Mode A forbids discarding it | §3.2 C2 |
| H4 | The published literature's answer to the availability-finality dilemma is *delayed finality* (finalize only an L1-anchored prefix), not finality rollback; no named checkpoint-rollback proposal was retrieved | §4, S20 |
| H5 | Taiko's current forced-inclusion path contains a documented incident (June 2026) where queued blob references expired and became underivable, and an owner-only function that voids the whole queue | §5, S29 |
| H6 | Mode A's safety argument is sound under <1/3 equivocation; its failure is liveness/availability (halt, 2 s cadence vs permissionless wide-area membership, proving latency) | §3.3 |

---

## 0. How to read this file

Evidence tags used on every claim:

| Tag | Meaning |
|-----|---------|
| **SPEC** | Normative text of a protocol specification or standard (EIP, consensus-spec, CometBFT spec) |
| **PAPER** | Peer-reviewed / arXiv paper by the protocol authors |
| **DOCS** | Official project documentation (not normative) |
| **CODE** | Source code read in this workspace or a pinned upstream repository |
| **PRESS** | News reporting; treated as a lead, never as proof |
| **REASON** | The author's own reasoning (explicitly not a source claim) |
| **UNVERIFIED** | Claim could not be confirmed from a source actually retrieved in this session |

Two conventions:

1. **Quotes are verbatim** between straight quotes, with the source immediately after. Where the
   retrieved render mangled mathematics (ar5iv renders formulas character-by-character), the claim is
   paraphrased and marked accordingly.
2. "Retrieved 2026-10-05" means the page/raw file was fetched by this agent on 2026-10-05. For
   Git-hosted files, a commit SHA is given where the GitHub API gave one; files fetched from a
   repository's default branch without a SHA are marked **moving target**.

### 0.1 Source register

| # | Source | URL | Version / pin | Type | Retrieved |
|---|--------|-----|---------------|------|-----------|
| S1 | CometBFT consensus algorithm spec | https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md | commit 709fd12b4b18cf1442d43c5d34009392c7d674ed (2025-09-03) per GitHub API for this path | SPEC | 2026-10-05 |
| S2 | CometBFT evidence spec | https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/evidence.md | main branch, no SHA pinned (moving target) | SPEC | 2026-10-05 |
| S3 | CometBFT validator signing spec | https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/signing.md | main branch, no SHA pinned (moving target) | SPEC | 2026-10-05 |
| S4 | CometBFT BFT time spec | https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/bft-time.md | main branch (moving target) | SPEC | 2026-10-05 |
| S5 | CometBFT time/PBTS spec | https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/time.md | main branch (moving target) | SPEC | 2026-10-05 |
| S6 | Casper FFG paper | https://ar5iv.labs.arxiv.org/html/1710.09437 | arXiv:1710.09437, version not shown on ar5iv render (**UNVERIFIED version**) | PAPER | 2026-10-05 |
| S7 | Tendermint consensus paper | https://ar5iv.labs.arxiv.org/html/1807.04938 (abstract page https://arxiv.org/abs/1807.04938) | arXiv:1807.04938, version not shown (**UNVERIFIED**) | PAPER | 2026-10-05 |
| S8 | HotStuff paper | https://ar5iv.labs.arxiv.org/html/1803.05069 | arXiv:1803.05069, version not shown (**UNVERIFIED**) | PAPER | 2026-10-05 |
| S9 | Ethereum consensus-specs — weak subjectivity guide | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/weak-subjectivity.md | commit 6b9bd532cca16555e2f3282d757622ebff29743e (2026-09-22) per GitHub API | SPEC | 2026-10-05 |
| S10 | Ethereum consensus-specs — beacon chain | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md | master, no SHA pinned (moving target) | SPEC | 2026-10-05 |
| S11 | Ethereum consensus-specs — fork choice | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/fork-choice.md | master, no SHA pinned (moving target) | SPEC | 2026-10-05 |
| S12 | EIP-4844 (proto-danksharding) | https://eips.ethereum.org/EIPS/eip-4844 | EIP page as published; status not captured (**UNVERIFIED status**) | SPEC | 2026-10-05 |
| S13 | EIP-7594 (PeerDAS) | https://eips.ethereum.org/EIPS/eip-7594 | page self-describes status **Final** (verified in page header) | SPEC | 2026-10-05 |
| S14 | EIP-4444 (bound historical data) | https://eips.ethereum.org/EIPS/eip-4444 | page self-describes status **Draft** (verified in page header) | SPEC | 2026-10-05 |
| S15 | EIP-3076 (slashing protection interchange) | https://eips.ethereum.org/EIPS/eip-3076 | page self-describes **Last Call** (verified) | SPEC | 2026-10-05 |
| S16 | Narwhal & Tusk | https://ar5iv.labs.arxiv.org/html/2105.11827 | arXiv:2105.11827, version not shown (**UNVERIFIED**) | PAPER | 2026-10-05 |
| S17 | BullShark | https://ar5iv.labs.arxiv.org/html/2201.05677 | arXiv:2201.05677, version not shown (**UNVERIFIED**) | PAPER | 2026-10-05 |
| S18 | Mysticeti | https://arxiv.org/html/2310.14821v4 | **arXiv:2310.14821v4**, 13 Jul 2024 (verified in page text) | PAPER | 2026-10-05 |
| S19 | Shoal | https://ar5iv.labs.arxiv.org/html/2306.03058 | arXiv:2306.03058, version not shown (**UNVERIFIED**) | PAPER | 2026-10-05 |
| S20 | Ebb-and-Flow Protocols (Neu, Tas, Tse) | https://eprint.iacr.org/2020/1091 | IACR eprint 2020/1091; "Forthcoming in 42nd IEEE S&P 2021" per abstract page | PAPER | 2026-10-05 |
| S21 | Vitalik Buterin, "Proof of Stake FAQ" (2020) | https://vitalik.eth.limo/general/2020/11/06/pos2020.html | page version not tracked (moving target) | DOCS/ANALYSIS | 2026-10-05 |
| S22 | Aditya Asgaonkar, "Weak Subjectivity in Eth2.0" | https://notes.ethereum.org/@adiasg/weak-subjectvity-eth2 | HackMD note, no revision shown (**UNVERIFIED revision**); referenced by S9 | DOCS/RESEARCH NOTE | 2026-10-05 |
| S23 | OP Stack Stage 1 roles and requirements | https://specs.optimism.io/protocol/stage-1.html | specs site, no revision (moving target) | SPEC | 2026-10-05 |
| S24 | OP Stack docs — forced transaction flow | https://raw.githubusercontent.com/ethereum-optimism/optimism/develop/docs/public-docs/op-stack/transactions/forced-transaction.mdx | develop branch, no SHA pinned (moving target) | DOCS | 2026-10-05 |
| S25 | Optimism docs — OP Stack security model | https://docs.optimism.io/op-stack/security/faq-sec-model | no revision (moving target); page body is client-rendered, only navigation text extracted | DOCS | 2026-10-05 |
| S26 | Optimism docs — Pausing the bridge | https://docs.optimism.io/op-stack/security/pause | no revision (moving target); body client-rendered, nav only | DOCS | 2026-10-05 |
| S27 | Arbitrum Nitro contracts — SequencerInbox.sol | https://raw.githubusercontent.com/OffchainLabs/nitro-contracts/master/src/bridge/SequencerInbox.sol | repo pin **ff6334e7bfe6468f85202df98db92468e25f5688** (2026-10-02, GitHub API, default branch master) | CODE | 2026-10-05 |
| S28 | zkSync Era docs — L1 to L2 communication (v25.2.0) | https://matter-labs.github.io/zksync-era/core/v25.2.0/specs/l1_l2_communication/l1_to_l2.html | docs pinned **v25.2.0** in URL | DOCS | 2026-10-05 |
| S29 | Taiko monorepo (this workspace) | /Users/daniel/Projects/taikoxyz/taiko-mono | revision **7718753c1cece7d7705afaf33e6f9680115086dd** (git rev-parse, 2026-10-05) | CODE | 2026-10-05 |
| S30 | The Block, "Ethereum developers release patches for recent beacon chain finality issues" | https://www.theblock.co/news/ecosystems/2023-05-13-ethereum-beacon-chain-patches-finality-issues-230723 | press article; primary postmortem **not retrieved (UNVERIFIED)** | PRESS | 2026-10-05 |
| S31 | Fischer–Lynch–Paterson impossibility (1985) and Dwork–Lynch–Stockmeyer partial synchrony (1988) | not retrieved as full text; no stable URL confirmed in this session | **UNVERIFIED — cited from memory, do not use as a citation until fetched** | PAPER | not retrieved |

Sources deliberately **not** used because the pages could not be retrieved as text in this session:
Celestia docs (client-rendered; https://docs.celestia.org/learn/celestia-101/data-availability
returned navigation only), EigenDA docs (https://docs.eigenda.xyz/ returned HTTP 522), Celestia spec
repository (GitHub contents API 404 on the paths tried), L2Beat escape-hatch pages (404 on the paths
tried), HotStuff-2 (arXiv:2302.04091, all URLs tried returned 404 / cross-origin redirect).

---

## 1. The unpublished-certificate problem

Question asked: *a certificate exists but has not been published or received — how do established
protocols behave, and is "we did not receive a certificate within timeout T" ever proof that no
certificate exists?*

Short answer, stated before the evidence: **no protocol reviewed here treats a timeout as evidence of
absence.** A timeout changes a node's *round* or its *view*, or halts it; it never licenses the
inference "therefore no quorum signed". What protects a node that has *already* taken a local
decision is not the certificate it has seen, but the **lock/locked-QC state plus the slashing
conditions that make a conflicting certificate cost at least 1/3 of the stake** — and, for data, the
availability properties of the dissemination layer (Section 2).

### 1.1 Tendermint / CometBFT

Primary text: S1 (CometBFT spec, pinned commit 709fd12b...). The spec defines the proof-of-lock
mechanism, the lock rule, and the safety argument.

| Claim | Verbatim text | Source |
|-------|---------------|--------|
| A proof-of-lock-change (PoLC) is defined by a supermajority of prevotes at a round | "A set of +2/3 of prevotes for a particular block or `<nil>` at `(H,R)` is called a _proof-of-lock-change_ or _PoLC_ for short." | S1 |
| The lock is round-scoped and changes only with a *later* PoLC | "First, if the validator is locked on a block since `LastLockRound` but now has a PoLC for something else at round `PoLC-Round` where `LastLockRound < PoLC-Round < R`, then it unlocks. If the validator is still locked on a block, it prevotes that. Else, if the proposed block from `Propose(H,R)` is good, it prevotes that. Else, if the proposal is invalid or wasn't received on time, it prevotes `<nil>`." | S1 |
| Lock (re)acquisition happens on precommit | "If the validator has a PoLC at `(H,R)` for a particular block `B`, it (re)locks (or changes lock to) and precommits `B` and sets `LastLockRound = R`." | S1 |
| A proposer advertises the lock it knows about; a node can only unlock against a *later* round's PoLC | "A proposal at `(H,R)` is composed of a block and an optional latest `PoLC-Round < R` which is included iff the proposer knows of one. This hints the network to allow nodes to unlock (when safe) to ensure the liveness property." | S1 |
| Safety does not depend on the certificate being seen by everyone | "If a validator commits block `B` at round `R`, it's because it saw +2/3 of precommits at round `R`. This implies that 1/3+ of honest nodes are still locked at round `R' > R`. These locked validators will remain locked until they see a PoLC at `R' > R`, but this won't happen because 1/3+ are locked and honest, so at most -2/3 are available to vote for anything other than `B`." | S1 |
| A conflicting commit requires 1/3+slashable equivocation | "**Lemma**: When a fork is detected by the existence of two conflicting commits, the union of the JSets for both commits (if they can be compiled) must include double-signing by at least 1/3+ of the validator set." | S1 |
| The certificate matters for *commitment*, not for safety | "if light clients and validators do not consider a block to be committed unless the JSet of the commit is also known, then we get the desirable property..." (sentence truncated in the retrieved render) — the "Alternative algorithm" section makes the commit *certificate* an explicit part of what a light client must obtain | S1 |
| Commits are gossiped so a node that missed a commit can catch up | "Nodes gossip to nodes lagging in blockchain height with block commits for older blocks." | S1 |
| Double-signing rules are local and enforced before signing | "once a validator signs a precommit for a given height and round, it must not sign any other message for that same height and round. Note this includes votes for `nil`" | S3 |
| Evidence has an expiry tied to unbonding | "for Proof of Stake chains where validators are bonded, evidence age should be less than the unbonding period so validators still can be punished." | S2 |
| Amnesia (a validator that "forgets" and signs a conflicting vote after restart) is an explicitly modelled attack | "If the header is valid, then the validator sets are the same and this is either a form of equivocation or amnesia." | S2 |

**Answers to the three sub-questions.**

1. *Exactly how does a correct validator behave at a later height when it has a lock but no
   certificate?* It **stays locked** and prevotes the locked block. It unlocks only against a PoLC at
   a strictly later round (S1, Prevote step). If it never receives such a PoLC it keeps prevoting the
   locked block; this is why 1/3+ honest locked validators stop a conflicting commit (S1, Proof of
   Safety). The cost of this rule is liveness: a validator that is locked and cannot see the round
   that produced the (unpublished) certificate simply cannot make progress. **REASON:** in a 2 s
   cadence, "cannot make progress" for longer than the round-timeout ladder means the chain stalls —
   by design, not by bug.
2. *What forbids conflicting votes?* Two independent mechanisms: (a) the lock rule above; (b) the
   signing rules, which are purely local and forbid two different messages of the same type at the
   same height/round (S3). The economic teeth are in fork accountability: a fork implies 1/3+
   double-signers (S1), and evidence is age-limited relative to unbonding (S2). Note that CometBFT
   itself says there is "not currently any explicit mechanism to punish validators signing votes or
   proposals that fail these basic validation rules" — the *punishment* is an application concern
   (S3).
3. *Can an unpublished commit invalidate a locally taken "decision"?* **No, not without 1/3+
   equivocation** (S1 fork-accountability lemma), and the reasoning does not depend on the node
   having seen the other commit. But the converse is the trap: **the fact that a node has not seen a
   certificate is not evidence that no certificate exists.** The CometBFT spec's liveness proof
   explicitly relies on the network eventually gossiping the missing proposal/PoLC: "eventually the
   network is able to 'fully gossip' the whole proposal (e.g. the block & PoLC)" (S1). Until that
   happens the correct behaviour is *stall*, not *conclude*.

### 1.2 HotStuff family

Primary text: S8.

| Claim | Verbatim text | Source |
|-------|---------------|--------|
| Safety rule (locked node) | "The safety rule to accept a proposal is the branch of m.node extends from the currently locked node lockedQC.node." | S8 |
| Liveness rule (higher QC) | "On the other hand, the liveness rule is the replica will accept m if m.justify has a higher view than the current lockedQC." | S8 |
| New leaders adopt the highest QC they know | "HotStuff revolves around a three-phase core, allowing a new leader to simply pick the highest QC it knows of." | S8 |
| The known blocker: an honest replica may hold the highest QC that the leader has never seen | "The crux of the difficulty is that there may exist an honest replica that has the highest QC, but the leader does not know about it. One can build scenarios where this prevents progress ad infinitum." | S8 |
| Non-responsiveness is inherent to designs that must wait for the highest QC | "Optimistic or not, responsiveness is precluded with designs such as Tendermint/Casper." | S8 |

**Interpretation (REASON, on top of the quotes).** A withheld QC constrains a later view change in
exactly one direction: the view change may only advance to a proposal that extends the locked node.
A QC that exists but is withheld therefore **cannot** be used by a node to violate safety (it will
reject branches not extending its lock) — but it **can** block liveness indefinitely, because no
node can prove the absence of a higher QC. The safety/liveness split is precise: withholding a
certificate is a **liveness attack**, never a safety attack, against a locked honest node.

**UNVERIFIED / not retrieved:** HotStuff-2 (arXiv:2302.04091) — all retrieval attempts (ar5iv,
arxiv.org/html variants) failed with 404 or cross-origin redirect; the "preferred branch"/
"locked node"/"highQC" formulations attributed to HotStuff-2 in the brief could not be confirmed in
this session. Do not cite HotStuff-2 in the specification until fetched.

### 1.3 Casper FFG and the Ethereum consensus specs

Primary texts: S6 (Casper FFG), S10 (beacon-chain.md), S11 (fork-choice.md), S9 (weak subjectivity).

| Claim | Verbatim text | Source |
|-------|---------------|--------|
| Accountable safety | "Accountable safety means that two conflicting checkpoints cannot both be finalized unless >= 1/3 of validators violate a slashing condition (meaning at least one third of the total deposit is lost)." | S6 |
| Theorem statement | "**Theorem 1 (Accountable Safety)**. Two conflicting checkpoints a_m and b_n cannot both be finalized." | S6 |
| Two slashing conditions replace the earlier four | "The most notable property of Casper is that it is impossible for any two conflicting checkpoints to be finalized unless >= 1/3 of the validators violate one of the two slashing conditions." | S6 |
| First commandment (double vote) | "An individual validator v must not publish two distinct votes, <v, s1, t1, h(s1), h(t1)> and <v, s2, t2, h(s2), h(t2)>, ..." (the retrieved render truncates the formulas; the condition is the no-two-distinct-votes rule) | S6 (formula render mangled) |
| Surround-vote condition | Described in S6 Figure 2 as the second commandment, forbidding a validator from voting a pair that "surrounds" another pair (h(s1) < h(s2) < h(t2) < h(t1)). **The exact formula could not be quoted verbatim from the retrieved render — UNVERIFIED verbatim, description reliable.** | S6 |
| Finality is a state function of justification bits, not a certificate a node must have seen | "if all(bits[1:4]) and old_previous_justified_checkpoint.epoch + 3 == current_epoch: state.finalized_checkpoint = old_previous_justified_checkpoint" (process_justification_and_finalization) | S10 |
| The fork choice *excludes* anything conflicting with the finalized checkpoint | "finalized_checkpoint: the highest known finalized checkpoint. The fork choice only considers blocks that are not conflicting with this checkpoint." | S11 |
| Inactivity leak exists to restore finality when participation is missing | "def is_in_inactivity_leak(state: BeaconState) -> bool: return get_finality_delay(state) > MIN_EPOCHS_TO_INACTIVITY_PENALTY" | S10 |
| Weak subjectivity: a *trusted* input is required, and failure is fatal by design | "Clients should allow users to input a Weak Subjectivity Checkpoint at startup, and guarantee that any successful sync leads to the given Weak Subjectivity Checkpoint along the canonical chain. If such a sync is not possible, the client should treat this as a critical and irrecoverable failure." | S9 |
| The WS checkpoint is the new genesis for fork choice | "if a node sees a block conflicting with a weak subjectivity checkpoint, then it immediately rejects that block. As far as the fork choice of nodes is concerned, the latest weak subjectivity checkpoint is the new genesis block of the network." | S22 |
| Safety margin decays; the WS period is a parameterised trust window | "SAFETY_DECAY is defined as the maximum percentage tolerable loss in the one-third safety margin of FFG finality. Thus, any attack exploiting the Weak Subjectivity Period has a safety margin of at least 1/3 - SAFETY_DECAY/100." | S9 |
| Casper's own slashing enforcement lives on the chain it protects | "In current Ethereum, stopping the enforcement of a slashing condition requires a successful 51% attack on Ethereum's proof-of-work block proposer." (paper written pre-Merge) | S6 |

**"Finality-reversal resistance" — exact statement.** Casper gives *accountable* safety (S6 Thm 1);
the client-side rule is the fork-choice filter (S11); the *economic* answer to a finality-reversing
51% attack is slashing plus social recovery, not cryptographic impossibility: "For certain kinds of
51% attacks (particularly, reverting finalized blocks), there is a built-in 'slashing' mechanism in
the proof of stake consensus by which a large portion of the attacker's stake (and no one else's
stake) can get automatically destroyed. For other, harder-to-detect attacks (notably, a 51% coalition
censoring everyone else), ..." (S21; the sentence continues beyond the retrieved window).
**REASON:** this is the load-bearing asymmetry for the Etna design — slashing *detects and punishes*
reversal, and it requires the evidence to be available and within the evidence window; it does not
make reversal impossible.

**Inactivity leak, precisely.** The leak is a liveness-recovery mechanism, not a safety mechanism:
when finality is delayed beyond MIN_EPOCHS_TO_INACTIVITY_PENALTY, non-participating validators lose
balance until the participating set crosses 2/3 again (S10). It buys finality back by *burning*
inactive stake — it never invalidates a finalized checkpoint. **REASON:** a "halt-safe" L2 could copy
this, but it needs a validator-set/balance model that makes burn-and-continue safe; Ethereum's leak
is tuned to a very large, slowly-churning validator set, not to a 2 s permissionless committee.

### 1.4 DAG-based BFT (Narwhal/Bullshark, Mysticeti, Shoal)

| Protocol | Is finality certificate-based? | What withholding does | Verbatim anchor |
|----------|-------------------------------|-----------------------|-----------------|
| Narwhal (S16) | Certificates in Narwhal are **availability** certificates, not finality: the paper defines write(d,b) returning "an unforgeable certificate of availability on the digest d" | A missing certificate is a missing *write*: the block is not in the DAG, so it cannot be ordered; the protocol does not conclude "no block was ever proposed" | "The returned value c(d) represents an unforgeable certificate of availability on the digest d and we say that the write succeeds when c(d) is formed." (S16) |
| Narwhal (S16) | The separation is explicit | Withholding hurts availability/liveness, not the integrity of already-certified data | "The Integrity and Block-Availability properties of Narwhal allow us to clearly separate data dissemination from consensus." (S16) |
| Narwhal (S16) | Garbage collection is the hard part | A DAG "is a local structure"; a node that lacks vertices must not GC past them, and the paper notes a GC bug that exhausted 120 GB RAM | "This challenge stems from the fact that a DAG is a local structure and although it will eventually converge to the same version in all validators ..." (S16); footnote 4: "A bug in our garbage collection led to exhausting 120GB of RAM in minutes compared to 700MB memory footprint of Narwhal." (S16) |
| Bullshark (S17) | Yes, commit rule over the DAG | A faulty/missing leader is handled without a view-change protocol; the protocol is "symmetric, and does not require a view-change or view synchronization mechanisms after a faulty leader" | "The protocol is fundamentally different from previous partially synchronous protocols since it is symmetric, and does not require a view-change or view synchronization mechanisms after a faulty leader." (S17) |
| Mysticeti (S18) | Yes, but blocks are **uncertified** | The commit rule is constrained by divergent sub-DAG views; the design goal is to commit more blocks per round | "our approach cannot afford to require sufficient distance between two potential candidate blocks on the DAG to prevent conflicting decisions among validators with divergent sub-DAG views" (S18) |
| Shoal (S19) | Yes, over a pipelined DAG | Pipelining proposes/commits across instances; withholding an anchor still costs a round, not a safety violation | "While the instances are not executing concurrently, this scheme effectively pipelines the 'proposing' and 'voting' rounds. As a result in Shoal, in a good case an anchor is ordered in every round." (S19) |

**REASON (synthesis).** Across all four, a DAG vertex/certificate is *data-plus-signatures*; the DAG
is the availability layer. None of these papers makes a claim of the form "if you have not received
the certificate by time T, it does not exist". Skipped leaders in Bullshark-style rules are *skips in
the local DAG view*, and the safety argument accounts for the fact that another validator's view may
contain the vertex (S17, S18). **Practical consequence for Etna:** if finality is defined as
"certificate published", then a certificate that exists but is withheld is indistinguishable, to
every node that lacks it, from a certificate that does not exist — forever, unless some other node
publishes it. Mode A must therefore specify what a node does with that permanent ambiguity (halt),
not pretend it can resolve it.

### 1.5 Is "not received within T" ever proof of absence? — the general principle

| Statement | Evidence |
|-----------|----------|
| No reviewed protocol treats a timeout as evidence of absence; timeouts rotate rounds/views or halt | S1 (round timeouts and PoLC-based unlock), S8 (view change picks the highest QC *known*), S16–S19 (skips are local-view events) |
| A quorum certificate proves that a quorum signed; it does not prove that anyone else received it — gossiped votes and commits are exactly the mechanism by which non-signers learn | S1: "Nodes gossip prevote/precommit votes"; "Nodes gossip to nodes lagging in blockchain height with block commits for older blocks" |
| Timing assumptions are explicit parameters, not facts about the network: CometBFT exposes SynchronyParams (Precision, MessageDelay) for PBTS | S5: "From SynchronyParams, the Precision and MessageDelay parameters" |
| Ethereum's own answer to "a node was offline and cannot verify history" is an out-of-band trusted checkpoint, not a timeout inference | S9 (WS checkpoint), S14: "Clients MUST use a valid Weak Subjectivity Checkpoint to bootstrap from a more recent view of the chain. For the purpose of syncing, clients treat weak subjectivity checkpoints as the genesis block." |
| The asynchronous/partial-synchrony literature makes the same point formally (FLP: a silent process cannot be distinguished from a slow one; DLS: message delay is unbounded until GST) | **S31 UNVERIFIED — papers not retrieved in this session.** Do not cite until fetched. |

> **Rule for the Etna specification (proposed, REASON).** "We did not receive a certificate within
> timeout T" MUST NOT appear as a premise in any rule. The only admissible forms are: (a) "we have a
> valid certificate" (evidence of a quorum's signatures), (b) "we are locked/locked-QC on X" (local
> state), (c) "we have not received X by T, therefore we enter state Y (round change / halt)" — an
> action, never an existential claim.

---

## 2. Data availability vs finality

Question asked: *how do published designs separate "the block is final" from "the block's data is available"?*

### 2.1 The standard argument and its exact limits

The common argument is: "a quorum voted for the block, therefore a quorum had the block, therefore the
data is available." Its primary formulations and its limits:

| Step | Primary anchor | Limit that the source itself states or implies |
|------|----------------|------------------------------------------------|
| A quorum holding a block is a *protocol* property, not a storage guarantee | Narwhal (S16): "Block-Availability" is one of the mempool properties, alongside Integrity | Narwhal's property is about *retrievability from honest parties while the DAG retains the vertex*; the paper treats garbage collection as an explicit design problem, not a permanent-storage guarantee (S16 §3.3) |
| DAS "ensures that blob data has been made available" while downloading a subset | EIP-7594 (S13): "PeerDAS ... allows nodes to perform data availability sampling (DAS) to ensure that blob data has been made available while downloading only a subset of the data." | Sampling establishes availability **to the sampling node at sampling time**; it is not a promise that the data can be retrieved later |
| Reconstruction requires 50% of columns | EIP-7594 (S13): "A node can reconstruct the entire data matrix if it acquires at least 50% of all the columns. If a node has less than 50%, it can request the necessary columns from its peer nodes." | Reconstruction assumes peers still *have* the columns; a node with <50% and no honest peers holding columns cannot reconstruct |
| Blob data is only *expected* to be kept ~18 days | EIP-4844 (S12): "there is no expectation that the blobs need to be stored for as long as an execution payload. This makes it possible to implement a policy that these blobs must be kept for at least a certain period. The specific value chosen is MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS epochs, which is around 18 days" (constant value 4096, S12) | **Finalized Ethereum blocks whose blob data is older than ~18 days are, by policy, not retrievable from the p2p network.** Finality and retrievability are explicitly decoupled |
| Execution history itself is being pruned | EIP-4444 (S14): "Clients must stop serving historical headers, bodies, and receipts older than 14,299 epochs on the p2p layer. Clients may locally prune this historical data." (HISTORY_PRUNE_EPOCHS = 14299) | A finalized block older than the retention window may be unavailable from the network; clients "MUST use a valid Weak Subjectivity Checkpoint to bootstrap" (S14) |
| Whether validators *serve* data is not enforced by consensus | S12/S14 above; CometBFT's own note that basic signing-rule violations are not automatically punished (S3) | Retention and serving are operational policy, not consensus rules, in every design reviewed |

**REASON (the exact limit, stated sharply).** "≥2/3 voted, therefore they hold the data" is only
valid at the instant of voting and only in the sense "they held it at vote time". It implies nothing
about (a) how long they keep it, (b) their obligation or incentive to serve it, (c) whether a *new*
node can obtain it, or (d) whether the data survives the departure of the specific nodes that held
it. Each of these is a separate assumption and must appear as such in the Etna spec.

### 2.2 Erasure coding and DAS: retrievability vs sampling

| Design | What is guaranteed | What is *not* guaranteed | Source |
|--------|--------------------|--------------------------|--------|
| Ethereum PeerDAS (EIP-7594) | Sampling every slot; deterministic custody of column subnets as a function of node ID; reconstruction from >=50% of columns | Retrievability after the retention window; that any specific node keeps its custody columns forever; that a light sampler can reconstruct | S13 |
| Ethereum EIP-4844 blobs | Availability on p2p within the retention policy; KZG binding of data to commitments | Long-term storage; historical retrieval after pruning | S12 |
| Ethereum execution history (EIP-4444) | Nothing beyond HISTORY_PRUNE_EPOCHS; sync relies on WS checkpoints | Availability of pre-window headers/bodies/receipts on p2p | S14 |
| Narwhal DAG | Availability certificates: 2f+1 acks make a block *retrievable from honest parties that have it*; causal histories | Permanent storage; availability if all holders of a vertex leave | S16 |
| Celestia | **UNVERIFIED in this session** — docs pages returned navigation text only; the spec repository path tried returned 404 | — | — |
| EigenDA | **UNVERIFIED in this session** — https://docs.eigenda.xyz/ returned HTTP 522 | — | — |
| Ethereum danksharding (full) | **UNVERIFIED** — only EIP-4844/7594 retrieved; no full-DAS spec retrieved | — | — |

### 2.3 Retention, serving and incentives

| Observation | Evidence |
|-------------|----------|
| Pruning is planned and endorsed upstream, not an anomaly | S14 (Draft EIP), S12 (18-day blob policy) |
| Clients that prune must rely on an out-of-band checkpoint | S14: "Clients MUST use a valid Weak Subjectivity Checkpoint to bootstrap from a more recent view of the chain." |
| History-pruning EIP explicitly lists "Relying on weak subjectivity" as a security consideration and "Centralization/censorship risk" | S14 (section headings retrieved verbatim), body text partially retrieved |
| CometBFT nodes without a validator key still relay data; there is no protocol obligation to store | S1 ("A node may not have a corresponding validator private key, but it nevertheless plays an active role ... by relaying relevant meta-data, proposals, blocks, and votes") |
| CometBFT's liveness proof assumes messages *eventually* arrive, not that data is stored | S1 ("eventually the network is able to 'fully gossip' the whole proposal") |

### 2.4 "Finalized but unavailable" incidents

| Candidate | What is actually documented | Verdict |
|-----------|------------------------------|---------|
| Ethereum finality stalls (May 2023; May 2024) | Press reporting of temporary loss of finality caused by consensus-layer client issues (S30 and other press leads). A finality **stall** is not a data-availability failure: blocks kept being produced; finality resumed | **PRESS only. Primary client postmortems were not retrieved → UNVERIFIED.** Do not use as an incident citation in the spec |
| Blob/history pruning makes old data unavailable | This is *protocol-sanctioned* unavailability with published windows (S12: ~18 days; S14: 14,299 epochs) | **Verified as policy, not as an "incident"**. It is the strongest documented evidence that "finalized" never implied "retrievable forever" |
| A specific chain that finalized a block and then could not retrieve its data due to withholding | Not found in this session | **UNVERIFIED — no incident found.** The specification must not claim such an incident exists |

### 2.5 Separation statement (proposed, REASON, evidence-backed)

| Property | Established by | Does **not** follow |
|----------|----------------|---------------------|
| PoS-finalized (Mode A) | A published quorum certificate over (chain, epoch, height, hash) | That the data is retrievable now, or later |
| Data available *now* | A fresh sampling / retrieval by the asking node | That the data will be available at settlement time |
| Data available *at settlement time* | An L1 transaction carrying the data (Etna D5) | That PoS-finalized history without such a transaction can ever be settled |
| Ethereum-finalized settlement | The L1 transaction is in a finalized Ethereum block | That L2 users' off-chain assumptions match |

---

## 3. Mode A feasibility

Requirements being tested (from the brief, restated as testable predicates):

| ID | Requirement |
|----|-------------|
| R-A | 2 s block cadence, continuously |
| R-B | Halt-safe recovery: no recovery step may invalidate PoS-finalized history |
| R-C | Permissionless validator entry/exit |
| R-D | Forced inclusion of user transactions from L1 |
| R-E | Long-range-attack resistance via weak subjectivity |
| R-F | Atomic data+proof settlement on L1 in one transaction (D5) |
| R-G | Proving latency of minutes to 30 min is normal (D6) |

### 3.1 The strongest FOR case (construction + assumptions)

**REASON.** The strongest defensible claim for Mode A is **not** "Mode A satisfies all requirements";
it is the conditional claim below. Every clause is an assumption that must be stated in the spec.

> **Conditional feasibility claim.** If (A1) at every height, >2/3 of the *bonded* stake is online and
> message delay is below the round-timeout bound; (A2) every validator that votes for a block has
> the full block data and keeps it available until the settling L1 transaction is finalized or the
> bond is released; (A3) the certificate/publication delay is bounded and every node eventually
> receives every certificate (strong eventual dissemination); (A4) the validator set is chosen with
> a weak-subjectivity checkpoint that is refreshed and distributed out of band; (A5) the evidence
> window for equivocation is at least the unbonding period; (A6) forced inclusion and the proving
> pipeline are both bounded in time — then a Tendermint-style protocol with one-slot finality
> satisfies R-B, R-C (subject to A4), R-D, R-E, R-F and R-G, and satisfies R-A only while A1 holds.

Supporting pieces of that construction, with sources:

| Piece | Why it supports Mode A | Source |
|-------|------------------------|--------|
| Lock rule prevents a later certificate from displacing a decision without 1/3+ equivocation | Safety of the "no rollback" rule | S1 (Proof of Safety, fork-accountability lemma) |
| Accountable safety makes any violation attributable and punishable | Economic recovery without invalidating history | S6 (Thm 1) |
| Finality gadget + fork choice already separates "finalized" from "head" | Precedent for Mode A's two-level history | S11 (fork choice filters on finalized_checkpoint) |
| Ebb-and-flow: a finalized prefix can trail a live ledger, then catch up | Formal precedent for "halt the finalized prefix, keep the live suffix" | S20: "ebb-and-flow protocols, which support a full dynamically available ledger in conjunction with a finalized prefix ledger. The finalized ledger falls behind the full ledger when the network partitions but catches up when the network heals." |
| Weak subjectivity is the accepted answer to long-range attacks | R-E is satisfiable, at the cost of a trusted startup input | S9: "Clients should allow users to input a Weak Subjectivity Checkpoint at startup" |
| Atomic data+proof matches the "no data-first path" rule | Settlement cannot outrun availability | Etna D5 (brief) + S12/S13 reality check in §2 |
| Forced inclusion exists in production L2s with published delays | R-D is implementable | §5 |

**What Mode A must *add* beyond the above** (REASON; these are design obligations, not citations):

1. A **publication rule**: a certificate is only usable (finality-bearing) once it is *published* to a
   defined dissemination substrate, and the rule must state what happens when it is not.
2. A **data-at-vote rule**: votes must be conditioned on data possession, or D5 can be violated by an
   honest-but-pruned voter. This is the crux of §3.2 C2.
3. A **halt-with-exit rule**: if the chain halts, users must still be able to exit through L1 without
   invalidating the halt point. This is not free: forced inclusion and bridge exits that depend on
   new L2 state cannot run while halted (see C6).
4. A **freshness rule**: the WS checkpoint distribution is a trusted operation; the spec must say who
   publishes it, how often, and what a node does if it cannot obtain one (the Ethereum answer is
   "critical and irrecoverable failure", S9).

### 3.2 The strongest COUNTER-argument: concrete breaking scenarios

Each scenario names its assumptions, the failure type, and the requirement it breaks.

| # | Scenario | Assumptions | Failure | Breaks | Evidence anchor |
|---|----------|-------------|---------|--------|-----------------|
| C1 | **Permanent halt from a partitioned minority.** 1/3+ of bonded stake is offline or partitioned (cloud region outage, client bug, coordinated exit). No quorum; the chain halts. Nothing in the protocol can distinguish "offline" from "withholding", and Mode A forbids rolling back to a point where a quorum existed | Permissionless set; no gate on participation/performance; halt-safe rule | **Liveness** (indefinite halt) | R-A, and R-B is satisfied only by paying with R-A | S1 (liveness proof needs eventual gossip), S8 ("prevents progress ad infinitum") |
| C2 | **Certified-but-unavailable (the strongest counterexample).** A quorum votes for block B; B's data lives in proposer/validator mempools and blobs that are not yet on L1 (D5 forbids data-first). The certificate is published; the holders then go offline, prune, or refuse to serve. B is PoS-finalized in Mode A. Because D5 requires data+proof in the *same* L1 transaction, no prover can produce a proof; B can never settle. Mode A forbids discarding B, so the chain must either halt forever behind B or keep producing unfinalizable history | Votes are possible without long-term data custody; the certificate does not carry the data; retention is not enforced | **Both**: liveness (settlement stuck) and, if the design keeps building, an ever-growing unsettled suffix | R-F, R-G, R-A; and the derived guarantee "finalized implies eventually settled" is false | S16 (availability is a protocol property of the DAG, and GC is a design problem), S12 (18-day policy), S14 (pruning), S13 (sampling is not retrievability) |
| C3 | **2 s cadence vs wide-area quorum.** One-slot finality at 2 s requires a full round-trip plus dissemination within ~2 s. A permissionless validator set has no performance gate (R-C), so honest-but-slow validators (consumer links, distant regions) will miss rounds. Round timeouts escalate; with 1/3+ slow, the chain stalls permanently under Mode A | Permissionless entry, global membership, no minimum bandwidth | **Liveness** | R-A vs R-C: directly in tension | S1 (round timeout ladders; "the block proposed ... did not propagate in time"), S8 (non-responsiveness inherent) |
| C4 | **Forced inclusion starved by a 1/3+ cartel.** Forced txs are only L2-ordered if validators include them. A 1/3+ cartel can refuse to prevote/precommit proposals containing forced txs; the chain keeps finalizing *other* blocks, so there is no halt and no objective fault (liveness violations are not slashable in CometBFT; only equivocation is) | >=1/3 colluding validators; forced txs identifiable | **Liveness for those users only** | R-D (guarantee is "eventual inclusion", not "inclusion") | S1, S3 ("there is not currently any explicit mechanism to punish validators signing votes or proposals that fail these basic validation rules") |
| C5 | **Long-range attack on a fresh node.** A new node has no local history. An attacker who held >2/3 at some past epoch builds an alternative history from that point and serves it. Without a WS checkpoint the node cannot tell which is canonical; with a WS checkpoint it depends on a trusted publisher | Unbonded ex-validators; no WS checkpoint, or a stale one | **Safety at the client** (the node accepts a conflicting history) | R-E; also R-C, since permissionless entry maximises the number of nodes that never saw history | S9, S22, S21 |
| C6 | **Halt prevents exits.** Mode A halts "safely"; but bridge withdrawals to L1 that require a new L2 state root cannot execute while halted. If the halt is permanent (C1/C2), user funds are stuck unless an L1 escape hatch exists — which is Mode B | Halt with no L1-side exit path independent of new L2 state | **Liveness for funds**; the safety story is intact, the usability guarantee is not | R-B's implicit promise "halt safely" is not enough for withdrawals | REASON + §4 escape hatches (S23, S24, S27) |
| C7 | **Evidence window vs unbonding.** An equivocating coalition can wait until after the evidence window (or until its stake is unbonded) before publishing a conflicting certificate. Slashing then cannot reach the stake. The conflicting certificate may still be used by third parties | Evidence age shorter than the practical unbonding/exit path, or a chain that does not implement slashing at all | **Safety** in the economic sense (the 1/3+ cost assumption fails) | R-E, R-B's economic assumption | S2: "evidence age should be less than the unbonding period so validators still can be punished" |
| C8 | **Data-at-vote is unenforceable under D6/2 s.** Requiring every voter to possess full data before voting is the natural fix for C2, but at 2 s with 900 blocks per proving window (D6), the data volume per validator grows; a permissionless validator can vote and then discard, and there is no cheap proof of retention | Votes are signature-only; no proof-of-retention | **Liveness/settlement** (same as C2, milder) | R-F | S12, S13, S14 (retention is policy, not consensus) |
| C9 | **Weak-subjectivity freshness is itself a liveness dependency.** If the WS checkpoint publisher is unavailable or the node cannot fetch it, the spec's own precedent is "critical and irrecoverable failure" | A single distribution path; no authenticated freshness proof | **Liveness**, and a **trust dependency** on the publisher | R-C/R-E tension: permissionless entry needs a trusted onboarding input | S9, S14 ("Clients MUST use a valid Weak Subjectivity Checkpoint to bootstrap"), S21 |
| C10 | **D6 proving latency vs halt-safe recovery.** If proving fails or a prover withholds a proof, the batch cannot settle (D5). Mode A forbids discarding the batch, so "proof-ready" is not guaranteed in bounded time by anything except prover honesty/incentives; a single withheld proof for an old batch can block settlement of everything after it if settlement is strictly ordered | Ordered settlement; permissionless provers; no proof deadline with consequences | **Liveness** (settlement), **not** consensus safety | R-F, R-G | REASON; anchored by the absence of any retention/proving obligation in S12/S13/S14 |

### 3.3 Verdict on Mode A (this agent's independent view)

**Mode A is not feasible as stated** — not because of a consensus-safety hole, but because the
required conjunction (R-A, R-C, R-D, R-F, R-G under halt-safe recovery) fails. The dominant
failure is **C2: certified-but-unavailable data**. A quorum certificate is evidence of signatures,
never of storage (S12, S13, S14, S16). Under D5, an unavailable-but-finalized block cannot be proven
and therefore cannot be settled, and Mode A forbids the only action that would unblock the chain.

The strongest single counterexample found: **a certificate over a block whose data is not on L1 and
whose holders all go offline** (or simply prune after the retention window). Every step is permitted
by the protocol; no fault is objectively attributable at consensus level; and Mode A's no-rollback
rule converts it into a permanent settlement halt. The mitigating designs all require either an
availability assumption enforced before finality (a DA layer, i.e. data published before the
certificate) or a rollback (Mode B).

Secondary, independent of C2: **C3** (2 s cadence vs permissionless global membership) and **C1**
(halt under minority outage). Both are liveness failures, and both are *by design* under Mode A.

What remains true and should be preserved in any Mode B design: Mode A's safety argument (S1, S6) is
sound under <1/3 equivocation; the problem is that safety is not the binding constraint — availability
and timing are.

---

## 4. Mode B design inputs (research only — no design is endorsed here)

Question asked: *if L1 recovery were used, which published mechanisms come closest?*

Reading of the evidence: **there is no published mechanism that "reverts a finalized-checkpoint
failure" as a first-class protocol operation.** What exists is (i) trusted-checkpoint onboarding,
(ii) social/off-chain coordination followed by a hard fork, (iii) rollup escape hatches that bypass
the sequencer, and (iv) formal protocols that *delay* finality rather than revert it. Everything else
is blog-level.

| Mechanism | Trigger | Invoker | Delay | What may be reverted | Treatment of late certificates | Replay protection | Source |
|-----------|---------|---------|-------|----------------------|--------------------------------|-------------------|--------|
| Weak-subjectivity checkpoint sync (Ethereum) | A node syncs after being offline longer than the WS period, or bootstraps | The node operator, using a checkpoint from a third party | None (immediate reliance on out-of-band data) | Nothing is "reverted" on-chain; the node *rejects* any chain conflicting with the checkpoint | A late certificate/block conflicting with the checkpoint is rejected | The WS checkpoint "is the new genesis block"; nothing below it is replayed | S9: "Clients should allow users to input a Weak Subjectivity Checkpoint at startup ... If such a sync is not possible, the client should treat this as a critical and irrecoverable failure."; S22: "the latest weak subjectivity checkpoint is the new genesis block of the network"; S14: "clients treat weak subjectivity checkpoints as the genesis block. We call this method 'checkpoint sync'." |
| Social slashing / community fork after a finality-reverting attack | A 51% attack that reverts finalized blocks | Off-chain social coordination; on-chain enforcement via a fork/governance action | Unbounded (social coordination time) | In principle anything, including finalized blocks; the attacker's stake is destroyed | Certificates from the attacker's branch are not honoured by the forked chain | Hard fork changes the valid history; operators must re-point | S21: "For certain kinds of 51% attacks (particularly, reverting finalized blocks), there is a built-in 'slashing' mechanism ... by which a large portion of the attacker's stake (and no one else's stake) can get automatically destroyed." |
| Checkpoint-rollback proposals in the literature | — | — | — | — | — | — | **UNVERIFIED: no concrete proposal retrieved in this session.** The closest formal treatment found is Ebb-and-Flow (S20), and it does *not* revert a finalized prefix: "The finalized ledger falls behind the full ledger when the network partitions but catches up when the network heals." I.e. the literature's answer to the availability-finality dilemma is **delayed finality, not finality rollback** |
| Finality gadget with fallback fork choice (Gasper: FFG + LMD-GHOST) | FFG stops finalizing (participation below 2/3) | Automatic — the fork choice simply keeps running | None | Nothing: finality stops *advancing*; the last finalized checkpoint is never discarded | Certificates/attestations for non-finalized branches are normal fork-choice input | Fork choice filters on the finalized checkpoint, so replay below it is impossible by construction | S11: "finalized_checkpoint: the highest known finalized checkpoint. The fork choice only considers blocks that are not conflicting with this checkpoint." |
| OP Stack permissionless fault proofs + Security Council | A dispute, or a bug/emergency | Anyone (proposals/disputes, with bonds); the Security Council for emergency actions | Dispute game + challenge windows; emergency actions can be fast | Output roots / dispute outcomes can be replaced by a winning fault proof; withdrawals can be paused or held (DelayedWETH hold/recover) | Late proposals are ordinary dispute-game moves | Bonded games and the DelayedWETH ledger track claims | S23: "A permanent Withdrawal Liveness or Withdrawal Safety failure requires 75% of the Security Council (w/o bugs)."; S23 lists Proxy Admin Owner powers: DisputeGameFactory.setImplementation, setInitBond, DelayedWETH.hold, DelayedWETH.recover; the Guardian can trigger pause (S23) |
| OP Stack forced transaction (L1 deposit as the censorship-resistance path) | Sequencer censors or is down | Any user, submitting an L1 deposit transaction to the OptimismPortal | Sequencing window of 12 h; deposits normally included within 30 min | Nothing: forced txs are ordinary deposit transactions that must be derived | n/a | Deposit nonces / L1 ordering | S24: "Sequencing Window: A 12-hour rolling window"; "After 12 hours, nodes begin generating blocks deterministically, incorporating only the forced-included transactions"; "Users are able to force-include transactions, which can initiate withdrawals, at any time." (deposit transactions on L1) |
| Arbitrum Nitro forceInclusion | The sequencer has not posted a message within the delay | Anyone (external call) | Chain-configurable **delayBlocks / delaySeconds**; the function reverts with ForceIncludeBlockTooSoon() before the deadline and exposes forceInclusionDeadline(blockNumber) | Nothing is reverted: a delayed message is inserted into the sequencer inbox | n/a | The delayed-message counter (totalDelayedMessagesRead) orders it | S27 (nitro-contracts pin ff6334e7, src/bridge/SequencerInbox.sol): forceInclusion(...), delayBlocks/delaySeconds state, delayBufferableBlocks, ForceIncludeBlockTooSoon, forceInclusionDeadline. **UNVERIFIED: the concrete Arbitrum One values (commonly cited as 5760 blocks / 86,400 s) were not read from the source in this session** |
| zkSync Era priority queue | A user calls requestL2Transaction on L1 | Anyone | Not specified on the retrieved page (**UNVERIFIED delay**) | Nothing: the operator must pop the priority queue at batch execution and the rolling hash is verified | n/a | priorityOperationsRollingHash is verified at batch execution | S28: "A new priority operation can be appended by calling the requestL2Transaction method on L1 ... Then, this transaction will be appended to the priority queue."; "During batch execution, we would pop numberOfPriorityTransactions from the top of priority queue and verify that their rolling hash does indeed equal to priorityOperationsRollingHash." |
| "Delay-relay" / timelock-vs-fraud-proof hybrids | — | — | — | — | — | — | **UNVERIFIED term: no published mechanism matching "delay-relay" was found in this session.** Closest published analogues: OP's DelayedWETH hold/recover + Guardian pause (S23), dispute-game challenge delays (S23), Arbitrum's forceInclusion delay (S27), L2->L1 withdrawal delays, and Ebb-and-Flow's finalized-prefix design (S20) |
| Taiko (this repo) forced-inclusion store | A user wants a tx included without relying on the proposer | Any user (payable call) | forcedInclusionDelay = 576 s on Mainnet config | Nothing is reverted; a due forced inclusion *must* be consumed by the next proposal | n/a | FIFO queue with head/tail pointers | S29: contracts/layer1/core/iface/IForcedInclusionStore.sol:24 (saveForcedInclusion), :26-36 (dynamic fee formula), contracts/layer1/core/libs/LibForcedInclusion.sol:42-72, contracts/layer1/mainnet/MainnetInbox.sol:48-50, contracts/layer1/core/impl/Inbox.sol:637-675 |

### 4.1 What a rollback CANNOT preserve

| Cannot be preserved | Why | Anchor |
|---------------------|-----|--------|
| L1-executed effects (withdrawals, messages already relayed to L1, bridge releases) | They are on Ethereum; an L2 rollback has no power over L1 state | REASON; the OP Stage 1 spec treats Withdrawal Safety as an L1 property that depends on what the L1 contracts have already executed (S23) |
| Third parties' off-chain finality assumptions (exchanges crediting deposits, bridges minting) | Those actors acted on an L2 state that the rollback erases; they cannot be un-credited on-chain | REASON |
| Signatures already produced by validators | Signatures are evidence; they remain and can be used for slashing even if the signed block is discarded | S3, S15 |
| Weak-subjectivity checkpoints already distributed | Nodes reject anything conflicting with their checkpoint: "if a node sees a block conflicting with a weak subjectivity checkpoint, then it immediately rejects that block" (S22). A rollback deeper than the freshest distributed checkpoint forks honest nodes off the chain | S22, S9 ("critical and irrecoverable failure") |
| Replay of history below the chosen rollback point | By construction the rollback re-runs those L2 blocks; anything with L2-derived identity (deterministic addresses, nonces, RNG) re-derives differently if the input changed | REASON |
| Time and proving work | Discarded blocks' ZK proofs are wasted; the 2 s cadence lost during the halt is not recovered | REASON |
| A safe validator-set restart at the same heights | Re-signing at a reused height/round with a different block is exactly the equivocation the signing rules forbid; honest validators restarted "as of the old state" can be slashed for amnesia | S3 (LastSigned height/round/type; "must not sign any other message for that same height and round"), S2 (amnesia as an attack class) |

---

## 5. Forced inclusion / censorship resistance

| L2 | Mechanism | Who can trigger | Delay / cost | Guarantee | Failure modes |
|----|-----------|-----------------|--------------|-----------|---------------|
| **Taiko (today, revision 7718753c1)** | ForcedInclusionStore: user pays a fee and stores a blob reference; the next proposal must consume all *due* inclusions | Any user with ETH (S29: IForcedInclusionStore.sol:24) | forcedInclusionDelay = **576 s** (S29: MainnetInbox.sol:48); fee = baseFee x (1 + pending/threshold), baseFee 0.001 ETH, threshold 50 (S29: MainnetInbox.sol:49-50, IForcedInclusionStore.sol:26-36) | Inbox.sol:662-663 requires the proposer to request at least the number of due inclusions, else UnprocessedForcedInclusionIsDue(); one blob and one L2 block per inclusion (LibForcedInclusion.sol:14-15) | (a) The referenced blob can expire: the in-repo comment for init3() says entries "were queued while forced inclusions were disabled after the June 2026 incident; their blobs have expired from the blob retention window and can no longer be derived" (S29: Inbox.sol:246-253). (b) init3() is **onlyOwner** and voids the whole queue (S29: Inbox.sol:253-258) — a trusted lever on the censorship-resistance path. (c) Proposing is gated by IProposerChecker and the source comment says "Permissionless proposing is temporarily disabled" (S29: Inbox.sol:601-603). (d) A forced inclusion is still only *proposed*; it needs a proof and settlement to become L1-accepted |
| **Optimism (OP Stack)** | Forced transaction = an L1 deposit transaction through the OptimismPortal (the only user-facing force-include path found) | Any user | Sequencing window 12 h; deposits normally included within 30 min | Derivation rules require deposits to be included; after 12 h of downtimes nodes generate blocks deterministically with only forced txs | Not general arbitrary-L2-tx forcing; during a 12 h window the sequencer can order/delay deposits (S24). Withdrawal-only safety guarantee lives in the L1 contracts (S23) |
| **Arbitrum Nitro** | SequencerInbox.forceInclusion inserts a delayed message once the delay has elapsed | Anyone (permissionless call) | delayBlocks / delaySeconds, chain-configurable; reverts ForceIncludeBlockTooSoon before the deadline; the contract exposes forceInclusionDeadline(blockNumber) (S27) | The delayed message enters the L2 inbox independent of the sequencer | Delay is owner-configurable (setMaxTimeVariation); concrete values not verified here; forced inclusion does not accelerate proof/settlement |
| **zkSync Era** | L1 priority queue via requestL2Transaction; the batch execution pops numberOfPriorityTransactions and verifies the rolling hash | Anyone | Delay not stated on the retrieved page (UNVERIFIED) | Priority operations are processed in order and the rolling hash is verified at batch execution (S28) | Operator can include priority ops late; the retrieved page documents no explicit deadline for processing them |

**Cross-cutting failure modes (REASON, anchored where noted).**

1. **Griefing/spam is priced, not free.** Taiko's fee grows linearly with queue length (S29), which
   bounds but does not remove queue-filling attacks; an attacker who wants to delay others pays the
   escalated fee.
2. **Forced inclusion is ordering, not finality.** In every design above the forced item must still be
   provable/settled (Taiko: proof + L1 tx; OP: derivation + output root; Arbitrum: batch + proof).
   Forced inclusion therefore does not remove the D5/C10 settlement latency problem.
3. **A PoS quorum can still starve forced txs** (C4): the Inbox consumption rule binds whoever is
   authorised to propose. If the proposer set is a PoS quorum, >=1/3+ can refuse to include, and
   liveness violations are not objectively slashable (S3).
4. **Trusted void paths exist in production today** (Taiko init3(), S29) and are used after incidents;
   any Mode A claim of "forced inclusion cannot be censored" must account for the owner/DAO path.

---

## 6. Safe halt and restart

| Question | What published sources say | Status |
|----------|---------------------------|--------|
| What happens on a Tendermint/CometBFT halt? | The liveness proof is conditional on eventual message delivery ("eventually the network is able to 'fully gossip' the whole proposal", S1); there is no *verified* canonical spec section describing halt semantics. CometBFT does not, in the specs read here, define a protocol-level "resume from halt" | **UNVERIFIED for halt semantics** — only the liveness precondition is verified (S1) |
| Validator-set restart without a quorum | No published Tendermint mechanism found. The closest published recovery mechanisms are Ethereum's inactivity leak (burn inactive stake until 2/3 participates again: is_in_inactivity_leak, S10) and social coordination + weak subjectivity (S9, S21) | Inactivity leak verified (S10); "validator-set restart" as a named mechanism: **UNVERIFIED / not found** |
| Checkpoint freshness | The WS period is computed from validator churn and balance top-ups; SAFETY_DECAY = 10 means any attack has a safety margin of at least 1/3 - SAFETY_DECAY/100 (S9). Reference values from the spec: 32,768 validators at 28 ETH -> 504 epochs; 131,072 -> 1,248 epochs (S9 table) | Verified (S9) |
| Replay of previously signed messages | Ethereum: EIP-3076 requires a signer to refuse anything slashable with respect to the imported set, to refuse new blocks with slot <= the minimum imported slot (unless it is a repeat signing of the same signing_root), and to refuse slashable attestations (S15). CometBFT: signers track Height/Round/Type of the last signed message and "must not sign any other message for that same height and round" (S3) | Verified (S15, S3) |
| How are new participants prevented from finalising a conflicting history? | They are not, cryptographically — they are prevented by a **trusted checkpoint**: Ethereum clients "MUST use a valid Weak Subjectivity Checkpoint to bootstrap" (S14), treat it as genesis (S14, S22), and reject conflicting blocks (S22). A node that cannot obtain a fresh checkpoint has "a critical and irrecoverable failure" (S9) | Verified (S9, S14, S22) |
| Amnesia (restart from old state) | Treated as an attack class distinct from equivocation, and evidence verification accounts for it (S2) | Verified (S2) |
| State sync (CometBFT) | Search evidence only (a docs page title "CometBFT Documentation — State Sync"); the page itself was not retrieved as text (**UNVERIFIED**). Ethereum's equivalent is documented in EIP-4444 (checkpoint sync, S14) | **UNVERIFIED** for CometBFT state sync details |

**Design inputs implied by the above (REASON, not source claims).**

1. A restart protocol must use a **new domain separator** (chain-id/epoch) for votes, or honest
   validators that sign again can be slashed for equivocation under S3/S15 regardless of intent.
2. A restart must be **anchored at a checkpoint that all restarting nodes already accept**, or it
   forks the honest nodes (S22).
3. Slashing protection state (S15) is part of the safety-critical restart surface and must be
   auditable; the June 2026 Taiko note (S29) shows that in practice incident handling can disable a
   censorship-resistance path entirely.

---

## 7. What cannot be proven by any of these mechanisms

Claims that **must not appear** in the Etna specification (each is either contradicted or unsupported
by the sources retrieved):

| # | Forbidden claim | Why | Anchor |
|---|-----------------|-----|--------|
| 1 | "No certificate was received within T, therefore no certificate exists" | Timeouts rotate rounds/views or halt; they are not evidence of absence. Also FLP/DLS (S31, UNVERIFIED) but the protocol evidence alone suffices | S1, S8 |
| 2 | "A PoS-finalized block's data is retrievable" | Retention is policy, not consensus: ~18 days for blobs (S12), 14,299 epochs for history (S14); sampling is not retrievability (S13) | S12, S13, S14 |
| 3 | ">=2/3 voted, therefore the data is available forever / to everyone" | The property holds at vote time for the voters only (S16 Block-Availability; S12/S14 policy windows) | S12, S14, S16 |
| 4 | "A ZK proof repairs consensus" | A proof attests a state transition over data the verifier has; it cannot make unavailable data available, cannot attest that users received data, and cannot restore a halted quorum | REASON + S12 (KZG binds data to commitment, it does not store it) |
| 5 | "Slashing makes finality reversal impossible" | Slashing is punishment contingent on evidence and an evidence window shorter than unbonding (S2); the enforcement mechanism itself lives on the chain being protected (S6) | S2, S6, S21 |
| 6 | "Permissionless entry guarantees a decentralised or robust validator set" | No source reviewed supports it; performance and synchrony assumptions are independent of permissionlessness (C3) | S1, S8 |
| 7 | "A halt is always recoverable / a halt is safe for users" | A halt stops state-root progression; L1-side exits that depend on new L2 state stop with it (C6). Ebb-and-Flow frames availability vs finality as a real dilemma, not a free lunch | S20, S23 |
| 8 | "Forced inclusion guarantees timely inclusion or finality" | OP's forced path has a 12 h sequencing window (S24); Arbitrum's forceInclusion has a chain-configurable delay and reverts before it (S27); Taiko's is 576 s plus proving/settlement (S29) | S24, S27, S29 |
| 9 | "Economic loss is universally bounded by X" | No retrieved source provides a universal bound; losses depend on exit paths, third-party credit assumptions and prices | REASON |
| 10 | "Weak subjectivity is objective / trustless" | The checkpoint is an explicit trusted input, and failure to obtain one is "a critical and irrecoverable failure" | S9, S22 |
| 11 | "Finality stalls are data-availability failures" | Ethereum's May 2023/2024 incidents were finality stalls; blocks kept being produced; only press sources were retrieved, and they do not establish a DA failure | S30 (PRESS, UNVERIFIED) |
| 12 | "Timeout-based recovery cannot break safety" | Any recovery rule that lets a node vote for a different branch without a lock-qualified PoLC/higher QC breaks the S1/S8 safety argument | S1, S8 |
| 13 | "The June 2026 Taiko incident proves X" | The repository comment (S29: Inbox.sol:246-253) establishes only: forced inclusions were disabled, queued blob references expired, and the queue was voided by an owner function. The incident's cause is **UNVERIFIED** here | S29 |
| 14 | "Certificates prove that non-signers received anything" | Votes are gossiped; a certificate proves signatures, not receipt by anyone else | S1 |

---

## 8. Open questions (ranked) and the evidence that would close each

| # | Question | Evidence that would close it |
|---|----------|------------------------------|
| Q1 | Can a Mode A design make "vote" conditional on *provable* data possession, at 2 s, for a permissionless validator set — without importing an external DA layer (which is a Mode B-style dependency on L1 blob retention)? | A published proof-of-retention / availability-certificate design with measured overhead at 2 s cadence; or an explicit decision that data-at-vote is an assumption, not a guarantee |
| Q2 | What is the exact halt/recovery semantics of CometBFT-class protocols after a permanent halt? | Fetch and pin the CometBFT "halt" material (consensus params, halt-height, state sync) and any ABI/app-level restart specification |
| Q3 | How deep can a Mode B rollback go before it conflicts with already-distributed weak-subjectivity checkpoints? | The checkpoint distribution cadence and retention policy the Etna deployment intends to use; Ethereum's answer (S9) is a period computed from churn, not a fixed number |
| Q4 | Is there any published, named "checkpoint rollback" proposal with a spec and security proof (not a blog)? | A literature search of eprint/ethresear.ch with direct retrieval; must be fetched, not inferred |
| Q5 | Does the regulatory/economic model allow slashing TAIKO stake for equivocation when the evidence is an *unpublished* certificate that later surfaces? | Legal/economic review plus a specification of the evidence window; S2 gives the technical constraint (evidence age < unbonding) |
| Q6 | What are the concrete Arbitrum/zkSync/Celestia/EigenDA parameters (delays, retention, guarantees) under pinned revisions? | Direct retrieval from pinned sources (nitro-contracts tag, era-contracts tag, Celestia spec commit, EigenDA spec) |
| Q7 | Under what exact conditions did Taiko's June 2026 forced-inclusion disablement happen? | The incident report / governance record (not retrieved here); the code comment alone is not enough |
| Q8 | Can forced inclusion be made a *slashable* obligation (rather than a proposer rule) so that a 1/3+ cartel cannot starve it? | A published mechanism with objective fault proofs for inclusion failures; none found in this session |
| Q9 | What is the measured message-delay distribution of the intended permissionless validator set at 2 s? | Real measurement (out of scope for this research; must not be fabricated) |
| Q10 | Does an ebb-and-flow construction (finalize only an L1-anchored prefix) satisfy Etna's D5/D6 without becoming Mode B in disguise? | A worked construction plus an explicit statement of which histories are "PoS-certified but revertible" — in Ebb-and-Flow terms, the finalized prefix never reverts (S20), which is Mode A applied to a shorter prefix |

---

## 9. Verification ledger for this file

| Item | Status |
|------|--------|
| All Taiko line references | Read at revision 7718753c1cece7d7705afaf33e6f9680115086dd on 2026-10-05 |
| CometBFT consensus.md | Pinned commit 709fd12b4b18cf1442d43c5d34009392c7d674ed |
| Consensus-specs weak-subjectivity.md | Pinned commit 6b9bd532cca16555e2f3282d757622ebff29743e |
| Mysticeti | Pinned v4 (13 Jul 2024) |
| Arbitrum SequencerInbox.sol | Pinned repo commit ff6334e7bfe6468f85202df98db92468e25f5688 (master, 2026-10-02) |
| zkSync L1->L2 docs | Pinned v25.2.0 URL |
| CometBFT evidence.md, signing.md, bft-time.md, time.md; consensus-specs beacon-chain.md, fork-choice.md | Fetched from default branches **without a SHA — moving targets** |
| arXiv papers via ar5iv (S6, S7, S8, S16, S17, S19) | Version not displayed on the rendered page — **version UNVERIFIED** |
| Celestia, EigenDA, L2Beat, HotStuff-2, FLP/DLS full texts | **Not retrieved — do not cite from this file** (S31) |
| Everything marked UNVERIFIED above | Must be re-fetched before it appears in the specification |

*End of raw research.*
