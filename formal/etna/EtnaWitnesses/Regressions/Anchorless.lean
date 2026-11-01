import EtnaProofs.Anchorless

namespace Etna.Design.AnchorlessRegression
open Anchorless

-- Ideal fixture roots and storage checker; no real L1/EL/crypto implementation is claimed.
def l1 (number : Nat) : Nat := number + 1000
def fork : Nat := 100
def domain : SourceDomain := ⟨1,42⟩
def early : Header := ⟨99,7,7,0,7⟩
def first : Header := ⟨100,7,7,1007,13⟩
def later : Header := ⟨8291,8,8,1008,13⟩
def oldEnough : Header := ⟨9000,9,9,1009,13⟩
def deployed : RootState := { initialRoots with code := true }
def legacy : RootState := { execute deployed early with checkpoints := fun n => if n = 7 then some 1007 else none }
def active : RootState := execute legacy first
def expired : RootState := execute active later
def retained : RootState := execute active oldEnough
def proof : HopProof := ⟨100,1007,1,42,77⟩
def verify (p : HopProof) : Bool := decide (p = proof)
def received : Cache := ⟨[999],[77]⟩
def prerequisites : Installation := ⟨100,99,true,true,true,true,true,false,false⟩
def installed : Installation := pairedUpgrade prerequisites true true
def live : Installation := { installed with clock := 100 }

private theorem legacy_history : RootRun l1 fork legacy := by
  exact .step (.step (.step .genesis (.deploy _)) (.block early (by decide) (by unfold ValidHeader; decide)))
    (.checkpoint 7 1007 (by decide) (by decide) rfl)

private theorem active_history : RootRun l1 fork active :=
  .step legacy_history (.block first (by decide) (by unfold ValidHeader; decide))

private theorem prerequisites_history : InstallRun fork prerequisites :=
  .step (.step (.step (.step (.step (.step .initial (.advance _ 99 (by decide))) (.engines _)) (.history rfl)) (.beacon rfl)) (.readers rfl)) (.images rfl)

/-- Real accepted pre/postfork roots coexist, and the first fork block rejects the old
anchor even though the old ancestors guard still succeeds. -/
theorem fork_boundary :
    RootRun l1 fork active ∧ resolve fork legacy true 7 = some 1007 ∧
      resolve fork active true 7 = none ∧ resolve fork active true 100 = some 1007 ∧
      anchorV4 fork 99 true = true ∧ anchorV4 fork 100 true = false :=
  ⟨active_history,by decide,by decide,by decide,by decide,by decide⟩

/-- Number 100 is a valid pre-fork checkpoint and also a post-fork timestamp: verifier
time changes its meaning rather than rejecting overlapping numeric domains. -/
theorem overlapping_domains :
    resolve fork { legacy with checkpoints := fun _ => some 1100 } true 100 = some 1100 ∧
    resolve fork active true 100 = some 1007 := by decide

/-- A canonical postfork block is possible with no system contract; its call does nothing
and the new resolver fails closed. Genesis itself never writes an entry. -/
theorem missing_system_contract :
    RootRun l1 fork (execute initialRoots first) ∧
    resolve fork (execute initialRoots first) true 100 = none ∧
    resolve fork active false 100 = none ∧ initialRoots.ring 0 = none :=
  ⟨.step .genesis (.block first (by decide) (by unfold ValidHeader; decide)),by decide,by decide,rfl⟩

/-- EIP beaconGet may return zero; Anchor adds the nonzero rejection. Timestamp zero is rejected
by the getter itself, including when a matching zero-timestamp entry is present. -/
theorem getter_and_anchor_filters :
    beaconGet true (execute deployed early).ring 99 = some 0 ∧
    beaconGet true (fun _ => some ⟨0,1007⟩) 0 = none ∧
    resolve 99 (execute deployed early) true 99 = none := by decide

