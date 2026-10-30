import Lean

/-! Trusted audit tooling, compiled separately from the five libraries. Imported dynamically
by RunAudit so the vector executable's global main does not collide with this tool. -/
namespace DerivationAudit
open Lean Meta

def libraries : List Name :=
  [`DerivationModel, `DerivationStatements, `DerivationProofs, `DerivationWitnesses, `DerivationVectors]

def packageModule (n : Name) : Bool := libraries.any (·.isPrefixOf n)

def owned (env : Environment) (n : Name) : Bool :=
  match env.getModuleIdxFor? n with
  | some idx => packageModule env.header.moduleNames[idx.toNat]!
  | none => false

def checkAxiomsOf (n : Name) : CoreM Unit := do
  for ax in ← collectAxioms n do
    unless [``propext, ``Classical.choice, ``Quot.sound].contains ax do
      throwError "forbidden axiom: {n} depends on {ax}"

def checkHeadline (thm claim : Name) : CoreM Unit := do
  let some info := (← getEnv).find? thm | throwError "missing headline {thm}"
  unless info.isTheorem && info.type.isConstOf claim do
    throwError "headline {thm} must be a theorem with exactly type {claim}"
  let some (.defnInfo statement) := (← getEnv).find? claim |
    throwError "claim {claim} must be a definition"
  unless statement.type.isProp do throwError "claim {claim} must have type Prop"
  checkAxiomsOf thm

/-- One pass of `liveProof`: every binder whose variable its body does not use is removed,
looking through metadata. `let x := v; b` and `have x := v; b` (`letE`, dependent or not),
`letFun v (fun x => b)` and the beta-redex `(fun x => b) v` all become `b`, so `v` (and the
binder type) no longer count as used. -/
partial def dropDeadBinders (e : Expr) : Expr :=
  let dead? (b : Expr) : Option Expr :=
    if b.hasLooseBVar 0 then none else some (dropDeadBinders (b.lowerLooseBVars 1 1))
  e.replace fun
    | .letE _ _ _ b _ => dead? b
    | .app f a =>
      match f.consumeMData, a.consumeMData with
      | .lam _ _ b _, _ => dead? b
      | f, .lam _ _ b _ => if f.isAppOfArity ``letFun 3 then dead? b else none
      | _, _ => none
    | _ => none

/-- A proof term without dead binders: `dropDeadBinders` repeated until nothing changes, since
removing an inner binder can leave an enclosing one unused (`have h := p; (fun _ => q) h`). -/
partial def liveProof (e : Expr) : Expr :=
  let e' := dropDeadBinders e
  if e' == e then e else liveProof e'

/-- The fields of structure `s` (field names `fields`) that term `e` reads, through a projection
function (`p.field`) or a primitive projection. -/
def fieldsRead (s : Name) (fields : Array Name) (e : Expr) : Array Name := Id.run do
  let used := e.getUsedConstants
  let mut out := #[]
  for h : i in [0:fields.size] do
    let read := used.contains (s ++ fields[i]) ||
      (e.find? fun | .proj t j _ => t == s && j == i | _ => false).isSome
    if read then out := out.push fields[i]
  return out

/-- Fields of structure `s` read by the proof of `c` or by a package theorem it uses,
every proof read without unused bindings (`liveProof`). Definitions and library lemmas are not entered. A field taken apart by a pattern match
(`cases`, `obtain ⟨…⟩ := p`) instead of a projection is not counted, so the check errs towards
reporting a field unused. In the other direction it over-approximates: reads are counted per
structure, not per hypothesis, so a projection of any value of `s` counts, and so does one that
appears only in a binder type or in an argument the proof ignores. Memoized in the state. -/
partial def premiseReads (s : Name) (fields : Array Name) (c : Name) :
    StateT (NameMap (Array Name)) CoreM (Array Name) := do
  if let some known := (← get).find? c then return known
  modify (·.insert c #[])
  let some (.thmInfo v) := (← getEnv).find? c | return #[]
  let live := liveProof v.value
  let mut out := fieldsRead s fields live
  for d in live.getUsedConstants do
    -- Fixture names exist only in the separate tooling mutation tests.
    if d != c && (owned (← getEnv) d || (`Fixture).isPrefixOf d) &&
        ((← getEnv).find? d |>.any (·.isTheorem)) then
      for f in ← premiseReads s fields d do
        unless out.contains f do out := out.push f
  modify (·.insert c out)
  return out

/-- Require all actual fields, counting live reads through package theorem calls.
This is syntactic evidence per structure, not logical necessity or dataflow per hypothesis. -/
def checkPremiseUse (s : Name) (theorems : Array Name) : CoreM Unit := do
  let some info := getStructureInfo? (← getEnv) s | throwError "not a premise structure: {s}"
  let reads ← (theorems.mapM fun t => return (t, ← premiseReads s info.fieldNames t)).run' {}
  for field in info.fieldNames do
    let readers := reads.filter (·.2.contains field) |>.map (·.1)
    if readers.isEmpty then throwError "unused premise field: {s}.{field}"
    logInfo m!"premise use: {s}.{field} <- {readers}"

