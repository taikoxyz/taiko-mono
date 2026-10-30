import EtnaModel.BlockValidity

/-! A valid decoded block trace constructs its certificate; CertifiedTable is a conclusion,
not an additional soundness premise. Accepted settlement extends the actual frontier on
that trace. Real verifier/guest soundness must establish the trace/statement binding. -/
namespace Etna.Design.Settlement

/-- Compute every public endpoint from the checked trace, rather than accepting caller
claims for the terminal hashes, FI head or active committee snapshot. -/
def statement (r : BlockValidity.Rules) (p : BlockValidity.Header) (bs : List BlockValidity.Block)
    (blobs : List Hash) : StatementData :=
  let last := BlockValidity.terminal p bs
  let input : LandInput := ⟨p.height,last.height,last.elHash,last.cometHash,last.stateRoot,
    r.referenceNumber,last.cursor,(Consensus.activeAt r.consensus last.height).cutoff⟩
  ⟨r.consensus.domain,r.consensus.generation,r.committeeConfig,p.elHash,p.cometHash,p.cursor,
    input,r.referenceHash,blobs,tableHash r.gridK r.consensus.generation p.height last.height
      (BlockValidity.cuts p bs)⟩

/-- Batch-to-blob binding remains an explicit decoding/authentication boundary. -/
def BatchValid (r : BlockValidity.Rules) (p : BlockValidity.Header)
    (bs : List BlockValidity.Block) (blobs : List Hash) : Prop :=
  BlockValidity.Chain r p bs ∧ r.batchPayloadValid blobs bs = true

/-- Generation floor of a context: genesisCutoff in generation 0, R in later generations. -/
def floor (c : Consensus.Context) : Nat := if c.generation = 0 then c.genesisCutoff else c.originBlock

/-- Slot 284 fits context c: it tracks c at the current checkpoint (within a generation), or
it is at most c's floor (the first landing after a recovery: R exceeds every earlier landed
snapshot, `land_snapshot_below_block`). -/
def SnapshotFits (c : Consensus.Context) (s : State) : Prop :=
  s.snapshot = (Consensus.activeAt c s.checkpoint.height).cutoff ∨ s.snapshot ≤ floor c

/-- Landings each certified by a valid batch whose rules share one consensus context c (one
generation's history-derived context; per-proof reference blocks may differ). -/
inductive CertifiedTrace (c : Consensus.Context) : State → State → Prop
  | refl (s : State) : CertifiedTrace c s s
  | step {start s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
      (prior : CertifiedTrace c start s) (accepted : land s i leaves e = some t) (context : r.consensus = c)
      (valid : BatchValid r p bs blobs) (binding : e.certificate = statement r p bs blobs) : CertifiedTrace c start t

/-- Structural reachable-state invariant for ordinary landings. Recovery and exceptional
rollback composition are separate proof obligations, not hidden cases of LandingTrace. -/
def StateValid (s : State) : Prop :=
  recordAt s s.checkpoint.height = some s.checkpoint ∧ s.checkpoint.cursor = s.head ∧
  OnGrid s ∧ (s.records.map Checkpoint.height).Nodup ∧ ∀ r ∈ s.records, r.height ≤ s.checkpoint.height

inductive LandingTrace : State → State → Prop
  | refl (s : State) : LandingTrace s s
  | step {start s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (prior : LandingTrace start s) (accepted : land s i leaves e = some t) : LandingTrace start t

end Etna.Design.Settlement
