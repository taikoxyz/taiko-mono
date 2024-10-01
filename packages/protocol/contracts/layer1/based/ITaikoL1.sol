// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./TaikoData.sol";

/// @title ITaikoL1
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 {
    /// @notice Proposes a Taiko L2 block.
    /// @param _params Block parameters, currently an encoded BlockParams object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    /// @return deposits_ The Ether deposits processed.
    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_);

    /// @notice Proposes a Taiko L2 block (version 2)
    /// @param _params Block parameters, an encoded BlockParamsV2 object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (TaikoData.BlockMetadataV2 memory meta_);

    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _paramsArr A list of encoded BlockParamsV2 objects.
    /// @param _txListArr A list of txList.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        returns (TaikoData.BlockMetadataV2[] memory metaArr_);

    /// @notice Proves or contests a block transition.
    /// @param _blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    function proveBlock(uint64 _blockId, bytes calldata _input) external;

    /// @notice Proves or contests multiple block transitions (version 2)
    /// @param _blockIds The indices of the blocks to prove.
    /// @param _inputs An list of abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuples.
    /// @param _batchProof An abi-encoded TaikoData.TierProof that contains the batch/aggregated
    /// proof for the given blocks.
    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external;

    /// @notice Verifies up to a certain number of blocks.
    /// @param _maxBlocksToVerify Max number of blocks to verify.
    function verifyBlocks(uint64 _maxBlocksToVerify) external;

    /// @notice Pause block proving.
    /// @param _pause True if paused.
    function pauseProving(bool _pause) external;

    /// @notice Deposits Taiko token to be used as bonds.
    /// @param _amount The amount of Taiko token to deposit.
    function depositBond(uint256 _amount) external;

    /// @notice Withdraws Taiko token.
    /// @param _amount The amount of Taiko token to withdraw.
    function withdrawBond(uint256 _amount) external;

    /// @notice Gets the prover that actually proved a verified block.
    /// @param _blockId The index of the block.
    /// @return The prover's address. If the block is not verified yet, address(0) will be returned.
    function getVerifiedBlockProver(uint64 _blockId) external view returns (address);

    /// @notice Returns information about the last verified block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is verified at.
    function getLastVerifiedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_);

    /// @notice Returns information about the last synchronized block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is verified at.
    function getLastSyncedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_);

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @dev This method can be deleted once node/client stops using it.
    /// @return State variables stored at SlotA.
    /// @return State variables stored at SlotB.
    function getStateVariables()
        external
        view
        returns (TaikoData.SlotA memory, TaikoData.SlotB memory);

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() external pure returns (TaikoData.Config memory);
}
