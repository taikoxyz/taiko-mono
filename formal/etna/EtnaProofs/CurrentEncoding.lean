import EtnaModel.CurrentEncoding

namespace Etna.Design.Current.Encoding

theorem relabel_head [DecidableEq α] (known : List α) (code : α → Nat) (a : α) :
    relabel (a :: known) code a = 0 := by
  simp only [relabel,ite_true]

theorem relabel_cons_ne [DecidableEq α] (known : List α) (code : α → Nat) {a b : α}
    (different : a ≠ b) : relabel (b :: known) code a = relabel known code a+1 := by
  simp only [relabel,different,ite_false]

theorem relabel_injective [DecidableEq α] (known : List α) (code : α → Nat)
    (injective : ∀ {a b}, code a=code b → a=b) {a b : α}
    (equal : relabel known code a = relabel known code b) : a=b := by
  induction known with
  | nil => exact injective equal
  | cons x xs ih =>
    by_cases ha : a=x
    · by_cases hb : b=x
      · exact ha.trans hb.symm
      · simp [relabel,ha,hb] at equal
    · by_cases hb : b=x
      · simp [relabel,ha,hb] at equal
      · exact ih (by simpa [relabel,ha,hb] using equal)

theorem pair_order {a b c d : Nat} (less : a+b < c+d) : pair a b < pair c d := by
  have one : (a+b)*(a+b)+(a+b) < (a+b+1)*(a+b+1) := by
    have strict := Nat.mul_lt_mul_of_pos_right (Nat.lt_succ_self (a+b)) (Nat.succ_pos (a+b))
    simpa [Nat.mul_add] using strict
  have two : (a+b+1)*(a+b+1) ≤ (c+d)*(c+d) := Nat.mul_le_mul (by omega) (by omega)
  unfold pair
  omega

theorem pair_injective {a b c d : Nat} (equal : pair a b = pair c d) : a=c ∧ b=d := by
  have sum : a+b=c+d := by
    have left : ¬ a+b<c+d := fun h => (Nat.ne_of_lt (pair_order h)) equal
    have right : ¬ c+d<a+b := fun h => (Nat.ne_of_lt (pair_order h)) equal.symm
    omega
  have first : a=c := by
    unfold pair at equal
    rw [sum] at equal
    omega
  exact ⟨first,by omega⟩

theorem tree_code_injective {a b : Tree} (equal : a.code = b.code) : a=b := by
  induction a generalizing b with
  | leaf n =>
    cases b with
    | leaf m =>
      simp only [Tree.code] at equal
      have same : n=m := by omega
      simp [same]
    | node c d => simp only [Tree.code] at equal; omega
  | node left right ia ib =>
    cases b with
    | leaf m => simp only [Tree.code] at equal; omega
    | node c d =>
      simp only [Tree.code] at equal
      have same : pair left.code right.code = pair c.code d.code := by omega
      have fields := pair_injective same
      rw [ia fields.1,ib fields.2]

theorem list_injective (f : α → Tree) (injective : ∀ {a b}, f a=f b → a=b)
    {as bs : List α} (equal : list f as = list f bs) : as=bs := by
  induction as generalizing bs with
  | nil => cases bs <;> simp_all [list]
  | cons a as ih =>
    cases bs with
    | nil => simp [list] at equal
    | cons b bs =>
      have fields := Tree.node.inj equal
      rw [injective fields.1,ih fields.2]

theorem list_eq (f : α → Tree) (injective : ∀ {a b}, f a=f b → a=b)
    {as bs : List α} : list f as = list f bs ↔ as=bs :=
  ⟨list_injective f injective,fun h => congrArg (list f) h⟩

theorem domain_eq {a b : Domain} : domain a = domain b ↔ a=b := by
  cases a; cases b; simp [domain,quad,and_assoc]

theorem entry_eq {a b : Committee.Entry} : entry a = entry b ↔ a=b := by
  cases a; cases b; simp [entry,quad,and_assoc]

theorem committee_eq {a b : Committee.Record} : committee a = committee b ↔ a=b := by
  cases a; cases b; simp [committee,list_eq entry (fun h => entry_eq.mp h),and_assoc]

