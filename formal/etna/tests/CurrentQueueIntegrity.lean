import EtnaProofs.CurrentQueueIntegrity

namespace Etna.CurrentQueueIntegrityRegression
open Etna.Design Etna.Design.Current
set_option maxRecDepth 20000
set_option maxHeartbeats 2000000

def domain : Domain := ⟨1,2,3,4⟩
def registry : RegistryMachine.State :=
  { ledger := {nextId := 0,bonds := fun _ => none,slots := fun _ => none,keyId := fun _ => none},
    config := {inbox := 3} }
def env : Protocol.Environment where
  core := ⟨domain,7,8,0,0,9⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,2,1152,10,1,1,9⟩
  genesisHeader := ⟨0,100,100,0,0,0,⟨0,0,0,0,0,0,0⟩⟩
  initialSigner := ⟨domain,0,0,[],false,[]⟩
  time := id
  stateRoot := fun s => s.number
  blockHash := fun _ n => n
  headerHash := fun h => h.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun _ => True
  txHash := fun raw => ((raw.head?).getD 0).toNat
  unzenNextProposal := 1
  archiveAuthenticated := fun _ _ _ => true
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => true
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9

def initial : Protocol.World := Protocol.empty env registry
def block1 : Protocol.World := Protocol.transact env initial (.advance 1)
def started : Protocol.World := Protocol.transact env block1 (.initializeInbox 7)
def admitted : Protocol.World := Protocol.transact env started (.enqueue [11] 1000000001 true)
def twice : Protocol.World := Protocol.transact env admitted (.enqueue [12] 2000000000 false)

-- These literal amounts use a base fee of one gwei, threshold one, and pending 0 then 1.
example : started.initialized = true := by decide
example : admitted.queue = [(0,⟨11,1,1⟩)] ∧ admitted.inbox.ethBalance = 1000000000 ∧
    admitted.inbox.feeAdmissions = 1000000000 := by decide
example : twice.queue = [(0,⟨11,1,1⟩),(1,⟨12,1,1⟩)] ∧
    twice.inbox.ethBalance = 3000000000 ∧ twice.inbox.feeAdmissions = 3000000000 := by decide
example : Protocol.transact env started (.enqueue [11] 999999999 true) = started := by rfl
example : Protocol.transact env started (.enqueue [11] 1000000001 false) = started := by rfl
example : Protocol.transact env admitted (.enqueue [12] 1999999999 true) = admitted := by rfl

theorem started_trace : Protocol.Trace env initial started :=
  .step (.step (.refl initial) (.call initial (.advance 1))) (.call block1 (.initializeInbox 7))
theorem admitted_trace : Protocol.Trace env initial admitted :=
  .step started_trace (.call started (.enqueue [11] 1000000001 true))
theorem twice_trace : Protocol.Trace env initial twice :=
  .step admitted_trace (.call admitted (.enqueue [12] 2000000000 false))
example : twice.inbox.head ≤ twice.inbox.tail := QueueIntegrity.trace_head_bounds twice_trace

-- Recovery rejects duplicate, out-of-pending-range and unadmitted indices atomically.
def request : Protocol.RecoveryRequest := ⟨7,0,0,0,1000,[],[0,1],0,none⟩
example : (Protocol.recover env twice request).isSome = true := by decide
example : Protocol.recover env twice {request with clear := [0,0]} = none := by decide
example : Protocol.recover env twice {request with clear := [2]} = none := by decide

-- A ready caller cannot turn snapshot publication into signing authorization; all HRS
-- records remain unchanged, and the origin and target headers are both present.
def signature : Signer.Signed := ⟨0,⟨0,0,2⟩,42,43⟩
def importing : Protocol.World :=
  { started with node := { started.node with
      target := some (0,started.inbox.checkpoint),signer := { started.node.signer with ready := true,log := [signature] } } }
def candidate : Import.Candidate := ⟨0,0,0,100,100,true,true,true,true⟩
def imported : Protocol.World := (Protocol.nodeImport env importing candidate true).getD importing
example : imported.node.trusted = false ∧ imported.node.signer.ready = false ∧
    imported.node.signer.log = [signature] ∧ imported.node.importedHeaders = [0] := by decide
example : Import.publish {candidate with origin := 1,height := 4} 0 importing.node.signer true =
    some ⟨0,4,[1,2,3,4],importing.node.signer,false⟩ := by rfl
example : Import.publish {candidate with origin := 5,height := 4} 0 importing.node.signer true = none := by decide

-- Exported contracts are exercised symbolically, not inferred from finite adapters.
example (env : Protocol.Environment) (w t : Protocol.World) (raw : Blocks.Bytes)
    (paid : Nat) (refund : Bool) (ok : Protocol.enqueue env w raw paid refund = some t) :
    QueueIntegrity.AdmissionAccounting w.inbox t.inbox raw.length paid refund :=
  (QueueIntegrity.admission_exact ok).1
example (env : Protocol.Environment) (w t : Protocol.World) (request : Protocol.RecoveryRequest)
    (ok : Protocol.recover env w request = some t) :
    request.clear.Pairwise (· < ·) ∧ ∀ i ∈ request.clear, w.inbox.head ≤ i ∧ i < w.inbox.tail :=
  QueueIntegrity.recovery_pending_guards ok

end Etna.CurrentQueueIntegrityRegression
