import EtnaModel.NormalSigning

/-! Decoded historical evidence for SPEC 6.2 items 1/2/7/8. The archive is indexed by
EL height and stores authenticated anchor numbers. Append-only extension means the same
canonical EL header cannot acquire a different anchor. Terminal coverage and `headers`
bind each accepted batch to that archive. `origin` and `anchors` express that the decoded
L1 origin and archive anchors exist at or before the proof's authenticated reference.
These are L1/header/hash adapter contracts, not assumptions about selected cutoffs,
stored snapshot provenance, confirmation coverage or excluded keys. Batch validity and
certificate binding are the certified guest interface; they can be supplied by
Etna.Proofs.submitted_landing_certified under the unchanged headline premises. -/
namespace Etna.Design.CanonicalHistory
open ProtocolState

/-- Original non-settlement calls, retaining all inputs and their order. Recovery is a
separate Run constructor because it changes the fixed generation origin. -/
inductive Edit : World → World → Prop
  | registration {w : World} {s : RegistryHistory.State} {key owner amount now : Nat}
      (time : w.l1Block ≤ now) (ok : RegistryHistory.register w.registry key owner amount now = some s) :
      Edit w (registered w s now)
  | modification {w : World} {s : RegistryHistory.State} {id now : Nat} {action : RegistryHistory.Edit}
      (time : w.l1Block ≤ now) (callable : publicEdit action = true)
      (ok : RegistryHistory.edit w.registry w.inbox id now action = some s) : Edit w (registered w s now)
  | enqueue {w : World} {s : State} {hash timestamp now raw paid : Nat} {refund : Bool}
      (time : w.l1Block ≤ now) (blockRange : now < limit48) (timestampRange : timestamp < limit48)
      (ok : Forced.enqueue w.inbox raw paid refund = some s) : Edit w (enqueued w s hash timestamp now)
  | sweep {w : World} {s : State} {now : Nat} {transfer : Bool}
      (time : w.l1Block ≤ now) (ok : Forced.sweep w.inbox transfer = some s) : Edit w (landed w s now)
  | invalidation {w : World} {s : State} {expected now : Nat} {owner : Bool}
      (time : w.l1Block ≤ now)
      (ok : Recovery.invalidateRecoveryNonce w.inbox expected owner = some s) : Edit w (landed w s now)

/-- Initialized canonical history. This does not embed NormalSigning.Run or SnapshotSource.
Its landing witnesses retain the actual calls and decoded accepted batches. Authenticating
these decoded values, reference finality and header/hash agreement remain external; no
unqualified lift of the old free-authentication-predicate Statements.Run is claimed. -/
inductive Run (initial : World) : World → List Nat → Prop
  | genesis {hash root : Hash} (init : Deployment.Genesis initial hash root) : Run initial initial []
  | landing {w : World} {old more : List Nat} {s : State} {i : LandInput} {leaves : List Leaf}
      {e : LandingEnv} {r template : BlockValidity.Rules} {parent : BlockValidity.Header}
      {blocks : List BlockValidity.Block} {blobs : List Hash}
      (prior : Run initial w old) (time : w.l1Block ≤ e.blockNumber)
      (accepted : Etna.Design.land w.inbox i leaves e = some s)
      (built : Deployment.build w w.inbox.configuration (old ++ more) template = some r)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (headers : ∀ b ∈ blocks, (old ++ more)[b.header.height]? = some b.header.anchor.number)
      (origin : w.inbox.origin.l1Block ≤ r.referenceNumber)
      (anchors : ∀ a ∈ old ++ more, a ≤ r.referenceNumber) :
      Run initial (landed w s e.blockNumber) (old ++ more)
  | edit {w t : World} {archive : List Nat} (prior : Run initial w archive) (change : Edit w t) :
      Run initial t archive
  | recovery {w : World} {archive : List Nat} {s : Recovery.World} {a : Recovery.Request}
      {origin : Origin} {owner externalOK : Bool}
      (prior : Run initial w archive) (time : w.l1Block ≤ origin.l1Block)
      (accepted : Recovery.recover (recoveryView w) a w.adapters.recovery origin owner externalOK = some s) :
      Run initial (recovered w a origin s) archive

/-- Submission annotation for the same original calls. It adds only the environment's
submission predicate; no selected cutoff, snapshot source or exclusion fact is added. -/
inductive Submitted (submit : World → LandInput → List Leaf → LandingEnv → Prop) :
    {initial w : World} → {archive : List Nat} → Run initial w archive → Prop
  | genesis {initial : World} {hash root : Hash} (init : Deployment.Genesis initial hash root) :
      Submitted submit (.genesis init)
  | landing {initial w : World} {old more : List Nat} {s : State} {i : LandInput} {leaves : List Leaf}
      {e : LandingEnv} {r template : BlockValidity.Rules} {parent : BlockValidity.Header}
      {blocks : List BlockValidity.Block} {blobs : List Hash} {history : Run initial w old}
      {time : w.l1Block ≤ e.blockNumber} {accepted : Etna.Design.land w.inbox i leaves e = some s}
      {built : Deployment.build w w.inbox.configuration (old ++ more) template = some r}
      {valid : Settlement.BatchValid r parent blocks blobs}
      {binding : e.certificate = Settlement.statement r parent blocks blobs}
      {headers : ∀ b ∈ blocks, (old ++ more)[b.header.height]? = some b.header.anchor.number}
      {origin : w.inbox.origin.l1Block ≤ r.referenceNumber}
      {anchors : ∀ a ∈ old ++ more, a ≤ r.referenceNumber}
      (prior : Submitted submit history) (submitted : submit w i leaves e) :
      Submitted submit (.landing history time accepted built valid binding headers origin anchors)
  | edit {initial w t : World} {archive : List Nat} {history : Run initial w archive}
      (prior : Submitted submit history) (change : Edit w t) : Submitted submit (.edit history change)
  | recovery {initial w : World} {archive : List Nat} {s : Recovery.World} {a : Recovery.Request}
      {origin : Origin} {owner externalOK : Bool} {history : Run initial w archive}
      (prior : Submitted submit history) (time : w.l1Block ≤ origin.l1Block)
      (accepted : Recovery.recover (recoveryView w) a w.adapters.recovery origin owner externalOK = some s) :
      Submitted submit (.recovery history time accepted)

end Etna.Design.CanonicalHistory
