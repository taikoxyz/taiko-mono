// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

interface IProverPool {
    function getProver(
        uint256 blockId,
        uint32 feePerGas
    )
        external
        view
        returns (address prover, uint32 rewardPerGas);
    function slashProver(address prover) external;
}

interface IStakingProverPool is IProverPool {
    function enterProverPool(
        uint256 amount,
        uint256 feeMultiplier,
        uint32 capacity
    )
        external;

    function stakeMoreTokens(uint256 amount) external;

    function adjustFeeMultiplier(uint8 newFeeMultiplier) external;

    function adjustCapacity(uint32 newCapacity) external;

    function withdrawRewards(uint64 amount) external;

    function exit() external;

    function pickRandomProver(
        uint256 randomNumber,
        uint256 blockId
    )
        external
        returns (address);
}

// @dani, I propose this interface.
interface IStakingProverPool2 is IProverPool {
    // Adjust the staking. Users can use this funciton to stake, re-stake, exit,
    // and change parameters.
    function stake(
        uint64 totalAmount,
        uint16 feeMultiplier, // as percentage
        uint16 capacity // up to 65535
    )
        external;

    // Claim any staking that have existed but not withdrawn.
    function withdraw() external;
}
