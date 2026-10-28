import EtnaModel.ProtocolState

/-! Deployment-bound decoded construction. Every Rules field the spec fixes at Inbox
initialization is read from the initialized World, never from the caller: L, genesisCutoff,
K, the slot-282 immutables, the config and committee-0 commitments, and the World's fixed
hash adapters (`ProtocolState.Adapters`, preserved by every transition). The decoded config
preimage and the committee-0 record are ghost authenticated openings of the two stored
commitments, not extra storage slots. Committee 0 recomputed from typed registry history must
equal its opening, so it is bound by the State even under a constant record-hash adapter.
Actual opening authentication and Keccak separation remain external;
`representable_opening_unique` states the separation premise explicitly, over uint256 configs. -/
namespace Etna.Design.Deployment

abbrev Config := CommitteeConfig

def words (s : State) (cfg : Config) : List Encoding.Word :=
  Encoding.configWords s.domain.l2ChainId s.domain.registry cfg.unit cfg.minimum cfg.nMax cfg.unsettled

def parameters (s : State) (cfg : Config) : HistoricalContext.Parameters :=
  ⟨s.genesisCutoff,s.epochLen,cfg.unit,cfg.minimum,cfg.nMax⟩

def genesis (s : State) (registry : RegistryHistory.State) (cfg : Config) (archive : List Nat) : Committee.Record :=
  Consensus.selected (HistoricalContext.derive s registry (parameters s cfg) archive) 0 s.genesisCutoff

/-- Generation 0's slot-290 origin (0, L1_0, initialization timestamp), written once (8.4). -/
def genesisOrigin (s : State) : Origin := ((s.origins.head?).map Prod.snd).getD ⟨0,0,0⟩

/-- §10 initialization constraints expressible on the decoded state (EN "Deployment
constraints", source L538): `configOK` is L ≥ 3, L+1 < 2^48, 1 ≤ K ≤ 6 and
K ≤ U ≤ 65,536 with K ∣ U; forcedInclusionDelay > 0 and maxAnchorAge ≥ 1152 s (also L568),
each fitting its 48-bit slot-282 field (L738, L753); the first origin is generation 0's
(0, L1_0, ·) with L1_0 < 2^48 and a past genesisCutoff < L1_0 (L492, L529); 1 ≤ n_max ≤ 4096;
vp_unit ≥ 867,361,738 (4.3, L175) and s_min ≥ vp_unit; and the §11 Inbox immutables (L569): maxBatchBlocks ≥ K (also L541), FI fee and threshold above 0 and a nonzero
protocolFeeRecipient (also L532). L538's "no earlier than the first registry checkpoint"
reads registry history, so it is a conjunct of `Genesis` and follows from the build guard's
`GenesisElected` (`build_initialization_constraints`). The 48-byte chain id, the L1-finality
bound on maxAnchorAge and the leaf-calldata gas bound on maxBatchBlocks are outside this
state. -/
def Constraints (s : State) (cfg : Config) : Prop :=
  Committee.configOK s.gridK s.epochLen cfg.unsettled = true ∧
  0 < s.forcedDelay ∧ s.forcedDelay < limit48 ∧ 1152 ≤ s.maxAnchorAge ∧ s.maxAnchorAge < limit48 ∧
  s.origins.head? = some (0,genesisOrigin s) ∧ (genesisOrigin s).height = 0 ∧
  s.genesisCutoff < (genesisOrigin s).l1Block ∧ (genesisOrigin s).l1Block < limit48 ∧
  1 ≤ cfg.nMax ∧ cfg.nMax ≤ 4096 ∧ Committee.minUnit ≤ cfg.unit ∧ cfg.unit ≤ cfg.minimum ∧
  s.gridK ≤ s.maxBatchBlocks ∧ 0 < s.forcedFee ∧ 0 < s.forcedThreshold ∧ s.protocolFeeRecipient ≠ 0

instance (s : State) (cfg : Config) : Decidable (Constraints s cfg) := inferInstanceAs (Decidable (_ ∧ _))

/-- §10/§11 registry deployment bounds (spec L538, L574): positive activation and
exit delays and slashBountyBps ≤ 10000. withdrawalDelay's lower bound (the double-sign
evidence window) and the nonzero slashSink are outside this state. L574's l2ChainId matching
the Inbox and the fixed Inbox proxy address equal to the Inbox's own (also 4.1 L156, checked
at initialization, §10 step 5) are not modeled: `RegistryHistory.State` has no l2ChainId or
Inbox-address field, and slashing reads the Inbox's own `domain` (`RegistryHistory.editBond`),
which presumes that equality. -/
def RegistryConstraints (r : RegistryHistory.State) : Prop :=
  0 < r.activationDelay ∧ 0 < r.exitDelay ∧ r.slashBountyBps ≤ 10000

instance (r : RegistryHistory.State) : Decidable (RegistryConstraints r) := inferInstanceAs (Decidable (_ ∧ _))

