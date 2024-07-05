// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
/**
 * @title ILidoBridgedToken
 * @dev Interface for Lido bridged token, extending the IERC20 interface
 */
interface ILidoBridgedToken is IERC20Upgradeable {
    /**
     * @notice Mints new tokens to a specified address
     * @param to The address to which the minted tokens will be sent
     * @param amount The number of tokens to be minted
     */
    function bridgeMint(address to, uint256 amount) external;

    /**
     * @notice Burns tokens from a specified address
     * @param from The address from which the tokens will be burned
     * @param amount The number of tokens to be burned
     */
    function bridgeBurn(address from, uint256 amount) external;

    /**
     * @notice Returns the address of the Lido L2 bridge
     * @return The address of the Lido L2 bridge
     */
    function lidoL2Bridge() external view returns (address);
}
