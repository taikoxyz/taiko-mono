import EtnaVectors.BlockRules

/-! `schedule` vectors: the committee that signs block h, `Consensus.activeAt`, and whether its
election is valid, `Consensus.ElectionValid`, in generation 0. A context fixes the epoch length
L, `L1_0`, the genesis cutoff, the selection parameters, the registry checkpoints and the anchor
of every L2 block; a vector names one context and one height. Each vector also says whether h is
a switch block S(t) that must carry a committee witness (`BlockValidity.WitnessValid`) and, if
so, which epoch t it derives. -/
namespace Etna.Vectors
open Etna.Design

/-- A registry entry as a context lists it, indexed by bond id. `staleHeartbeat` is client-only
input the model ignores: the spec has no heartbeat rule, so a client that drops an entry for a
stale heartbeat diverges on the vectors that set it. -/
structure SchedEntry where
  key : Nat
  stake : Nat
  activeFrom : Nat := 80
  exitAt : Nat := Staking.noExit
  staleHeartbeat : Bool := false

def SchedEntry.model (e : SchedEntry) : Committee.Entry := ⟨e.key, e.stake, e.activeFrom, e.exitAt⟩

/-- A released slot is all zero. -/
def releasedSlot : SchedEntry := { key := 0, stake := 0, activeFrom := 0, exitAt := 0 }

structure SchedContext where
  name : String
  spec : Option String := none
  epochLen : Nat
  originBlock : Nat := 100
  genesisCutoff : Nat := 90
  unit : Nat := 1000
  minimum : Nat := 1000
  nMax : Nat := 128
  /-- Registry checkpoints, oldest first: (L1 block, entries by bond id). -/
  snapshots : List (Nat × List SchedEntry)
  /-- Element x is the anchor of L2 block x (nondecreasing). -/
  archive : List Nat
  heights : List Nat

def SchedContext.registry (s : SchedContext) : RegistryHistory.State :=
  { RegistryHistory.empty with
    history := (s.snapshots.map fun (b, es) => (⟨b, es.map SchedEntry.model⟩ : RegistryHistory.Snapshot)).reverse }

/-- Generation 0: origin height 0 and origin block `L1_0`. -/
def SchedContext.consensus (s : SchedContext) : Consensus.Context :=
  ⟨deployment, 0, 0, s.originBlock, s.genesisCutoff, s.epochLen, s.unit, s.minimum, s.nMax,
    HistoricalContext.registryAt s.registry, HistoricalContext.anchorAt s.archive⟩

/-- Whether block h must carry a committee witness: `WitnessValid` fails without one. -/
def SchedContext.switchWitness (s : SchedContext) (h : Nat) : Bool :=
  let base : RuleCase := { label := "", rule := "", height := h }
  !decide (BlockValidity.WitnessValid { base.rules with consensus := s.consensus } base.block)

def memberJ (unit : Nat) (e : Committee.Entry) : JVal :=
  jLine [("key", jNat e.key), ("stake", jNat e.stake), ("power", jNat (Committee.power unit e))]

/-- The committee active at h, whether its election is valid, and the epoch a switch at h
derives: `WitnessValid` requires the record `normal c ((h+1)/L)` there. -/
def SchedContext.expect (s : SchedContext) (h : Nat) : List (String × JVal) :=
  let c := s.consensus
  let r := Consensus.activeAt c h
  [("targetEpoch", jNat r.targetEpoch), ("cutoff", jNat r.cutoff),
   ("valid", jBool (decide (Consensus.ElectionValid c r))),
   ("members", jRow (r.members.map (memberJ s.unit))),
   ("switchTarget", if s.switchWitness h then jNat ((h+1)/s.epochLen) else jNull)]

def SchedContext.cases (s : SchedContext) : List ClientCase :=
  let group := if s.spec.isSome then "schedule.hw." else "schedule."
  s.heights.map fun h =>
    { label := group ++ s.name ++ ".h" ++ Nat.repr h, spec := s.spec,
      input := [("context", jStr s.name), ("height", jNat h)], expect := s.expect h }

def schedEntryJ (e : SchedEntry) : JVal :=
  jLine [("key", jNat e.key), ("stake", jNat e.stake), ("activeFrom", jNat e.activeFrom), ("exitAt", jNat e.exitAt),
    ("staleHeartbeat", jBool e.staleHeartbeat)]

def SchedContext.json (s : SchedContext) : JVal :=
  jObj [("name", jStr s.name), ("epochLen", jNat s.epochLen), ("originBlock", jNat s.originBlock),
    ("genesisCutoff", jNat s.genesisCutoff), ("unit", jNat s.unit), ("minimum", jNat s.minimum),
    ("nMax", jNat s.nMax),
    ("snapshots", jArr (s.snapshots.map fun (b, es) => jLine [("block", jNat b), ("entries", jRow (es.map schedEntryJ))])),
    ("archive", jNats s.archive)]

/-- Anchors 100, 102, 104, …: every derivation height has its own anchor. -/
def evenArchive (n : Nat) : List Nat := (List.range n).map fun x => 100 + 2*x
def stepArchive (n : Nat) : List Nat := (List.range n).map fun x => 100 + x

