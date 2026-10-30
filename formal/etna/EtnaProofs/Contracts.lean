import EtnaProofs.Accountability
import EtnaProofs.Lifecycle

/-! Independent unfolded semantic contracts for the predicates the decoded claims rest on.
Each pin restates its definition body and is closed by `Iff.rfl`/`rfl` (structure pins by
field reconstruction), so weakening a definition without editing its pin fails to build.
Inductive transition relations (`Step`, `Trace`, `SoundStep`, the registry and landing traces)
are pinned by constructor-set characterizations proved by `cases` and the constructors.
Every identifier is written from `_root_` so a same-named declaration in an `Etna.*`
namespace cannot capture the pin. Pins constrain the modeled definitions, not their
correspondence to the prose specification. -/
namespace Etna.Design.Contracts

theorem config_ok_eq (k l u : _root_.Nat) :
    _root_.Etna.Design.Committee.configOK k l u =
      _root_.Decidable.decide (1 ≤ k ∧ k ≤ 6 ∧ 3 ≤ l ∧ l+1 < _root_.Etna.Design.limit48 ∧ k ≤ u ∧
        u ≤ 65536 ∧ u % k = 0) := rfl

theorem signed_power_eq (c : _root_.Etna.Design.Consensus.Context)
    (members : _root_.List _root_.Etna.Design.Committee.Entry) (keys : _root_.List _root_.Etna.Design.Hash) :
    _root_.Etna.Design.Consensus.signedPower c members keys =
      _root_.Etna.Design.Committee.totalPower c.unit (members.filter (fun e => keys.contains e.key)) := rfl

theorem vote_valid_iff (c : _root_.Etna.Design.Consensus.Context)
    (signature : _root_.Etna.Design.Consensus.Vote → Prop) (h round block : _root_.Nat)
    (v : _root_.Etna.Design.Consensus.Vote) :
    _root_.Etna.Design.Consensus.VoteValid c signature h round block v ↔
      v.domain = c.domain ∧ v.generation = c.generation ∧ v.height = h ∧ v.round = round ∧
      v.kind = 2 ∧ v.blockId = block ∧
      v.key ∈ ((_root_.Etna.Design.Consensus.activeAt c h).members.map _root_.Etna.Design.Committee.Entry.key) ∧
      signature v := Iff.rfl

theorem commit_valid_iff (c : _root_.Etna.Design.Consensus.Context)
    (signature : _root_.Etna.Design.Consensus.Vote → Prop) (h round block : _root_.Nat)
    (votes : _root_.List _root_.Etna.Design.Consensus.Vote) :
    _root_.Etna.Design.Consensus.CommitValid c signature h round block votes ↔
      c.originHeight < h ∧
      _root_.Etna.Design.Consensus.ElectionValid c (_root_.Etna.Design.Consensus.activeAt c h) ∧
      (votes.map _root_.Etna.Design.Consensus.Vote.key).Nodup ∧
      (∀ v ∈ votes, _root_.Etna.Design.Consensus.VoteValid c signature h round block v) ∧
      2*_root_.Etna.Design.Committee.totalPower c.unit (_root_.Etna.Design.Consensus.activeAt c h).members <
        3*_root_.Etna.Design.Consensus.signedPower c (_root_.Etna.Design.Consensus.activeAt c h).members
          (votes.map _root_.Etna.Design.Consensus.Vote.key) := Iff.rfl

theorem header_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.HeaderValid r p b ↔
      b.header.height = p.height+1 ∧ b.parentHash = p.elHash ∧
      b.lastBlockId = (if p.height = r.consensus.originHeight then _root_.Option.none else _root_.Option.some p.cometHash) ∧
      b.domain = r.consensus.domain ∧ b.generation = r.consensus.generation ∧
      b.header.height < _root_.Etna.Design.limit48 ∧ b.header.timestamp < _root_.Etna.Design.limit256 ∧
      b.header.timestamp = _root_.Max.max (_root_.Max.max (p.timestamp+1) b.bftTime) b.header.anchor.timestamp ∧
      b.feeShare = 100 ∧ b.blockBytes ≤ 124000 ∧
      b.parentBeaconRoot = b.header.anchor.stateRoot ∧
      b.validatorsHash = r.committeeHash (_root_.Etna.Design.Consensus.activeAt r.consensus b.header.height) ∧
      b.nextValidatorsHash = r.committeeHash (_root_.Etna.Design.Consensus.activeAt r.consensus (b.header.height+1)) :=
  Iff.rfl

theorem anchor_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.AnchorValid r p b ↔
      p.anchor.number ≤ b.header.anchor.number ∧ r.consensus.originBlock ≤ b.header.anchor.number ∧
      b.header.anchor.number ≤ r.referenceNumber ∧ b.header.anchor.number < _root_.Etna.Design.limit48 ∧
      b.header.anchor.generation = r.consensus.generation ∧
      b.header.anchor.timestamp ≤ b.header.timestamp ∧
      b.header.timestamp-b.header.anchor.timestamp ≤ r.maxAnchorAge ∧
      b.header.height-b.header.anchor.checkpointHeight ≤ r.unsettled ∧
      r.consensus.anchorAt b.header.height = b.header.anchor.number ∧
      r.consensus.anchorAt p.height = p.anchor.number ∧
      b.anchorWitness = _root_.Decidable.decide
        (p.height = r.consensus.originHeight ∨ p.anchor.number ≠ b.header.anchor.number) ∧
      (p.anchor.number = b.header.anchor.number → p.anchor = b.header.anchor) ∧
      r.anchorAuthenticated b.header.anchor = _root_.Bool.true := Iff.rfl

theorem witness_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.WitnessValid r b ↔
      if (b.header.height+1) % r.consensus.epochLen = 0 then
        match b.committeeWitness with
        | .none => _root_.False
        | .some w => w.record = _root_.Etna.Design.Consensus.normal r.consensus ((b.header.height+1)/r.consensus.epochLen) ∧
            w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
            r.committeeAuthenticated w.root w.record = _root_.Bool.true ∧
            _root_.Etna.Design.Consensus.ElectionValid r.consensus w.record
      else b.committeeWitness = _root_.Option.none := Iff.rfl

theorem external_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.ExternalValid r p b ↔
      r.executionValid p b = _root_.Bool.true ∧ r.payloadValid b = _root_.Bool.true ∧
      (match b.forced with
        | .none => _root_.True
        | .some w => r.forcedAuthenticated b.header.anchor w = _root_.Bool.true) ∧
      r.committeeConfig = r.configHash (_root_.Etna.Design.Encoding.configWords r.consensus.domain.l2ChainId
        r.consensus.domain.registry r.consensus.unit r.consensus.minimum r.consensus.nMax r.unsettled) ∧
      r.historyAuthenticated r.consensus r.referenceNumber = _root_.Bool.true := Iff.rfl

theorem valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.Valid r p b ↔
      _root_.Etna.Design.Committee.configOK r.gridK r.consensus.epochLen r.unsettled = _root_.Bool.true ∧
      r.consensus.originHeight ≤ p.height ∧ _root_.Etna.Design.BlockValidity.HeaderValid r p b ∧
      _root_.Etna.Design.BlockValidity.AnchorValid r p b ∧ _root_.Etna.Design.BlockValidity.WitnessValid r b ∧
      _root_.Etna.Design.Consensus.CommitValid r.consensus r.signature b.header.height b.round b.header.cometHash b.votes ∧
      _root_.Etna.Design.Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp r.forcedDelay b.forced
        b.singleton = .accepted b.header.cursor ∧
      _root_.Etna.Design.BlockValidity.ExternalValid r p b := Iff.rfl

theorem chain_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) (rest : _root_.List _root_.Etna.Design.BlockValidity.Block) :
    (_root_.Etna.Design.BlockValidity.Chain r p [] ↔ _root_.True) ∧
    (_root_.Etna.Design.BlockValidity.Chain r p (b :: rest) ↔
      _root_.Etna.Design.BlockValidity.Valid r p b ∧ _root_.Etna.Design.BlockValidity.Chain r b.header rest) :=
  ⟨Iff.rfl,Iff.rfl⟩

theorem batch_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (p : _root_.Etna.Design.BlockValidity.Header)
    (bs : _root_.List _root_.Etna.Design.BlockValidity.Block) (blobs : _root_.List _root_.Etna.Design.Hash) :
    _root_.Etna.Design.Settlement.BatchValid r p bs blobs ↔
      _root_.Etna.Design.BlockValidity.Chain r p bs ∧ r.batchPayloadValid blobs bs = _root_.Bool.true := Iff.rfl

theorem dual_ok_eq (proofs : _root_.List (_root_.Etna.Design.Backend × _root_.Bool)) :
    _root_.Etna.Design.dualOK proofs =
      (_root_.Decidable.decide (proofs.length = 2) && proofs.all _root_.Prod.snd &&
        proofs.any (fun x => x.1 != .sgx) && _root_.Decidable.decide ((proofs.map _root_.Prod.fst).Nodup)) := rfl

