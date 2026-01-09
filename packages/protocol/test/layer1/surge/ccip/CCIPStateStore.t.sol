// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/src/Test.sol";
import { AzureTDXVerifier } from "src/layer1/surge/ccip/AzureTDXVerifier.sol";
import { CCIPStateStore } from "src/layer1/surge/ccip/CCIPStateStore.sol";
import { ICCIPStateStore } from "src/layer1/surge/ccip/ICCIPStateStore.sol";

contract CCIPStateStoreTest is Test {
    address internal constant SIGNER = 0x4ed3F69025Bd5643C287850513C4414B3f11F41C;

    CCIPStateStore internal stateStore;

    // ---------------------------------------------------------------
    // Test data
    // ---------------------------------------------------------------

    bytes32 internal constant BLOCK_HASH_1 =
        0xa9a0b8088df56f5e7372dba983fbe046d30b2db732f875d0b08fd18139aaec1e;
    bytes32 internal constant STATE_ROOT_1 =
        0x3385a9d486ab63a556b8da050cd2ab40d5da241d21f756b267692db5bce8d7b6;
    bytes internal constant SIGNATURE_1 =
    // solhint-disable-next-line max-line-length
    hex"b83f5dc2338208ee4f62ac2d8818e65254abb42540c33713c2b0e55ece32a5b563bfb99d045f151c78107206bced8e61f88a8cfac06215c0378ce87e04f638971c";

    // Test Data 2
    bytes32 internal constant BLOCK_HASH_2 =
        0xf2a617aaf5d55cc0032081d9c67b6a03b785d063ab48f5d69b5f6013930bb200;
    bytes32 internal constant STATE_ROOT_2 =
        0x786b899e4d147419080c5e9b9fd8f178a7840116cb7f07bb5b0084d9b0c72d33;
    bytes internal constant SIGNATURE_2 =
    // solhint-disable-next-line max-line-length
    hex"389afb7fd06ec853674a1324701a9a5fba4d85ebc036e560854d1610c87b57913014b698a26d0332f44d829c7362a753ab2c196c96fe310e05bf9c732a0a8a5a1b";

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------

    function setUp() public {
        vm.warp(1000);

        // Deploy CCIp store
        CCIPStateStore impl = new CCIPStateStore(address(1));
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(AzureTDXVerifier.init, (address(this))));

        stateStore = CCIPStateStore(address(proxy));

        // Register the signer as a valid instance
        address[] memory instances = new address[](1);
        instances[0] = SIGNER;
        stateStore.addInstances(instances);
    }

    /// @notice Tests syncing state for a single state
    function test_syncState_singleState_succeeds() external {
        bytes memory proof = _buildProof(BLOCK_HASH_1, STATE_ROOT_1, SIGNATURE_1);

        // Expect the StateSynced event
        vm.expectEmit();
        emit CCIPStateStore.StateSynced(BLOCK_HASH_1, STATE_ROOT_1, block.timestamp);

        // Sync state
        stateStore.syncState(proof);

        // Verify synced state
        ICCIPStateStore.SyncedState memory syncedState = stateStore.getSyncedState();
        assertEq(syncedState.blockHash, BLOCK_HASH_1, "blockHash mismatch");
        assertEq(syncedState.stateRoot, STATE_ROOT_1, "stateRoot mismatch");
        assertEq(syncedState.syncedAt, block.timestamp, "syncedAt mismatch");
    }

    /// @notice Tests syncing two states after the minimum delay
    function test_syncState_twoStatesAfterDelay_succeeds() external {
        // Sync first state
        bytes memory proof1 = _buildProof(BLOCK_HASH_1, STATE_ROOT_1, SIGNATURE_1);
        stateStore.syncState(proof1);

        // Verify first synced state
        ICCIPStateStore.SyncedState memory syncedState1 = stateStore.getSyncedState();
        assertEq(syncedState1.blockHash, BLOCK_HASH_1, "first blockHash mismatch");
        assertEq(syncedState1.stateRoot, STATE_ROOT_1, "first stateRoot mismatch");

        // Warp time past the minimum sync delay
        uint256 minSyncDelay = stateStore.MIN_SYNC_DELAY();
        vm.warp(block.timestamp + minSyncDelay + 1);

        // Sync second state
        bytes memory proof2 = _buildProof(BLOCK_HASH_2, STATE_ROOT_2, SIGNATURE_2);

        vm.expectEmit();
        emit CCIPStateStore.StateSynced(BLOCK_HASH_2, STATE_ROOT_2, block.timestamp);

        stateStore.syncState(proof2);

        // Verify second synced state
        ICCIPStateStore.SyncedState memory syncedState2 = stateStore.getSyncedState();
        assertEq(syncedState2.blockHash, BLOCK_HASH_2, "second blockHash mismatch");
        assertEq(syncedState2.stateRoot, STATE_ROOT_2, "second stateRoot mismatch");
        assertEq(syncedState2.syncedAt, block.timestamp, "second syncedAt mismatch");
    }

    /// @notice Tests that syncState reverts with invalid proof length
    function test_syncState_revertWhen_invalidProofLength() external {
        // Test with too short proof
        bytes memory shortProof = hex"1234";
        vm.expectRevert(CCIPStateStore.SurgeCCIP_InvalidProofLength.selector);
        stateStore.syncState(shortProof);

        // Test with too long proof
        bytes memory longProof = new bytes(130);
        vm.expectRevert(CCIPStateStore.SurgeCCIP_InvalidProofLength.selector);
        stateStore.syncState(longProof);

        // Test with empty proof
        bytes memory emptyProof = "";
        vm.expectRevert(CCIPStateStore.SurgeCCIP_InvalidProofLength.selector);
        stateStore.syncState(emptyProof);
    }

    /// @notice Tests that syncState reverts with invalid signer
    function test_syncState_revertWhen_invalidSigner() external {
        // Create a valid signature from an unregistered signer using vm.sign
        uint256 unregisteredPrivateKey = 0x12345; // An arbitrary private key
        bytes32 message = keccak256(abi.encodePacked(BLOCK_HASH_1, STATE_ROOT_1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unregisteredPrivateKey, message);
        bytes memory invalidSignerSignature = abi.encodePacked(r, s, v);

        bytes memory proof = _buildProof(BLOCK_HASH_1, STATE_ROOT_1, invalidSignerSignature);

        vm.expectRevert(CCIPStateStore.SurgeCCIP_InvalidSigner.selector);
        stateStore.syncState(proof);
    }

    /// @notice Tests that syncState reverts when called before minimum sync delay
    function test_syncState_revertWhen_syncTooFrequent() external {
        // Sync first state
        bytes memory proof1 = _buildProof(BLOCK_HASH_1, STATE_ROOT_1, SIGNATURE_1);
        stateStore.syncState(proof1);

        bytes memory proof2 = _buildProof(BLOCK_HASH_2, STATE_ROOT_2, SIGNATURE_2);

        // Try to sync second state immediately, without waiting for delay (txn fails)
        vm.expectRevert(CCIPStateStore.SurgeCCIP_SyncTooFrequent.selector);
        stateStore.syncState(proof2);

        uint256 minSyncDelay = stateStore.MIN_SYNC_DELAY();
        vm.warp(block.timestamp + (minSyncDelay / 2));

        // Try again with partial delay (still should fail)
        vm.expectRevert(CCIPStateStore.SurgeCCIP_SyncTooFrequent.selector);
        stateStore.syncState(proof2);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @notice Helper to build proof from components
    function _buildProof(
        bytes32 _blockHash,
        bytes32 _stateRoot,
        bytes memory _signature
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_blockHash, _stateRoot, _signature);
    }
}

