// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LidoBridgedToken is ERC20 {
    // The address of the L2 bridge
    address public lidoL2Bridge;

    /**
     * @dev Custom error to indicate that the caller is not the bridge contract
     */
    error notBridge();

    // Modifier to restrict access to the bridge contract
    modifier onlyBridge() {
        if (msg.sender != lidoL2Bridge) revert notBridge();
        _;
    }

    /**
     * @notice Initializes the contract with a name, symbol, and L2 bridge address
     * @param name_ The name of the ERC20 token
     * @param symbol_ The symbol of the ERC20 token
     * @param l2bridge_ The address of the L2 bridge
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address l2bridge_
    )
        ERC20(name_, symbol_)
    {
        lidoL2Bridge = l2bridge_;
    }

    /**
     * @notice Mints new tokens to a specified address
     * @dev Only the bridge contract can call this function
     * @param to The address to which the minted tokens will be sent
     * @param amount The number of tokens to be minted
     */
    function bridgeMint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from a specified address
     * @dev Only the bridge contract can call this function
     * @param to The address from which the tokens will be burned
     * @param amount The number of tokens to be burned
     */
    function bridgeBurn(address to, uint256 amount) external onlyBridge {
        _burn(to, amount);
    }
}
