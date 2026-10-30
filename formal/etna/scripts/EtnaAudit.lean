import Lean

/-! Proof-audit checks, compiled separately from the model.

This module imports only `Lean`, so instances, attributes or names declared by the Etna
libraries cannot change how the checks below elaborate. The generated `Audit.lean` imports
this library and the Etna libraries, then only calls these functions with string literals:
manifest types arrive as data and are parsed here, never pasted into Lean source. -/
namespace EtnaAudit
open Lean Elab Term Meta

def allowedAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- Parse `"a b\nc d"` rows of space-separated ASCII names (validated by the Python side). -/
def rows (data : String) : List (List Name) :=
  (data.splitOn "\n").filter (· ≠ "") |>.map fun row => (row.splitOn " ").map String.toName

/-- The package's Lake libraries (scripts/check_imports.py `LIBRARIES`); every module of the
package is one of these roots or sits under one. -/
def packageLibraries : List Name := [`EtnaModel, `EtnaStatements, `EtnaProofs, `EtnaWitnesses, `EtnaVectors]

def packageModule (m : Name) : Bool := packageLibraries.any (·.isPrefixOf m)

/-- Every constant of the imported modules selected by `select`, with its owning module. -/
def moduleConstants (env : Environment) (select : Name → Bool) : Array (ConstantInfo × Name) := Id.run do
  let mut out := #[]
  for h : idx in [0:env.header.moduleNames.size] do
    let owner := env.header.moduleNames[idx]
    if select owner then
      for info in env.header.moduleData[idx]!.constants do
        out := out.push (info, owner)
  return out

def userName (n : Name) : Name := (privateToUserName? n).getD n

/-- The one package declaration outside `Etna`: the root `main` of `EtnaVectors.Main`, which
Lake requires as the conformance-vector executable's entry point. -/
def vectorsEntryPoint (user owner : Name) : Bool := user == `main && owner == `EtnaVectors.Main

def checkAxiomsOf (n : Name) : CoreM Unit := do
  for ax in (← collectAxioms n) do
    unless allowedAxioms.contains ax do
      throwError "forbidden axioms in {n}: {ax}"

def fromComponents (cs : List Name) : Name :=
  cs.foldl (init := .anonymous) fun acc c =>
    match c with
    | .str _ s => .str acc s
    | .num _ k => .num acc k
    | .anonymous => acc

/-- Names Lean derives from a parent declaration (constructors, recursors, projections,
equation/injectivity lemmas, matchers). Their shadowing is reported on the parent. -/
def generatedChild (env : Environment) (n : Name) : Bool :=
  n.isInternalDetail || isAuxRecursor env n || isNoConfusion env n || isRecCore env n ||
    (env.getProjectionFnInfo? n).isSome || Meta.isMatcherCore env n ||
    (match env.find? n with | some (.ctorInfo _) => true | _ => false) ||
    (match n with
     | .str _ s => ["injEq", "inj", "sizeOf_spec", "ctorIdx", "toCtorIdx", "eq_def",
                    "induct", "mutual_induct", "ctorElim", "ctorElimType"].contains s
     | _ => false)

/-- Every pair `(n, m)` where source declaration `n = N ++ s` makes the name `s`, written
inside namespace `N`, resolve to `n` instead of the existing `m = N' ++ s` for a strict
prefix `N'` of `N` (including the root and its aliases). Private names count in their own
module. Lean-generated names without source ranges (recursors, `noConfusion`, matcher
equations, `below`) and helpers under instances (derived `repr`/`decEq`) are skipped;
the source lint forbids creating range-less declarations by metaprogramming. A pair
found through a generated child (constructor, projection, ...) is reported on its parent. -/
def shadowing (constants : Array (ConstantInfo × Name)) : CoreM (Array (Name × Name)) := do
  let env ← getEnv
  let aliases := getAliasState env
  let mut found : Array (Name × Name) := #[]
  for (info, owner) in constants do
    let n := info.name
    let user := userName n
    if user.hasMacroScopes || (← findDeclarationRangesCore? n).isNone then continue
    let comps := user.components
    let actual (a : Name) : Name := if isPrivateName n then mkPrivateNameCore owner a else a
    if (List.range (comps.length - 1)).any fun k =>
        Meta.isInstanceCore env (actual (fromComponents (comps.take (k + 1)))) then continue
    let resolvable (m : Name) : Bool :=
      m != user && (env.contains m || aliases.contains m || env.contains (mkPrivateNameCore owner m))
    for k in [1:comps.length] do
      for j in [0:k] do
        let m := fromComponents (comps.take j ++ comps.drop k)
        if resolvable m then
          let mut a := user
          let mut b := m
          let mut rest := comps.length - k
          while rest > 1 && generatedChild env (actual a) do
            a := a.getPrefix
            b := b.getPrefix
            rest := rest - 1
          unless found.contains (a, b) do
            found := found.push (a, b)
  return found

/-- Libraries that hold definitions and statements only (scripts/check_imports.py
`THEOREM_FREE_LIBRARIES`). -/
def definitionLibraries : List Name := [`EtnaModel, `EtnaStatements]

/-- The headline proofs' namespace and the modules that hold it. -/
def headlineNamespace : Name := `Etna.Proofs
def headlineModules : Name := `EtnaProofs.Headline

/-- A constant that proves something: a theorem other than a structure projection, an axiom,
an `opaque` constant, or a definition whose type is a proposition. -/
def proofLike (info : ConstantInfo) : MetaM Bool := do
  match info with
  | .thmInfo _ => return !(← getEnv).isProjectionFn info.name
  | .axiomInfo _ | .opaqueInfo _ => return true
  | .defnInfo v => isProp v.type
  | _ => return false

def kindName : ConstantInfo → String
  | .thmInfo _ => "theorem" | .axiomInfo _ => "axiom" | .opaqueInfo _ => "opaque constant"
  | .defnInfo _ => "definition" | .inductInfo _ => "inductive type" | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor" | .quotInfo _ => "quotient constant"

/-- What each library may hold, on the built declarations. A source declaration is one with a
declaration range; the ones Lean generates (equation, injectivity and `sizeOf` lemmas,
`_proof_N`, matchers, recursors) have none, and the source lint rejects every command that
could add a declaration by metaprogramming.
- `Etna.Proofs` (the headline proofs) lives in `EtnaProofs.Headline`.
- EtnaModel and EtnaStatements hold no proofs: no source theorem (apart from `modelTheorems`,
  scripts/check_imports.py `ALLOWED_MODEL_THEOREMS`), axiom, `opaque` constant or definition of a
  proof (`proofLike`). `def P : Prop` predicates, inductive predicates and Prop structures with
  their constructors and projections are definitions.
- EtnaProofs holds theorems: every other source declaration there is private (a proof helper);
  public definitions belong in EtnaModel or EtnaStatements. -/
def checkLibraryContents (constants : Array (ConstantInfo × Name)) (modelTheorems : List Name) :
    CoreM Unit := do
  for (info, owner) in constants do
    let n := info.name
    let user := userName n
    if headlineNamespace.isPrefixOf user && !headlineModules.isPrefixOf owner then
      throwError "{n} in {owner}: the {headlineNamespace} namespace (the headline proofs) lives in \
        {headlineModules}"
    unless (← findDeclarationRangesCore? n).isSome do continue
    if definitionLibraries.any (·.isPrefixOf owner) then
      if !modelTheorems.contains user && (← (proofLike info).run') then
        throwError "{kindName info} {n} in {owner}: EtnaModel and EtnaStatements hold definitions, \
          not proofs; move it to EtnaProofs, or list a theorem a definition needs in \
          ALLOWED_MODEL_THEOREMS (scripts/check_imports.py)"
    else if (`EtnaProofs).isPrefixOf owner && !info.isTheorem && !isPrivateName n then
      throwError "public {kindName info} {n} in {owner}: EtnaProofs holds theorems and private \
        helpers; public definitions belong in EtnaModel or EtnaStatements"

/-- Package-wide checks. `manifest` rows are `declaration module`; `allowlist` rows are
`shadower shadowed` reviewed pairs from `manifests/shadowing-allowlist.json`; `modelTheorems`
lists the theorems EtnaModel/EtnaStatements may hold (`checkLibraryContents`). -/
def checkPackage (manifest allowlist modelTheorems : String) : CoreM Unit := do
  let env ← getEnv
  let constants := moduleConstants env packageModule
  let expected := (rows manifest).filterMap fun
    | [d, m] => some (d, m)
    | _ => none
  -- 1. Package names live under `Etna`, except the vector executable's `main`: nothing can be
  -- injected into other namespaces.
  for (info, owner) in constants do
    let user := userName info.name
    unless (`Etna).isPrefixOf user || user.isInternal || vectorsEntryPoint user owner do
      throwError "declaration {info.name} in {owner} is outside the Etna namespace"
  -- 2. Every manifest entry names its true owning module.
  for (d, m) in expected do
    match env.getModuleIdxFor? d with
    | some idx =>
      let owner := env.header.moduleNames[idx.toNat]!
      unless owner == m do
        throwError "manifest module mismatch: {d} is declared in {owner}, manifest says {m}"
    | none => throwError "manifest module mismatch: {d} is not an imported declaration"
  -- 3. Axioms of every package constant.
  for (info, _) in constants do
    checkAxiomsOf info.name
  -- 4. Name shadowing must be exactly the reviewed allowlist.
  let allowed := (rows allowlist).filterMap fun
    | [a, b] => some (a, b)
    | _ => none
  let found ← shadowing constants
  let new := found.toList.filter (!allowed.contains ·)
  let stale := allowed.filter (!found.contains ·)
  let render (pairs : List (Name × Name)) : String :=
    ", ".intercalate (pairs.map fun (a, b) => s!"{a} -> {b}")
  unless new.isEmpty && stale.isEmpty do
    throwError "name shadowing differs from manifests/shadowing-allowlist.json; \
      unreviewed name shadowing (declaration -> shadowed name): [{render new}]; \
      stale shadowing allowlist entries: [{render stale}]"
  -- 5. What each library may hold.
  checkLibraryContents constants (rows modelTheorems).flatten
  -- 6. Every public source theorem is manifested.
  for (info, owner) in constants do
    let n := info.name
    if info.isTheorem && !isPrivateName n && !env.isProjectionFn n then
      if (← findDeclarationRangesCore? n).isSome then
        unless expected.contains (n, owner) do
          throwError "unmanifested public theorem {n} in {owner}"

/-- Atoms that run tactics/elaborators, echo other terms' types or skip proofs. `%`
alone is the modulo operator; `foo%` elaborators such as `type_of%` are rejected. -/
partial def forbiddenAtom? : Syntax → Option String
  | .atom _ val =>
    if (val.length > 1 && val.endsWith "%") ||
        ["by", "‹", "›", "sorry", "admit", "from", "by_elab", "unsafe", "do"].contains val then
      some val
    else none
  | .node _ _ args => args.findSome? forbiddenAtom?
  | _ => none

partial def identifiers : Syntax → Array Name
  | .ident _ _ val _ => #[val]
  | .node _ _ args => args.foldl (fun acc a => acc ++ identifiers a) #[]
  | _ => #[]

/-- Drop positions taken from the manifest string so diagnostics point at the audit call. -/
partial def stripInfo : Syntax → Syntax
  | .atom _ val => .atom .none val
  | .ident _ raw val pre => .ident .none raw val pre
  | .node _ kind args => .node .none kind (args.map stripInfo)
  | .missing => .missing

/-- Erase every metadata node, at any depth. -/
partial def eraseMData (e : Expr) : Expr :=
  e.replace fun
    | .mdata _ b => some (eraseMData b)
    | _ => none

/-- Rule P view of a statement: metadata erased, head beta-reduced and `let`s inlined, so
`(fun _ => C) x` or `let y := x; C` cannot pass as a use of `x`. -/
partial def ruleView (e : Expr) : Expr :=
  match (eraseMData e).headBeta with
  | .letE _ _ value body _ => ruleView (body.instantiate1 value)
  | e => e

/-- The statement layer's namespace and library: the premise record and the headline claims. -/
def statementNamespace : Name := `Etna.Statements
def statementLibrary : Name := `EtnaStatements

/-- A statement-layer definition: named under `Etna.Statements` and declared in an
EtnaStatements module (a definition of that name anywhere else is not one). -/
def statementDefinition (c : Name) : CoreM Bool := do
  let env ← getEnv
  let some idx := env.getModuleIdxFor? c | return false
  return statementNamespace.isPrefixOf c && statementLibrary.isPrefixOf env.header.moduleNames[idx.toNat]!

/-- `ruleView`, with a statement-layer definition (`statementDefinition`) at the head read as
its body (unfolded and beta-reduced, repeatedly). A headline theorem is stated as its claim's
name, so the claim's own binders and conclusion are what Rule P and the `constant` role check;
the result is the same as writing the body inline. Other definitions stay folded. -/
partial def statementView (e : Expr) : MetaM Expr := do
  let e := ruleView e
  if let .const c us := e.getAppFn then
    if ← statementDefinition c then
      if let some (.defnInfo v) := (← getEnv).find? c then
        return ← statementView ((v.value.instantiateLevelParams v.levelParams us).beta e.getAppArgs)
  return e

/-- Rule P trivial atoms: `True`, and `a = a`, `a ↔ a`, `HEq a a` with syntactically
identical sides. -/
def triviallyTrue (e : Expr) : Bool :=
  match e.getAppFnArgs with
  | (``True, #[]) => true
  | (``Eq, #[_, a, b]) | (``Iff, #[a, b]) | (``HEq, #[_, a, _, b]) => a == b
  | _ => false

/-- Rule P on a conclusion: `a ∧ b` and `a ∨ b` split into both sides, `∃ y, body` into
`body` (`y` is not an outer binder), anything else (including `↔`) is an atom. Every atom
must mention an outer binder and must not be trivially true. -/
partial def checkConclusion (decl : Name) (outer : Array FVarId) (e : Expr) : MetaM Unit := do
  let e ← statementView (← instantiateMVars e)
  match e.getAppFnArgs with
  | (``And, #[a, b]) | (``Or, #[a, b]) =>
    checkConclusion decl outer a
    checkConclusion decl outer b
  | (``Exists, #[_, .lam n t body bi]) =>
    withLocalDecl n bi t fun y => checkConclusion decl outer (body.instantiate1 y)
  | _ =>
    unless outer.any e.containsFVar do
      throwError "role property requires every conclusion atom to use a leading bound variable: \
        {decl}: atom `{e}` uses none (use constant/supporting/regression, or restate without it)"
    if triviallyTrue e then
      throwError "role property requires every conclusion atom to be non-trivial: {decl}: \
        atom `{e}` is trivially true (use constant/supporting/regression, or restate without it)"

/-- Rule P: strip every leading `∀`/hypothesis arrow (the outer binders), then check the
conclusion with `checkConclusion`. A statement without leading binders has no atom that
can use one, so it fails too. Both read statement-layer definitions as their bodies
(`statementView`). -/
partial def checkProperty (decl : Name) (e : Expr) (outer : Array FVarId := #[]) : MetaM Unit := do
  match ← statementView e with
  | .forallE n t body bi =>
    withLocalDecl n bi t fun x => checkProperty decl (body.instantiate1 x) (outer.push x.fvarId!)
  | body => checkConclusion decl outer body

/-- An inductive type with a recursive constructor (`InductiveVal.isRec`). -/
def recursiveInductive (env : Environment) (t : Name) : Bool :=
  match env.find? t with
  | some (.inductInfo v) => v.isRec
  | _ => false

/-- An induction principle used directly in a proof term: `T.rec`/`T.recOn`/`T.brecOn`/
`T.binductionOn` (and the `_N` variants of nested inductives) for a recursive inductive `T`;
an `@[induction_eliminator]` for a recursive type (the `induction` tactic elaborates `Nat`
induction to `Nat.recAux`, not `Nat.rec`); a functional-induction principle generated for a
recursive definition (`f.induct`, `f.induct_unfolding`, `f.mutual_induct`); or well-founded
recursion. Recursors of non-recursive types (`Eq`, `And`, `Or`, `Exists`, `Bool`, `Option`,
`Decidable`, structures), `casesOn`, `cases_eliminator`s and `match_` helpers are case
splits, not induction. -/
def inductionPrinciple (env : Environment) (c : Name) : Bool :=
  [``WellFounded.fix, ``WellFounded.fixF, ``WellFounded.induction, ``WellFounded.Nat.fix].contains c ||
    Tactic.FunInd.isFunInductName env c ||
    (Meta.customEliminatorExt.getState env).map.toList.any (fun ((induction, types), elim) =>
      induction && elim == c && types.any (recursiveInductive env)) ||
    match c with
    | .str t s =>
      let recursor := ["rec", "recOn", "brecOn", "binductionOn"].any fun r =>
        s == r || (s.startsWith (r ++ "_") && (s.drop (r.length + 1)).all Char.isDigit)
      recursor && recursiveInductive env t
    | _ => false

/-- Whether `d` is a theorem of an Etna library module written in the source (it has a
declaration range, private ones included) or an auxiliary proof Lean split off such a theorem
(`thm._proof_N`, `thm._simp_N`). Range-less lemmas Lean generates for a definition
(`eq_def`, `eq_N`, matcher equations and splitters, a `def`'s `_proof_N`, constructor
injectivity, `brecOn` of an inductive predicate) belong to that definition: an equation
lemma of a structurally recursive `f` is proved from `f`'s compiled `brecOn`, so entering it
would make `unfold f` count as induction. -/
partial def sourceTheorem (d : Name) : CoreM Bool := do
  let env ← getEnv
  let some (.thmInfo _) := env.find? d | return false
  let some idx := env.getModuleIdxFor? d | return false
  unless packageModule env.header.moduleNames[idx.toNat]! do return false
  if (← findDeclarationRangesCore? d).isSome then return true
  match d with
  | .str p _ | .num p _ => sourceTheorem p
  | .anonymous => return false

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

/-- `derived(c)`: the chain `[c, d₁, …, p]` when the proof term of `c` uses an induction
principle `p` directly, or uses an Etna source theorem `d₁` (`sourceTheorem`) that is itself
derived. A constant counts as used only if it is still in the term after `liveProof`, so a
dead `have _ := lemma` (or a `let`, `letFun` or beta-redex whose variable is never used)
cannot make a proof derived; the same holds for every private or `_proof_N` theorem the
search enters. Only theorem proof terms are read: definitions (with their generated
lemmas), instances and library (non-Etna) lemmas are not entered, so a core lemma proved by
induction does not make its user derived. Memoized in the state.

Limit: this is a syntactic test. A live but irrelevant use of an induction lemma (for
example `pad_zero n ▸ h`, or an argument a function ignores) still counts as derived, so
the audit records each property's chain for human review. -/
partial def derivation (c : Name) : StateT (NameMap (Option (List Name))) CoreM (Option (List Name)) := do
  if let some known := (← get).find? c then return known
  modify (·.insert c none)
  let env ← getEnv
  let used := match env.find? c with
    | some (.thmInfo v) => (liveProof v.value).getUsedConstants
    | _ => #[]
  let mut result := (used.find? (inductionPrinciple env)).map ([c, ·])
  if result.isNone then
    for d in used do
      if d != c && (← sourceTheorem d) then
        if let some chain ← derivation d then
          result := some (c :: chain)
          break
  modify (·.insert c result)
  return result

def renderChain (chain : List Name) : String := " -> ".intercalate (chain.map toString)

/-- Exact-type, axiom and mechanical-role check for one manifest entry. Runs inside the
theorem's namespace, so the manifest type resolves names as the source statement does.
Roles: `property` iff Rule P (`checkProperty`) holds and the proof is derived
(`derivation`); a `supporting` entry must fail one of the two, so both labels are
mechanical in both directions. A `property` entry reports its chain as an info message
`derivation chain: c -> … -> p`, which the audit records for review. `constant` must have
no leading binder, read through `statementView` (a theorem stated as a bare claim name is
judged on the claim's body); `regression` carries no shape requirement. Only `property` backs
claims. -/
def checkContract (declaration role source : String) : TermElabM Unit := do
  let decl := declaration.toName
  let info ← getConstInfo decl
  unless info.isTheorem do throwError "expected theorem declaration: {decl}"
  checkAxiomsOf decl
  -- Layout-sensitive terms (`let x := v⏎ body`) read the first line at the continuation
  -- lines' indentation, as the statement sits in its source file.
  let rest := (source.splitOn "\n").drop 1 |>.map (·.toList) |>.filter (!·.all (· == ' '))
  let indent := (rest.map fun l => (l.takeWhile (· == ' ')).length).min?.getD 0
  let stx ← match Parser.runParserCategory (← getEnv) `term ("".pushn ' ' indent ++ source) with
    | .ok stx => pure (stripInfo stx)
    | .error msg => throwError "manifest type of {decl} is not exactly one Lean term: {msg}"
  if let some bad := forbiddenAtom? stx then
    throwError "manifest type of {decl} uses forbidden syntax `{bad}`"
  for id in identifiers stx do
    for (target, _) in (← resolveGlobalName id) do
      if target == decl then
        throwError "manifest type of {decl} refers to the theorem itself"
  let expected ← withoutErrToSorry do
    let e ← elabType stx
    synthesizeSyntheticMVarsNoPostponing
    instantiateMVars e
  if expected.hasMVar || expected.hasSorry then throwError "unresolved manifest type: {decl}"
  if expected.getUsedConstants.contains decl then
    throwError "manifest type of {decl} refers to the theorem itself"
  unless ← isDefEq info.type expected do throwError "full theorem type mismatch: {decl}"
  match role with
  | "property" =>
    checkProperty decl info.type
    let some chain ← (derivation decl).run' {} |
      throwError "role property requires a derived proof: {decl}: not derived: the proof, without \
        unused `have`/`let` bindings, uses no induction principle and no derived Etna theorem \
        (use supporting)"
    logInfo m!"derivation chain: {renderChain chain}"
  | "supporting" =>
    if let some chain ← (derivation decl).run' {} then
      if ← (try checkProperty decl info.type; pure true catch _ => pure false) then
        throwError "role supporting is wrong for a derived Rule P statement: {decl}: derived via \
          {renderChain chain} and passes Rule P (use property)"
  | "constant" =>
    if (← statementView info.type).isForall then
      throwError "role constant requires a closed statement without leading binders: {decl}"
  | "regression" => pure ()
  | _ => throwError "unknown role {role}: {decl}"

/-- Every constant reachable from `todo` through the types of the constants it meets, the values
of definitions and the constructors of inductive types. Only constants whose root namespace is
in `roots` are entered; the others are recorded but not expanded. -/
partial def dependencies (roots : List Name) (todo : List Name) (seen : NameSet := {}) : CoreM NameSet := do
  match todo with
  | [] => return seen
  | c :: rest =>
    if seen.contains c then
      dependencies roots rest seen
    else
      let next := match (← getEnv).find? c with
        | some info =>
          if roots.contains c.getRoot then
            let extra := match info with
              | .defnInfo v => v.value.getUsedConstants
              | .inductInfo v => v.ctors.toArray
              | _ => #[]
            (info.type.getUsedConstants ++ extra).toList
          else []
        | none => []
      dependencies roots (next ++ rest) (seen.insert c)

/-- Shape of one statement-layer claim (tests/test_statements.py): `claim` is a documented
`Prop` definition whose definitions (under its own root namespace and `Etna`) reach every name in
`required`, and every field of the premise structure `premises` is documented and is not `True`
(after unfolding definitions to weak head normal form). All problems are reported together. -/
def checkStatement (claim premises required : String) : MetaM Unit := do
  let env ← getEnv
  let claim := claim.toName
  let premises := premises.toName
  let mut problems : Array String := #[]
  match env.find? claim with
  | some (.defnInfo v) =>
    unless v.type.isProp do problems := problems.push s!"{claim} is not a Prop"
  | _ => throwError "statement check: {claim} is not a definition"
  if (← findDocString? env claim).isNone then problems := problems.push s!"{claim} has no docstring"
  let reached ← dependencies [claim.getRoot, premises.getRoot, `Etna] [claim]
  for n in (rows required).flatten do
    unless reached.contains n do problems := problems.push s!"{claim} does not depend on {n}"
  match getStructureInfo? env premises with
  | none => problems := problems.push s!"{premises} is not a structure"
  | some info =>
    for field in info.fieldNames do
      let projection := premises ++ field
      match env.find? projection with
      | none => problems := problems.push s!"premise field {field} has no projection"
      | some projectionInfo =>
        let vacuous ← forallTelescope projectionInfo.type fun _ body => do
          return (← whnf body).isConstOf ``True
        if vacuous then problems := problems.push s!"premise field {field} is `True`"
        if (← findDocString? env projection).isNone then
          problems := problems.push s!"premise field {field} has no docstring"
  unless problems.isEmpty do
    throwError "statement check failed: {"; ".intercalate problems.toList}"

/-- The headline layer. Each row `theorem claim` names a theorem whose type is exactly the
statement-layer claim `claim`, the constant itself (no binder, conjunct or disjunct added or
dropped, nothing unfolded), and whose axioms are the standard three. -/
def checkHeadline (headlines : String) : CoreM Unit := do
  for row in rows headlines do
    let [thm, claim] := row | throwError "invalid headline row {row}"
    let some info := (← getEnv).find? thm | throwError "missing headline theorem {thm} : {claim}"
    unless info.isTheorem do throwError "headline {thm} is not a theorem"
    unless info.type.isConstOf claim do
      throwError "headline theorem {thm} must have exactly type {claim}, not {info.type}"
    checkAxiomsOf thm

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

/-- Fields of structure `s` read by the proof of `c` or by an Etna source theorem it uses
(`sourceTheorem`), every proof read without unused bindings (`liveProof`). Like `derivation`,
definitions and library lemmas are not entered. A field taken apart by a pattern match
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
    if d != c && (← sourceTheorem d) then
      for f in ← premiseReads s fields d do
        unless out.contains f do out := out.push f
  modify (·.insert c out)
  return out

/-- Every field of the premise structure `premises` is read by the proof of at least one of
`theorems` (newline-separated), through the Etna source theorems it uses (`premiseReads`):
a premise no headline proof needs is an assumption the claims do not rest on. Logs one
`premise use: field <- theorem …` line per read field, in field order, then fails naming
every unread field. -/
def checkPremiseUse (premises theorems : String) : CoreM Unit := do
  let s := premises.toName
  let some info := getStructureInfo? (← getEnv) s | throwError "premise use: {s} is not a structure"
  let names := (rows theorems).flatten
  let reads ← (names.mapM fun t => return (t, ← premiseReads s info.fieldNames t)).run' {}
  let mut unread := #[]
  for f in info.fieldNames do
    let readers := reads.filter (·.2.contains f) |>.map (·.1.toString)
    if readers.isEmpty then unread := unread.push f
    else logInfo m!"premise use: {f} <- {" ".intercalate readers}"
  unless unread.isEmpty do
    throwError "premise fields of {s} read by no headline proof (after unused bindings are removed): \
      {unread.toList}; every premise must be needed by one of {names}"

/-- Kernel-replayed Lean regression modules may use only the standard axioms. -/
def checkTestModules (pre : String) : CoreM Unit := do
  let constants := moduleConstants (← getEnv) pre.toName.isPrefixOf
  for (info, _) in constants do
    checkAxiomsOf info.name
  if constants.isEmpty then throwError "no regression declarations found under {pre}"

end EtnaAudit
