// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * @title IProverPool Interface
 * @dev Interface for the ProverPool contract, which manages the assignment,
 * release, and slashing of provers.
 */
interface IProverPool {
    /**
     * @notice Assigns a prover to a specific block.
     *
     * @param blockId Unique identifier for the block.
     * @param feePerGas The fee amount per unit of gas.
     * @return prover Address of the assigned prover.
     * @return rewardPerGas Reward allocated per unit of gas for the prover.
     */
    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas);

    /**
     * @notice Releases a prover.
     *
     * @param prover Address of the prover to be released.
     */
    function releaseProver(address prover) external;

    /**
     * @notice Penalizes a prover by burning their staked tokens.
     *
     * @param blockId Unique identifier for the block associated with the
     * prover's task.
     * @param prover Address of the prover being penalized.
     * @param proofReward Reward initially allocated for proof validation.
     */
    function slashProver(
        uint64 blockId,
        address prover,
        uint64 proofReward
    )
        external;
}
