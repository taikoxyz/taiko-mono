import Audit
open Lean

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  let env ← importModules (ZkGasAudit.libraries.toArray.map fun module => { module }) {}
  let ctx : Core.Context := { fileName := "zk gas audit", fileMap := default }
  try
    let (_, state) ← ZkGasAudit.checkAll.toIO ctx { env }
    for msg in state.messages.toList do IO.println (← msg.toString)
    return 0
  catch e =>
    IO.eprintln (toString e)
    return 1
