// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

interface ITaikoProverPool {

    function enterProverPool(uint256 amount, uint256 feeMultiplier, uint32 capacity) external;

    function stakeMoreTokens(uint256 amount) external;

    function adjustFeeMultiplier(uint8 newFeeMultiplier) external;

    function adjustCapacity(uint32 newCapacity) external;

    function withdrawRewards(uint64 amount) external;
   
    function exit() external;

    function pickRandomProver(uint256 randomNumber, uint256 blockId) external returns (address);

    function getProver(uint256 blockId) external view returns (address);

    function slash(address prover) external;
}