theorem origin_eq {a b : Origin} : origin a = origin b ↔ a=b := by
  cases a; cases b; simp [origin]

theorem named_origin_eq {a b : Nat × Origin} : namedOrigin a = namedOrigin b ↔ a=b := by
  cases a; cases b; simp [namedOrigin,origin_eq]

theorem checkpoint_eq {a b : Checkpoint} : checkpoint a = checkpoint b ↔ a=b := by
  cases a; cases b; simp [checkpoint,quad,and_assoc]

theorem signal_eq {a b : Signal} : signal a = signal b ↔ a=b := by
  cases a; cases b; simp [signal]

theorem configuration_eq {a b : CommitteeConfig} : configuration a = configuration b ↔ a=b := by
  cases a; cases b; simp [configuration,quad,and_assoc]

theorem bool_nat_eq {a b : Bool} : a.toNat=b.toNat ↔ a=b := by
  cases a <;> cases b <;> decide

theorem state_eq {a b : Etna.Design.State} : state a = state b ↔ a=b := by
  cases a; cases b
  simp [state,quad,bool_nat_eq,domain_eq,origin_eq,checkpoint_eq,configuration_eq,committee_eq,
    list_eq namedOrigin (fun h => named_origin_eq.mp h),
    list_eq checkpoint (fun h => checkpoint_eq.mp h),list_eq signal (fun h => signal_eq.mp h),and_assoc]

theorem schedule_eq {a b : Rules.Schedule} : schedule a = schedule b ↔ a=b := by
  cases a; cases b; simp [schedule,quad,and_assoc]

theorem start_eq {a b : Protocol.StartData} : start a = start b ↔ a=b := by
  cases a; cases b; simp [start]

theorem optional_eq (f : α → Tree) (injective : ∀ {a b}, f a=f b → a=b)
    {a b : Option α} : optional f a = optional f b ↔ a=b := by
  cases a <;> cases b <;> simp [optional]
  exact ⟨injective,fun h => congrArg f h⟩

theorem registry_snapshot_eq {a b : RegistryHistory.Snapshot} : registrySnapshot a = registrySnapshot b ↔ a=b := by
  cases a; cases b; simp [registrySnapshot,list_eq entry (fun h => entry_eq.mp h)]

theorem forced_entry_eq {a b : Forced.Entry} : forcedEntry a = forcedEntry b ↔ a=b := by
  cases a; cases b; simp [forcedEntry]

theorem queued_entry_eq {a b : Nat × Forced.Entry} : queuedEntry a = queuedEntry b ↔ a=b := by
  cases a; cases b; simp [queuedEntry,forced_entry_eq]

theorem snapshot_eq {a b : Protocol.Snapshot} : snapshot a = snapshot b ↔ a=b := by
  cases a; cases b
  simp [snapshot,quad,state_eq,schedule_eq,optional_eq start (fun h => start_eq.mp h),
    list_eq registrySnapshot (fun h => registry_snapshot_eq.mp h),
    list_eq queuedEntry (fun h => queued_entry_eq.mp h),and_assoc]

theorem snapshot_hash_injective {a b : Protocol.Snapshot} (equal : snapshotHash a = snapshotHash b) : a=b :=
  snapshot_eq.mp (tree_code_injective equal)

theorem reference_binding {env : Protocol.Environment} : Protocol.ReferenceBinding
    { env with blockHash := referenceHash } := by
  intro a b number equal
  have same := (pair_injective equal).1
  exact list_injective snapshot (fun h => snapshot_eq.mp h) (tree_code_injective same)

theorem anchor_eq {a b : BlockValidity.Anchor} : anchor a = anchor b ↔ a=b := by
  cases a; cases b; simp [anchor,quad,and_assoc]

theorem header_hash_separation {a b : Blocks.Header} (equal : headerHash a = headerHash b) :
    a.height=b.height ∧ a.stateRoot=b.stateRoot ∧ a.timestamp=b.timestamp ∧ a.anchor=b.anchor := by
  have same := tree_code_injective equal
  simpa [header,quad,anchor_eq,and_assoc] using same

end Etna.Design.Current.Encoding
