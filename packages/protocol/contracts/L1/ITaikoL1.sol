// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity 0.8.20;

import "./TaikoData.sol";

interface ITaikoL1 {
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

    function proveBlock(uint64 blockId, bytes calldata input) external;

    function verifyBlocks(uint64 maxBlocksToVerify) external;
}
