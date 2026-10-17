// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaClaimReceiver, EtnaVaultProof, EtnaVaultTestBase } from "./L2FeeVaultTestBase.sol";
import {
    ContentLengthMismatch,
    EmptyItem,
    InvalidDataRemainder,
    InvalidHeader,
    UnexpectedList,
    UnexpectedString
} from "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPErrors.sol";
import { Vm, VmSafe } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { LibTrieProof } from "src/shared/libs/LibTrieProof.sol";
import { EtnaRewardProof } from "test/shared/EtnaRewardProof.sol";

/// @title L2FeeVaultLeanConformanceTest
/// @notice Executes canonical CLAIM rows through the actual L2FeeVault with real MPT proofs.
/// @dev The EIP-4788 roots contract is the canonical runtime the Etna genesis installs; roots are
/// written by its system caller. Recipients are the test base's receiver fixture. Prior claims run
/// through the same vault before the observed call. Logs and the call journal expose the observed
/// call's effects; committed flags apply the EVM journal rule to the call result.
contract L2FeeVaultLeanConformanceTest is EtnaVaultTestBase {
    // build_etna_genesis.py ROOTS_RUNTIME; its sha256 is asserted before every row.
    bytes private constant _ROOTS_RUNTIME =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500";
    bytes32 private constant _ROOTS_SHA256 =
        0xcb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d;
    address private constant _SYSTEM = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    uint256 private constant _ROOTS_BUFFER = 8191;
    bytes32 private constant _OTHER_ROOT = bytes32(uint256(123));
    bytes32 private constant _CLAIM_EVENT = keccak256("RewardClaimed(bytes32,address,uint256)");

    struct Row {
        string id;
        uint256 vaultL1ChainId;
        uint64 chainId;
        address vaultInbox;
        uint256 balance;
        bool entered;
        LibEtnaRewards.Receipt receipt;
        address ledgerAccount;
        uint256 ledgerSlot;
        LibEtnaRewards.Receipt ledgerReceipt;
        string accountProof;
        string storageProof;
        string root;
        uint256 anchorTimestamp;
        string recipient;
        address caller;
        bool hasPrior;
        LibEtnaRewards.Receipt prior;
        uint256 priorTimestamp;
        bool hasReentry;
        LibEtnaRewards.Receipt reentry;
        uint256 reentryTimestamp;
    }

    struct Observation {
        bool ok;
        string errorName;
        bytes rawReason;
        bytes32 batchId;
        bool claimed;
        bool claimedBefore;
        address paidTo;
        uint256 paidWei;
        uint256 vaultBefore;
        uint256 vaultBalance;
        uint256 recipientBefore;
        uint256 callerBefore;
        uint256 rewardEvents;
        bytes32 eventBatchId;
        address eventRecipient;
        uint256 eventAmount;
        uint256 rootQueries;
        uint256 recipientCalls;
        string nestedResult;
        bool callbackRan;
        bool callbackObservedClaimed;
    }

    /// @notice Runs all rows staged by the portable adapter; prints machine-readable observations.
    function test_claim_LeanCorpus() external {
        vm.pauseGasMetering();
        string memory path = vm.envOr("ETNA_CLAIM_CORPUS", string(""));
        if (bytes(path).length == 0) return;
        string memory json = vm.readFile(path);
        uint256 count;
        while (vm.keyExistsJson(json, string.concat("$[", vm.toString(count), "]"))) {
            uint256 snapshot = vm.snapshotState();
            this.executeLeanRow(json, string.concat("$[", vm.toString(count), "]"));
            assertTrue(vm.revertToStateAndDelete(snapshot), "isolated row restore");
            ++count;
        }
        assertGt(count, 0, "nonempty canonical CLAIM corpus");
        console2.log("CLAIM_CASE_COUNT", count);
    }

    /// @notice Isolates instrumentation memory per row; only this harness may enter it.
    /// @param _json The complete staged JSON array.
    /// @param _key The JSON path identifying this isolated row.
    function executeLeanRow(string calldata _json, string calldata _key) external {
        require(msg.sender == address(this), "self-only fixture");
        Row memory row = _readRow(_json, _key);
        (bytes[] memory account, bytes[] memory storageProof) = _configure(row);
        Observation memory o = _execute(row, account, storageProof);
        _assertBusiness(row, o);
        _print(row, o);
    }

    /// @dev Reads all frozen-schema fields explicitly; uint ranges are the adapter boundary.
    /// @param _json The complete staged JSON array.
    /// @param _key The path to the row.
    /// @return row_ The typed fixture row.
    function _readRow(
        string memory _json,
        string memory _key
    )
        private
        view
        returns (Row memory row_)
    {
        require(vm.parseJsonUint(_json, string.concat(_key, ".schemaVersion")) == 1, "schema");
        row_.id = vm.parseJsonString(_json, string.concat(_key, ".id"));
        string memory vault = string.concat(_key, ".vault");
        row_.vaultL1ChainId = vm.parseJsonUint(_json, string.concat(vault, ".l1ChainId"));
        row_.chainId = _uint64(vm.parseJsonUint(_json, string.concat(vault, ".chainId")));
        row_.vaultInbox = vm.parseJsonAddress(_json, string.concat(vault, ".inbox"));
        row_.balance = vm.parseJsonUint(_json, string.concat(vault, ".balanceWei"));
        row_.entered = vm.parseJsonBool(_json, string.concat(vault, ".entered"));
        row_.receipt = _readReceipt(_json, string.concat(_key, ".receipt"));
        string memory ledger = string.concat(_key, ".ledger");
        row_.ledgerAccount = vm.parseJsonAddress(_json, string.concat(ledger, ".account"));
        row_.ledgerSlot = vm.parseJsonUint(_json, string.concat(ledger, ".mappingSlot"));
        row_.ledgerReceipt = _readReceipt(_json, string.concat(ledger, ".receipt"));
        row_.accountProof = vm.parseJsonString(_json, string.concat(_key, ".accountProof"));
        row_.storageProof = vm.parseJsonString(_json, string.concat(_key, ".storageProof"));
        row_.root = vm.parseJsonString(_json, string.concat(_key, ".root"));
        row_.anchorTimestamp = vm.parseJsonUint(_json, string.concat(_key, ".anchorTimestamp"));
        row_.recipient = vm.parseJsonString(_json, string.concat(_key, ".recipient"));
        row_.caller = vm.parseJsonAddress(_json, string.concat(_key, ".caller"));
        row_.hasPrior = vm.keyExistsJson(_json, string.concat(_key, ".prior"));
        if (row_.hasPrior) {
            row_.prior = _readReceipt(_json, string.concat(_key, ".prior.receipt"));
            row_.priorTimestamp =
                vm.parseJsonUint(_json, string.concat(_key, ".prior.anchorTimestamp"));
        }
        row_.hasReentry = vm.keyExistsJson(_json, string.concat(_key, ".reentry"));
        if (row_.hasReentry) {
            row_.reentry = _readReceipt(_json, string.concat(_key, ".reentry.receipt"));
            row_.reentryTimestamp =
                vm.parseJsonUint(_json, string.concat(_key, ".reentry.anchorTimestamp"));
        }
        require(row_.hasReentry == _same(row_.recipient, "reentrant"), "reentry fixture");
    }

    /// @dev Reads one receipt object; numeric decimal strings are parsed losslessly.
    /// @param _json The staged JSON document.
    /// @param _key The receipt object path.
    /// @return r_ The typed receipt.
    function _readReceipt(
        string memory _json,
        string memory _key
    )
        private
        pure
        returns (LibEtnaRewards.Receipt memory r_)
    {
        r_.l1ChainId = vm.parseJsonUint(_json, string.concat(_key, ".l1ChainId"));
        r_.l2ChainId = _uint64(vm.parseJsonUint(_json, string.concat(_key, ".l2ChainId")));
        r_.inbox = vm.parseJsonAddress(_json, string.concat(_key, ".inbox"));
        r_.generation = _uint64(vm.parseJsonUint(_json, string.concat(_key, ".generation")));
        r_.parentHeight = _uint64(vm.parseJsonUint(_json, string.concat(_key, ".parentHeight")));
        r_.parentHash = vm.parseJsonBytes32(_json, string.concat(_key, ".parentHash"));
        r_.lastHeight = _uint64(vm.parseJsonUint(_json, string.concat(_key, ".lastHeight")));
        r_.lastBlockHash = vm.parseJsonBytes32(_json, string.concat(_key, ".lastBlockHash"));
        r_.l2RewardRecipient = vm.parseJsonAddress(_json, string.concat(_key, ".l2RewardRecipient"));
        r_.baseFeeAmount = vm.parseJsonUint(_json, string.concat(_key, ".baseFeeAmount"));
    }

    /// @dev Builds the row's actual world: vault, canonical roots, prior claim, proofs, recipient.
    /// @param _row The typed initial state and controlled external outcomes.
    /// @return account_ The account proof submitted by the observed call.
    /// @return storage_ The storage proof submitted by the observed call.
    function _configure(Row memory _row)
        private
        returns (bytes[] memory account_, bytes[] memory storage_)
    {
        vm.chainId(_row.chainId);
        vm.etch(ROOTS, _ROOTS_RUNTIME);
        assertEq(sha256(ROOTS.code), _ROOTS_SHA256, "canonical EIP-4788 runtime");
        _vault = new L2FeeVault(_row.vaultL1ChainId, _row.vaultInbox);
        vm.deal(address(_vault), _row.balance);
        if (_row.hasPrior) {
            EtnaVaultProof.Proof memory prior = EtnaVaultProof.proof(_row.prior);
            _publishRoot(_row.priorTimestamp, prior.root);
            _vault.claim(_row.prior, _row.priorTimestamp, prior.account, prior.storageProof);
        }
        bytes32 root;
        (root, account_, storage_) = EtnaRewardProof._proof(
            _row.ledgerAccount,
            keccak256(abi.encode(EtnaVaultProof.batchId(_row.ledgerReceipt), _row.ledgerSlot)),
            EtnaVaultProof.commitment(_row.ledgerReceipt)
        );
        _publishAnchor(_row, root, keccak256(storage_[0]));
        account_ = _shape(account_, _row.accountProof);
        storage_ = _shape(storage_, _row.storageProof);
        _installRecipient(_row);
        if (_row.entered) {
            // `_entered` is the vault's first declared state variable (slot 0, offset 0).
            assertEq(vm.load(address(_vault), bytes32(0)), bytes32(0), "unlocked vault guard");
            vm.store(address(_vault), bytes32(0), bytes32(uint256(1)));
        }
    }

    /// @dev Writes the observed call's anchored root through the canonical system-caller path.
    /// @param _row The row selecting the root mode and timestamp.
    /// @param _root The state root committing to the row's ledger.
    /// @param _storageRoot The ledger account's storage root.
    function _publishAnchor(Row memory _row, bytes32 _root, bytes32 _storageRoot) private {
        uint256 timestamp = _row.anchorTimestamp;
        if (_same(_row.root, "published")) {
            _publishRoot(timestamp, _root);
        } else if (_same(_row.root, "storage-root")) {
            _publishRoot(timestamp, _storageRoot);
        } else if (_same(_row.root, "zero")) {
            _publishRoot(timestamp, bytes32(0));
        } else if (_same(_row.root, "other")) {
            _publishRoot(timestamp, _OTHER_ROOT);
        } else if (_same(_row.root, "expired")) {
            _publishRoot(timestamp, _root);
            // A write one ring length later reuses the slot, so the old timestamp expires.
            _publishRoot(timestamp + _ROOTS_BUFFER, _OTHER_ROOT);
        } else {
            require(_same(_row.root, "missing"), "root mode");
        }
    }

    /// @dev Calls the canonical roots contract as the EIP-4788 system address at `_timestamp`.
    /// @param _timestamp The block timestamp the root is stored under.
    /// @param _root The stored root.
    function _publishRoot(uint256 _timestamp, bytes32 _root) private {
        vm.warp(_timestamp);
        vm.prank(_SYSTEM);
        (bool ok,) = ROOTS.call(abi.encode(_root));
        require(ok, "system root write");
    }

    /// @dev Applies one frozen proof-shape mode to a valid single-leaf proof.
    /// @param _proof The valid proof.
    /// @param _mode `valid`, `empty` or `corrupt` (last byte of the only node flipped).
    /// @return shaped_ The submitted proof.
    function _shape(
        bytes[] memory _proof,
        string memory _mode
    )
        private
        pure
        returns (bytes[] memory shaped_)
    {
        if (_same(_mode, "empty")) return new bytes[](0);
        if (_same(_mode, "corrupt")) {
            bytes memory node = _proof[0];
            node[node.length - 1] ^= 0x01;
        } else {
            require(_same(_mode, "valid"), "proof mode");
        }
        return _proof;
    }

    /// @dev Installs the test base's receiver at the receipt recipient for contract modes.
    /// @param _row The row selecting the recipient mode and nested claim.
    function _installRecipient(Row memory _row) private {
        if (_same(_row.recipient, "eoa")) return;
        address recipient = _row.receipt.l2RewardRecipient;
        vm.etch(recipient, address(new EtnaClaimReceiver()).code);
        bytes memory payload;
        if (_row.hasReentry) {
            EtnaVaultProof.Proof memory nested = EtnaVaultProof.proof(_row.reentry);
            _publishRoot(_row.reentryTimestamp, nested.root);
            payload = _payload(_row.reentry, _row.reentryTimestamp, nested);
        } else {
            require(_same(_row.recipient, "rejecting"), "recipient mode");
        }
        EtnaClaimReceiver(payable(recipient))
            .configure(
                _vault,
                EtnaVaultProof.batchId(_row.receipt),
                payload,
                _same(_row.recipient, "rejecting")
            );
    }

    /// @dev Records the actual call journal and logs around the observed claim only.
    /// @param _row The isolated case to execute and observe.
    /// @param _account The submitted account proof.
    /// @param _storage The submitted storage proof.
    /// @return o_ The observation.
    function _execute(
        Row memory _row,
        bytes[] memory _account,
        bytes[] memory _storage
    )
        private
        returns (Observation memory o_)
    {
        o_.batchId = EtnaVaultProof.batchId(_row.receipt);
        o_.claimedBefore = _vault.claimed(o_.batchId);
        o_.vaultBefore = address(_vault).balance;
        o_.recipientBefore = _row.receipt.l2RewardRecipient.balance;
        o_.callerBefore = _row.caller.balance;
        vm.recordLogs();
        vm.startStateDiffRecording();
        vm.resumeGasMetering();
        vm.prank(_row.caller);
        (bool ok, bytes memory reason) = address(_vault)
            .call(
                abi.encodeCall(
                    L2FeeVault.claim, (_row.receipt, _row.anchorTimestamp, _account, _storage)
                )
            );
        vm.pauseGasMetering();
        _accesses(o_, vm.stopAndReturnStateDiff());
        _logs(o_, vm.getRecordedLogs());
        o_.ok = ok;
        o_.rawReason = reason;
        o_.errorName = _classify(ok, reason);
        _commit(o_);
        o_.claimed = _vault.claimed(o_.batchId);
        o_.vaultBalance = address(_vault).balance;
        o_.nestedResult = "none";
        if (!_same(_row.recipient, "eoa")) {
            EtnaClaimReceiver receiver = EtnaClaimReceiver(payable(_row.receipt.l2RewardRecipient));
            o_.callbackRan = receiver.calls() != 0;
            o_.callbackObservedClaimed = receiver.observedClaimed();
            if (o_.callbackRan && _row.hasReentry) {
                o_.nestedResult = receiver.nestedSuccess()
                    ? "ok"
                    : _classify(false, abi.encodePacked(receiver.nestedError()));
            }
        }
    }

    /// @dev Counts the vault's executed EIP-4788 STATICCALLs and CALLs and sums its committed value
    /// calls. The journal holds every call frame the vault opens, including nested frames and calls
    /// that then failed (marked reverted). A debug trace is not used: decoding the MPT
    /// verification's steps needs more memory-expansion gas than the row frame has.
    /// @param _observation The observation populated in memory.
    /// @param _list The actual call and storage journal.
    function _accesses(
        Observation memory _observation,
        Vm.AccountAccess[] memory _list
    )
        private
        view
    {
        for (uint256 i; i < _list.length; ++i) {
            Vm.AccountAccess memory access = _list[i];
            if (access.accessor != address(_vault)) continue;
            if (access.kind == VmSafe.AccountAccessKind.StaticCall && access.account == ROOTS) {
                ++_observation.rootQueries;
            }
            if (access.kind != VmSafe.AccountAccessKind.Call) continue;
            // The vault's only CALL is the reward transfer; zero-value calls are counted too.
            ++_observation.recipientCalls;
            if (access.value > 0 && !access.reverted) {
                _observation.paidTo = access.account;
                _observation.paidWei += access.value;
            }
        }
    }

    /// @dev Reads the vault's raw RewardClaimed logs; the last one belongs to the outer call.
    /// @param _observation The observation populated in memory.
    /// @param _list The raw executed logs, including reverted-frame logs.
    function _logs(Observation memory _observation, Vm.Log[] memory _list) private view {
        for (uint256 i; i < _list.length; ++i) {
            if (
                _list[i].emitter != address(_vault) || _list[i].topics.length == 0
                    || _list[i].topics[0] != _CLAIM_EVENT
            ) continue;
            ++_observation.rewardEvents;
            _observation.eventBatchId = _list[i].topics[1];
            _observation.eventRecipient = address(uint160(uint256(_list[i].topics[2])));
            _observation.eventAmount = abi.decode(_list[i].data, (uint256));
        }
    }

    /// @dev Applies the EVM journal rule: a reverted call commits no log or value transfer.
    /// @param _observation The observation to normalize.
    function _commit(Observation memory _observation) private pure {
        if (_observation.ok) return;
        assertEq(_observation.paidWei, 0, "no committed transfer after outer revert");
        _observation.paidTo = address(0);
        _observation.rewardEvents = 0;
        _observation.eventBatchId = bytes32(0);
        _observation.eventRecipient = address(0);
        _observation.eventAmount = 0;
    }

    /// @dev Maps the exact observed top-level revert without hiding unknown failures.
    /// @param _ok Whether the actual call returned successfully.
    /// @param _reason The actual revert data.
    /// @return error_ The frozen schema error classification.
    function _classify(bool _ok, bytes memory _reason) private pure returns (string memory error_) {
        if (_ok) return "none";
        require(_reason.length >= 4, "unclassified short claim revert");
        // Deliberately extract the ABI selector; unknown errors fail classification below.
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 selector = bytes4(_reason);
        if (selector == L2FeeVault.ReentrantClaim.selector) return "reentrant";
        if (selector == L2FeeVault.InvalidReceipt.selector) return "invalid-receipt";
        if (selector == L2FeeVault.EmptyAccountProof.selector) return "empty-account-proof";
        if (selector == L2FeeVault.AlreadyClaimed.selector) return "already-claimed";
        if (selector == L2FeeVault.InvalidAnchorRoot.selector) return "invalid-anchor-root";
        if (selector == L2FeeVault.RewardTransferFailed.selector) return "transfer";
        if (_proofFailure(selector, _reason)) return "proof";
        revert("unclassified actual claim selector");
    }

    /// @dev LibTrieProof, SecureMerkleTrie (string reasons) and RLPReader rejections.
    /// @param _selector The revert selector.
    /// @param _reason The full revert data.
    /// @return proof_ Whether the revert comes from storage/account proof verification.
    function _proofFailure(
        bytes4 _selector,
        bytes memory _reason
    )
        private
        pure
        returns (bool proof_)
    {
        if (
            _selector == LibTrieProof.LTP_INVALID_ACCOUNT_PROOF.selector
                || _selector == LibTrieProof.LTP_INVALID_INCLUSION_PROOF.selector
                || _selector == EmptyItem.selector || _selector == UnexpectedString.selector
                || _selector == InvalidDataRemainder.selector
                || _selector == UnexpectedList.selector
                || _selector == ContentLengthMismatch.selector
                || _selector == InvalidHeader.selector
        ) return true;
        if (_selector != bytes4(keccak256("Error(string)")) || _reason.length < 68) return false;
        bytes memory body = new bytes(_reason.length - 4);
        for (uint256 i; i < body.length; ++i) {
            body[i] = _reason[i + 4];
        }
        bytes memory message = bytes(abi.decode(body, (string)));
        bytes memory prefix = bytes("MerkleTrie: ");
        if (message.length < prefix.length) return false;
        for (uint256 i; i < prefix.length; ++i) {
            if (message[i] != prefix[i]) return false;
        }
        return true;
    }

    /// @dev Checks input-derived business rules on the actual result; outcomes are compared with
    /// Lean separately. A revert must leave the batch flag and every balance unchanged.
    /// @param _row The original typed fixture inputs.
    /// @param _observation The actual observations.
    function _assertBusiness(Row memory _row, Observation memory _observation) private view {
        string memory id = _row.id;
        assertEq(_row.caller.balance, _observation.callerBefore, string.concat(id, ": caller"));
        if (!_observation.ok) {
            assertEq(
                _observation.claimed,
                _observation.claimedBefore,
                string.concat(id, ": rollback claimed flag")
            );
            assertEq(
                _observation.vaultBalance,
                _observation.vaultBefore,
                string.concat(id, ": rollback vault balance")
            );
            assertEq(
                _row.receipt.l2RewardRecipient.balance,
                _observation.recipientBefore,
                string.concat(id, ": rollback recipient balance")
            );
            return;
        }
        LibEtnaRewards.Receipt memory r = _row.receipt;
        assertFalse(_observation.claimedBefore, "successful claim requires an unclaimed batch");
        assertTrue(
            r.l1ChainId == _row.vaultL1ChainId && r.l2ChainId == _row.chainId
                && r.inbox == _row.vaultInbox && r.lastHeight > r.parentHeight
                && r.l2RewardRecipient != address(0),
            "successful claim requires the configured receipt identity"
        );
        assertFalse(
            _same(_row.accountProof, "empty"), "successful claim requires a nonempty account proof"
        );
        assertTrue(
            _same(_row.root, "published"), "successful claim requires the published anchored root"
        );
        assertTrue(
            _row.ledgerAccount == _row.vaultInbox && _row.ledgerSlot == LibEtnaRewards.RECEIPTS_SLOT
                && EtnaVaultProof.commitment(_row.ledgerReceipt) == EtnaVaultProof.commitment(r),
            "successful claim requires the anchored receipt commitment"
        );
        assertTrue(_observation.claimed, "successful claim marks its batch");
        assertEq(_observation.paidWei, r.baseFeeAmount, "successful claim pays the receipt amount");
        assertEq(
            _observation.paidTo,
            r.baseFeeAmount == 0 ? address(0) : r.l2RewardRecipient,
            "successful claim pays the receipt recipient"
        );
        assertEq(
            _observation.vaultBefore - _observation.vaultBalance,
            r.baseFeeAmount,
            "vault balance pays exactly the amount"
        );
        assertEq(
            _observation.recipientCalls,
            r.baseFeeAmount == 0 ? 0 : 1,
            "one recipient call, none for a zero amount"
        );
        assertEq(_observation.rewardEvents, 1, "one committed RewardClaimed event");
        assertEq(_observation.eventBatchId, _observation.batchId, "event batch id");
        if (_observation.callbackRan) {
            assertTrue(_observation.callbackObservedClaimed, "claimed flag precedes the transfer");
        }
        if (_row.hasReentry) {
            assertTrue(_same(_observation.nestedResult, "reentrant"), "nested claim hits the guard");
        }
    }

    /// @dev Emits canonical scalar observations for independent Lean comparison.
    /// @param _row The original fixture inputs and identifier.
    /// @param _observation The actual observations to serialize.
    function _print(Row memory _row, Observation memory _observation) private {
        string memory k = string.concat("claim-", _row.id);
        vm.serializeUint(k, "schemaVersion", 1);
        vm.serializeString(k, "id", _row.id);
        vm.serializeString(k, "status", _observation.ok ? "ok" : "revert");
        vm.serializeString(k, "error", _observation.errorName);
        vm.serializeBytes32(k, "batchId", _observation.batchId);
        vm.serializeBool(k, "claimed", _observation.claimed);
        vm.serializeAddress(k, "paidTo", _observation.paidTo);
        vm.serializeString(k, "paidWei", vm.toString(_observation.paidWei));
        vm.serializeString(k, "vaultBalanceWei", vm.toString(_observation.vaultBalance));
        vm.serializeUint(k, "rewardEvents", _observation.rewardEvents);
        vm.serializeBytes32(k, "eventBatchId", _observation.eventBatchId);
        vm.serializeAddress(k, "eventRecipient", _observation.eventRecipient);
        vm.serializeString(k, "eventAmount", vm.toString(_observation.eventAmount));
        vm.serializeUint(k, "rootQueries", _observation.rootQueries);
        vm.serializeUint(k, "recipientCalls", _observation.recipientCalls);
        vm.serializeString(k, "nestedResult", _observation.nestedResult);
        vm.serializeBool(k, "priorClaimed", _row.hasPrior);
        vm.serializeBool(k, "callbackRan", _observation.callbackRan);
        vm.serializeBool(k, "callbackObservedClaimed", _observation.callbackObservedClaimed);
        vm.serializeBytes(k, "rawReason", _observation.rawReason);
        vm.serializeAddress(k, "vault", address(_vault));
        string memory output = vm.serializeString(
            k,
            "fixtureBoundary",
            "real-L2FeeVault;canonical-EIP-4788-runtime;real-single-leaf-MPT;test-base-receiver"
        );
        console2.log(string.concat("CLAIM_OBSERVATION ", output));
    }

    /// @dev Narrows a schema uint64 field, rejecting wider values instead of truncating.
    /// @param _value The parsed value.
    /// @return value_ The checked uint64.
    function _uint64(uint256 _value) private pure returns (uint64 value_) {
        require(_value <= type(uint64).max, "uint64 field");
        // The preceding bound makes this narrowing lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(_value);
    }

    /// @dev Compares a schema enum string.
    /// @param _a The first enum string.
    /// @param _b The second enum string.
    /// @return equal_ Whether the strings have matching hashes.
    function _same(string memory _a, string memory _b) private pure returns (bool equal_) {
        return keccak256(bytes(_a)) == keccak256(bytes(_b));
    }
}
