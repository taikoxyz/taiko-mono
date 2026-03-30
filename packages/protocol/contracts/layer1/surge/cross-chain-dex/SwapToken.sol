// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SwapToken
/// @notice Simple ERC20 token for cross-chain DEX POC on L1
/// @dev Freely mintable by anyone — intended for devnet/testnet use only.
/// @custom:security-contact security@taiko.xyz
contract SwapToken is ERC20 {
    uint8 private immutable _tokenDecimals;

    constructor(
        string memory _name,
        string memory _symbol,
        address _mintTo,
        uint256 _initialSupply,
        uint8 _decimals
    )
        ERC20(_name, _symbol)
    {
        _tokenDecimals = _decimals;
        if (_initialSupply > 0) {
            _mint(_mintTo, _initialSupply);
        }
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    /// @notice Mint tokens to any address — open faucet for POC
    /// @param _to Recipient address
    /// @param _amount Amount to mint
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
