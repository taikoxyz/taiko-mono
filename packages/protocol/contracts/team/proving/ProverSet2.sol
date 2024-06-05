// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ProverSet.sol";

/// @title ProverSet2
/// @notice An improved impleentation over ProverSet to return TaikoL1 and Taiko token addresses
/// from code instead of storage. This contract also allow owner to enable more than one assignment
/// hooks using the new `approveAllowance` function.
contract ProverSet2 is ProverSet {
    uint256[50] private __gap;

    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        IERC20(getTaikoTokenAddress()).approve(_address, _allowance);
    }

    function getTaikoL1Address() internal pure override returns (address) {
        return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    }

    function getTaikoTokenAddress() internal pure override returns (address) {
        return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    }
}
