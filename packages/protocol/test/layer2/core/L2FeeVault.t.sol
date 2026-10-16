// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    EtnaClaimReceiver,
    EtnaVaultProof,
    EtnaVaultTestBase,
    ForceEtnaEther,
    MockEtnaRoots
} from "./L2FeeVaultTestBase.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { EtnaRewardProof } from "test/shared/EtnaRewardProof.sol";

contract L2FeeVaultTest is EtnaVaultTestBase {
    function test_constructor_RevertWhen_ChainOrInboxIsZero() external {
        vm.expectRevert(L2FeeVault.InvalidL1Identity.selector);
        new L2FeeVault(0, INBOX);
        vm.expectRevert(L2FeeVault.InvalidL1Identity.selector);
        new L2FeeVault(1, address(0));
    }

    function test_claim_PaysAuthenticatedRecipientOnce() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        bytes32 id = EtnaVaultProof.batchId(r);
        vm.expectCall(ROOTS, abi.encode(uint256(100)));
        vm.expectEmit();
        emit L2FeeVault.RewardClaimed(id, RECIPIENT, 3 ether);
        vm.prank(address(0x3333));
        _claim(r, 100, p);
        assertEq(RECIPIENT.balance, 3 ether);
        assertEq(address(0x3333).balance, 0);
        assertEq(address(_vault).balance, 2 ether);
        assertTrue(_vault.claimed(id));
        vm.expectRevert(L2FeeVault.AlreadyClaimed.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
        assertEq(RECIPIENT.balance, 3 ether);
    }

    function testFuzz_claim_RevertWhen_AnyReceiptFieldIsForged(uint8 _field) external {
        uint256 field = bound(_field, 0, 9);
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        if (field == 0) r.l1ChainId++;
        else if (field == 1) r.l2ChainId++;
        else if (field == 2) r.inbox = address(0x4444);
        else if (field == 3) r.generation++;
        else if (field == 4) r.parentHeight++;
        else if (field == 5) r.parentHash = bytes32(uint256(77));
        else if (field == 6) r.lastHeight++;
        else if (field == 7) r.lastBlockHash = bytes32(uint256(88));
        else if (field == 8) r.l2RewardRecipient = address(0x4444);
        else r.baseFeeAmount++;
        vm.expectRevert();
        _vault.claim(r, 100, p.account, p.storageProof);
        assertEq(address(_vault).balance, 5 ether);
        assertEq(RECIPIENT.balance, 0);
        assertFalse(_vault.claimed(EtnaVaultProof.batchId(r)));
    }

    function test_claim_RevertWhen_ConfiguredIdentityMismatchesEvenWithValidProof() external {
        for (uint256 i; i < 3; ++i) {
            LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
            if (i == 0) r.l1ChainId++;
            else if (i == 1) r.l2ChainId++;
            else r.inbox = address(0x4444);
            EtnaVaultProof.Proof memory p = _publish(r, 100);
            vm.expectRevert(L2FeeVault.InvalidReceipt.selector);
            _vault.claim(r, 100, p.account, p.storageProof);
        }
    }

    function test_claim_RevertWhen_RangeIsEmptyOrReversed() external {
        for (uint64 i; i < 2; ++i) {
            LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(1, RECIPIENT, 3 ether);
            r.lastHeight = r.parentHeight - i;
            EtnaVaultProof.Proof memory p = _publish(r, 100);
            vm.expectRevert(L2FeeVault.InvalidReceipt.selector);
            _vault.claim(r, 100, p.account, p.storageProof);
        }
    }

    function test_claim_RevertWhen_RecipientIsZero() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, address(0), 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.expectRevert(L2FeeVault.InvalidReceipt.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_AccountProofIsEmptyEvenWithStorageRoot() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        // LibTrieProof accepts storage-root mode for other users; the vault must not.
        MockEtnaRoots(ROOTS).setRoot(100, keccak256(p.storageProof[0]));
        vm.expectRevert(L2FeeVault.EmptyAccountProof.selector);
        _vault.claim(r, 100, new bytes[](0), p.storageProof);
    }

    function test_claim_RevertWhen_ProofAuthenticatesAnotherAccount() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = EtnaVaultProof.proof(r);
        (p.root, p.account, p.storageProof) = EtnaRewardProof._proof(
            address(0x4444),
            keccak256(abi.encode(EtnaVaultProof.batchId(r), uint256(283))),
            EtnaVaultProof.commitment(r)
        );
        MockEtnaRoots(ROOTS).setRoot(100, p.root);
        vm.expectRevert();
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_ProofUsesWrongMappingSlot() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p;
        (p.root, p.account, p.storageProof) = EtnaRewardProof._proof(
            INBOX,
            keccak256(abi.encode(EtnaVaultProof.batchId(r), uint256(284))),
            EtnaVaultProof.commitment(r)
        );
        MockEtnaRoots(ROOTS).setRoot(100, p.root);
        vm.expectRevert();
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function testFuzz_claim_RevertWhen_AccountOrStorageNodeIsCorrupt(bool _account) external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        if (_account) p.account[0][p.account[0].length - 1] ^= 0x01;
        else p.storageProof[0][p.storageProof[0].length - 1] ^= 0x01;
        vm.expectRevert();
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_StorageProofIsEmpty() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.expectRevert();
        _vault.claim(r, 100, p.account, new bytes[](0));
    }

    function testFuzz_claim_RevertWhen_RootReturnLengthIsNot32(uint8 _size) external {
        uint256 size = bound(_size, 0, 96);
        if (size == 32) size++;
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        // A valid root prefix plus trailing bytes must also fail, so this detects a
        // permissive >=32 length check rather than passing only because the root is zero.
        bytes memory malformed = new bytes(size);
        bytes memory prefix = abi.encode(p.root);
        for (uint256 i; i < size && i < 32; ++i) {
            malformed[i] = prefix[i];
        }
        vm.mockCall(ROOTS, abi.encode(uint256(100)), malformed);
        vm.expectRevert(L2FeeVault.InvalidAnchorRoot.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_RootIsZero() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.expectRevert(L2FeeVault.InvalidAnchorRoot.selector);
        _vault.claim(r, 101, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_RootSourceReverts() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.mockCallRevert(ROOTS, abi.encode(uint256(100)), hex"1234");
        vm.expectRevert(L2FeeVault.InvalidAnchorRoot.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_RootSourceHasNoCode() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.etch(ROOTS, hex"");
        vm.expectRevert(L2FeeVault.InvalidAnchorRoot.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_RevertWhen_AnchorContainsDifferentStateRoot() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        MockEtnaRoots(ROOTS).setRoot(100, bytes32(uint256(123)));
        vm.expectRevert();
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_claim_CanUseNewAnchorAfterOldRootExpires() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        MockEtnaRoots(ROOTS).setRoot(100, 0);
        vm.expectRevert(L2FeeVault.InvalidAnchorRoot.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
        // Same persistent receipt under a newer L1 account state (changed account balance).
        EtnaVaultProof.Proof memory newer = EtnaVaultProof.newerProof(r);
        assertTrue(newer.root != p.root);
        MockEtnaRoots(ROOTS).setRoot(9000, newer.root);
        _claim(r, 9000, newer);
        assertEq(RECIPIENT.balance, 3 ether);
        assertTrue(_vault.claimed(EtnaVaultProof.batchId(r)));
    }

    function test_claim_RevertWhen_SameBatchHasAnotherCommittedRecipientOrAmount() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        _claim(r, 100, p);
        r.l2RewardRecipient = address(0x4444);
        r.baseFeeAmount = 1 ether;
        p = _publish(r, 200);
        vm.expectRevert(L2FeeVault.AlreadyClaimed.selector);
        _vault.claim(r, 200, p.account, p.storageProof);
        assertEq(address(0x4444).balance, 0);
    }

    function testFuzz_claim_LegalBatchesPayInEitherOrder(bool _reverse) external {
        LibEtnaRewards.Receipt memory first = EtnaVaultProof.receipt(0, RECIPIENT, 2 ether);
        LibEtnaRewards.Receipt memory second = EtnaVaultProof.receipt(1, address(0x4444), 3 ether);
        EtnaVaultProof.Proof memory p1 = _publish(first, 100);
        EtnaVaultProof.Proof memory p2 = _publish(second, 200);
        if (_reverse) {
            _claim(second, 200, p2);
            _claim(first, 100, p1);
        } else {
            _claim(first, 100, p1);
            _claim(second, 200, p2);
        }
        assertEq(RECIPIENT.balance, 2 ether);
        assertEq(address(0x4444).balance, 3 ether);
        assertEq(address(_vault).balance, 0);
    }

    function test_claim_ZeroAmountDoesNotCallRecipient() external {
        EtnaClaimReceiver receiver = new EtnaClaimReceiver();
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, address(receiver), 0);
        receiver.configure(_vault, EtnaVaultProof.batchId(r), hex"", true);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        _claim(r, 100, p);
        assertEq(receiver.calls(), 0);
        assertTrue(_vault.claimed(EtnaVaultProof.batchId(r)));
        assertEq(address(_vault).balance, 5 ether);
    }

    function test_claim_RejectingRecipientRollsBackAndCanRetry() external {
        EtnaClaimReceiver receiver = new EtnaClaimReceiver();
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, address(receiver), 3 ether);
        bytes32 id = EtnaVaultProof.batchId(r);
        receiver.configure(_vault, id, hex"", true);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.expectRevert(L2FeeVault.RewardTransferFailed.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
        assertFalse(_vault.claimed(id));
        assertEq(address(_vault).balance, 5 ether);
        assertEq(address(receiver).balance, 0);
        receiver.configure(_vault, id, hex"", false);
        _claim(r, 100, p);
        assertTrue(_vault.claimed(id));
        assertTrue(receiver.observedClaimed());
        assertEq(address(receiver).balance, 3 ether);
    }

    function test_claim_InsufficientFundsRollBackAndCanRetry() external {
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 6 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        vm.expectRevert(L2FeeVault.RewardTransferFailed.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
        assertFalse(_vault.claimed(EtnaVaultProof.batchId(r)));
        vm.deal(address(_vault), 6 ether);
        _claim(r, 100, p);
        assertEq(RECIPIENT.balance, 6 ether);
    }

    function testFuzz_claim_BlocksSameAndCrossBatchReentry(bool _crossBatch) external {
        EtnaClaimReceiver receiver = new EtnaClaimReceiver();
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, address(receiver), 2 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        LibEtnaRewards.Receipt memory nested =
            _crossBatch ? EtnaVaultProof.receipt(1, RECIPIENT, 3 ether) : r;
        EtnaVaultProof.Proof memory nestedProof = _publish(nested, 200);
        receiver.configure(
            _vault, EtnaVaultProof.batchId(r), _payload(nested, 200, nestedProof), false
        );
        _claim(r, 100, p);
        assertTrue(receiver.observedClaimed());
        assertFalse(receiver.nestedSuccess());
        assertEq(receiver.nestedError(), L2FeeVault.ReentrantClaim.selector);
        assertEq(address(receiver).balance, 2 ether);
        assertEq(RECIPIENT.balance, 0);
        assertEq(receiver.calls(), 1);
        if (_crossBatch) {
            assertFalse(_vault.claimed(EtnaVaultProof.batchId(nested)));
            _claim(nested, 200, nestedProof);
            assertEq(RECIPIENT.balance, 3 ether);
        }
    }

    function test_claim_ForcedEtherDoesNotExpandReceiptEntitlement() external {
        vm.deal(address(this), 7 ether);
        new ForceEtnaEther{ value: 7 ether }().force(address(_vault));
        LibEtnaRewards.Receipt memory r = EtnaVaultProof.receipt(0, RECIPIENT, 3 ether);
        EtnaVaultProof.Proof memory p = _publish(r, 100);
        _claim(r, 100, p);
        assertEq(RECIPIENT.balance, 3 ether);
        assertEq(address(_vault).balance, 9 ether);
        vm.expectRevert(L2FeeVault.AlreadyClaimed.selector);
        _vault.claim(r, 100, p.account, p.storageProof);
    }

    function test_directTransferAndObsoleteMutationRoutes_Revert() external {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(_vault).call{ value: 1 ether }(hex"");
        assertFalse(ok);
        bytes[4] memory calls = [
            abi.encodeWithSignature("sweep()"),
            abi.encodeWithSignature("init(address)", address(this)),
            abi.encodeWithSignature("upgradeTo(address)", address(this)),
            abi.encodeWithSignature("transferOwnership(address)", address(this))
        ];
        for (uint256 i; i < calls.length; ++i) {
            (ok,) = address(_vault).call(calls[i]);
            assertFalse(ok);
        }
        assertEq(address(_vault).balance, 5 ether);
    }
}
