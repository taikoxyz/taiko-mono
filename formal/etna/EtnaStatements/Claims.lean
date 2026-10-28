import EtnaStatements.Premises

/-! The three headline claims of §1 "Positioning and security model" and their conjunction
`Claims`. Each is stated for every deployment World `w0` and environment `env` that satisfy the
one premise record `Premises w0 env`. Claims that need the verifier range over runs whose
landings the environment submits (`Run`); the others range over every `ProtocolState.Trace`. -/
namespace Etna.Statements
open Etna.Design

/-- Blocks `bs` after header `q` are a chain of `BlockValidity.Valid` blocks under rules `r`
whose ends carry checkpoints `parent` and `child`: `q` has `parent`'s height and cut (EL hash,
CometBFT hash, FI cursor: the fields of cutLeaf, 6.1), the last header has `child`'s height and
cut, and its EL stateRoot is `root`. Only the ends' heights and cuts are pinned; `q`'s stateRoot,
timestamp and anchor are not (continuity of headers is `FundSafety`'s statement, not this one's). -/
def Links (r : BlockValidity.Rules) (parent child : Checkpoint) (root : Hash) (q : BlockValidity.Header)
    (bs : List BlockValidity.Block) : Prop :=
  BlockValidity.Chain r q bs ∧ q.height = parent.height ∧ q.cut = ⟨parent.elHash,parent.cometHash,parent.cursor⟩ ∧
  (BlockValidity.terminal q bs).height = child.height ∧
  (BlockValidity.terminal q bs).cut = ⟨child.elHash,child.cometHash,child.cursor⟩ ∧
  (BlockValidity.terminal q bs).stateRoot = root

/-- `H` gives checkpoint `c` the header of its block: the same height and cut (EL hash, CometBFT
hash, FI cursor). -/
def HeaderOf (H : Checkpoint → BlockValidity.Header) (c : Checkpoint) : Prop :=
  (H c).height = c.height ∧ (H c).cut = ⟨c.elHash,c.cometHash,c.cursor⟩

/-- Header `stop` extends header `start` under the rules of generation `generation`: some World
`w'` of that generation lies on a run from `w0` through `w'` to `w`, and blocks valid under rules
the deployment builds on `w'` lead from exactly `start` to exactly `stop`. -/
def Extends (env : Environment) (w0 w : ProtocolState.World) (generation : Nat)
    (start stop : BlockValidity.Header) : Prop :=
  ∃ w' r bs, Run env w0 w' ∧ Run env w' w ∧ w'.inbox.generation = generation ∧ Built env w' r ∧
    BlockValidity.Chain r start bs ∧ BlockValidity.terminal start bs = stop

/-- H1, fund safety. §1 "Funds" (spec L12): "L1 recognizes only landed checkpoints, and every
landing needs two proofs, at least one of them ZK (6.2). Even the whole committee acting
maliciously cannot take funds on L1."; 6.2 (spec L331): "Withdrawals use the checkpoint that land
writes into SignalService directly". Along every run from the initialized World `w0`, some map `H`
gives every retained slot-285 record the header of its block (`HeaderOf`) such that:
- block 0's record gets block 0's header `env.genesisHeader`;
- every other record sits on its parent record (the checkpoint c it landed on, 6.1) at a lower
  height, and blocks valid under the rules the deployment builds for its generation lead from
  exactly the parent's header to exactly its own;
- every SignalService checkpoint, block 0's included, names a record's height and EL hash, and
  its state root is that record's header's stateRoot.
Following parents from any record ends at block 0's record. So every state root L1 recognizes is
reached from block 0's header (stateRoot = the genesis root) by consecutive chains of valid
blocks, each starting at the very header (height, EL and CometBFT hashes, FI cursor, stateRoot,
timestamp, anchor) where the one before ended. L1 stores only hashes; that segments meet in full
headers rests on two premises: `Premises.headerHashes` (an EL hash is the hash of the header it
names) and `Premises.headerSeparation` (Keccak collision resistance, assumed). -/
def FundSafety : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env → ∀ w, Run env w0 w →
    ∃ H : Checkpoint → BlockValidity.Header,
      (∀ child ∈ w.inbox.records, HeaderOf H child ∧
        (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
          ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
            Extends env w0 w child.generation (H parent) (H child))) ∧
      ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
        (H child).stateRoot = g.stateRoot

/-- The members of `members` whose key cast a vote in both `votesA` and `votesB`. -/
def signedBoth (members : List Committee.Entry) (votesA votesB : List Consensus.Vote) : List Committee.Entry :=
  members.filter fun m => (votesA.map Consensus.Vote.key).contains m.key && (votesB.map Consensus.Vote.key).contains m.key