theorem cursor_steps_eq (a b : _root_.Etna.Design.Cut) (rest : _root_.List _root_.Etna.Design.Cut) :
    _root_.Etna.Design.cursorSteps [] = _root_.Bool.true ∧ _root_.Etna.Design.cursorSteps [a] = _root_.Bool.true ∧
    _root_.Etna.Design.cursorSteps (a :: b :: rest) =
      (_root_.Decidable.decide (a.cursor ≤ b.cursor ∧ b.cursor ≤ a.cursor+1) &&
        _root_.Etna.Design.cursorSteps (b :: rest)) := ⟨rfl,rfl,rfl⟩

theorem certified_table_iff (k : _root_.Nat) (d : _root_.Etna.Design.StatementData)
    (table : _root_.List _root_.Etna.Design.Cut) :
    _root_.Etna.Design.CertifiedTable k d table ↔
      table.length = d.input.lastHeight-d.input.parentHeight+1 ∧
      d.cutHash = _root_.Etna.Design.tableHash k d.generation d.input.parentHeight d.input.lastHeight table ∧
      table.head? = _root_.Option.some ⟨d.parentHash,d.parentCometHash,d.headBefore⟩ ∧
      table.getLast? = _root_.Option.some ⟨d.input.lastBlockHash,d.input.lastCometHash,d.input.forcedInclusionHead⟩ ∧
      _root_.Etna.Design.cursorSteps table = _root_.Bool.true ∧ d.input.parentHeight % k = 0 ∧
      d.input.lastHeight % k = 0 := Iff.rfl

theorem base_ok_iff (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput) (e : _root_.Etna.Design.LandingEnv) :
    _root_.Etna.Design.BaseOK s i e ↔
      s.entered = _root_.Bool.false ∧
      s.origin.height ≤ i.parentHeight ∧ i.parentHeight ≤ s.checkpoint.height ∧ s.checkpoint.height < i.lastHeight ∧
      i.lastHeight < _root_.Etna.Design.limit48 ∧
      i.parentHeight % s.gridK = 0 ∧ i.lastHeight % s.gridK = 0 ∧
      i.lastHeight-i.parentHeight ≤ s.maxBatchBlocks ∧
      (_root_.Etna.Design.recordAt s i.parentHeight).isSome = _root_.Bool.true ∧
      (((_root_.Etna.Design.recordAt s i.parentHeight).getD _root_.Inhabited.default).generation = s.generation ∨
        i.parentHeight = s.origin.height) ∧
      s.head ≤ i.forcedInclusionHead ∧ i.forcedInclusionHead ≤ s.tail ∧
      i.forcedInclusionHead-s.head ≤ i.lastHeight-s.checkpoint.height ∧
      i.l1ReferenceBlockNumber < e.blockNumber ∧
      e.blockNumber-i.l1ReferenceBlockNumber ≤ 8191 ∧ e.referenceHashAvailable = _root_.Bool.true ∧
      1 ≤ e.blobHashes.length ∧ e.blobHashes.length ≤ 6 := Iff.rfl

