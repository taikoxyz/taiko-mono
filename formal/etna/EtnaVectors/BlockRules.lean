import EtnaVectors.Client

/-! `block_rules` vectors: the block-validity rules of 3.4 that do not depend on hash values.
The model's verdict is `BlockValidity.HeaderValid ∧ BlockValidity.AnchorValid` on a parent
header and a block built from the vector's numbers. Every other field (hashes, witnesses, the
committee hash adapter, the reference block) is set so its conjunct holds, so the verdict turns
only on: height linkage, the derived timestamp, the base-fee sharing byte, the generation triple,
the anchor's progress, range and freshness, and back-pressure U. -/
namespace Etna.Vectors
open Etna.Design

/-- One block on one parent, as numbers. -/
structure RuleCase where
  label : String
  spec : Option String := none
  /-- The rule the vector varies (its other inputs stay valid). -/
  rule : String
  /-- The chain's generation, the extraData generation and the anchored Inbox generation. -/
  chain : Nat := 0
  extra : Nat := 0
  inbox : Nat := 0
  epochLen : Nat := 10
  /-- The generation's L1 origin (`L1_0` for generation 0). -/
  origin : Nat := 100
  maxAge : Nat := 7200
  /-- U, the unsettled-block limit. -/
  unsettled : Nat := 6
  parentHeight : Nat := 4
  parentTimestamp : Nat := 1700000000
  parentAnchor : Nat := 110
  parentAnchorTimestamp : Nat := 1699999000
  height : Nat := 5
  bft : Nat := 1700000004
  anchor : Nat := 111
  anchorTimestamp : Nat := 1699999500
  /-- The anchored Inbox's lastCheckpoint.height. -/
  checkpoint : Nat := 2
  /-- The header timestamp; none: max(parent + 1, BFT time, anchor timestamp). -/
  timestamp : Option Nat := none
  feeShare : Nat := 100
  /-- The length of the envelope's block item (the payload's executionBlock). -/
  blockBytes : Nat := 1000

def RuleCase.headerTimestamp (c : RuleCase) : Nat :=
  c.timestamp.getD (max (max (c.parentTimestamp+1) c.bft) c.anchorTimestamp)

/-- The anchor's L1 state root (the header's parentBeaconBlockRoot) and the parent anchor's. -/
def ruleAnchorRoot : Hash := 7
def ruleParentAnchorRoot : Hash := 8

def RuleCase.anchorRec (c : RuleCase) : BlockValidity.Anchor :=
  ⟨c.anchor, c.anchorTimestamp, ruleAnchorRoot, c.checkpoint, 0, c.inbox, 0⟩

/-- A block that keeps its parent's anchor number inherits the whole anchor. -/
def RuleCase.parentAnchorRec (c : RuleCase) : BlockValidity.Anchor :=
  if c.parentAnchor = c.anchor then c.anchorRec
  else ⟨c.parentAnchor, c.parentAnchorTimestamp, ruleParentAnchorRoot, c.checkpoint, 0, c.inbox, 0⟩

/-- Generation 0's origin height is 0; the anchor history maps the block and its parent to their
anchors. -/
def RuleCase.context (c : RuleCase) : Consensus.Context :=
  ⟨deployment, c.chain, 0, c.origin, 90, c.epochLen, vpUnit, vpUnit, 128, fun _ => [],
    fun h => if h = c.height then c.anchor else c.parentAnchor⟩

/-- The reference block is far enough that only the 48-bit anchor range binds. -/
def RuleCase.rules (c : RuleCase) : BlockValidity.Rules :=
  { consensus := c.context, gridK := landGrid, committeeConfig := 0, maxAnchorAge := c.maxAge,
    forcedDelay := fiDelay, unsettled := c.unsettled, referenceNumber := limit48, referenceHash := 0,
    committeeHash := fun _ => 0, signature := fun _ => True, anchorAuthenticated := fun _ => true,
    committeeAuthenticated := fun _ _ => true, executionValid := fun _ _ => true, payloadValid := fun _ => true,
    forcedAuthenticated := fun _ _ => true, batchPayloadValid := fun _ _ => true, configHash := fun _ => 0,
    historyAuthenticated := fun _ _ => true }

def RuleCase.parent (c : RuleCase) : BlockValidity.Header :=
  ⟨c.parentHeight, 0, 0, 0, 0, c.parentTimestamp, c.parentAnchorRec⟩

/-- The witness-presence and hash fields take the values their conjuncts require. -/
def RuleCase.block (c : RuleCase) : BlockValidity.Block :=
  let origin := c.context.originHeight
  { header := ⟨c.height, 0, 0, 0, 0, c.headerTimestamp, c.anchorRec⟩, parentHash := 0,
    lastBlockId := if c.parentHeight = origin then none else some 0, domain := deployment,
    generation := c.extra, bftTime := c.bft, feeShare := c.feeShare, blockBytes := c.blockBytes,
    anchorWitness := decide (c.parentHeight = origin ∨ c.parentAnchor ≠ c.anchor), committeeWitness := none,
    validatorsHash := 0, nextValidatorsHash := 0, parentBeaconRoot := ruleAnchorRoot, round := 0, votes := [],
    forced := none, singleton := .completedEmpty }