/-- Traverse statement/model definitions to check named anchors of the intended claims.
These anchors catch accidental erasure, not arbitrary logical weakening of a proposition. -/
partial def dependencies (todo : List Name) (seen : NameSet := {}) : CoreM NameSet := do
  match todo with
  | [] => return seen
  | c :: rest =>
    if seen.contains c then return ← dependencies rest seen
    let env ← getEnv
    let extra := match env.find? c with
      | some info =>
        if owned env c then
          let value := match info with
            | .defnInfo v => v.value.getUsedConstants
            | .inductInfo v => v.ctors.toArray
            | _ => #[]
          (info.type.getUsedConstants ++ value).toList
        else []
      | none => []
    dependencies (extra ++ rest) (seen.insert c)

def checkAnchors (claim : Name) (required : List Name) : CoreM Unit := do
  let deps ← dependencies [claim]
  for n in required do
    unless deps.contains n do throwError "claim {claim} missing dependency {n}"

def checkDefinitionLayers (n : Name) : MetaM Unit := do
  let env ← getEnv
  let some idx := env.getModuleIdxFor? n | return
  let owner := env.header.moduleNames[idx.toNat]!
  unless (`DerivationModel).isPrefixOf owner || (`DerivationStatements).isPrefixOf owner do return
  -- Generated equation lemmas, constructors, projections and recursors are allowed.
  unless (← findDeclarationRangesCore? n).isSome do return
  let some info := env.find? n | return
  let proof ← match info with
    | .thmInfo _ => pure (!env.isProjectionFn n)
    | .axiomInfo _ | .opaqueInfo _ => pure true
    | .defnInfo v => isProp v.type
    | _ => pure false
  if proof then throwError "proof declaration in definitions layer: {n}"

/-- Reject missing, added, or trivially True premise fields. Other logical weakening
still requires review of Statements; the audit does not decide semantic necessity. -/
def checkPremiseShape (s : Name) (expected : Array Name) : MetaM Unit := do
  let env ← getEnv
  let some info := getStructureInfo? env s | throwError "not a structure: {s}"
  unless info.fieldNames == expected do throwError "premise fields changed: {s}"
  for field in info.fieldNames do
    let some projection := env.find? (s ++ field) | throwError "missing projection"
    forallTelescope projection.type fun _ body => do
      if (← whnf body).isConstOf ``True then throwError "trivial premise field: {s}.{field}"

def checkAll : CoreM Unit := do
  let env ← getEnv
  let decls := env.constants.map₁.fold (fun acc n _ => if owned env n then acc.push n else acc) #[]
  if decls.isEmpty then throwError "no package declarations imported"
  for n in decls do
    checkAxiomsOf n
    (checkDefinitionLayers n).run'
  for (thm, claim) in [(`derivation_safety, `DerivationSafety), (`header_safety, `HeaderSafety),
      (`forced_inclusion_safety, `ForcedInclusionSafety), (`claims, `Claims)] do
    checkHeadline (`TaikoSpec.Derivation.Proofs ++ thm) (`TaikoSpec.Derivation.Statements ++ claim)
  checkAnchors `TaikoSpec.Derivation.Statements.DerivationSafety
    [`TaikoSpec.Derivation.Statements.InitialParentBounds, `TaikoSpec.Derivation.deriveSources,
     `TaikoSpec.Derivation.sourceBlocks, `TaikoSpec.Chain]
  checkAnchors `TaikoSpec.Derivation.Statements.HeaderSafety
    [`TaikoSpec.Derivation.Statements.HeaderPremises, `TaikoSpec.Derivation.deriveHeaders,
     `TaikoSpec.Derivation.HeaderCommits, `TaikoSpec.Derivation.ParentCommits,
     `TaikoSpec.Derivation.Statements.HeaderForkPolicy]
  checkAnchors `TaikoSpec.Derivation.Statements.ForcedInclusionSafety
    [`TaikoSpec.Derivation.Statements.ForcedAcceptance, `TaikoSpec.Derivation.finalizeSource,
     `TaikoSpec.Derivation.defaultBlock, `TaikoSpec.Derivation.deriveSources]
  checkAnchors `TaikoSpec.Derivation.Statements.Claims
    [`TaikoSpec.Derivation.Statements.DerivationSafety, `TaikoSpec.Derivation.Statements.HeaderSafety,
     `TaikoSpec.Derivation.Statements.ForcedInclusionSafety]
  (checkPremiseShape `TaikoSpec.Derivation.Statements.InitialParentBounds
    #[`anchorNotAfterOrigin, `gasMinimum, `gasMaximum]).run'
  (checkPremiseShape `TaikoSpec.Derivation.Statements.HeaderPremises
    #[`lookupsSound, `parentAuthenticated]).run'
  checkPremiseUse `TaikoSpec.Derivation.Statements.InitialParentBounds
    #[`TaikoSpec.Derivation.Proofs.derivation_safety]
  checkPremiseUse `TaikoSpec.Derivation.Statements.HeaderPremises
    #[`TaikoSpec.Derivation.Proofs.header_safety]
  logInfo m!"audit: {decls.size} package declarations, four exact headlines and all premise fields OK"
end DerivationAudit