/-- L = 3, n_max = 2: activation between checkpoint and cutoff, ties by key, an exit at the
cutoff, the stake floor, a released slot, activation at the cutoff and finally no eligible
entry. -/
def rotationContext : SchedContext :=
  { name := "rotation", epochLen := 3, nMax := 2, archive := evenArchive 21, heights := List.range' 1 16,
    snapshots := [
      (85, [{ key := 1, stake := 5000 }, { key := 2, stake := 3000 }, { key := 3, stake := 3000, activeFrom := 95 },
            { key := 4, stake := 3000 }]),
      (104, [{ key := 1, stake := 5000, exitAt := 108 }, { key := 2, stake := 2000 },
             { key := 3, stake := 3000, activeFrom := 95 }, { key := 4, stake := 3000 },
             { key := 5, stake := 999, activeFrom := 100 }, { key := 6, stake := 1000, activeFrom := 100 }]),
      (110, [releasedSlot, { key := 2, stake := 2000 }, { key := 3, stake := 3000, activeFrom := 95, exitAt := 115 },
             { key := 4, stake := 3000 }, { key := 5, stake := 999, activeFrom := 100 },
             { key := 6, stake := 1000, activeFrom := 100 }, { key := 7, stake := 4000, activeFrom := 114 }]),
      (118, [releasedSlot, releasedSlot, { key := 3, stake := 3000, activeFrom := 95, exitAt := 115 },
             { key := 4, stake := 3000, exitAt := 119 }, { key := 5, stake := 999, activeFrom := 100, exitAt := 119 },
             { key := 6, stake := 1000, activeFrom := 100, exitAt := 119 },
             { key := 7, stake := 4000, activeFrom := 114, exitAt := 120 }])] }

/-- L = 10, s_min = 2,500 above vp_unit = 1,000: the floor is s_min and power rounds down. -/
def powerContext : SchedContext :=
  { name := "power", epochLen := 10, minimum := 2500, archive := stepArchive 41, heights := List.range' 1 25,
    snapshots := [
      (85, [{ key := 1, stake := 2499 }, { key := 2, stake := 2500 }, { key := 3, stake := 3999 },
            { key := 4, stake := 1000000 }]),
      (105, [{ key := 1, stake := 2500 }, { key := 2, stake := 2500 }, { key := 3, stake := 3999 },
             { key := 4, stake := 1000000, exitAt := 118 }])] }

def scheduleHandwritten : List SchedContext := [
  { name := "genesis-uses-genesis-cutoff", spec := some "EN L178", epochLen := 4, archive := stepArchive 12,
    heights := List.range' 1 8,
    snapshots := [(85, [{ key := 1, stake := 5000 }, { key := 2, stake := 4000 }]),
                  (95, [{ key := 1, stake := 5000 }, { key := 2, stake := 4000 }, { key := 3, stake := 6000, activeFrom := 95 }])] },
  { name := "switch-uses-derivation-parent-anchor", spec := some "EN L183", epochLen := 5,
    archive := [100, 100, 100, 100, 130, 130, 130, 130, 130, 130, 130, 130, 130], heights := List.range' 1 12,
    snapshots := [(85, [{ key := 1, stake := 5000 }, { key := 2, stake := 4000 }]),
                  (120, [{ key := 1, stake := 5000 }, { key := 2, stake := 4000 }, { key := 3, stake := 6000, activeFrom := 120 }])] },
  { name := "duplicate-eligible-key", spec := some "EN L168", epochLen := 3, archive := evenArchive 8,
    heights := List.range' 1 4,
    snapshots := [(85, [{ key := 1, stake := 5000 }, { key := 2, stake := 3000 }, { key := 2, stake := 2000 }])] },
  { name := "duplicate-key-one-exited", spec := some "EN L168", epochLen := 3, archive := evenArchive 8,
    heights := [1, 4],
    snapshots := [(85, [{ key := 1, stake := 5000 }, { key := 2, stake := 3000 }, { key := 2, stake := 2000, exitAt := 50 }])] },
  { name := "stale-heartbeat", spec := some "EN L168", epochLen := 3, archive := evenArchive 16,
    heights := List.range' 1 12,
    snapshots := [(85, [{ key := 1, stake := 5000 }, { key := 2, stake := 4000 },
                        { key := 3, stake := 6000, staleHeartbeat := true }])] },
  { name := "eligibility-boundaries", spec := some "EN L168", epochLen := 10, archive := stepArchive 12,
    heights := [1],
    snapshots := [(85, [{ key := 1, stake := 5000, activeFrom := 90 }, { key := 2, stake := 5000, activeFrom := 91 },
                        { key := 3, stake := 5000, exitAt := 90 }, { key := 4, stake := 5000, exitAt := 91 },
                        { key := 5, stake := 1000 }, { key := 6, stake := 999 }])] },
  { name := "n-max-tie-by-set-key", spec := some "EN L169", epochLen := 10, nMax := 1, archive := stepArchive 12,
    heights := [1],
    snapshots := [(85, [{ key := 2, stake := 3000 }, { key := 1, stake := 3000 }])] },
  { name := "no-eligible-entry", spec := some "EN L170", epochLen := 10, archive := stepArchive 12, heights := [1],
    snapshots := [(85, [{ key := 1, stake := 5000, activeFrom := 91 }, { key := 2, stake := 999 }])] },
  { name := "latest-checkpoint-at-cutoff", spec := some "EN L167", epochLen := 10, archive := stepArchive 12,
    heights := [1],
    snapshots := [(90, [{ key := 1, stake := 5000 }]), (91, [{ key := 1, stake := 5000 }, { key := 2, stake := 6000 }])] }]

def scheduleContexts : List SchedContext := [rotationContext, powerContext] ++ scheduleHandwritten

def scheduleHeader : List (String × JVal) := [("contexts", jArr (scheduleContexts.map SchedContext.json))]

def scheduleFile (provenance : Option String) : Except String String :=
  clientFile "schedule" provenance scheduleHeader (scheduleContexts.flatMap SchedContext.cases)

end Etna.Vectors