theorem leaves_ok_iff (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
    (leaves : _root_.List _root_.Etna.Design.Leaf) :
    _root_.Etna.Design.LeavesOK s i leaves ↔
      leaves.length = _root_.Etna.Design.gridCount s.gridK i.parentHeight i.lastHeight ∧
      (i.parentHeight < s.checkpoint.height →
        leaves.getD ((s.checkpoint.height-i.parentHeight)/s.gridK-1) _root_.Inhabited.default =
          _root_.Etna.Design.cutLeaf s.checkpoint.height
            ⟨(_root_.Etna.Design.currentRecord s).elHash,(_root_.Etna.Design.currentRecord s).cometHash,
              (_root_.Etna.Design.currentRecord s).cursor⟩) ∧
      (_root_.Etna.Design.currentRecord s).cursor = s.head := Iff.rfl

theorem precheck_iff (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
    (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv) :
    _root_.Etna.Design.Precheck s i leaves e ↔ _root_.Etna.Design.BaseOK s i e ∧ _root_.Etna.Design.LeavesOK s i leaves :=
  Iff.rfl

theorem landing_allowed_iff (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
    (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv) :
    _root_.Etna.Design.LandingAllowed s i leaves e ↔
      _root_.Etna.Design.Precheck s i leaves e ∧ _root_.Etna.Design.dualOK e.proofs = _root_.Bool.true ∧
      e.certificate = _root_.Etna.Design.statementData s i (_root_.Etna.Design.leavesHash s i leaves) e := Iff.rfl

theorem on_grid_iff (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.OnGrid s ↔
      s.checkpoint.height % s.gridK = 0 ∧ ∀ r ∈ s.records, r.height % s.gridK = 0 := Iff.rfl

theorem state_valid_iff (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.Settlement.StateValid s ↔
      _root_.Etna.Design.recordAt s s.checkpoint.height = _root_.Option.some s.checkpoint ∧ s.checkpoint.cursor = s.head ∧
      _root_.Etna.Design.OnGrid s ∧ (s.records.map _root_.Etna.Design.Checkpoint.height).Nodup ∧
      ∀ r ∈ s.records, r.height ≤ s.checkpoint.height := Iff.rfl

theorem fee_conserved_iff (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.FeeConserved s ↔ s.feeAdmissions+s.forcedETH = s.ethBalance+s.swept := Iff.rfl

theorem double_sign_eq (deployment : _root_.Etna.Design.Domain) (currentGeneration : _root_.Nat)
    (a b : _root_.Etna.Design.Staking.Vote) :
    _root_.Etna.Design.Staking.doubleSign deployment currentGeneration a b =
      _root_.Decidable.decide (a.domain = deployment ∧ b.domain = deployment ∧ a.generation = b.generation ∧
        a.generation ≤ currentGeneration ∧ a.height = b.height ∧ a.round = b.round ∧
        a.kind = b.kind ∧ (a.kind = 1 ∨ a.kind = 2) ∧ a.blockId ≠ b.blockId) := rfl

theorem inbox_initialized_eq (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.Staking.inboxInitialized s = s.origins.any (fun pair => pair.1 == 0) := rfl

theorem confirmable_iff (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.Staking.Confirmable s b ↔
      _root_.Etna.Design.Staking.inboxInitialized s = _root_.Bool.true ∧ s.entered = _root_.Bool.false ∧
      b.released = _root_.Bool.false ∧ b.exitAt ≠ _root_.Etna.Design.Staking.noExit ∧ b.exitAt ≤ s.snapshot := Iff.rfl

theorem withdrawable_iff (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (atL1 caller now delay : _root_.Nat) :
    _root_.Etna.Design.Staking.Withdrawable s b atL1 caller now delay ↔
      s.entered = _root_.Bool.false ∧ b.released = _root_.Bool.false ∧ atL1+delay ≤ now ∧
      atL1+delay < _root_.Etna.Design.limit256 ∧ (b.stake+b.pendingTopUp = 0 ∨ caller = b.owner) := Iff.rfl

/-- Pending deposits remain principal for all liability and payment operations. -/
theorem bond_balance_eq (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.Staking.Bond.balance b = b.stake+b.pendingTopUp := rfl

/-- Deposit guards and metadata update; no Inbox-initialization or free-slot requirement. -/
theorem top_up_eq (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (caller amount now activationDelay : _root_.Nat) :
    _root_.Etna.Design.Staking.topUp s b caller amount now activationDelay =
      if s.entered = _root_.Bool.false ∧ caller = b.owner ∧ b.released = _root_.Bool.false ∧ b.activeFrom ≤ now ∧
          0 < b.stake ∧ b.exitAt = _root_.Etna.Design.Staking.noExit ∧ b.pendingTopUp = 0 ∧ 0 < amount ∧
          b.stake+b.pendingTopUp+amount < _root_.Etna.Design.limit256 ∧
          0 < activationDelay ∧ now+activationDelay < _root_.Etna.Design.limit48 then
        _root_.Option.some { b with pendingTopUp := amount,topUpReadyAtL1 := now+activationDelay }
      else _root_.Option.none := rfl

theorem activate_top_up_eq (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (now : _root_.Nat) :
    _root_.Etna.Design.Staking.activateTopUp s b now =
      if s.entered = _root_.Bool.false ∧ b.released = _root_.Bool.false ∧ 0 < b.pendingTopUp ∧
          b.exitAt = _root_.Etna.Design.Staking.noExit ∧ b.topUpReadyAtL1 ≤ now ∧
          b.stake+b.pendingTopUp < _root_.Etna.Design.limit256 then
        _root_.Option.some { b with stake := b.stake+b.pendingTopUp,pendingTopUp := 0,topUpReadyAtL1 := 0 }
      else _root_.Option.none := rfl

theorem withdraw_eq (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (caller now delay : _root_.Nat) :
    _root_.Etna.Design.Staking.withdraw s b caller now delay =
      match b.confirmedAt with
      | .none => _root_.Option.none
      | .some atL1 => if _root_.Etna.Design.Staking.Withdrawable s b atL1 caller now delay then
          _root_.Option.some (⟨0,0,0,0,0,_root_.Bool.true,_root_.Option.none,0,0⟩,b.stake+b.pendingTopUp)
        else _root_.Option.none := rfl

/-- The bounty and sink split consume effective plus pending principal. -/
theorem slash_double_eq (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (now bountyBps : _root_.Nat) :
    _root_.Etna.Design.Staking.slashDouble s b now bountyBps =
      if _root_.Etna.Design.Staking.inboxInitialized s = _root_.Bool.true ∧
          b.released = _root_.Bool.false ∧ 0 < b.stake+b.pendingTopUp ∧ bountyBps ≤ 10000 then
        _root_.Option.some
          ({ b with stake := 0,pendingTopUp := 0,topUpReadyAtL1 := 0,exitAt := _root_.Min.min b.exitAt now },
            _root_.Etna.Design.Staking.fraction (b.stake+b.pendingTopUp) bountyBps,
            b.stake+b.pendingTopUp-_root_.Etna.Design.Staking.fraction (b.stake+b.pendingTopUp) bountyBps)
      else _root_.Option.none := rfl

theorem forfeit_penalty_eq (balance bps : _root_.Nat) :
    _root_.Etna.Design.Staking.forfeitPenalty balance bps = (balance*bps+9999)/10000 := rfl

/-- Fixed-rate, one-shot authenticated forfeiture deducts effective stake first and pays
the sink; readiness clears only when pending principal is exhausted. -/
theorem forfeit_eq (s : _root_.Etna.Design.State) (b : _root_.Etna.Design.Staking.Bond)
    (entryKey now timestamp validUntil bps : _root_.Nat) (owner unused externalOK : _root_.Bool) :
    _root_.Etna.Design.Staking.forfeit s b entryKey now timestamp validUntil bps owner unused externalOK =
      if _root_.Etna.Design.Staking.inboxInitialized s = _root_.Bool.true ∧
          s.entered = _root_.Bool.false ∧ owner = _root_.Bool.true ∧ b.released = _root_.Bool.false ∧
          b.key = entryKey ∧ unused = _root_.Bool.true ∧ 0 < b.stake+b.pendingTopUp ∧
          timestamp ≤ validUntil ∧ 0 < bps ∧ bps ≤ 10000 ∧ externalOK = _root_.Bool.true then
        let penalty := _root_.Etna.Design.Staking.forfeitPenalty (b.stake+b.pendingTopUp) bps
        let pending := b.pendingTopUp-(penalty-b.stake)
        _root_.Option.some
          ({ b with
            stake := b.stake-penalty,pendingTopUp := pending,
            topUpReadyAtL1 := (if pending = 0 then 0 else b.topUpReadyAtL1),
            exitAt := _root_.Min.min b.exitAt now },penalty)
      else _root_.Option.none := rfl

theorem register_allowed_iff (s : _root_.Etna.Design.RegistryHistory.State) (key amount now : _root_.Nat) :
    _root_.Etna.Design.RegistryHistory.RegisterAllowed s key amount now ↔
      _root_.Etna.Design.RegistryHistory.lastBlock s ≤ now ∧ key ≠ 0 ∧ key ∉ s.usedKeys ∧ s.minStake ≤ amount ∧
      0 < s.minStake ∧ 0 < s.activationDelay ∧ now+s.activationDelay < _root_.Etna.Design.Staking.noExit ∧
      (_root_.Etna.Design.RegistryHistory.allocation s).1 < (_root_.Etna.Design.RegistryHistory.allocation s).2.2 ∧
      (_root_.Etna.Design.RegistryHistory.allocation s).2.2 ≤ 4096 ∧
      (s.slots (_root_.Etna.Design.RegistryHistory.allocation s).1).released = _root_.Bool.true := Iff.rfl

theorem keys_valid_iff (s : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.KeysValid s ↔ s.nextId ≤ 4096 ∧ s.usedKeys.Nodup := Iff.rfl

theorem identities_valid_iff (s : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.IdentitiesValid s ↔
      ∀ id, id < s.nextId → (s.slots id).released = _root_.Bool.false → (s.slots id).key ∈ s.usedKeys := Iff.rfl

theorem ordered_iff (history : _root_.List _root_.Etna.Design.RegistryHistory.Snapshot) :
    _root_.Etna.Design.RegistryHistory.Ordered history ↔ history.Pairwise (fun a b => b.block < a.block) := Iff.rfl

theorem current_snapshot_iff (s : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.CurrentSnapshot s ↔
      (s.history.head?).map _root_.Etna.Design.RegistryHistory.Snapshot.entries =
          _root_.Option.some (_root_.Etna.Design.RegistryHistory.entries s) ∨
        (s.nextId = 0 ∧ s.history = []) := Iff.rfl

theorem inbox_valid_iff (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.ProtocolState.InboxValid s ↔
      _root_.Etna.Design.Settlement.StateValid s ∧ _root_.Etna.Design.FeeConserved s ∧ s.head ≤ s.tail ∧
      ∀ record ∈ s.records, record.cursor ≤ s.tail :=
  ⟨fun h => ⟨h.1,h.2,h.3,h.4⟩,fun h => ⟨h.1,h.2.1,h.2.2.1,h.2.2.2⟩⟩

theorem registry_valid_iff (s : _root_.Etna.Design.RegistryHistory.State) (block : _root_.Nat) :
    _root_.Etna.Design.ProtocolState.RegistryValid s block ↔
      _root_.Etna.Design.RegistryHistory.KeysValid s ∧ _root_.Etna.Design.RegistryHistory.IdentitiesValid s ∧
      _root_.Etna.Design.RegistryHistory.Ordered s.history ∧ _root_.Etna.Design.RegistryHistory.CurrentSnapshot s ∧
      _root_.Etna.Design.RegistryHistory.lastBlock s ≤ block :=
  ⟨fun h => ⟨h.1,h.2,h.3,h.4,h.5⟩,fun h => ⟨h.1,h.2.1,h.2.2.1,h.2.2.2.1,h.2.2.2.2⟩⟩

theorem core_iff (w : _root_.Etna.Design.ProtocolState.World) :
    _root_.Etna.Design.ProtocolState.Core w ↔
      _root_.Etna.Design.ProtocolState.InboxValid w.inbox ∧
      _root_.Etna.Design.ProtocolState.RegistryValid w.registry w.l1Block ∧
      w.queue.map _root_.Prod.fst = _root_.List.range w.inbox.tail :=
  ⟨fun h => ⟨h.1,h.2,h.3⟩,fun h => ⟨h.1,h.2.1,h.2.2⟩⟩

/-- The forced-inclusion block rule (§7.2) that `valid_iff` composes. -/
theorem forced_step_eq (cursor tail anchor delay : _root_.Nat) (w : _root_.Option _root_.Etna.Design.Forced.Witness)
    (execution : _root_.Etna.Design.Forced.Singleton) :
    _root_.Etna.Design.Forced.step cursor tail anchor delay w execution =
      if cursor ≥ tail then
        if w.isNone then _root_.Etna.Design.Forced.Result.accepted cursor else _root_.Etna.Design.Forced.Result.rejected
      else match w with
      | .none => _root_.Etna.Design.Forced.Result.rejected
      | .some w =>
        if w.index ≠ cursor ∨ !w.storageAuthenticated ∨ w.rawBytes > 8192 ∨
          (w.rawBytes ≠ 0 ∧ w.rawHash ≠ w.stored.txHash) then _root_.Etna.Design.Forced.Result.rejected
        else if w.firstHash = _root_.Option.some w.stored.txHash ∧ w.firstCanonical = _root_.Bool.true ∧
            w.firstBytes ≤ 8192 then _root_.Etna.Design.Forced.Result.accepted (cursor+1)
        else if anchor < w.stored.timestamp+delay then _root_.Etna.Design.Forced.Result.accepted cursor
        else if w.rawHash ≠ w.stored.txHash ∨ w.rawBytes > 8192 then _root_.Etna.Design.Forced.Result.rejected
        else if w.canonical = _root_.Bool.false then _root_.Etna.Design.Forced.Result.accepted (cursor+1)
        else match execution with
          | .unavailable => _root_.Etna.Design.Forced.Result.waiting
          | .completedRetained | .inconsistent => _root_.Etna.Design.Forced.Result.rejected
          | .completedEmpty => _root_.Etna.Design.Forced.Result.accepted (cursor+1) := rfl

theorem node_valid_iff (r : _root_.Etna.Design.BlockValidity.Rules) (localHash : _root_.Nat → _root_.Etna.Design.Hash)
    (ownFinalized : _root_.Etna.Design.BlockValidity.Anchor → Prop) (p : _root_.Etna.Design.BlockValidity.Header)
    (b : _root_.Etna.Design.BlockValidity.Block) :
    _root_.Etna.Design.BlockValidity.NodeValid r localHash ownFinalized p b ↔
      _root_.Etna.Design.BlockValidity.Valid r p b ∧ ownFinalized b.header.anchor ∧
      b.header.anchor.checkpointHeight ≤ p.height ∧
      b.header.anchor.checkpointHash = localHash b.header.anchor.checkpointHeight := Iff.rfl

/-- The election function and every helper it reads (4.3): eligibility, stake-then-key rank,
selection, power, its sum and the CometBFT power cap. -/
theorem election_eq (unit minimum cutoff nMax : _root_.Nat) (e a b : _root_.Etna.Design.Committee.Entry)
    (entries : _root_.List _root_.Etna.Design.Committee.Entry) :
    _root_.Etna.Design.Committee.eligible unit minimum cutoff e =
      _root_.Decidable.decide (e.activeFrom ≤ cutoff ∧ cutoff < e.exitAt ∧ _root_.Max.max minimum unit ≤ e.stake) ∧
    _root_.Etna.Design.Committee.rank a b =
      _root_.Decidable.decide (b.stake < a.stake ∨ (a.stake = b.stake ∧ a.key ≤ b.key)) ∧
    _root_.Etna.Design.Committee.chosen unit minimum cutoff nMax entries =
      (((entries.filter (_root_.Etna.Design.Committee.eligible unit minimum cutoff)).mergeSort
        _root_.Etna.Design.Committee.rank).take nMax).mergeSort (fun x y => _root_.Decidable.decide (x.key ≤ y.key)) ∧
    _root_.Etna.Design.Committee.power unit e = e.stake/unit ∧
    _root_.Etna.Design.Committee.totalPower unit entries = (entries.map (_root_.Etna.Design.Committee.power unit)).sum ∧
    _root_.Etna.Design.Committee.maxPower = (2^63-1)/8 ∧
    _root_.Etna.Design.Committee.election unit minimum cutoff nMax entries =
      if 0 < unit ∧ unit ≤ minimum ∧ 1 ≤ nMax ∧ nMax ≤ 4096 ∧
          ((entries.filter (_root_.Etna.Design.Committee.eligible unit minimum cutoff)).map
            _root_.Etna.Design.Committee.Entry.key).Nodup ∧
          _root_.Etna.Design.Committee.chosen unit minimum cutoff nMax entries ≠ [] ∧
          (∀ x ∈ _root_.Etna.Design.Committee.chosen unit minimum cutoff nMax entries,
            0 < _root_.Etna.Design.Committee.power unit x) ∧
          _root_.Etna.Design.Committee.totalPower unit (_root_.Etna.Design.Committee.chosen unit minimum cutoff nMax entries) ≤
            _root_.Etna.Design.Committee.maxPower
      then _root_.Option.some (_root_.Etna.Design.Committee.chosen unit minimum cutoff nMax entries)
      else _root_.Option.none := ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- FI admission and sweeping read the Inbox's own fee, threshold and recipient immutables. -/
theorem forced_fee_eq (s : _root_.Etna.Design.State) (base threshold pending rawBytes paid : _root_.Nat)
    (refundOK transferOK : _root_.Bool) :
    _root_.Etna.Design.Forced.admissionFee base threshold pending = base*(threshold+pending)/threshold*1000000000 ∧
    _root_.Etna.Design.Forced.enqueue s rawBytes paid refundOK =
      (if s.entered = _root_.Bool.false ∧ s.forcedThreshold > 0 ∧ rawBytes ≤ 8192 ∧ s.head ≤ s.tail ∧
          s.tail+1 < _root_.Etna.Design.limit48 ∧
          _root_.Etna.Design.Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head) ≤ paid ∧
          s.ethBalance+_root_.Etna.Design.Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head) <
            _root_.Etna.Design.limit256 ∧
          (paid = _root_.Etna.Design.Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head) ∨
            refundOK = _root_.Bool.true) then
        _root_.Option.some { s with
          tail := s.tail+1,
          feeAdmissions := s.feeAdmissions+_root_.Etna.Design.Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head),
          ethBalance := s.ethBalance+_root_.Etna.Design.Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head) }
      else _root_.Option.none) ∧
    _root_.Etna.Design.Forced.sweep s transferOK =
      if s.entered = _root_.Bool.false ∧ s.protocolFeeRecipient ≠ 0 ∧ transferOK = _root_.Bool.true then
        _root_.Option.some { s with ethBalance := 0,swept := s.swept+s.ethBalance }
      else _root_.Option.none := ⟨rfl,rfl,rfl⟩

/-- Registration and every public registry edit read the registry's own minimum, delays,
bounty and signature adapter; no call input carries them. -/
theorem registry_transitions_eq (s r : _root_.Etna.Design.RegistryHistory.State) (inbox : _root_.Etna.Design.State)
    (key owner amount now id caller snapshot : _root_.Nat) (b : _root_.Etna.Design.Staking.Bond)
    (a v : _root_.Etna.Design.Staking.Vote) (sigA sigB : _root_.Etna.Design.Hash)
    (action : _root_.Etna.Design.RegistryHistory.Edit) :
    _root_.Etna.Design.RegistryHistory.register s key owner amount now =
      (if _root_.Etna.Design.RegistryHistory.RegisterAllowed s key amount now then
        _root_.Option.some (_root_.Etna.Design.RegistryHistory.finish s now
          { _root_.Etna.Design.RegistryHistory.writeSlot s (_root_.Etna.Design.RegistryHistory.allocation s).1
              ⟨key,owner,amount,now+s.activationDelay,_root_.Etna.Design.Staking.noExit,_root_.Bool.false,
                _root_.Option.none,0,0⟩ with
            nextId := (_root_.Etna.Design.RegistryHistory.allocation s).2.2,
            free := (_root_.Etna.Design.RegistryHistory.allocation s).2.1,usedKeys := key :: s.usedKeys })
      else _root_.Option.none) ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b (.requestExit caller) =
      _root_.Etna.Design.Staking.requestExit b caller now r.exitDelay ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b .confirm = _root_.Etna.Design.Staking.confirmExit inbox b now ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b (.withdraw caller) =
      (_root_.Etna.Design.Staking.withdraw inbox b caller now r.withdrawalDelay).map _root_.Prod.fst ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b (.topUp caller amount) =
      _root_.Etna.Design.Staking.topUp inbox b caller amount now r.activationDelay ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b .activateTopUp =
      _root_.Etna.Design.Staking.activateTopUp inbox b now ∧
    (∀ entryKey incidentId validUntil timestamp registryOwner externalOK,
      _root_.Etna.Design.RegistryHistory.editBond r inbox now b
        (.forfeit entryKey incidentId validUntil timestamp registryOwner externalOK) =
      (_root_.Etna.Design.Staking.forfeit inbox b entryKey now timestamp validUntil r.forfeitBps registryOwner
        (_root_.Decidable.decide (entryKey ∉ r.forfeited)) externalOK).map _root_.Prod.fst) ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b (.slash a v sigA sigB) =
      (if r.verify b.key a sigA = _root_.Bool.true ∧ r.verify b.key v sigB = _root_.Bool.true ∧
          _root_.Etna.Design.Staking.doubleSign inbox.domain inbox.generation a v = _root_.Bool.true then
        (_root_.Etna.Design.Staking.slashDouble inbox b now r.slashBountyBps).map (fun x => x.1)
      else _root_.Option.none) ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b .forceExit =
      (if b.released = _root_.Bool.false then _root_.Option.some (_root_.Etna.Design.Staking.exclude b now)
      else _root_.Option.none) ∧
    _root_.Etna.Design.RegistryHistory.editBond r inbox now b (.recheck snapshot) =
      _root_.Option.some (_root_.Etna.Design.Staking.rollbackBySnapshot snapshot b) ∧
    _root_.Etna.Design.RegistryHistory.forfeitFlags s action =
      (match action with
        | .forfeit entryKey _ _ _ _ _ => entryKey :: s.forfeited
        | _ => s.forfeited) ∧
    _root_.Etna.Design.RegistryHistory.edit s inbox id now action =
      if id < s.nextId ∧ _root_.Etna.Design.RegistryHistory.lastBlock s ≤ now ∧ inbox.entered = _root_.Bool.false then
        (_root_.Etna.Design.RegistryHistory.editBond s inbox now (s.slots id) action).map fun x =>
          _root_.Etna.Design.RegistryHistory.finish s now
            { _root_.Etna.Design.RegistryHistory.writeSlot s id x with
              free := if x.released && !(s.slots id).released then s.free ++ [id] else s.free,
              forfeited := _root_.Etna.Design.RegistryHistory.forfeitFlags s action }
      else _root_.Option.none := ⟨rfl,rfl,rfl,rfl,rfl,rfl,fun _ _ _ _ _ _ => rfl,rfl,rfl,rfl,by cases action <;> rfl,rfl⟩

/-- The combined recovery reads the fixed Keccak constants from the World's adapters. -/
theorem recover_eq (w : _root_.Etna.Design.ProtocolState.World) (a : _root_.Etna.Design.Recovery.Request)
    (r : _root_.Etna.Design.Origin) (owner externalOK : _root_.Bool) :
    _root_.Etna.Design.ProtocolState.recover w a r owner externalOK =
      (_root_.Etna.Design.Recovery.recover (_root_.Etna.Design.ProtocolState.recoveryView w) a w.adapters.recovery r
        owner externalOK).map (_root_.Etna.Design.ProtocolState.recovered w a r) := rfl

/-- Nonce and expiry are checked against current state and execution-time Unix seconds. -/
theorem authorization_allowed_iff (s : _root_.Etna.Design.State)
    (a : _root_.Etna.Design.Recovery.Request) (timestamp : _root_.Nat) :
    _root_.Etna.Design.Recovery.AuthorizationAllowed s a timestamp ↔
      _root_.Etna.Design.Staking.inboxInitialized s = _root_.Bool.true ∧ a.nonce = s.recoveryNonce ∧
      s.recoveryNonce+1 < _root_.Etna.Design.limit256 ∧ a.validUntil < _root_.Etna.Design.limit256 ∧
      timestamp ≤ a.validUntil := Iff.rfl

theorem nonce_mutable_iff (s : _root_.Etna.Design.State) :
    _root_.Etna.Design.Recovery.NonceMutable s ↔
      _root_.Etna.Design.Staking.inboxInitialized s = _root_.Bool.true ∧ s.entered = _root_.Bool.false ∧
      s.recoveryNonce+1 < _root_.Etna.Design.limit256 := Iff.rfl

theorem invalidation_eq (s : _root_.Etna.Design.State) (w : _root_.Etna.Design.ProtocolState.World)
    (expected now : _root_.Nat) (owner : _root_.Bool) :
    _root_.Etna.Design.Recovery.applyInvalidation s = { s with recoveryNonce := s.recoveryNonce+1 } ∧
    _root_.Etna.Design.Recovery.invalidateRecoveryNonce s expected owner =
      (if owner = _root_.Bool.true ∧ expected = s.recoveryNonce ∧ _root_.Etna.Design.Recovery.NonceMutable s then
        _root_.Option.some (_root_.Etna.Design.Recovery.applyInvalidation s)
      else _root_.Option.none) ∧
    _root_.Etna.Design.ProtocolState.invalidateRecoveryNonce w expected now owner =
      (_root_.Etna.Design.Recovery.invalidateRecoveryNonce w.inbox expected owner).map
        (fun t => _root_.Etna.Design.ProtocolState.landed w t now) := ⟨rfl,rfl,rfl⟩

/-- The public rollback boundary fails atomically at initialization/reentrancy/nonce failure. -/
theorem checked_rollback_eq (w : _root_.Etna.Design.ProtocolState.World)
    (trusted : _root_.Etna.Design.Checkpoint) (snapshot now : _root_.Nat) :
    _root_.Etna.Design.ProtocolState.rollback w trusted snapshot now =
      if _root_.Etna.Design.Recovery.NonceMutable w.inbox then
        _root_.Option.some (_root_.Etna.Design.ProtocolState.applyRollback w trusted snapshot now)
      else _root_.Option.none := rfl

/-- Recovery's execution-time checks (8.3): owner, expected state, generation and
origin bounds, list validity, FI-clear range and nonce/expiry authorization. -/
theorem recovery_allowed_iff (w : _root_.Etna.Design.Recovery.World) (a : _root_.Etna.Design.Recovery.Request)
    (cfg : _root_.Etna.Design.Recovery.Config) (r : _root_.Etna.Design.Origin) (owner : _root_.Bool) :
    _root_.Etna.Design.Recovery.Allowed w a cfg r owner ↔
      owner = _root_.Bool.true ∧ w.inbox.entered = _root_.Bool.false ∧
      a.generation = w.inbox.generation ∧ a.checkpoint = w.inbox.checkpoint.height ∧
      w.inbox.generation+1 < _root_.Etna.Design.limit48 ∧
      r.height = w.inbox.checkpoint.height ∧ r.l1Block < _root_.Etna.Design.limit48 ∧
      r.timestamp < _root_.Etna.Design.limit256 ∧ 3 ≤ w.inbox.epochLen ∧
      ¬ (w.inbox.origins.map _root_.Prod.fst).contains (w.inbox.generation+1) ∧
      a.exclusions.Pairwise (fun x y => x.bondId < y.bondId) ∧
      (a.exclusions.all (fun x => w.registry.any (fun (id,e) => id == x.bondId && e.key == x.entryKey)) =
        _root_.Bool.true) ∧
      (a.exclusions.all (fun x => x.entryKey != cfg.releasedKey) = _root_.Bool.true) ∧
      a.fiToClear.Pairwise (· < ·) ∧
      (∀ i ∈ a.fiToClear, w.inbox.head ≤ i ∧ i < w.inbox.tail ∧
        (w.queue.map _root_.Prod.fst).contains i = _root_.Bool.true) ∧
      _root_.Etna.Design.Recovery.AuthorizationAllowed w.inbox a r.timestamp := Iff.rfl

/-- Recovery's transition (8 steps 2-5) and the combined-machine wrappers it runs through: the
exclusion and FI-clear updates, the R election, the new schedule and origin, the journaled
`recover` and the registry-side forced exits. -/
theorem recovery_eq (w : _root_.Etna.Design.Recovery.World) (pw : _root_.Etna.Design.ProtocolState.World)
    (a : _root_.Etna.Design.Recovery.Request) (cfg : _root_.Etna.Design.Recovery.Config) (r : _root_.Etna.Design.Origin)
    (owner externalOK : _root_.Bool) (s : _root_.Etna.Design.Recovery.World)
    (xs : _root_.List _root_.Etna.Design.Recovery.Exclusion) (id key now emptyHash : _root_.Nat)
    (indices : _root_.List _root_.Nat) (entry : _root_.Etna.Design.Forced.Entry)
    (record : _root_.Etna.Design.Committee.Record) (registry : _root_.Etna.Design.RegistryHistory.State)
    (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.Recovery.exclusionApplies xs id key = xs.any (fun x => x.bondId == id && x.entryKey == key) ∧
    _root_.Etna.Design.Recovery.excludedRegistry w xs now =
      w.registry.map (fun (id,e) =>
        (id,if _root_.Etna.Design.Recovery.exclusionApplies xs id e.key then { e with exitAt := _root_.Min.min e.exitAt now }
          else e)) ∧
    _root_.Etna.Design.Recovery.clearedQueue w indices emptyHash =
      w.queue.map (fun (id,e) => (id,if indices.contains id then _root_.Etna.Design.Forced.clear emptyHash e else e)) ∧
    _root_.Etna.Design.Forced.clear emptyHash entry = { entry with txHash := emptyHash } ∧
    _root_.Etna.Design.Recovery.selection w a r =
      _root_.Etna.Design.Committee.election w.inbox.configuration.unit w.inbox.configuration.minimum r.l1Block
        w.inbox.configuration.nMax
        ((_root_.Etna.Design.Recovery.excludedRegistry w a.exclusions r.l1Block).map _root_.Prod.snd) ∧
    _root_.Etna.Design.Committee.recoverySchedule record = ⟨record,_root_.Option.none⟩ ∧
    _root_.Etna.Design.Recovery.applyRecovery w a cfg r =
      { inbox := { w.inbox with
          generation := w.inbox.generation+1,recoveryNonce := w.inbox.recoveryNonce+1,
          origin := r,origins := w.inbox.origins ++ [(w.inbox.generation+1,r)] },
        registry := _root_.Etna.Design.Recovery.excludedRegistry w a.exclusions r.l1Block,
        queue := _root_.Etna.Design.Recovery.clearedQueue w a.fiToClear cfg.emptyHash,
        schedule := _root_.Etna.Design.Committee.recoverySchedule
          ⟨w.inbox.checkpoint.height/w.inbox.epochLen,r.l1Block,
            (_root_.Etna.Design.Recovery.selection w a r).getD []⟩ } ∧
    _root_.Etna.Design.Recovery.recover w a cfg r owner externalOK =
      (if _root_.Etna.Design.Recovery.Allowed w a cfg r owner ∧ externalOK = _root_.Bool.true then
        _root_.Option.some (_root_.Etna.Design.Recovery.applyRecovery w a cfg r)
      else _root_.Option.none) ∧
    _root_.Etna.Design.ProtocolState.recoveryView pw =
      ⟨pw.inbox,_root_.Etna.Design.RegistryHistory.registryView pw.registry,pw.queue,pw.schedule⟩ ∧
    _root_.Etna.Design.ProtocolState.recovered pw a r s =
      ⟨s.inbox,_root_.Etna.Design.RegistryHistory.forceExclusions pw.registry a.exclusions r.l1Block,s.queue,
        s.schedule,r.l1Block,pw.adapters⟩ ∧
    _root_.Etna.Design.RegistryHistory.registryView registry =
      (_root_.List.range registry.nextId).map
        (fun id => (id,_root_.Etna.Design.Staking.toEntry (registry.slots id))) ∧
    _root_.Etna.Design.RegistryHistory.forceExclusions registry xs now =
      _root_.Etna.Design.RegistryHistory.finish registry now
        { registry with
          slots := fun id =>
            if _root_.Etna.Design.Recovery.exclusionApplies xs id (registry.slots id).key then
              _root_.Etna.Design.Staking.exclude (registry.slots id) now
            else registry.slots id } ∧
    _root_.Etna.Design.Staking.exclude b now = { b with exitAt := _root_.Min.min b.exitAt now } :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- §8 verifier-failure rollback: the World wrapper, the Inbox restore and the registry
confirmation re-check against the restored snapshot. -/
theorem rollback_eq (w : _root_.Etna.Design.ProtocolState.World) (s : _root_.Etna.Design.State)
    (registry : _root_.Etna.Design.RegistryHistory.State) (trusted : _root_.Etna.Design.Checkpoint)
    (snapshot now : _root_.Nat) (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.ProtocolState.applyRollback w trusted snapshot now =
      { w with
        inbox := _root_.Etna.Design.Recovery.rollbackInbox w.inbox trusted snapshot,
        registry := _root_.Etna.Design.RegistryHistory.recheckAll w.registry snapshot,
        l1Block := now } ∧
    _root_.Etna.Design.Recovery.rollbackInbox s trusted snapshot =
      { s with
        recoveryNonce := s.recoveryNonce+1,
        checkpoint := trusted,head := trusted.cursor,snapshot := snapshot,
        records := s.records.filter (fun r => r.height ≤ trusted.height),
        signals := s.signals.filter (fun g => g.height ≤ trusted.height) } ∧
    _root_.Etna.Design.RegistryHistory.recheckAll registry snapshot =
      { registry with slots := fun id => _root_.Etna.Design.Staking.rollbackBySnapshot snapshot (registry.slots id) } ∧
    _root_.Etna.Design.Staking.rollbackBySnapshot snapshot b =
      (match b.confirmedAt with
        | .some _ => if snapshot < b.exitAt then { b with confirmedAt := _root_.Option.none } else b
        | .none => b) := ⟨rfl,rfl,rfl,rfl⟩

/-- The combined machine's other transition targets: landing, registry, FI enqueue and sweep
wrappers, and which registry edits are public. -/
theorem world_transitions_eq (w : _root_.Etna.Design.ProtocolState.World) (s : _root_.Etna.Design.State)
    (registry : _root_.Etna.Design.RegistryHistory.State) (i : _root_.Etna.Design.LandInput)
    (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv)
    (action : _root_.Etna.Design.RegistryHistory.Edit) (hash timestamp now : _root_.Nat) :
    _root_.Etna.Design.ProtocolState.landed w s now = { w with inbox := s,l1Block := now } ∧
    _root_.Etna.Design.ProtocolState.land w i leaves e =
      (_root_.Etna.Design.land w.inbox i leaves e).map
        (fun s => _root_.Etna.Design.ProtocolState.landed w s e.blockNumber) ∧
    _root_.Etna.Design.ProtocolState.registered w registry now = { w with registry := registry,l1Block := now } ∧
    _root_.Etna.Design.ProtocolState.publicEdit action =
      (match action with
        | .forceExit | .recheck _ => _root_.Bool.false
        | _ => _root_.Bool.true) ∧
    _root_.Etna.Design.ProtocolState.enqueued w s hash timestamp now =
      { w with inbox := s,queue := w.queue ++ [(w.inbox.tail,⟨hash,timestamp,now⟩)],l1Block := now } :=
  ⟨rfl,rfl,rfl,rfl,rfl⟩

/-- The Inbox landing transition (6.1): record lookup, the statement it certifies, the stored
record and SignalService checkpoint, and the update. -/
theorem landing_eq (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
    (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv)
    (root : _root_.Etna.Design.CutHash) (h : _root_.Nat) :
    _root_.Etna.Design.recordAt s h = s.records.find? (fun r => r.height == h) ∧
    _root_.Etna.Design.currentRecord s =
      (_root_.Etna.Design.recordAt s s.checkpoint.height).getD _root_.Inhabited.default ∧
    _root_.Etna.Design.statementData s i root e =
      ⟨s.domain,s.generation,s.committeeConfig,
        ((_root_.Etna.Design.recordAt s i.parentHeight).getD _root_.Inhabited.default).elHash,
        ((_root_.Etna.Design.recordAt s i.parentHeight).getD _root_.Inhabited.default).cometHash,
        ((_root_.Etna.Design.recordAt s i.parentHeight).getD _root_.Inhabited.default).cursor,
        i,e.referenceHash,e.blobHashes,root⟩ ∧
    _root_.Etna.Design.leavesHash s i leaves = ⟨s.generation,i.parentHeight,i.lastHeight,leaves⟩ ∧
    _root_.Etna.Design.landedCheckpoint s i =
      ⟨i.lastHeight,i.lastBlockHash,i.lastCometHash,i.forcedInclusionHead,s.generation,s.checkpoint.height⟩ ∧
    _root_.Etna.Design.landedSignal i = ⟨i.lastHeight,i.lastBlockHash,i.lastStateRoot⟩ ∧
    _root_.Etna.Design.applyLanding s i =
      { s with
        checkpoint := _root_.Etna.Design.landedCheckpoint s i,
        records := _root_.Etna.Design.landedCheckpoint s i :: s.records,
        head := i.forcedInclusionHead,
        snapshot := i.activeCommitteeSnapshot,
        signals := s.signals ++ [_root_.Etna.Design.landedSignal i] } ∧
    _root_.Etna.Design.land s i leaves e =
      if _root_.Etna.Design.LandingAllowed s i leaves e then
        _root_.Option.some (_root_.Etna.Design.applyLanding s i)
      else _root_.Option.none := ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Which committee governs a height (4.2/4.4): epochs, switch heights, the selection rule,
the generation's initial committee, ordinary rotation and the activation choice. -/
theorem committee_schedule_eq (c : _root_.Etna.Design.Consensus.Context) (h t target cutoff : _root_.Nat) :
    _root_.Etna.Design.Consensus.epoch c h = (h-1)/c.epochLen ∧
    _root_.Etna.Design.Consensus.switchHeight c t = t*c.epochLen-1 ∧
    _root_.Etna.Design.Consensus.selected c target cutoff =
      ⟨target,cutoff,_root_.Etna.Design.Committee.chosen c.unit c.minimum cutoff c.nMax (c.registry cutoff)⟩ ∧
    _root_.Etna.Design.Consensus.initial c =
      _root_.Etna.Design.Consensus.selected c (if c.generation = 0 then 0 else c.originHeight/c.epochLen)
        (if c.generation = 0 then c.genesisCutoff else c.originBlock) ∧
    _root_.Etna.Design.Consensus.normal c t =
      _root_.Etna.Design.Consensus.selected c t (_root_.Max.max (c.anchorAt (t*c.epochLen-2)) c.originBlock) ∧
    _root_.Etna.Design.Consensus.activeAt c h =
      if c.originHeight < _root_.Etna.Design.Consensus.switchHeight c (_root_.Etna.Design.Consensus.epoch c h) then
        _root_.Etna.Design.Consensus.normal c (_root_.Etna.Design.Consensus.epoch c h)
      else _root_.Etna.Design.Consensus.initial c := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Registry checkpoints (4.1): one checkpoint per entry-changing L1 block, the latest-at-cutoff
lookup, the election view of the slots, and the slot/allocation helpers every edit uses. -/
theorem registry_history_eq (now cutoff id : _root_.Nat) (entries : _root_.List _root_.Etna.Design.Committee.Entry)
    (head : _root_.Etna.Design.RegistryHistory.Snapshot)
    (rest history : _root_.List _root_.Etna.Design.RegistryHistory.Snapshot)
    (s t : _root_.Etna.Design.RegistryHistory.State) (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.RegistryHistory.recordSnapshot now entries [] = [⟨now,entries⟩] ∧
    _root_.Etna.Design.RegistryHistory.recordSnapshot now entries (head :: rest) =
      (if head.block = now then ⟨now,entries⟩ :: rest else ⟨now,entries⟩ :: head :: rest) ∧
    _root_.Etna.Design.RegistryHistory.latestSnapshot history cutoff =
      history.find? (fun cp => _root_.Decidable.decide (cp.block ≤ cutoff)) ∧
    _root_.Etna.Design.RegistryHistory.entries s =
      (_root_.List.range s.nextId).map (fun id => _root_.Etna.Design.Staking.toEntry (s.slots id)) ∧
    _root_.Etna.Design.Staking.toEntry b = ⟨b.key,b.stake,b.activeFrom,b.exitAt⟩ ∧
    _root_.Etna.Design.RegistryHistory.lastBlock s = ((s.history.head?).getD _root_.Inhabited.default).block ∧
    _root_.Etna.Design.RegistryHistory.finish s now t =
      { t with
        history :=
          if _root_.Etna.Design.RegistryHistory.entries t = _root_.Etna.Design.RegistryHistory.entries s then
            s.history
          else _root_.Etna.Design.RegistryHistory.recordSnapshot now (_root_.Etna.Design.RegistryHistory.entries t)
            s.history } ∧
    _root_.Etna.Design.RegistryHistory.writeSlot s id b = { s with slots := fun i => if i = id then b else s.slots i } ∧
    _root_.Etna.Design.RegistryHistory.allocation s =
      (match s.free with
        | [] => (s.nextId,[],s.nextId+1)
        | id :: rest => (id,rest,s.nextId)) := ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Typed history lookups (HS-03): the saturating archive anchor and the registry snapshot
read at a cutoff. -/
theorem history_lookup_eq (floor a h cutoff : _root_.Nat) (rest archive : _root_.List _root_.Nat)
    (registry : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.HistoricalContext.prefixAnchor floor [] h = floor ∧
    _root_.Etna.Design.HistoricalContext.prefixAnchor floor (a :: rest) 0 = _root_.Max.max floor a ∧
    _root_.Etna.Design.HistoricalContext.prefixAnchor floor (a :: rest) (h+1) =
      _root_.Etna.Design.HistoricalContext.prefixAnchor (_root_.Max.max floor a) rest h ∧
    _root_.Etna.Design.HistoricalContext.anchorAt archive h =
      _root_.Etna.Design.HistoricalContext.prefixAnchor 0 archive h ∧
    _root_.Etna.Design.HistoricalContext.registryAt registry cutoff =
      ((_root_.Etna.Design.RegistryHistory.latestSnapshot registry.history cutoff).map
        _root_.Etna.Design.RegistryHistory.Snapshot.entries).getD [] :=
  ⟨by cases h <;> rfl,rfl,rfl,rfl,rfl⟩

/-- Constructor set of the combined machine: `Step w t` holds exactly when one of the eight
transactions (landing, registration, public registry edit, FI enqueue, sweep, recovery,
nonce invalidation, rollback) with its premises produces `t`. Adding, removing or weakening a constructor, or
changing the World it produces, breaks this characterization. -/
theorem step_iff (w t : _root_.Etna.Design.ProtocolState.World) :
    _root_.Etna.Design.ProtocolState.Step w t ↔
      (∃ (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
          (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv),
        w.l1Block ≤ e.blockNumber ∧ _root_.Etna.Design.land w.inbox i leaves e = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.landed w s e.blockNumber) ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (key owner amount now : _root_.Nat),
        w.l1Block ≤ now ∧
        _root_.Etna.Design.RegistryHistory.register w.registry key owner amount now = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.registered w s now) ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (id now : _root_.Nat)
          (action : _root_.Etna.Design.RegistryHistory.Edit),
        w.l1Block ≤ now ∧ _root_.Etna.Design.ProtocolState.publicEdit action = _root_.Bool.true ∧
        _root_.Etna.Design.RegistryHistory.edit w.registry w.inbox id now action = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.registered w s now) ∨
      (∃ (s : _root_.Etna.Design.State) (hash timestamp now raw paid : _root_.Nat) (refund : _root_.Bool),
        w.l1Block ≤ now ∧ now < _root_.Etna.Design.limit48 ∧ timestamp < _root_.Etna.Design.limit48 ∧
        _root_.Etna.Design.Forced.enqueue w.inbox raw paid refund = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.enqueued w s hash timestamp now) ∨
      (∃ (s : _root_.Etna.Design.State) (now : _root_.Nat) (transfer : _root_.Bool),
        w.l1Block ≤ now ∧ _root_.Etna.Design.Forced.sweep w.inbox transfer = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.landed w s now) ∨
      (∃ (s : _root_.Etna.Design.Recovery.World) (a : _root_.Etna.Design.Recovery.Request)
          (r : _root_.Etna.Design.Origin) (owner externalOK : _root_.Bool),
        w.l1Block ≤ r.l1Block ∧
        _root_.Etna.Design.Recovery.recover (_root_.Etna.Design.ProtocolState.recoveryView w) a w.adapters.recovery r
          owner externalOK = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.recovered w a r s) ∨
      (∃ (s : _root_.Etna.Design.State) (expected now : _root_.Nat) (owner : _root_.Bool),
        w.l1Block ≤ now ∧
        _root_.Etna.Design.Recovery.invalidateRecoveryNonce w.inbox expected owner = _root_.Option.some s ∧
        t = _root_.Etna.Design.ProtocolState.landed w s now) ∨
      (∃ (trusted : _root_.Etna.Design.Checkpoint) (snapshot now : _root_.Nat),
        w.l1Block ≤ now ∧ _root_.Etna.Design.recordAt w.inbox trusted.height = _root_.Option.some trusted ∧
        _root_.Etna.Design.Recovery.NonceMutable w.inbox ∧
        t = _root_.Etna.Design.ProtocolState.applyRollback w trusted snapshot now) := by
  constructor
  · intro change
    cases change with
    | landing time ok => exact .inl ⟨_,_,_,_,time,ok,rfl⟩
    | registration time ok => exact .inr (.inl ⟨_,_,_,_,_,time,ok,rfl⟩)
    | modification time callable ok => exact .inr (.inr (.inl ⟨_,_,_,_,time,callable,ok,rfl⟩))
    | enqueue time blockRange timestampRange ok =>
      exact .inr (.inr (.inr (.inl ⟨_,_,_,_,_,_,_,time,blockRange,timestampRange,ok,rfl⟩)))
    | sweep time ok => exact .inr (.inr (.inr (.inr (.inl ⟨_,_,_,time,ok,rfl⟩))))
    | recovery time ok => exact .inr (.inr (.inr (.inr (.inr (.inl ⟨_,_,_,_,_,time,ok,rfl⟩)))))
    | invalidation time ok => exact .inr (.inr (.inr (.inr (.inr (.inr (.inl ⟨_,_,_,_,time,ok,rfl⟩))))))
    | rollback trusted snapshot now time retained authorized =>
      exact .inr (.inr (.inr (.inr (.inr (.inr (.inr ⟨trusted,snapshot,now,time,retained,authorized,rfl⟩))))))
  · rintro (⟨s,i,leaves,e,time,ok,rfl⟩ | ⟨s,key,owner,amount,now,time,ok,rfl⟩ |
      ⟨s,id,now,action,time,callable,ok,rfl⟩ | ⟨s,hash,timestamp,now,raw,paid,refund,time,blockRange,timestampRange,ok,rfl⟩ |
      ⟨s,now,transfer,time,ok,rfl⟩ | ⟨s,a,r,owner,externalOK,time,ok,rfl⟩ |
      ⟨s,expected,now,owner,time,ok,rfl⟩ | ⟨trusted,snapshot,now,time,retained,authorized,rfl⟩)
    · exact .landing time ok
    · exact .registration time ok
    · exact .modification time callable ok
    · exact .enqueue time blockRange timestampRange ok
    · exact .sweep time ok
    · exact .recovery time ok
    · exact .invalidation time ok
    · exact .rollback trusted snapshot now time retained authorized

/-- Constructor set of combined traces: reflexive, or a trace followed by one `Step`. -/
theorem trace_iff (first t : _root_.Etna.Design.ProtocolState.World) :
    _root_.Etna.Design.ProtocolState.Trace first t ↔
      first = t ∨
        ∃ w, _root_.Etna.Design.ProtocolState.Trace first w ∧ _root_.Etna.Design.ProtocolState.Step w t := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | step prior change => exact .inr ⟨_,prior,change⟩
  · rintro (rfl | ⟨w,prior,change⟩)
    · exact .refl _
    · exact .step prior change

/-- Constructor set of sound steps: a landing whose proof certifies its snapshot at or below
its reference block, a rollback restoring a snapshot below its own block, or any `Step` that
leaves slot 284 untouched. -/
theorem sound_step_iff (w t : _root_.Etna.Design.ProtocolState.World) :
    _root_.Etna.Design.ProtocolState.SoundStep w t ↔
      (∃ (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput)
          (leaves : _root_.List _root_.Etna.Design.Leaf) (e : _root_.Etna.Design.LandingEnv),
        w.l1Block ≤ e.blockNumber ∧ _root_.Etna.Design.land w.inbox i leaves e = _root_.Option.some s ∧
        i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber ∧
        t = _root_.Etna.Design.ProtocolState.landed w s e.blockNumber) ∨
      (∃ (trusted : _root_.Etna.Design.Checkpoint) (snapshot now : _root_.Nat),
        w.l1Block ≤ now ∧ _root_.Etna.Design.recordAt w.inbox trusted.height = _root_.Option.some trusted ∧
        snapshot < now ∧ _root_.Etna.Design.Recovery.NonceMutable w.inbox ∧
        t = _root_.Etna.Design.ProtocolState.applyRollback w trusted snapshot now) ∨
      (_root_.Etna.Design.ProtocolState.Step w t ∧ t.inbox.snapshot = w.inbox.snapshot) := by
  constructor
  · intro change
    cases change with
    | landing time ok certified => exact .inl ⟨_,_,_,_,time,ok,certified,rfl⟩
    | rollback trusted snapshot now time retained written authorized =>
      exact .inr (.inl ⟨trusted,snapshot,now,time,retained,written,authorized,rfl⟩)
    | framed change same => exact .inr (.inr ⟨change,same⟩)
  · rintro (⟨s,i,leaves,e,time,ok,certified,rfl⟩ |
      ⟨trusted,snapshot,now,time,retained,written,authorized,rfl⟩ | ⟨change,same⟩)
    · exact .landing time ok certified
    · exact .rollback trusted snapshot now time retained written authorized
    · exact .framed change same

/-- Constructor set of sound traces: reflexive, or a sound trace followed by one `SoundStep`. -/
theorem sound_trace_iff (first t : _root_.Etna.Design.ProtocolState.World) :
    _root_.Etna.Design.ProtocolState.SoundTrace first t ↔
      first = t ∨
        ∃ w, _root_.Etna.Design.ProtocolState.SoundTrace first w ∧ _root_.Etna.Design.ProtocolState.SoundStep w t := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | step prior change => exact .inr ⟨_,prior,change⟩
  · rintro (rfl | ⟨w,prior,change⟩)
    · exact .refl _
    · exact .step prior change

/-- Constructor set of registry steps: a registration, any registry edit, or the rollback
confirmation re-check. -/
theorem registry_step_iff (s t : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.Step s t ↔
      (∃ key owner amount now : _root_.Nat,
        _root_.Etna.Design.RegistryHistory.register s key owner amount now = _root_.Option.some t) ∨
      (∃ (inbox : _root_.Etna.Design.State) (id now : _root_.Nat) (action : _root_.Etna.Design.RegistryHistory.Edit),
        _root_.Etna.Design.RegistryHistory.edit s inbox id now action = _root_.Option.some t) ∨
      (∃ snapshot : _root_.Nat, t = _root_.Etna.Design.RegistryHistory.recheckAll s snapshot) := by
  constructor
  · intro change
    cases change with
    | registration ok => exact .inl ⟨_,_,_,_,ok⟩
    | modification ok => exact .inr (.inl ⟨_,_,_,_,ok⟩)
    | rollback snapshot => exact .inr (.inr ⟨snapshot,rfl⟩)
  · rintro (⟨key,owner,amount,now,ok⟩ | ⟨inbox,id,now,action,ok⟩ | ⟨snapshot,rfl⟩)
    · exact .registration ok
    · exact .modification ok
    · exact .rollback s snapshot

/-- Constructor set of registry traces: reflexive, or a trace followed by one registry step. -/
theorem registry_trace_iff (first t : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.Trace first t ↔
      first = t ∨
        ∃ s, _root_.Etna.Design.RegistryHistory.Trace first s ∧ _root_.Etna.Design.RegistryHistory.Step s t := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | step prior change => exact .inr ⟨_,prior,change⟩
  · rintro (rfl | ⟨s,prior,change⟩)
    · exact .refl _
    · exact .step prior change

/-- Constructor set of registry traces after a cutoff: registrations, edits and forced exits
in L1 blocks after the cutoff, and rollback re-checks. -/
theorem future_trace_iff (cutoff : _root_.Nat) (first t : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.RegistryHistory.FutureTrace cutoff first t ↔
      first = t ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (key owner amount now : _root_.Nat),
        _root_.Etna.Design.RegistryHistory.FutureTrace cutoff first s ∧ cutoff < now ∧
        _root_.Etna.Design.RegistryHistory.register s key owner amount now = _root_.Option.some t) ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (inbox : _root_.Etna.Design.State) (id now : _root_.Nat)
          (action : _root_.Etna.Design.RegistryHistory.Edit),
        _root_.Etna.Design.RegistryHistory.FutureTrace cutoff first s ∧ cutoff < now ∧
        _root_.Etna.Design.RegistryHistory.edit s inbox id now action = _root_.Option.some t) ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (xs : _root_.List _root_.Etna.Design.Recovery.Exclusion)
          (now : _root_.Nat),
        _root_.Etna.Design.RegistryHistory.FutureTrace cutoff first s ∧ cutoff < now ∧
        t = _root_.Etna.Design.RegistryHistory.forceExclusions s xs now) ∨
      (∃ (s : _root_.Etna.Design.RegistryHistory.State) (snapshot : _root_.Nat),
        _root_.Etna.Design.RegistryHistory.FutureTrace cutoff first s ∧
        t = _root_.Etna.Design.RegistryHistory.recheckAll s snapshot) := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | registration prior past ok => exact .inr (.inl ⟨_,_,_,_,_,prior,past,ok⟩)
    | modification prior past ok => exact .inr (.inr (.inl ⟨_,_,_,_,_,prior,past,ok⟩))
    | recovery xs now prior past => exact .inr (.inr (.inr (.inl ⟨_,xs,now,prior,past,rfl⟩)))
    | rollback snapshot prior => exact .inr (.inr (.inr (.inr ⟨_,snapshot,prior,rfl⟩)))
  · rintro (rfl | ⟨s,key,owner,amount,now,prior,past,ok⟩ | ⟨s,inbox,id,now,action,prior,past,ok⟩ |
      ⟨s,xs,now,prior,past,rfl⟩ | ⟨s,snapshot,prior,rfl⟩)
    · exact .refl _
    · exact .registration prior past ok
    · exact .modification prior past ok
    · exact .recovery xs now prior past
    · exact .rollback snapshot prior

/-- Constructor set of plain landing sequences: reflexive, or a sequence followed by one
accepted `land`. -/
theorem landing_trace_iff (start t : _root_.Etna.Design.State) :
    _root_.Etna.Design.Settlement.LandingTrace start t ↔
      start = t ∨
        ∃ (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput) (leaves : _root_.List _root_.Etna.Design.Leaf)
          (e : _root_.Etna.Design.LandingEnv),
          _root_.Etna.Design.Settlement.LandingTrace start s ∧
          _root_.Etna.Design.land s i leaves e = _root_.Option.some t := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | step prior accepted => exact .inr ⟨_,_,_,_,prior,accepted⟩
  · rintro (rfl | ⟨s,i,leaves,e,prior,accepted⟩)
    · exact .refl _
    · exact .step prior accepted

/-- Constructor set of certified landing sequences under one context: each accepted landing
is bound to a decoded valid batch whose rules use that context. -/
theorem certified_trace_iff (c : _root_.Etna.Design.Consensus.Context) (start t : _root_.Etna.Design.State) :
    _root_.Etna.Design.Settlement.CertifiedTrace c start t ↔
      start = t ∨
        ∃ (s : _root_.Etna.Design.State) (i : _root_.Etna.Design.LandInput) (leaves : _root_.List _root_.Etna.Design.Leaf)
          (e : _root_.Etna.Design.LandingEnv) (r : _root_.Etna.Design.BlockValidity.Rules)
          (p : _root_.Etna.Design.BlockValidity.Header) (bs : _root_.List _root_.Etna.Design.BlockValidity.Block)
          (blobs : _root_.List _root_.Etna.Design.Hash),
          _root_.Etna.Design.Settlement.CertifiedTrace c start s ∧
          _root_.Etna.Design.land s i leaves e = _root_.Option.some t ∧ r.consensus = c ∧
          _root_.Etna.Design.Settlement.BatchValid r p bs blobs ∧
          e.certificate = _root_.Etna.Design.Settlement.statement r p bs blobs := by
  constructor
  · intro trace
    cases trace with
    | refl => exact .inl rfl
    | step prior accepted context valid binding => exact .inr ⟨_,_,_,_,_,_,_,_,prior,accepted,context,valid,binding⟩
  · rintro (rfl | ⟨s,i,leaves,e,r,p,bs,blobs,prior,accepted,context,valid,binding⟩)
    · exact .refl _
    · exact .step prior accepted context valid binding

end Etna.Design.Contracts