def RuleCase.valid (c : RuleCase) : Bool :=
  decide (BlockValidity.HeaderValid c.rules c.parent c.block ∧ BlockValidity.AnchorValid c.rules c.parent c.block)

def RuleCase.toClient (c : RuleCase) : ClientCase :=
  let pa := c.parentAnchorRec
  { label := c.label, spec := c.spec,
    input := [("rule", jStr c.rule),
      ("chainGeneration", jNat c.chain), ("epochLen", jNat c.epochLen), ("origin", jNat c.origin),
      ("maxAnchorAge", jNat c.maxAge), ("unsettled", jNat c.unsettled),
      ("parent", jLine [("height", jNat c.parentHeight), ("timestamp", jNat c.parentTimestamp),
        ("anchor", jNat pa.number), ("anchorTimestamp", jNat pa.timestamp)]),
      ("block", jLine [("height", jNat c.height), ("bftTime", jNat c.bft), ("timestamp", jNat c.headerTimestamp),
        ("feeShare", jNat c.feeShare), ("generation", jNat c.extra)]),
      ("anchor", jLine [("number", jNat c.anchor), ("timestamp", jNat c.anchorTimestamp),
        ("checkpointHeight", jNat c.checkpoint), ("generation", jNat c.inbox)])],
    expect := [("valid", jBool c.valid)] }

def ruleT : Nat := 1700000000

def heightGrid : List RuleCase :=
  [(4, 3), (4, 4), (4, 5), (4, 6), (0, 1), (0, 2)].map fun (p, h) =>
    { label := "block_rules.height.parent" ++ Nat.repr p ++ ".block" ++ Nat.repr h, rule := "height",
      parentHeight := p, height := h, parentAnchor := 111, checkpoint := 0 }

/-- The header timestamp is the derived one (k = 0), one second later (1) or earlier (2). -/
def timestampCase (bft ats k : Nat) (name : String) : RuleCase :=
  let base : RuleCase :=
    { label := "block_rules.timestamp." ++ name, rule := "timestamp", bft := bft, anchorTimestamp := ats }
  let t := base.headerTimestamp
  { base with timestamp := some (if k = 0 then t else if k = 1 then t + 1 else t - 1) }

/-- Which of the three timestamp terms is largest, and a header one second off either way. -/

def timestampGrid : List RuleCase :=
  [(ruleT - 5, "bft-behind"), (ruleT + 1, "bft-at-parent-plus-1"), (ruleT + 10, "bft-ahead")].flatMap fun (bft, bn) =>
    [(ruleT - 3600, "anchor-old"), (ruleT + 1, "anchor-at-parent-plus-1"), (ruleT + 10, "anchor-at-ten"),
     (ruleT + 20, "anchor-ahead")].flatMap fun (ats, an) =>
      [(0, "derived"), (1, "plus1"), (2, "minus1")].map fun (k, kn) =>
        timestampCase bft ats k (bn ++ "." ++ an ++ "." ++ kn)

/-- The anchor against its parent's and the origin L1_0 = 100, inside epoch 0. -/
def anchorGrid : List RuleCase :=
  [100, 110].flatMap fun pa =>
    ([pa - 1, pa, pa + 1, 99, 100, 101].eraseDups).map fun a =>
      { label := "block_rules.anchor.parent" ++ Nat.repr pa ++ ".anchor" ++ Nat.repr a, rule := "anchor",
        parentAnchor := pa, anchor := a }

/-- The anchor's age against maxAnchorAge (the header timestamp is 1700000004). -/
def freshnessGrid : List RuleCase :=
  [1152, 7200].flatMap fun m => [m + 1, m, m - 1, 0].map fun age =>
    { label := "block_rules.freshness.max" ++ Nat.repr m ++ ".age" ++ Nat.repr age, rule := "freshness",
      maxAge := m, anchorTimestamp := 1700000004 - age }

/-- height − lastCheckpoint.height against U, including a checkpoint ahead of the block. -/
def backPressureGrid : List RuleCase :=
  [6, 1].flatMap fun u => (([u + 1, u, u - 1, 0].map (20 - ·)).eraseDups ++ [22]).map fun cp =>
    { label := "block_rules.back-pressure.u" ++ Nat.repr u ++ ".checkpoint" ++ Nat.repr cp, rule := "backPressure",
      unsettled := u, parentHeight := 19, height := 20, checkpoint := cp }

