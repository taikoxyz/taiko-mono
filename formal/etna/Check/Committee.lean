import Etna.Committee.Transition
import Lean
open Lean Etna.Committee
private def opt : Option Nat → String | none => "none" | some n => toString n
private def scheduleError : ScheduleError → String
  | .tooShort => "too-short" | .shorterThanCap => "shorter-than-cap" | .zeroL1 => "zero-l1"
  | .firstHeight => "height-range" | .firstAnchor => "anchor-range"
private def failure : Failure → String
  | .unknown t => s!"unknown:{t}" | .conflict t => s!"conflict:{t}" | _ => "adapter-error"
private def planLabel (p : Plan) : String :=
  let sw := match p.switch with | none => "none" | some s => s!"{s.outgoing}:{s.incoming}:{s.pruneBefore}"
  s!"{opt p.insertEpoch}/{sw}"
private def runCase (j : Json) : Except String String := do
  let op ← j.getObjValAs? String "op"
  let args ← j.getObjValAs? (Array Json) "args"
  let n (i : Nat) := args[i]!.getNat?
  if op = "quorum" then return toString (decide (3*(← n 0) > 2*(← n 1)))
  if op = "committee-size" then return toString (committeeSizeBounded (← n 0))
  if op = "positive-cap" then return toString (positiveCap (← n 0) (← n 1))
  let s : Schedule := ⟨← n 0, ← n 1, ← n 2, ← n 3⟩
  let x ← n 4
  match op with
  | "validate" => return match validate s x with | .ok _ => "ok" | .error e => scheduleError e
  | "anchor" => return match anchorProgress s x (← n 5) (← n 6) with
    | .ok _ => "ok" | .error .regressed => "regressed" | .error .beforeActivation => "before-activation"
    | .error .invalidSchedule => "invalid-schedule" | .error (.epochNotOpen epoch minimum) => s!"not-open:{epoch}:{minimum}"
  | "urgency" => return (forceEpoch s x (← n 5)).map toString |>.getD "none"
  | "epoch" => return opt (epochOf s x)
  | "first" => return opt (first s x)
  | "last" => return opt (last s x)
  | "l1" => return opt (l1First s x)
  | "parent" => return opt (parentHeight s x)
  | "starting" => return opt (startingAt s x)
  | "switch" => return opt (switchTarget s x)
  | "next" => return opt (nextSwitch s x)
  | "plan" =>
    let epoch ← n 6
    let relation ← match ← args[5]!.getStr? with
      | "none" => pure Relation.none | "absent" => pure (.absent epoch)
      | "equal" => pure (.equal epoch) | "conflict" => pure (.conflict epoch)
      | _ => throw "invalid relation"
    return match plan s x relation (← args[7]!.getBool?) (← args[8]!.getBool?) with
      | .ok p => planLabel p | .error e => failure e
  | _ => throw "unknown operation"
def main (args : List String) : IO UInt32 := do
  let stdout ← IO.getStdout
  for line in (← IO.FS.readFile (args.headD "corpus/committee.jsonl")).splitOn "\n" do
    if !line.isEmpty then
      let j ← IO.ofExcept (Json.parse line)
      let id ← IO.ofExcept (j.getObjValAs? String "id")
      let actual ← IO.ofExcept (runCase j)
      stdout.putStrLn s!"{id}\t{actual}"
  return 0
