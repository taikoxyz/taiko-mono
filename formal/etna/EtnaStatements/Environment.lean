import EtnaModel

/-! The environment of the headline claims: what the L1 contracts do not fix. The model leaves
these as named external relations of `BlockValidity.Rules` or as free step inputs; here they are
fixed once per deployment, so a premise and a claim talk about the same relations, and a run
takes only the landings the environment submits. -/
namespace Etna.Statements
open Etna.Design

/-- Everything outside the L1 contracts, fixed for one deployment. The first eight fields are
the named external relations that `Deployment.build` takes from its template: the guest checks
of 6.2 "What the guest must prove" that the model does not decode. They are the same for every
proof, so "valid" in a claim means valid under one fixed rule set, not under relations chosen per
landing. `headerHash` and `genesisHeader` give the model's opaque EL hashes their meaning: the
hash of a decoded header, and block 0's header. `submits` holds the `land` calls landers make
(6.1: "land is permissionless"). Only the premises constrain these fields. -/
structure Environment where
  /-- A vote carries a signature by its key under the vote's own domain (3.1: secp256k1eth over
  keccak256 sign bytes). -/
  signature : Consensus.Vote → Prop
  /-- The anchor's raw L1 header and Inbox account/storage proofs verify (3.3; 6.2 item 8). -/
  anchorAuthenticated : BlockValidity.Anchor → Bool
  /-- A switch block's registry proofs verify under the given state root (3.4 rule 6; 4.3). -/
  committeeAuthenticated : Hash → Committee.Record → Bool
  /-- The EL accepts the block on its parent (3.4 rule 9: `newPayload` returns VALID). -/
  executionValid : BlockValidity.Header → BlockValidity.Block → Bool
  /-- The envelope, data hash, FI transaction 0 and singleton build decode as 5 and 7.2 require. -/
  payloadValid : BlockValidity.Block → Bool
  /-- A forced-inclusion witness is a storage proof under the anchor's stateRoot (7.2). -/
  forcedAuthenticated : BlockValidity.Anchor → Forced.Witness → Bool
  /-- The blobs carry exactly this batch's payload (6.2 item 9). -/
  batchPayloadValid : List Hash → List BlockValidity.Block → Bool
  /-- The fixed origin, genesis schedule and historical registry and anchor lookups are
  authenticated (6.2 items 1-2). -/
  historyAuthenticated : Consensus.Context → Nat → Bool
  /-- The EL block hash of a decoded L2 header: keccak256 of its RLP-encoded EL header, whose
  fields 3.2 fixes (number, stateRoot, timestamp, extraData with the anchor block number,
  parentBeaconBlockRoot = the anchor's stateRoot, ...). -/
  headerHash : BlockValidity.Header → Hash
  /-- Block 0's decoded header, the deployment's starting point (§10 step 4, EN L534: "Compute
  block 0's hash and stateRoot with the EL"). -/
  genesisHeader : BlockValidity.Header
  /-- The `land` calls landers submit: the World they act on and the call's inputs. -/
  submits : ProtocolState.World → LandInput → List Leaf → LandingEnv → Prop

/-- The template `Deployment.build` completes for one proof whose reference block is `number`,
with hash `hash`: the environment's relations plus that reference. `build` overwrites every other
field (consensus context, K, config commitment, slot-282 values, U and both hash adapters) from
the World, so the zeros here are never read. -/
def Environment.template (env : Environment) (number : Nat) (hash : Hash) : BlockValidity.Rules where
  consensus := ⟨⟨0,0,0,0⟩,0,0,0,0,0,0,0,0,fun _ => [],fun _ => 0⟩
  gridK := 0
  committeeConfig := 0
  maxAnchorAge := 0
  forcedDelay := 0
  unsettled := 0
  referenceNumber := number
  referenceHash := hash
  committeeHash := fun _ => 0
  signature := env.signature
  anchorAuthenticated := env.anchorAuthenticated
  committeeAuthenticated := env.committeeAuthenticated
  executionValid := env.executionValid
  payloadValid := env.payloadValid
  forcedAuthenticated := env.forcedAuthenticated
  batchPayloadValid := env.batchPayloadValid
  configHash := fun _ => 0
  historyAuthenticated := env.historyAuthenticated

/-- `r` is a rule set the deployment builds on World `w`: `Deployment.build` with the stored
configuration, some anchor archive and the environment's template at some reference block. -/
def Built (env : Environment) (w : ProtocolState.World) (r : BlockValidity.Rules) : Prop :=
  ∃ archive number hash, Deployment.build w w.inbox.configuration archive (env.template number hash) = some r

/-- A run of the whole L1 machine from `w0` under `env`: a sequence of `ProtocolState.Step`s
(so a `ProtocolState.Trace`) in which every landing is one `env` submits. `landing` is
`ProtocolState.Step.landing` plus `submitted`. `other` is any `ProtocolState.Step` that does not
advance lastCheckpoint: every registration, registry edit, forced-inclusion enqueue, fee sweep,
governance recovery and verifier-failure rollback. A landing always advances it (6.1 requires
c < h and writes h). -/
inductive Run (env : Environment) : ProtocolState.World → ProtocolState.World → Prop
  | refl (w : ProtocolState.World) : Run env w w
  | landing {w0 w : ProtocolState.World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (prior : Run env w0 w) (submitted : env.submits w i leaves e) (time : w.l1Block ≤ e.blockNumber)
      (ok : Etna.Design.land w.inbox i leaves e = some s) : Run env w0 (ProtocolState.landed w s e.blockNumber)
  | other {w0 w t : ProtocolState.World} (prior : Run env w0 w) (change : ProtocolState.Step w t)
      (settled : t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height) : Run env w0 t

end Etna.Statements
