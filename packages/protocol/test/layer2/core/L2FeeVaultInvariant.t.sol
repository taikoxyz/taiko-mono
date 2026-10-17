// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EtnaVaultProof, EtnaVaultTestBase, MockEtnaRoots } from "./L2FeeVaultTestBase.sol";
import { StdInvariant } from "forge-std/src/StdInvariant.sol";
import { Test } from "forge-std/src/Test.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";

contract EtnaVaultHandler is Test {
    address private constant _ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    L2FeeVault private immutable _vault;
    LibEtnaRewards.Receipt[] private _receipts;
    mapping(bytes32 id => bool paid) public modelClaimed;
    uint256 public credited;
    uint256 public paid;
    uint256 public forced;
    bool public modelMismatch;
    bool public unexpectedSuccess;

    constructor(L2FeeVault _target) {
        _vault = _target;
    }

    function recordCredit(uint256 _seed) external {
        if (_receipts.length >= 32) return;
        uint64 index = uint64(_receipts.length);
        uint256 amount = bound(_seed, 0, 1 ether);
        // The independently recorded ledger creates disjoint ranges exactly once.
        LibEtnaRewards.Receipt memory r =
            EtnaVaultProof.receipt(index, address(uint160(0x10000 + index)), amount);
        _receipts.push(r);
        credited += amount;
        vm.deal(address(_vault), address(_vault).balance + amount);
        EtnaVaultProof.Proof memory p = EtnaVaultProof.proof(r);
        MockEtnaRoots(_ROOTS).setRoot(uint256(index) + 100, p.root);
    }

    function claimBatch(uint256 _seed) external {
        if (_receipts.length == 0) return;
        uint256 index = _seed % _receipts.length;
        LibEtnaRewards.Receipt memory r = _receipts[index];
        EtnaVaultProof.Proof memory p = EtnaVaultProof.proof(r);
        bytes32 id = EtnaVaultProof.batchId(r);
        uint256 beforeBalance = r.l2RewardRecipient.balance;
        (bool ok,) = address(_vault)
            .call(abi.encodeCall(L2FeeVault.claim, (r, index + 100, p.account, p.storageProof)));
        uint256 delta = r.l2RewardRecipient.balance - beforeBalance;
        if (ok) {
            if (modelClaimed[id] || delta != r.baseFeeAmount) modelMismatch = true;
            modelClaimed[id] = true;
            paid += delta;
        } else if (!modelClaimed[id]) {
            modelMismatch = true;
        }
        if (_vault.claimed(id) != modelClaimed[id]) modelMismatch = true;
    }

    function forgeAmount(uint256 _seed) external {
        if (_receipts.length == 0) return;
        uint256 index = _seed % _receipts.length;
        LibEtnaRewards.Receipt memory r = _receipts[index];
        EtnaVaultProof.Proof memory p = EtnaVaultProof.proof(r);
        r.baseFeeAmount++;
        (bool ok,) = address(_vault)
            .call(abi.encodeCall(L2FeeVault.claim, (r, index + 100, p.account, p.storageProof)));
        if (ok) unexpectedSuccess = true;
    }

    function forceEther(uint256 _seed) external {
        uint256 amount = bound(_seed, 0, 1 ether);
        // No external call models both forced Ether and execution-layer balance credits.
        // Unlike recordCredit this deliberately does not add anything to credited.
        forced += amount;
        vm.deal(address(_vault), address(_vault).balance + amount);
    }

    function count() external view returns (uint256 count_) {
        return _receipts.length;
    }

    function receipt(uint256 _index) external view returns (LibEtnaRewards.Receipt memory r_) {
        return _receipts[_index];
    }
}

/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract L2FeeVaultInvariantTest is StdInvariant, EtnaVaultTestBase {
    EtnaVaultHandler private _handler;

    function setUp() public override {
        super.setUp();
        vm.deal(address(_vault), 0);
        _handler = new EtnaVaultHandler(_vault);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = EtnaVaultHandler.recordCredit.selector;
        selectors[1] = EtnaVaultHandler.claimBatch.selector;
        selectors[2] = EtnaVaultHandler.forgeAmount.selector;
        selectors[3] = EtnaVaultHandler.forceEther.selector;
        targetSelector(FuzzSelector({ addr: address(_handler), selectors: selectors }));
        targetContract(address(_handler));
        // Foundry gas refunds must never credit a tracked recipient or the vault.
        targetSender(makeAddr("Etna vault invariant sender"));
    }

    function invariant_paymentsNeverExceedRecordedBasefeeCredits() external view {
        assertLe(_handler.paid(), _handler.credited());
        assertFalse(_handler.unexpectedSuccess());
        assertFalse(_handler.modelMismatch());
        assertEq(address(_vault).balance + _handler.paid(), _handler.credited() + _handler.forced());
    }

    function invariant_receiptsAreDisjointAndClaimStateMatchesPayments() external view {
        assertFalse(_handler.modelMismatch());
        assertFalse(_handler.unexpectedSuccess());
        uint256 expectedPaid;
        uint256 expectedCredit;
        uint64 previousLast;
        for (uint256 i; i < _handler.count(); ++i) {
            LibEtnaRewards.Receipt memory r = _handler.receipt(i);
            assertEq(r.parentHeight, previousLast);
            assertGt(r.lastHeight, r.parentHeight);
            previousLast = r.lastHeight;
            bytes32 id = EtnaVaultProof.batchId(r);
            bool didPay = _handler.modelClaimed(id);
            assertEq(_vault.claimed(id), didPay);
            assertEq(r.l2RewardRecipient.balance, didPay ? r.baseFeeAmount : 0);
            expectedCredit += r.baseFeeAmount;
            if (didPay) expectedPaid += r.baseFeeAmount;
        }
        assertEq(_handler.credited(), expectedCredit);
        assertEq(_handler.paid(), expectedPaid);
    }
}
