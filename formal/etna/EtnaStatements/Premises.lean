import EtnaStatements.Environment

/-! The premise record: every assumption the headline claims make, one documented field each.
Each field constrains the deployment's initialized World or the environment (the proof
backends, the guests' L1 data, the hash and signature adapters). No field mentions the Inbox
records, signals or queue progress the claims are about; the run itself is any sequence of
protocol steps whose landings the environment submits (`Run`). -/
namespace Etna.Statements
open Etna.Design

/-- A decoded config whose four words fit in uint256, as the 7-word preimage of
committeeConfigHash carries them (Appendix A). -/
def Representable (cfg : CommitteeConfig) : Prop :=
  cfg.unit < limit256 ∧ cfg.minimum < limit256 ∧ cfg.nMax < limit256 ∧ cfg.unsettled < limit256

/-- World `w` as a guest sees it: the two stored commitments (committeeConfigHash and committee
0's record hash) open to the preimages `cfg` and `zero` the guest supplies, not to the model's
ghost openings. `Deployment.build` on this view checks those openings against the stored hashes
and recomputes committee 0 (6.2 item 1). -/
def guestView (w : ProtocolState.World) (cfg : CommitteeConfig) (zero : Committee.Record) : ProtocolState.World :=
  { w with inbox := { w.inbox with configuration := cfg, committeeZeroRecord := zero } }

/-- Statement `d` is certified on World `w`: it is the statement (6.2, Appendix A) of a batch
that is `Settlement.BatchValid` (every block `BlockValidity.Valid`, the payload bound to the
blobs) under the rules `Deployment.build` derives on a guest's view of `w`, at `d`'s own reference
block, from a representable opening of the stored commitments. -/
def Certifies (env : Environment) (w : ProtocolState.World) (d : StatementData) : Prop :=
  ∃ (cfg : CommitteeConfig) (zero : Committee.Record) (archive : List Nat) (r : BlockValidity.Rules)
    (p : BlockValidity.Header) (bs : List BlockValidity.Block) (blobs : List Hash),
    Representable cfg ∧
    Deployment.build (guestView w cfg zero) cfg archive
      (env.template d.input.l1ReferenceBlockNumber d.referenceHash) = some r ∧
    Settlement.BatchValid r p bs blobs ∧ d = Settlement.statement r p bs blobs

/-- Two proofs, at least one sound. Some set of proof backends is sound: every combination the
dual verifier accepts (`dualOK`: two distinct backends, at least one of them ZK) contains a sound
one, and a sound backend approves a submitted landing's statement only if it is certified.
This is equivalent to "every submitted landing that lands (`land … = some s`) is `Certifies`":
`land` requires `dualOK`, so a landing carries an accepting proof from a sound backend; and
conversely, if every such landing is certified, every backend can be taken as sound. -/
def VerifierSound (env : Environment) : Prop :=
  ∃ sound : Backend → Prop,
    (∀ proofs : List (Backend × Bool), dualOK proofs = true → ∃ q ∈ proofs, sound q.1) ∧
    ∀ b w i leaves e s, sound b → env.submits w i leaves e → Etna.Design.land w.inbox i leaves e = some s →
      (b, true) ∈ e.proofs → Certifies env w e.certificate

/-- The guests' L1 data agree with the Inbox's own state. For every submitted landing on World
`w` that the Inbox accepts at L1 block `e.blockNumber`: under an authenticated anchor whose L1
block lies in [`w.inbox.origin.l1Block`, `e.blockNumber`), that is, from the L1 block of the
current generation's origin (slot 290: the recovery that started the generation, or
initialization for generation 0) up to but not including the landing's block, an authenticated
forced-inclusion witness for an index below the anchor's tail shows `w`'s queue entry at that
index. Between such an anchor and the landing no recovery runs (it would write a later origin),
and an existing queue entry changes only in recovery, so this is the entry the anchor's L1 state
holds. -/
def InputsAuthenticated (env : Environment) : Prop :=
  ∀ w i leaves e s, env.submits w i leaves e → Etna.Design.land w.inbox i leaves e = some s →
    ∀ (A : BlockValidity.Anchor) (wit : Forced.Witness),
      env.anchorAuthenticated A = true → env.forcedAuthenticated A wit = true →
      w.inbox.origin.l1Block ≤ A.number → A.number < e.blockNumber → wit.index < A.tail →
      (wit.index, wit.stored) ∈ w.queue