/-- Expiry is an actual collision at 100+8191. More than 8191 seconds without collision
leaves timestamp 100 readable, and a future timestamp has no canonical write. -/
theorem actual_overwrite :
    RootRun l1 fork expired ∧ resolve fork expired true 100 = none ∧
    RootRun l1 fork retained ∧ resolve fork retained true 100 = some 1007 ∧
    resolve fork active true 101 = none :=
  ⟨.step active_history (.block later (by decide) (by unfold ValidHeader; decide)),by decide,
   .step active_history (.block oldEnough (by decide) (by unfold ValidHeader; decide)),by decide,by decide⟩

/-- Valid proof and independent root/chain/account/slot attacks all exercise the actual
checker; invalid coordinates cannot be rescued by a permissive crypto callback. -/
theorem proof_domain_boundaries :
    checkProof fork active true domain verify 77 proof = true ∧
    checkProof fork active true domain (fun _ => true) 77 { proof with root := 666 } = false ∧
    checkProof fork active true domain (fun _ => true) 77 { proof with chain := 2 } = false ∧
    checkProof fork active true domain (fun _ => true) 77 { proof with account := 43 } = false ∧
    checkProof fork active true domain (fun _ => true) 77 { proof with slot := 78 } = false := by decide

/-- A cache history contains the actual accepted proof before an actual ring overwrite;
the original authorization survives, whereas the old flat cached signal does not. -/
theorem cached_after_expiry :
    CacheRun l1 fork domain verify expired received ∧
    resolve fork expired true proof.blockId = none ∧ cached received 77 = true ∧ cached received 999 = false := by
  refine ⟨?_,by decide,by decide,by decide⟩
  apply CacheRun.roots (event := .block later (by decide) (by unfold ValidHeader; decide))
  apply CacheRun.prove (cache := ⟨[999],[]⟩) (slot := 77) (p := proof) (accepted := by decide)
  exact .roots (.roots (.roots (.roots (.initial [999]) (.deploy _))
    (.block early (by decide) (by unfold ValidHeader; decide))) (.checkpoint 7 1007 (by decide) (by decide) rfl))
    (.block first (by decide) (by unfold ValidHeader; decide))

/-- Malicious flat checkpoints stay physically present but are ignored by service
resolution before AND after the fork; only the prover can consult this fallback. -/
theorem namespace_separation :
    resolve fork { legacy with checkpoints := fun _ => none, flatCheckpoints := fun _ => some 666 } true 7 = none ∧
    resolve fork active true 7 = none ∧ cached ⟨[999],[]⟩ 999 = false ∧
    proverCheckpoint (fun _ => none) (fun _ => some 666) 7 = some 666 ∧
    proverCheckpoint (fun _ => some 1007) (fun _ => some 666) 7 = some 1007 := by decide

/-- Valid staged migration succeeds; either missing proxy action, absent image trust and
flat rollback fail. A manually partial deployment cannot resolve an uncached proof. -/
theorem paired_migration :
    InstallRun fork installed ∧ activate live 100 = true ∧
    activate live 101 = false ∧
    pairedUpgrade prerequisites false true = prerequisites ∧
    pairedUpgrade prerequisites true false = prerequisites ∧
    pairedUpgrade { prerequisites with images := false } true true = { prerequisites with images := false } ∧
    rollbackFlat installed = none ∧
    checkProof fork active false domain verify 77 proof = false :=
  ⟨.step prerequisites_history (.pair _ true true),by decide,by decide,by decide,by decide,by decide,by decide,by decide⟩

/-- Nonzero root and 13-byte shape alone admit a forged L1 root; canonical header
validation supplies the missing root-at-number binding. -/
theorem el_shape_insufficient :
    ({ first with root := 666 } : Header).root ≠ 0 ∧
    ({ first with root := 666 } : Header).extraBytes = 13 ∧
    ¬ ValidHeader l1 fork { first with root := 666 } ∧
    ¬ ValidHeader l1 fork { first with encodedNumber := 8 } := by unfold ValidHeader; decide

