import EtnaModel.ProtocolState

/-! Section 6.4 back-pressure accounting. A block's anchor proves an L1 checkpoint height,
and the block may be at most `unsettled` (U) blocks above it (3.4 rule 8, `AnchorValid`).
6.4 says this anchor-based count never undercounts the unsettled blocks, except for the
section 8 verifier-failure rollback. `OrdinaryTrace` names the traces without that
exception; it introduces no new transition. -/
namespace Etna.Design.ProtocolState

/-- An original transaction other than verifier-failure rollback, told apart by the operation
and not by its result: each constructor takes exactly the premises of the `Step` constructor of
the same name. An owner nonce invalidation stays ordinary even when its result equals a
rollback that keeps the current checkpoint and snapshot. -/
inductive OrdinaryStep : World → World → Prop
  | landing {w : World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (time : w.l1Block ≤ e.blockNumber) (ok : Etna.Design.land w.inbox i leaves e = some s) :
      OrdinaryStep w (landed w s e.blockNumber)
  | registration {w : World} {s : RegistryHistory.State} {key owner amount now : Nat}
      (time : w.l1Block ≤ now) (ok : RegistryHistory.register w.registry key owner amount now = some s) :
      OrdinaryStep w (registered w s now)
  | modification {w : World} {s : RegistryHistory.State} {id now : Nat} {action : RegistryHistory.Edit}
      (time : w.l1Block ≤ now) (callable : publicEdit action = true)
      (ok : RegistryHistory.edit w.registry w.inbox id now action = some s) : OrdinaryStep w (registered w s now)
  | enqueue {w : World} {s : State} {hash timestamp now raw paid : Nat} {refund : Bool}
      (time : w.l1Block ≤ now) (blockRange : now < limit48) (timestampRange : timestamp < limit48)
      (ok : Forced.enqueue w.inbox raw paid refund = some s) : OrdinaryStep w (enqueued w s hash timestamp now)
  | sweep {w : World} {s : State} {now : Nat} {transfer : Bool}
      (time : w.l1Block ≤ now) (ok : Forced.sweep w.inbox transfer = some s) : OrdinaryStep w (landed w s now)
  | recovery {w : World} {s : Recovery.World} {a : Recovery.Request} {r : Origin}
      {owner externalOK : Bool} (time : w.l1Block ≤ r.l1Block)
      (ok : Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK = some s) :
      OrdinaryStep w (recovered w a r s)
  | invalidation {w : World} {s : State} {expected now : Nat} {owner : Bool}
      (time : w.l1Block ≤ now)
      (ok : Recovery.invalidateRecoveryNonce w.inbox expected owner = some s) : OrdinaryStep w (landed w s now)

/-- A trace with no verifier-failure rollback edge: every edge is an `OrdinaryStep`. -/
inductive OrdinaryTrace : World → World → Prop
  | refl (w : World) : OrdinaryTrace w w
  | step {first w t : World} (prior : OrdinaryTrace first w) (change : OrdinaryStep w t) :
      OrdinaryTrace first t

end Etna.Design.ProtocolState