/-- The premises of the headline claims for a deployment whose Inbox was initialized as World
`w0` and whose environment (guest relations, proof backends, submitted landings) is `env`. -/
structure Premises (w0 : ProtocolState.World) (env : Environment) : Prop where
  /-- §10 step 5 (EN L535): "initialize the Inbox ... with genesis hash/stateRoot, L,
  genesisCutoff, committee-0/config hashes, forcedInclusionDelay and maxAnchorAge, and save the
  block-0 checkpoint ... Initialize recoveryGeneration to 0, activeCommitteeSnapshot to
  genesisCutoff and generation 0's origin under 8.4"; step 4 (EN L534): "Compute block 0's hash
  and stateRoot with the EL". `w0` is the World right after that call (`Deployment.Genesis`),
  made with block 0's header's EL hash and stateRoot. That header has height 0, CometBFT hash 0
  (Appendix B slot 285, EN L743: "Initialize block 0 with parent/generation/head=0, EL hash =
  genesis hash and Comet hash=0"; 6.1, EN L273: "block 0 stores the genesis hash; its Comet hash
  is 0") and FI cursor 0 (7.2, EN L400: "a cursor c ... initially 0"). -/
  genesis : Deployment.Genesis w0 env.genesisHeader.elHash env.genesisHeader.stateRoot ∧
    env.genesisHeader.height = 0 ∧ env.genesisHeader.cometHash = 0 ∧ env.genesisHeader.cursor = 0
  /-- §1 "Funds" (EN L14): "every landing needs two proofs, at least one of them ZK (6.2)"; §1
  "Upgrades and trust" (EN L18): "Verifier soundness ... is a separate assumption"; 8 (EN L457):
  "both proofs accepting a wrong result is outside the threat model". See `VerifierSound`. -/
  verifierSound : VerifierSound env
  /-- 3.3 (EN L86): the anchor witness "proves the Inbox's recoveryGeneration, lastCheckpoint
  (height, hash) and the forced inclusion queue's head and tail"; 7.2 (EN L401): a block with a
  pending head "must carry entry c's witness, a storage proof under A's stateRoot". See
  `InputsAuthenticated`. -/
  authenticatedInputs : InputsAuthenticated env
  /-- 6.2 item 1 (EN L338): "committeeConfigHash opens per appendix A". Keccak separation for
  the config adapter: the stored committeeConfigHash has exactly one representable 7-word
  opening, the deployment's own configuration (the `separates` premise of
  `Deployment.opening_unique`, restricted to uint256 words so that it can hold at all). -/
  hashSeparation : ∀ cfg, Representable cfg →
    w0.adapters.configHash (Deployment.words w0.inbox cfg) = w0.inbox.committeeConfig → cfg = w0.inbox.configuration
  /-- 3.4 rule 1 (EN L99): "height = parent + 1, and parentHash links to the parent"; rule 9 (EN
  L107): "The EL's newPayload returns VALID"; 6.2 item 4 (EN L341): "execution runs from parentHash
  to the last block's hash and stateRoot". An EL hash is the hash of the header it names: when the
  EL accepts block `b` on parent header `p`, both `p`'s and `b`'s EL hashes are `headerHash` of
  those decoded headers, and so is block 0's. -/
  headerHashes : (∀ p b, env.executionValid p b = true →
      p.elHash = env.headerHash p ∧ b.header.elHash = env.headerHash b.header) ∧
    env.genesisHeader.elHash = env.headerHash env.genesisHeader
  /-- 3.2 (EN L68): "Every field except beneficiary is determined by the committed parent ...,
  the block's anchor, BFT time and chain constants". The EL header carries the height (number,
  EN L72), the timestamp (EN L73), the anchor block number (extraData, EN L75), the anchor's
  stateRoot (parentBeaconBlockRoot, EN L76) and the block's own stateRoot, which execution writes
  (6.2 item 4, EN L341). The rest of the decoded anchor is read from that authenticated L1 block
  (3.3). Keccak collision resistance, idealized: equal EL hashes mean equal height, stateRoot,
  timestamp and anchor. -/
  headerSeparation : ∀ h₁ h₂, env.headerHash h₁ = env.headerHash h₂ →
    h₁.height = h₂.height ∧ h₁.stateRoot = h₂.stateRoot ∧ h₁.timestamp = h₂.timestamp ∧ h₁.anchor = h₂.anchor
  /-- 3.1 (EN L42): "L1 can therefore verify any vote directly with ecrecover (double-sign
  slashing in 4.1)"; 4.1 (EN L150): the registry recomputes the sign bytes from "this
  deployment's full L1/L2 chain ids, the Inbox proxy fixed in the registry and the votes' shared
  generation". The registry's signature check accepts every vote of this deployment that the
  consensus signature relation accepts, with the vote's own signature bytes `sig v`. -/
  signatureAgreement : ∃ sig : Consensus.Vote → Hash, ∀ v, v.domain = w0.inbox.domain → env.signature v →
    w0.registry.verify v.key (Accountability.evidence v) (sig v) = true

end Etna.Statements
