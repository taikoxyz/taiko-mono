// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ILidoBridgedToken } from "./interfaces/ILidoBridgedToken.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract LidoBridgedToken is ERC20Upgradeable, ILidoBridgedToken {
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
    function init(
        string memory name_,
        string memory symbol_,
        address l2bridge_
    )
        external
        initializer
    {
        __ERC20_init(name_, symbol_);
        lidoL2Bridge = l2bridge_;
    }

    /// @inheritdoc ILidoBridgedToken
    function bridgeMint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
    }

    /// @inheritdoc ILidoBridgedToken
    function bridgeBurn(address from, uint256 amount) external onlyBridge {
        _burn(from, amount);
    }
}
