// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "./TaikoData.sol";

interface ITaikoL1 {
    /// @notice Proposes a Taiko L2 block.
    /// @param params Block parameters, currently an encoded BlockParams object.
    /// @param txList txList data if calldata is used for DA.
    /// @return meta The metadata of the proposed L2 block.
    /// @return depositsProcessed The Ether deposits processed.
    function proposeBlock(
        bytes calldata params,
        bytes calldata txList
    )
        external
        payable
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        );

    /// @notice Proves or contests a block transition.
    /// @param blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param input An abi-encoded (BlockMetadata, Transition, TierProof)
    /// tuple.
    function proveBlock(uint64 blockId, bytes calldata input) external;

    /// @notice Verifies up to a certain number of blocks.
    /// @param maxBlocksToVerify Max number of blocks to verify.
    function verifyBlocks(uint64 maxBlocksToVerify) external;
}
