// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/signal/ICheckpointStore.sol";
import "src/shared/signal/SignalService.sol";

import { SignalServiceProofFixture } from "./SignalServiceProofFixture.sol";

contract TestSignalService is CommonTest, SignalServiceProofFixture {
    SignalService private signalService;

    function setUpOnEthereum() internal override {
        signalService = deploySignalService(AUTHORIZED_SYNCER, REMOTE_SIGNAL_SERVICE, deployer);
    }

    function test_sendSignal_RecordsSlotAndEmitsEvent() public {
        bytes32 signal = keccak256("signal");
        uint64 chainId = uint64(block.chainid);
        bytes32 expectedSlot = signalService.getSignalSlot(chainId, address(this), signal);

        vm.expectEmit(true, true, true, true, address(signalService));
        emit ISignalService.SignalSent(address(this), signal, expectedSlot, signal);

        bytes32 slot = signalService.sendSignal(signal);

        assertEq(slot, expectedSlot);
        assertTrue(signalService.isSignalSent(address(this), signal));
        assertTrue(signalService.isSignalSent(slot));
    }

    function test_sendSignal_RevertWhen_SignalIsZero() public {
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        signalService.sendSignal(bytes32(0));
    }

    function test_saveCheckpoint_PersistsWhenAuthorized() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(2))
        });

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        signalService.saveCheckpoint(checkpoint);

        vm.prank(AUTHORIZED_SYNCER);
        signalService.saveCheckpoint(checkpoint);

        ICheckpointStore.Checkpoint memory stored = signalService.getCheckpoint(1);
        assertEq(stored.blockNumber, checkpoint.blockNumber);
        assertEq(stored.blockHash, checkpoint.blockHash);
        assertEq(stored.stateRoot, checkpoint.stateRoot);
    }

    function test_saveCheckpoint_RevertWhen_CheckpointFieldInvalid() public {
        ICheckpointStore.Checkpoint memory badStateRoot = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(0)
        });
        vm.prank(AUTHORIZED_SYNCER);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        signalService.saveCheckpoint(badStateRoot);

        ICheckpointStore.Checkpoint memory badBlockHash = ICheckpointStore.Checkpoint({
            blockNumber: 2, blockHash: bytes32(0), stateRoot: bytes32(uint256(2))
        });
        vm.prank(AUTHORIZED_SYNCER);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        signalService.saveCheckpoint(badBlockHash);
    }

    function test_getCheckpoint_RevertWhen_Missing() public {
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(42);
    }

    function test_getCheckpoint_RevertWhen_OnlyDeprecatedCheckpointExists() public {
        uint48 blockNumber = 42;
        _storeDeprecatedCheckpoint(blockNumber, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(blockNumber);
    }

    function test_proveSignalReceived_RevertWhen_OnlyDeprecatedCheckpointExists() public {
        _storeDeprecatedCheckpoint(
            uint48(VALID_PROOF_BLOCK_ID), VALID_BLOCK_HASH, VALID_PROOF_STATE_ROOT
        );

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    function test_verifySignalReceived_RevertWhen_SignalNotCached() public {
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function test_verifySignalReceived_RevertWhen_OnlyDeprecatedCacheExists() public {
        bytes32 slot = signalService.getSignalSlot(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL);
        bytes32 deprecatedCacheSlot = keccak256(abi.encode(slot, uint256(253)));

        vm.store(address(signalService), deprecatedCacheSlot, bytes32(uint256(1)));

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function test_proveSignalReceived_RevertWhen_OnlyDeprecatedCacheExists() public {
        bytes32 slot = signalService.getSignalSlot(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL);
        bytes32 deprecatedCacheSlot = keccak256(abi.encode(slot, uint256(253)));

        vm.store(address(signalService), deprecatedCacheSlot, bytes32(uint256(1)));

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function test_proveSignalReceived_RevertWhen_ProofBytesEmpty() public {
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function test_proveSignalReceived_RevertWhen_ProofLengthMismatch() public {
        ISignalService.HopProof[] memory proofs = new ISignalService.HopProof[](2);
        proofs[0].accountProof = new bytes[](1);
        proofs[0].accountProof[0] = hex"11";
        proofs[0].storageProof = new bytes[](1);
        proofs[0].storageProof[0] = hex"22";

        vm.expectRevert(SignalService.SS_INVALID_PROOF_LENGTH.selector);
        signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_proveSignalReceived_RevertWhen_ProofArraysEmpty() public {
        ISignalService.HopProof[] memory proofs = new ISignalService.HopProof[](1);
        proofs[0].blockId = 1;
        proofs[0].rootHash = bytes32(uint256(1));
        proofs[0].storageProof = new bytes[](1);
        proofs[0].storageProof[0] = hex"01";

        vm.expectRevert(SignalService.SS_EMPTY_PROOF.selector);
        signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_proveSignalReceived_RevertWhen_CheckpointMissing() public {
        ISignalService.HopProof[] memory proofs = new ISignalService.HopProof[](1);
        proofs[0].blockId = 99;
        proofs[0].rootHash = bytes32(uint256(99));
        proofs[0].accountProof = new bytes[](1);
        proofs[0].accountProof[0] = hex"aa";
        proofs[0].storageProof = new bytes[](1);
        proofs[0].storageProof[0] = hex"bb";

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_proveSignalReceived_RevertWhen_StateRootMismatch() public {
        _saveCheckpoint(VALID_PROOF_BLOCK_ID, bytes32(uint256(123)));

        ISignalService.HopProof[] memory proofs = new ISignalService.HopProof[](1);
        proofs[0].blockId = VALID_PROOF_BLOCK_ID;
        proofs[0].rootHash = bytes32(uint256(456));
        proofs[0].accountProof = new bytes[](1);
        proofs[0].accountProof[0] = hex"aa";
        proofs[0].storageProof = new bytes[](1);
        proofs[0].storageProof[0] = hex"bb";

        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_proveSignalReceived_AcceptsValidProofAndCaches() public {
        _saveCheckpoint(VALID_PROOF_BLOCK_ID, VALID_PROOF_STATE_ROOT);

        uint64 originalChainId = uint64(block.chainid);
        vm.chainId(167_001);

        uint256 cacheOps = signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        assertEq(cacheOps, 0);

        signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");

        vm.chainId(originalChainId);
    }

    function test_proveSignalReceived_RevertWhen_BlockIdTruncates() public {
        _saveCheckpoint(VALID_PROOF_BLOCK_ID, VALID_PROOF_STATE_ROOT);

        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));

        uint64 truncatedOffset = uint64(1) << 48;
        proofs[0].blockId = uint64(VALID_PROOF_BLOCK_ID) + truncatedOffset;

        bytes memory proof = abi.encode(proofs);

        uint64 originalChainId = uint64(block.chainid);
        vm.chainId(167_001);

        vm.expectRevert(SignalService.SS_INVALID_BLOCK_ID.selector);
        signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);

        vm.chainId(originalChainId);
    }

    // ---------------------------------------------------------------
    // Pause authorization (owner or designated immutable pauser)
    // ---------------------------------------------------------------

    function test_pause_byDesignatedPauser() public {
        SignalService svc = _deployWithPauser(Alice);

        vm.prank(Alice);
        svc.pause();
        assertTrue(svc.paused());

        vm.prank(Alice);
        svc.unpause();
        assertFalse(svc.paused());
    }

    function test_pause_byOwner_stillWorks() public {
        SignalService svc = _deployWithPauser(Alice);

        vm.prank(deployer);
        svc.pause();
        assertTrue(svc.paused());

        vm.prank(deployer);
        svc.unpause();
        assertFalse(svc.paused());
    }

    function test_pause_RevertWhen_notOwnerOrPauser() public {
        SignalService svc = _deployWithPauser(Alice);

        vm.prank(Bob);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        svc.pause();
    }

    function test_pause_RevertWhen_zeroPauser_nonOwner() public {
        // `signalService` from setUp was deployed with a zero pauser -> owner-only.
        vm.prank(Alice);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        signalService.pause();
    }

    // ---------------------------------------------------------------
    // Paused state blocks signal proving and verification
    // ---------------------------------------------------------------

    function test_proveSignalReceived_RevertWhen_Paused() public {
        vm.prank(deployer);
        signalService.pause();

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function test_verifySignalReceived_RevertWhen_Paused() public {
        vm.prank(deployer);
        signalService.pause();

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"");
    }

    function _deployWithPauser(address pauser) private returns (SignalService) {
        SignalService impl = new SignalService(AUTHORIZED_SYNCER, REMOTE_SIGNAL_SERVICE, pauser);
        return SignalService(
            address(new ERC1967Proxy(address(impl), abi.encodeCall(SignalService.init, (deployer))))
        );
    }

    function _saveCheckpoint(uint64 blockNumber, bytes32 stateRoot) private {
        vm.prank(AUTHORIZED_SYNCER);
        signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: uint48(blockNumber), blockHash: VALID_BLOCK_HASH, stateRoot: stateRoot
            })
        );
    }

    function _storeDeprecatedCheckpoint(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        private
    {
        bytes32 deprecatedRecordSlot = keccak256(abi.encode(uint256(blockNumber), uint256(254)));

        vm.store(address(signalService), deprecatedRecordSlot, blockHash);
        vm.store(address(signalService), bytes32(uint256(deprecatedRecordSlot) + 1), stateRoot);
    }
}