/-- Key `k` signed (under `signature`) two precommits for different blocks at height `h` and round
`round` in context `c`'s domain and generation: a same-round double sign (4.1). -/
def Equivocates (c : Consensus.Context) (signature : Consensus.Vote → Prop) (h round : Nat) (k : Hash) : Prop :=
  ∃ va vb : Consensus.Vote, signature va ∧ signature vb ∧ va.key = k ∧ vb.key = k ∧
    va.domain = c.domain ∧ vb.domain = c.domain ∧ va.generation = c.generation ∧ vb.generation = c.generation ∧
    va.height = h ∧ vb.height = h ∧ va.round = round ∧ vb.round = round ∧ va.kind = 2 ∧ vb.kind = 2 ∧
    va.blockId ≠ vb.blockId

/-- From World `w` on, anyone can slash with evidence votes `a`, `b` and signatures `sigA`,
`sigB` (`slashDoubleSign`, 4.1): in every World `w'` reached from `w`, at any L1 block from `w'`'s
on, every live staked bond whose consensus key is `k` loses its whole stake. -/
def Slashable (w : ProtocolState.World) (a b : Staking.Vote) (sigA sigB k : Hash) : Prop :=
  ∀ w', ProtocolState.Trace w w' → ∀ now id, w'.l1Block ≤ now → id < w'.registry.nextId →
    (w'.registry.slots id).key = k → (w'.registry.slots id).released = false → 0 < (w'.registry.slots id).stake →
    ∃ t, RegistryHistory.edit w'.registry w'.inbox id now (.slash a b sigA sigB) = some t ∧ (t.slots id).stake = 0

/-- H2, accountable finality. §1 "Finality" (spec L13): "while Byzantine voting power stays below
1/3, a CometBFT commit is final and consensus never rolls back a committed block"; 3.1 (spec L56):
"slashing happens only on L1 ... and anyone can submit two conflicting votes"; 4.1 (spec L149):
"Valid evidence from historical generations remains admissible after recovery". For every World
`w` that any trace reaches from the initialized World, and every rule set the deployment builds
on it: two valid commits (6.2 item 3) for different blocks at one height and round were both
signed by members holding more than 1/3 of the active committee's voting power, and from `w` on
each such member's live staked bond can be slashed with one vote from each commit. So if the
members that sign conflicting precommits at that height and round hold less than 1/3 of the
power, every two valid commits there are for the same block.
Scope: this is same-round safety only. Two commits at different rounds of one height are not
compared, and CometBFT's locking rules are not modelled (§1 "Slashing scope", spec L18: "only
same-round double signing is slashed"). It says nothing about checkpoints staying put:
governance recovery and the rollback after verifier failure (section 8) are outside it. -/
def AccountableFinality : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env →
  ∀ w, ProtocolState.Trace w0 w → ∀ r, Built env w r →
    (∀ h round a b votesA votesB,
      Consensus.CommitValid r.consensus r.signature h round a votesA →
      Consensus.CommitValid r.consensus r.signature h round b votesB → a ≠ b →
      Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus h).members <
        3*Committee.totalPower r.consensus.unit (signedBoth (Consensus.activeAt r.consensus h).members votesA votesB) ∧
      ∀ m ∈ signedBoth (Consensus.activeAt r.consensus h).members votesA votesB,
        ∃ va ∈ votesA, ∃ vb ∈ votesB, va.key = m.key ∧ vb.key = m.key ∧
          ∃ sigA sigB, Slashable w (Accountability.evidence va) (Accountability.evidence vb) sigA sigB m.key) ∧
    (∀ h round (honest : Hash → Bool),
      (∀ m ∈ (Consensus.activeAt r.consensus h).members, honest m.key = true →
        ¬ Equivocates r.consensus r.signature h round m.key) →
      3*Committee.totalPower r.consensus.unit
          ((Consensus.activeAt r.consensus h).members.filter fun m => !honest m.key) <
        Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus h).members →
      ∀ a b votesA votesB, Consensus.CommitValid r.consensus r.signature h round a votesA →
        Consensus.CommitValid r.consensus r.signature h round b votesB → a = b)

