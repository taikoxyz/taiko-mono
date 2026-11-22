import EtnaModel.L2Staking

open Etna.Design (limit256)
open Etna.Design.L2Staking

namespace L2StakingTests

-- Small balances keep the seat and rounding cases readable. Validate deployment units separately.
def config : Config := ⟨2, 10, 3, 2, 2000, 5, 2000, 99, 9, 2500⟩
def deployment : Config :=
  { config with minStake := 10^27 / 2, vpUnit := 867361738, withdrawalDelay := 12 }

example : deployment.valid 5 5 = true := by decide +kernel
example : deployment.valid 5 6 = false := by decide +kernel
example : ({ deployment with minStake := deployment.minStake - 1 }).valid 5 5 = false :=
  by decide +kernel

def auth : Adapters :=
  { registerOK := fun caller _ proof ↦ caller == proof
    recoverVote := fun _ sig ↦ some sig
    transfersOK := fun _ ↦ true }

def rejectTransfers : Adapters := { auth with transfersOK := fun _ ↦ false }

def atBlock (height caller : Nat) : Context := ⟨height, 100 + height, caller, false⟩

def after (s : State) (ctx : Context) (act : Action) : State :=
  ((execute s auth ctx act).map Result.state).getD s

def vacant : State := State.empty config
def keyA : Key := ⟨101, 2, 1001⟩
def keyB : Key := ⟨102, 3, 1002⟩
def keyC : Key := ⟨103, 2, 1003⟩
def first : State := after vacant (atBlock 18 1) (.register keyA 11 1)
def both : State := after first (atBlock 18 2) (.register keyB 27 2)

-- Id/seat zero is present. Rejected registrations consume neither a seat nor an identity.
example : (execute vacant auth (atBlock 18 1) (.register keyA 11 1)).bind Result.registeredId =
    some 0 := by decide +kernel
example : (bondForKey both 101, seatOfBond both 0, bondInSeat both 0) =
    (some 0, some 0, some 0) := by decide +kernel
example : (bondForKey both 103, seatOfBond both 2, bondInSeat both 2) =
    (none, none, none) := by decide +kernel
example : execute vacant auth (atBlock 18 1) (.register keyA 9 1) = none := by decide +kernel
example : execute vacant auth (atBlock 18 1) (.register keyA 11 2) = none := by decide +kernel
example : execute vacant rejectTransfers (atBlock 18 1) (.register keyA 11 1) = none :=
  by decide +kernel
example : execute first auth (atBlock 18 2) (.register keyA 11 2) = none := by decide +kernel
example : execute both auth (atBlock 18 3) (.register keyC 11 3) = none := by decide +kernel
example : execute vacant auth (atBlock 18 0) (.requestExit 0) = none := by decide +kernel
example : execute both auth (atBlock noExit 1) (.requestExit 0) = none := by decide +kernel

def start (s : State) (height bitmap : Nat) : State :=
  onBlockStart s height systemCaller 2 bitmap true

def misses (s : State) (seat : Nat) : Option Nat := (liveSeat s seat).map LiveSeat.misses
def balance (s : State) (id : Nat) : Option Nat := (bondAt s id).map Bond.effStake

-- Both seats miss once, then one reset branch and one penalty branch from that same parent.
def firstMiss : State := start both 20 (2^127 + 3)
def restoredSignature : State := start firstMiss 21 2
def penalized : State := start firstMiss 21 3

example : (misses firstMiss 0, misses firstMiss 1, misses firstMiss 127) =
    (some 1, some 1, none) := by decide +kernel
example : (firstMiss.snapshot.height, firstMiss.snapshot.totalStake, firstMiss.generation) =
    (20, 38, 2) := by decide +kernel
example : firstMiss.snapshot.members = [(0, ⟨2, 1001, 3⟩), (1, ⟨3, 1002, 9⟩)] := by decide +kernel
example : (balance restoredSignature 0, misses restoredSignature 0) = (some 11, some 0) :=
  by decide +kernel
example : (balance penalized 0, seatForKey penalized 101,
    (bondAt penalized 0).map Bond.exitHeight) = (some 8, none, some noExit) := by decide +kernel
example : (balance penalized 1, seatForKey penalized 102, misses penalized 1) =
    (some 21, some 1, some 0) := by decide +kernel
example : (blockStartTransition firstMiss 21 systemCaller 2 3 true).map Result.transfers =
    some [.pay 99 3, .pay 99 6] := by decide +kernel
example : (penalized.snapshot.height, penalized.snapshot.totalStake,
    penalized.snapshot.seats.length, penalized.snapshot.seats[0]?, penalized.snapshot.seats[127]?) =
    (21, 21, 128, some none, some none) := by decide +kernel
example : penalized.snapshot.members = [(1, ⟨3, 1002, 7⟩)] := by decide +kernel
example : onBlockStart firstMiss 21 systemCaller 3 3 false = firstMiss := by decide +kernel
example : onBlockStart firstMiss 21 1 3 3 true = firstMiss := by decide +kernel

-- Topping up an occupied seat keeps its miss count. A seatless bond readmits only at the
-- minimum and needs a vacancy in that same call. The new occupant starts at zero misses.
def occupiedTopUp : State := after firstMiss (atBlock 20 2) (.topUp 1 3)
def shortTopUp : State := after penalized (atBlock 21 1) (.topUp 0 1)
def reseated : State := after shortTopUp (atBlock 21 1) (.topUp 0 1)
def filled : State := after penalized (atBlock 21 3) (.register keyC 11 3)