/-- New authorization is live for a valid proof, then for its cached empty proof after
expiry. A partial provider upgrade and stale flat receipt provide neither route. -/
theorem composed_authorization :
    authorize installed active ⟨[999],[]⟩ domain verify 77 (some proof) = true ∧
    authorize installed expired received domain verify 77 none = true ∧
    authorize { prerequisites with signal := true } active ⟨[999],[]⟩ domain verify 77 (some proof) = false ∧
    authorize { prerequisites with signal := true } active ⟨[999],[]⟩ domain verify 999 none = false := by decide

/-- The proxy batch refuses its old activation boundary, and successful lifecycle
activation retains the original immutable schedule through a real time advance. -/
theorem scheduled_migration :
    InstallRun fork live ∧ live.forkTime = 100 ∧
    pairedUpgrade { prerequisites with clock := 100 } true true = { prerequisites with clock := 100 } :=
  ⟨.step (.step prerequisites_history (.pair _ true true)) (.advance _ 100 (by decide)),rfl,by decide⟩

def service : ServiceConfig := ⟨domain,fun chain app signal => chain*10000 + app*100 + signal⟩
def request : ServiceRequest := ⟨1,6,70⟩
def appRequest : ServiceRequest := { request with app := 7 }
def signalRequest : ServiceRequest := { request with signal := 71 }
def serviceProof : HopProof := { proof with slot := requestSlot service request }
def serviceVerify (p : HopProof) : Bool :=
  decide (p.root = 1007 ∧ p.chain = 1 ∧ p.account = 42 ∧ p.slot ∈ [10670,10770,10671])
def serviceCache : Cache := ⟨[999],[10670]⟩

/-- The fixed service history consumes an explicit source chain/app/signal request and
then a real expiry write; its current receipt remains authorized. -/
theorem service_history :
    ServiceRun service l1 fork serviceVerify expired serviceCache ∧
    serviceAuthorize service installed expired serviceCache serviceVerify request none = true := by
  refine ⟨?_,by decide⟩
  apply ServiceRun.roots (event := .block later (by decide) (by unfold ValidHeader; decide))
  apply ServiceRun.prove (cache := ⟨[999],[]⟩) (installation := installed)
    (migration := paired_migration.1) (time := by decide) (request := request) (p := serviceProof)
    (accepted := by decide)
  exact .roots (.roots (.roots (.roots (.initial [999]) (.deploy _))
    (.block early (by decide) (by unfold ValidHeader; decide))) (.checkpoint 7 1007 (by decide) (by decide) rfl))
    (.block first (by decide) (by unfold ValidHeader; decide))

/-- Changed app/signal reject an old proof and old cache, yet fresh matching proofs
work. A mismatched request source chain also fails independently. -/
theorem service_request_boundaries :
    serviceAuthorize service installed active ⟨[],[]⟩ serviceVerify request (some serviceProof) = true ∧
    serviceAuthorize service installed active serviceCache serviceVerify appRequest (some serviceProof) = false ∧
    serviceAuthorize service installed active serviceCache serviceVerify signalRequest (some serviceProof) = false ∧
    serviceAuthorize service installed active serviceCache serviceVerify appRequest none = false ∧
    serviceAuthorize service installed active serviceCache serviceVerify signalRequest none = false ∧
    serviceAuthorize service installed active serviceCache serviceVerify { request with sourceChain := 2 } (some serviceProof) = false ∧
    serviceAuthorize service installed active serviceCache serviceVerify appRequest
      (some { serviceProof with slot := requestSlot service appRequest }) = true ∧
    serviceAuthorize service installed active serviceCache serviceVerify signalRequest
      (some { serviceProof with slot := requestSlot service signalRequest }) = true := by decide

/-- A deliberately colliding ideal adapter explains the isolation theorem's separation
premise: distinct request coordinates alone do not imply distinct finite hashed slots. -/
theorem collision_scope :
    request ≠ appRequest ∧
    serviceAuthorize ⟨domain,fun _ _ _ => 77⟩ installed active received verify appRequest (some proof) = true ∧
    serviceAuthorize ⟨domain,fun _ _ _ => 77⟩ installed expired received verify appRequest none = true := by decide

end Etna.Design.AnchorlessRegression
