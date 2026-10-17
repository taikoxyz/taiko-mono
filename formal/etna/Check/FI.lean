import Etna.FI.Model
import Lean
open Lean Etna.FI

private def errorLabel : Etna.FI.Error → String
  | .missingWitness c => s!"missing-witness:{c}"
  | .unexpectedWitness => "unexpected-witness"
  | .wrongIndex e g => s!"wrong-index:{e}:{g}"
  | .tooLarge n => s!"too-large:{n}"
  | .hashMismatch => "hash-mismatch"
  | .needsSingleton => "needs-singleton"
  | .retained => "retained"
  | .cursorOverflow => "cursor-overflow"
  | .malformed => "malformed"
  | .wrongContext => "wrong-context"

private def render (f : α → String) : Except Etna.FI.Error α → String
  | .ok value => f value
  | .error error => errorLabel error

private def decisionLabel : Decision → String
  | .ordinary => "ordinary"
  | .included i => s!"included:{i}"
  | .skippedInvalid i => s!"invalid:{i}"
  | .needsSkip i => s!"needs:{i}"

private def runCase (j : Json) : Except String String := do
  let op ← j.getObjValAs? String "op"
  let args ← j.getObjValAs? (Array Json) "args"
  let n (i : Nat) : Except String Nat := args[i]!.getNat?
  let b (i : Nat) : Except String Bool := args[i]!.getBool?
  let o (i : Nat) : Except String (Option Nat) :=
    if args[i]! == Json.null then .ok none else some <$> n i
  match op with
  | "pending" => return render toString (pending (← n 0) (← n 1) (← o 2))
  | "preimage" => return render (fun _ => "ok") (checkPreimage (← n 0) (← b 1))
  | "due" => return toString (isDue (← n 0) (← n 1) (← n 2))
  | "classify" =>
    return render decisionLabel (classify ⟨← n 0, ← n 1, ← n 2, ← n 3, ← n 4,
      ← b 5, ← b 6, ← b 7⟩)
  | "resolve" =>
    let index ← n 1
    let decision ← match ← args[0]!.getStr? with
      | "ordinary" => pure Decision.ordinary
      | "included" => pure (.included index)
      | "invalid" => pure (.skippedInvalid index)
      | "needs" => pure (.needsSkip index)
      | _ => throw "invalid decision"
    let outcome ← match ← args[2]!.getStr? with
      | "empty" => pure SingletonOutcome.completedEmpty
      | "retained" => pure .retained
      | "unavailable" => pure .unavailable
      | _ => throw "invalid scalar outcome"
    return render (fun x => match x with | none => "none" | some i => s!"consumed:{i}")
      (resolve decision outcome)
  | "advance" => return render toString (advance (← n 0) (← o 1))
  | _ => throw s!"unknown operation {op}"

def main (args : List String) : IO UInt32 := do
  let path := args.headD "corpus/fi.jsonl"
  let stdout ← IO.getStdout
  for line in (← IO.FS.readFile path).splitOn "\n" do
    if !line.isEmpty then
      let j ← IO.ofExcept (Json.parse line)
      let id ← IO.ofExcept (j.getObjValAs? String "id")
      let actual ← IO.ofExcept (runCase j)
      stdout.putStrLn s!"{id}\t{actual}"
  return 0
