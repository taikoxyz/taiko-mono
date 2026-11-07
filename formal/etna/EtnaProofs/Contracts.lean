import EtnaModel.Committee
import EtnaModel.Consensus
import EtnaModel.Forced
import EtnaModel.RegistryHistory
import EtnaModel.Staking

/-! Independent unfolded semantic contracts for shared model definitions the current statements
use. Each pin restates its definition body and is closed by `rfl`/`Iff.rfl`, so weakening a
definition without editing its pin fails to build. Every identifier is written from `_root_`
so a same-named declaration in an `Etna.*` namespace cannot capture the pin. Pins constrain the
modeled definitions, not their correspondence to the prose specification. The review-surface
lock (scripts/review_surface.py) covers every definition the statements use; these pins add a
build-time check for the shared consensus, committee, staking and forced-inclusion core. -/
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

theorem dual_ok_eq (proofs : _root_.List (_root_.Etna.Design.Backend × _root_.Bool)) :
    _root_.Etna.Design.dualOK proofs =
      (_root_.Decidable.decide (proofs.length = 2) && proofs.all _root_.Prod.snd &&
        proofs.any (fun x => x.1 != .sgx) && _root_.Decidable.decide ((proofs.map _root_.Prod.fst).Nodup)) := rfl

theorem double_sign_eq (deployment : _root_.Etna.Design.Domain) (currentGeneration : _root_.Nat)
    (a b : _root_.Etna.Design.Staking.Vote) :
    _root_.Etna.Design.Staking.doubleSign deployment currentGeneration a b =
      _root_.Decidable.decide (a.domain = deployment ∧ b.domain = deployment ∧ a.generation = b.generation ∧
        a.generation ≤ currentGeneration ∧ a.height = b.height ∧ a.round = b.round ∧
        a.kind = b.kind ∧ (a.kind = 1 ∨ a.kind = 2) ∧ a.blockId ≠ b.blockId) := rfl

/-- Pending deposits remain principal for all liability and payment operations. -/
theorem bond_balance_eq (b : _root_.Etna.Design.Staking.Bond) :
    _root_.Etna.Design.Staking.Bond.balance b = b.stake+b.pendingTopUp := rfl

theorem forfeit_penalty_eq (balance bps : _root_.Nat) :
    _root_.Etna.Design.Staking.forfeitPenalty balance bps = (balance*bps+9999)/10000 := rfl

theorem ordered_iff (history : _root_.List _root_.Etna.Design.RegistryHistory.Snapshot) :
    _root_.Etna.Design.RegistryHistory.Ordered history ↔ history.Pairwise (fun a b => b.block < a.block) := Iff.rfl

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

end Etna.Design.Contracts
