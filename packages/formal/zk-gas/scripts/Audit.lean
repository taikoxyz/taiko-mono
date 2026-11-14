import Lean

/-! Trusted audit tooling, compiled separately from the five libraries. Imported dynamically
by RunAudit so the check-traces executable's global main does not collide with this tool. -/
namespace ZkGasAudit
open Lean Meta

def libraries : List Name :=
  [`ZkGasModel, `ZkGasStatements, `ZkGasProofs, `ZkGasWitnesses, `ZkGasTraces]

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
  unless (`ZkGasModel).isPrefixOf owner || (`ZkGasStatements).isPrefixOf owner do return
  -- Generated equation lemmas, constructors, projections and recursors are allowed.
  unless (← findDeclarationRangesCore? n).isSome do return
  let some info := env.find? n | return
  let proof ← match info with
    | .thmInfo _ => pure (!env.isProjectionFn n)
    | .axiomInfo _ | .opaqueInfo _ => pure true
    | .defnInfo v => isProp v.type
    | _ => pure false
  if proof then throwError "proof declaration in definitions layer: {n}"

/-- Each headline theorem under `TaikoSpec.ZkGas.Proofs` and the statement under
`TaikoSpec.ZkGas.Statements` that must be exactly its type. -/
def headlines : List (Name × Name) :=
  [(`block_within_limit, `BlockWithinLimit),
   (`abort_contributes_nothing, `AbortContributesNothing), (`total_is_sum, `TotalIsSum),
   (`fit_commits, `FitCommits), (`branches_complete, `BranchesComplete),
   (`step_gas_monotone, `StepGasMonotone), (`spawn_only_for_spawn_ops, `SpawnOnlyForSpawnOps)]

def checkAll : CoreM Unit := do
  let env ← getEnv
  let decls := env.constants.map₁.fold (fun acc n _ => if owned env n then acc.push n else acc) #[]
  if decls.isEmpty then throwError "no package declarations imported"
  for n in decls do
    checkAxiomsOf n
    (checkDefinitionLayers n).run'
  for (thm, claim) in headlines do
    checkHeadline (`TaikoSpec.ZkGas.Proofs ++ thm) (`TaikoSpec.ZkGas.Statements ++ claim)
  checkAnchors `TaikoSpec.ZkGas.Statements.BlockWithinLimit
    [`TaikoSpec.ZkGas.meterBlock, `TaikoSpec.ZkGas.meterTx, `TaikoSpec.ZkGas.meterCharges,
     `TaikoSpec.ZkGas.Schedule.blockLimit]
  checkAnchors `TaikoSpec.ZkGas.Statements.AbortContributesNothing
    [`TaikoSpec.ZkGas.meterBlock, `TaikoSpec.ZkGas.meterBlockFrom, `TaikoSpec.ZkGas.meterTx]
  checkAnchors `TaikoSpec.ZkGas.Statements.TotalIsSum
    [`TaikoSpec.ZkGas.meterBlock, `TaikoSpec.ZkGas.meterTx, `List.sum, `List.filterMap]
  checkAnchors `TaikoSpec.ZkGas.Statements.FitCommits
    [`TaikoSpec.ZkGas.meterBlock, `TaikoSpec.ZkGas.meterBlockFrom, `TaikoSpec.ZkGas.meterTx,
     `TaikoSpec.ZkGas.meterCharges, `List.sum]
  checkAnchors `TaikoSpec.ZkGas.Statements.BranchesComplete
    [`TaikoSpec.ZkGas.allBranches, `TaikoSpec.ZkGas.BranchId]
  checkAnchors `TaikoSpec.ZkGas.Statements.StepGasMonotone
    [`TaikoSpec.ZkGas.stepOutcome, `TaikoSpec.ZkGas.classify, `TaikoSpec.ZkGas.body,
     `TaikoSpec.ZkGas.staticGas, `TaikoSpec.ZkGas.StepResult.gasAfter, `TaikoSpec.ZkGas.Pre.gas]
  checkAnchors `TaikoSpec.ZkGas.Statements.SpawnOnlyForSpawnOps
    [`TaikoSpec.ZkGas.stepOutcome, `TaikoSpec.ZkGas.callStep, `TaikoSpec.ZkGas.createStep,
     `TaikoSpec.ZkGas.StepResult.outcome, `TaikoSpec.ZkGas.Outcome.newFrame,
     `TaikoSpec.ZkGas.Schedule.spawnEstimate, `TaikoSpec.ZkGas.unzen]
  logInfo m!"audit: {decls.size} package declarations, {headlines.length} exact headlines and claim anchors OK"
end ZkGasAudit
