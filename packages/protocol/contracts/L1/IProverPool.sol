//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

interface IProverPool {
    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas);

    function releaseProver(address prover) external;

    function slashProver(address prover) external;

    function getAvailableCapacity() external view returns (uint256);
}