example : (balance occupiedTopUp 1, misses occupiedTopUp 1) = (some 30, some 1) := by decide +kernel
example : occupiedTopUp.snapshot = firstMiss.snapshot := by decide +kernel
example : (balance shortTopUp 0, seatForKey shortTopUp 101) = (some 9, none) := by decide +kernel
example : (seatForKey reseated 101, bondInSeat reseated 0, misses reseated 0) =
    (some 0, some 0, some 0) := by decide +kernel
example : reseated.snapshot = penalized.snapshot := by decide +kernel
example : (start reseated 22 0).snapshot.members =
    [(0, ⟨2, 1001, 3⟩), (1, ⟨3, 1002, 7⟩)] := by decide +kernel
example : (bondForKey filled 103, seatForKey filled 103, misses filled 0) =
    (some 2, some 0, some 0) := by decide +kernel
example : execute filled auth (atBlock 21 1) (.topUp 0 2) = none := by decide +kernel
example : execute penalized auth (atBlock 21 2) (.topUp 0 2) = none := by decide +kernel
example : execute penalized auth (atBlock 21 1) (.topUp 0 limit256) = none := by decide +kernel

-- Exit releases a live seat immediately. Its stale snapshot survives the block's calls.
-- Positive principal requires the owner after the full delay, and the key remains reserved.
def exited : State := after penalized (atBlock 21 2) (.requestExit 1)
def withdrawn : State := after exited (atBlock 26 2) (.withdraw 1 4)

example : (seatOfBond exited 1, bondInSeat exited 1, exited.snapshot) =
    (none, none, penalized.snapshot) := by decide +kernel
example : ((start exited 22 2).snapshot.members, misses (start exited 22 2) 1) =
    ([], none) := by decide +kernel
example : execute exited auth (atBlock 22 2) (.topUp 1 1) = none := by decide +kernel
example : execute exited auth (atBlock 25 2) (.withdraw 1 4) = none := by decide +kernel
example : execute exited auth (atBlock 26 4) (.withdraw 1 4) = none := by decide +kernel
example : (execute exited auth (atBlock 26 2) (.withdraw 1 4)).map Result.transfers =
    some [.pay 4 21] := by decide +kernel
example : bondAt withdrawn 1 = some {
    key := keyB, owner := 0, effStake := 0, exitHeight := 21, withdrawn := true } :=
  by decide +kernel
example : bondForKey withdrawn 102 = some 1 := by decide +kernel
example : execute withdrawn auth (atBlock 26 2) (.register keyB 11 2) = none := by decide +kernel

-- Evidence may be historical. The part-set header is part of the signed block identity.
def voteA : Vote := ⟨2, 18, 1, ⟨71, 2, 72⟩, -1, 10, 1⟩
def voteB : Vote := { voteA with blockId := ⟨71, 3, 72⟩ }
def slashed : State := after firstMiss (atBlock 20 1) (.slashDoubleSign 0 voteA voteB 101 101)

example : execute firstMiss auth (atBlock 20 1) (.slashDoubleSign 0 voteA voteB 101 102) =
    none := by decide +kernel
example : execute firstMiss auth (atBlock 20 1) (.slashDoubleSign 0 voteA voteB 102 102) =
    none := by decide +kernel
example : doubleSign firstMiss auth 0 { voteA with generation := 3 }
    { voteB with generation := 3 } 101 101 = false := by decide +kernel
example : doubleSign firstMiss auth 0 voteA { voteA with timestampSeconds := 0 } 101 101 =
    false := by decide +kernel
example : (execute firstMiss auth (atBlock 20 1) (.slashDoubleSign 0 voteA voteB 101 101)).map
    Result.transfers = some [.pay 1 2, .pay 99 9] := by decide +kernel
example : (balance slashed 0, seatOfBond slashed 0, slashed.snapshot) =
    (some 0, none, firstMiss.snapshot) := by decide +kernel
example : (execute slashed auth (atBlock 25 7) (.withdraw 0 4)).map Result.transfers = some [] :=
  by decide +kernel

-- The DAO acts on the balance at execution, including a top-up, and keeps an earlier exit.
def topped : State := after firstMiss (atBlock 20 2) (.topUp 1 4)
def earlierExit : State := after topped (atBlock 21 2) (.requestExit 1)
def forfeiture : Action := .forfeit 1 200 124
def forfeited : State := after earlierExit (atBlock 24 9) forfeiture

example : execute earlierExit auth (atBlock 24 2) forfeiture = none := by decide +kernel
example : execute earlierExit auth (atBlock 25 9) forfeiture = none := by decide +kernel
example : execute earlierExit rejectTransfers (atBlock 24 9) forfeiture = none := by decide +kernel
example : execute earlierExit auth { (atBlock 24 9) with entered := true } forfeiture = none :=
  by decide +kernel
example : (execute earlierExit auth (atBlock 24 9) forfeiture).map
    (fun r ↦ (r.forfeiture, r.transfers)) =
    some (some ⟨1, 200, 31, 8⟩, [.pay 99 8]) := by decide +kernel
example : (balance forfeited 1, (bondAt forfeited 1).map Bond.exitHeight, forfeited.snapshot) =
    (some 23, some 21, firstMiss.snapshot) := by decide +kernel
example : execute forfeited auth (atBlock 24 9) (.forfeit 1 201 124) = none := by decide +kernel
example : (execute forfeited auth (atBlock 24 9) (.forfeit 0 200 124)).isSome = true :=
  by decide +kernel
example : balance (after forfeited (atBlock 25 7) (.slashDoubleSign 1 voteA voteB 102 102)) 1 =
    some 0 := by decide +kernel
example : ((bondAt (after forfeited (atBlock 26 2) (.withdraw 1 4)) 1).map Bond.forfeited) =
    some true := by decide +kernel

end L2StakingTests