def generationGrid : List RuleCase :=
  [0, 1].flatMap fun ch => [0, 1].flatMap fun ex => [0, 1].map fun ib =>
    { label := "block_rules.generation.chain" ++ Nat.repr ch ++ ".extra" ++ Nat.repr ex ++ ".inbox" ++ Nat.repr ib,
      rule := "generation", chain := ch, extra := ex, inbox := ib }

def feeShareGrid : List RuleCase :=
  [0, 50, 100].map fun f =>
    { label := "block_rules.fee-share." ++ Nat.repr f, rule := "feeShare", feeShare := f }

def ruleHandwritten : List RuleCase := [
  { label := "block_rules.hw.fee-share-is-100", spec := some "EN L75", rule := "feeShare", feeShare := 100 },
  { label := "block_rules.hw.anchor-at-origin-in-a-later-epoch", spec := some "EN L162", rule := "anchor",
    parentHeight := 24, height := 25, parentAnchor := 100, anchor := 101, checkpoint := 20 },
  { label := "block_rules.hw.inherited-origin-anchor-in-a-later-epoch", spec := some "EN L162", rule := "anchor",
    parentHeight := 34, height := 35, parentAnchor := 100, anchor := 100, checkpoint := 30 },
  { label := "block_rules.hw.anchor-below-origin", spec := some "EN L101", rule := "anchor",
    parentAnchor := 99, anchor := 99 },
  { label := "block_rules.hw.anchor-max-uint48", spec := some "EN L75", rule := "anchor",
    parentAnchor := 110, anchor := limit48 - 1 },
  { label := "block_rules.hw.anchor-2pow48", spec := some "EN L75", rule := "anchor",
    parentAnchor := 110, anchor := limit48 },
  { label := "block_rules.hw.superseded-chain", spec := some "EN L102", rule := "generation", inbox := 1 },
  { label := "block_rules.hw.inbox-behind-chain", spec := some "EN L102", rule := "generation",
    chain := 1, extra := 1 },
  { label := "block_rules.hw.back-pressure-at-u", spec := some "EN L103", rule := "backPressure",
    parentHeight := 19, height := 20, checkpoint := 14 },
  { label := "block_rules.hw.freshness-at-max-age", spec := some "EN L105", rule := "freshness",
    anchorTimestamp := 1700000004 - 7200 },
  { label := "block_rules.hw.timestamp-strictly-increases", spec := some "EN L73", rule := "timestamp",
    bft := ruleT, anchorTimestamp := ruleT - 10, timestamp := some ruleT },
  { label := "block_rules.hw.height-max-uint48", spec := some "EN L266", rule := "height",
    epochLen := limit48 / 2, parentHeight := limit48 - 2, height := limit48 - 1, checkpoint := limit48 - 3 },
  { label := "block_rules.hw.height-2pow48", spec := some "EN L266", rule := "height",
    epochLen := limit48 / 2, parentHeight := limit48 - 1, height := limit48, checkpoint := limit48 - 2 }]

def ruleCases : List RuleCase :=
  heightGrid ++ timestampGrid ++ anchorGrid ++ freshnessGrid ++ backPressureGrid ++ generationGrid ++
    feeShareGrid ++ ruleHandwritten

def blockRulesFile (provenance : Option String) : Except String String :=
  clientFile "block_rules" provenance [] (ruleCases.map RuleCase.toClient)

/-! `block_size` vectors: the block size bound of 3.4, the `blockBytes ≤ 124,000` conjunct of
`HeaderValid`, with every other input valid. `content` is client-only input the model ignores:
the bytes are incompressible or all zero, which matters to a bound on compressed bytes. -/

structure SizeCase where
  label : String
  spec : Option String := none
  blockBytes : Nat
  incompressible : Bool

def SizeCase.toClient (c : SizeCase) : ClientCase :=
  let r : RuleCase := { label := c.label, rule := "size", blockBytes := c.blockBytes }
  { label := c.label, spec := c.spec,
    input := [("blockBytes", jNat c.blockBytes), ("content", jStr (if c.incompressible then "incompressible" else "zeros"))],
    expect := [("valid", jBool r.valid)] }

def sizeCases : List SizeCase :=
  ([1000, 123999, 124000, 124001, 200000, 780000].flatMap fun n => [true, false].map fun inc =>
    ({ label := "block_size.bytes" ++ Nat.repr n ++ (if inc then ".incompressible" else ".zeros"),
       blockBytes := n, incompressible := inc } : SizeCase)) ++
  [{ label := "block_size.hw.compressible-block-over-bound", spec := some "EN L113", blockBytes := 500000,
     incompressible := false },
   { label := "block_size.hw.six-blob-block-over-bound", spec := some "EN L113", blockBytes := 700000,
     incompressible := true }]

def blockSizeFile (provenance : Option String) : Except String String :=
  clientFile "block_size" provenance [] (sizeCases.map SizeCase.toClient)

end Etna.Vectors