/-- Committee 0 is the genesis-cutoff election under the same selection and power rule (4.3):
non-empty, positive powers and bounded total, so a checkpoint exists at the cutoff. -/
def GenesisElected (s : State) (registry : RegistryHistory.State) (cfg : Config) : Prop :=
  Committee.election cfg.unit cfg.minimum s.genesisCutoff cfg.nMax
    (HistoricalContext.registryAt registry s.genesisCutoff) = some s.committeeZeroRecord.members

instance (s : State) (registry : RegistryHistory.State) (cfg : Config) : Decidable (GenesisElected s registry cfg) :=
  inferInstanceAs (Decidable (_ = _))

/-- Rules from the initialized deployment only. The supplied decoded config must be the
authenticated opening; committee 0 recomputed from typed registry history must be the
authenticated committee-0 opening and a valid election; both commitments must open under the
World's fixed adapters; §10's Inbox and registry constraints must hold. `template` supplies
only the per-proof reference block and the named external relations. -/
def build (w : ProtocolState.World) (cfg : Config) (archive : List Nat) (template : BlockValidity.Rules) :
    Option BlockValidity.Rules :=
  if Constraints w.inbox cfg ∧ cfg = w.inbox.configuration ∧
      w.inbox.committeeConfig = w.adapters.configHash (words w.inbox cfg) ∧
      genesis w.inbox w.registry cfg archive = w.inbox.committeeZeroRecord ∧ GenesisElected w.inbox w.registry cfg ∧
      w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧ RegistryConstraints w.registry then
    (HistoricalContext.build w.inbox w.registry (parameters w.inbox cfg) archive).map fun c =>
      { template with
        consensus := c,gridK := w.inbox.gridK,committeeConfig := w.inbox.committeeConfig,
        maxAnchorAge := w.inbox.maxAnchorAge,forcedDelay := w.inbox.forcedDelay,unsettled := cfg.unsettled,
        configHash := w.adapters.configHash,committeeHash := w.adapters.recordHash }
  else none

/-- §10 step 5 (spec L532) with Appendix B slots 268/270/271/281/284/285/290 and 8.4:
the World right after the Inbox is initialized on genesis hash `hash` and stateRoot `root`.
recoveryGeneration is 0; lastCheckpoint, its only slot-285 record and the only SignalService
checkpoint are block 0 (EL hash = genesis hash, Comet hash 0, parent/generation/FI cursor 0);
the FI queue is empty (head = tail = 0); activeCommitteeSnapshot = genesisCutoff; generation
0's origin (0, L1_0, ·) is the only origin and the World clock is at or after L1_0; no call is
in flight; fee ghosts are consistent; the registry is valid at the clock; committee 0 governs
with nothing pending; the §10 constraints hold for the stored configuration (including the
nonzero protocolFeeRecipient) and for the registry immutables; the stored config and
committee-0 hashes open, under the World's fixed adapters, to the stored ghost openings; the
committee-0 opening is the genesis election (4.3 L178, §10 step 2 L529): target epoch 0,
cutoff genesisCutoff and members the election over the registry snapshot at genesisCutoff
under the stored configuration; and genesisCutoff is no earlier than the first registry
checkpoint (L538). `genesis_builds` shows these admit the deployment construction.
Owner-only `recover` is the owner check of `Recovery.Allowed`, not state. Step 5's registry
check (4.1 L156: the registry's fixed Inbox address and l2ChainId equal the Inbox's own) is
not state here; see `RegistryConstraints`. -/
def Genesis (w : ProtocolState.World) (hash root : Hash) : Prop :=
  w.inbox.generation = 0 ∧ w.inbox.checkpoint = ⟨0,hash,0,0,0,0⟩ ∧ w.inbox.records = [w.inbox.checkpoint] ∧
  w.inbox.signals = [⟨0,hash,root⟩] ∧ w.inbox.head = 0 ∧ w.inbox.tail = 0 ∧ w.queue = [] ∧
  w.inbox.snapshot = w.inbox.genesisCutoff ∧ w.inbox.origins = [(0,w.inbox.origin)] ∧
  w.inbox.origin.l1Block ≤ w.l1Block ∧ w.inbox.entered = false ∧ FeeConserved w.inbox ∧
  ProtocolState.RegistryValid w.registry w.l1Block ∧
  w.schedule = Committee.recoverySchedule w.inbox.committeeZeroRecord ∧
  Constraints w.inbox w.inbox.configuration ∧ RegistryConstraints w.registry ∧
  w.inbox.committeeConfig = w.adapters.configHash (words w.inbox w.inbox.configuration) ∧
  w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧
  w.inbox.committeeZeroRecord.targetEpoch = 0 ∧ w.inbox.committeeZeroRecord.cutoff = w.inbox.genesisCutoff ∧
  GenesisElected w.inbox w.registry w.inbox.configuration ∧
  (RegistryHistory.latestSnapshot w.registry.history w.inbox.genesisCutoff).isSome = true

end Etna.Design.Deployment
