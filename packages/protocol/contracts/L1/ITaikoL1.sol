// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

    /// @notice Proves or contests a block transition.
    /// @param _blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    function proveBlock(uint64 _blockId, bytes calldata _input) external;

    /// @notice Verifies up to a certain number of blocks.
    /// @param _maxBlocksToVerify Max number of blocks to verify.
    function verifyBlocks(uint64 _maxBlocksToVerify) external;

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() external view returns (TaikoData.Config memory);
}