/-- Step `w → t` is a governance recovery whose `fiToClear` lists entry `j`, and it blanks
`entry`: txHash becomes keccak256("") (the recovery adapter's `emptyHash`), timestamp and L1
block stay (8 step 3, spec L461; 7.2 "Blanked entries", spec L432). -/
def Blanks (w t : ProtocolState.World) (j : Nat) (entry : Forced.Entry) : Prop :=
  ∃ (a : Recovery.Request) (r : Origin) (owner externalOK : Bool) (s : Recovery.World),
    Recovery.recover (ProtocolState.recoveryView w) a w.adapters.recovery r owner externalOK = some s ∧
    t = ProtocolState.recovered w a r s ∧ j ∈ a.fiToClear ∧
    (j, Forced.clear w.adapters.recovery.emptyHash entry) ∈ t.queue

/-- The (parent header, block) pairs along the blocks `bs` after header `q`. -/
def pairs (q : BlockValidity.Header) (bs : List BlockValidity.Block) :
    List (BlockValidity.Header × BlockValidity.Block) :=
  (q :: bs.map BlockValidity.Block.header).zip bs

/-- Block `b` on parent header `p`, under rules `r`, in a batch landed on World `w`, serves the
forced-inclusion queue as 7.2 requires. If it consumes entry `p.cursor`, `Forced.step` accepts
that advance (inclusion at position 0 or a legal skip, spec L423) from a witness that shows the
entry's actual queue content. If its anchor shows that entry pending and due, it consumes it
(7.3, spec L436: "A due queue-head entry must be included or legally skipped under 7.2"). -/
def ServesQueue (w : ProtocolState.World) (r : BlockValidity.Rules) (p : BlockValidity.Header)
    (b : BlockValidity.Block) : Prop :=
  (b.header.cursor = p.cursor+1 →
    Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp r.forcedDelay b.forced b.singleton =
      .accepted (p.cursor+1) ∧
    ∃ wit, b.forced = some wit ∧ wit.index = p.cursor ∧ (p.cursor, wit.stored) ∈ w.queue) ∧
  (∀ entry, (p.cursor, entry) ∈ w.queue → p.cursor < b.header.anchor.tail →
    entry.timestamp+r.forcedDelay ≤ b.header.anchor.timestamp → b.header.cursor = p.cursor+1)

/-- H3, forced-inclusion integrity. §1 "Censorship resistance" (spec L15): "a due queue-head entry
can only be included or legally skipped, otherwise the block is invalid. Entries cannot be
deleted merely because they are old; the only exception is that governance recovery (section 8)
can explicitly blank specified entries"; 6.2 item 5 (spec L342): "Forced inclusion entries
[headBefore, headAfter) are consumed exactly and in order"; 7.2 (spec L400): "After a landing, the
Inbox's head equals c at the checkpoint".
- Along every trace from the initialized World, each step keeps every queue entry, except that a
  governance recovery blanks the entries its fiToClear lists (8 step 3, spec L461).
- Along every trace, a step that does not advance lastCheckpoint (any step but a landing) never
  advances the FI head. 6.1 (spec L289): "FI head only advances from its pre-execution value to
  forcedInclusionHead" in land; 8 step 4 (spec L462): recovery must "Preserve checkpoint c's
  landing record and FI head"; 7.1 (spec L395): sweeping "does not modify FI entries or queue
  progress"; 8 (spec L457): rollback restores "the FI head (281) ... to the values written by the
  last trusted landing".
- Each landing of a run settles blocks valid under rules the deployment builds on the World it
  lands on, from the current checkpoint (FI cursor = head) to the new one. Each entry in
  [head, new head) is consumed by one of those blocks, and every block serves the queue
  (`ServesQueue`).
Along a run, the head passes an entry only through blocks that include or legally skip it.
The third part constrains only the blocks inside landed segments; blocks that are never landed
are not covered. It does not claim L436's maxAnchorAge bound (7.3: any valid block with
block.timestamp ≥ entry.timestamp + forcedInclusionDelay + maxAnchorAge sees the entry as due). -/
def ForcedInclusionIntegrity : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env →
    (∀ w t, ProtocolState.Trace w0 w → ProtocolState.Step w t →
      ∀ j entry, (j, entry) ∈ w.queue → (j, entry) ∈ t.queue ∨ Blanks w t j entry) ∧
    (∀ w t, ProtocolState.Trace w0 w → ProtocolState.Step w t →
      t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height → t.inbox.head ≤ w.inbox.head) ∧
    (∀ w i leaves e s, Run env w0 w → env.submits w i leaves e → w.l1Block ≤ e.blockNumber →
      Etna.Design.land w.inbox i leaves e = some s →
      ∃ r q bs, Built env w r ∧ Links r w.inbox.checkpoint s.checkpoint i.lastStateRoot q bs ∧
        q.cursor = w.inbox.head ∧
        (∀ j, w.inbox.head ≤ j → j < s.head → ∃ x ∈ pairs q bs, x.1.cursor = j ∧ x.2.header.cursor = j+1) ∧
        ∀ x ∈ pairs q bs, ServesQueue w r x.1 x.2)

/-- The headline claims of §1 "Positioning and security model" (spec L9-L19): fund safety,
accountable finality and forced-inclusion integrity, each under the one premise record. -/
def Claims : Prop := FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity

end Etna.Statements
