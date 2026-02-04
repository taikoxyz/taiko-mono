// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SwapToken
/// @notice Simple ERC20 token for cross-chain DEX POC on L1
/// @custom:security-contact security@taiko.xyz
contract SwapToken is ERC20 {
    address public immutable minter;

    error ONLY_MINTER();

    constructor(
        string memory _name,
        string memory _symbol,
        address _minter,
        uint256 _initialSupply
    )
        ERC20(_name, _symbol)
    {
        minter = _minter;
        if (_initialSupply > 0) {
            _mint(_minter, _initialSupply);
        }
    }

    /// @notice Allows minter to mint additional tokens
    /// @param _to Recipient address
    /// @param _amount Amount to mint
    function mint(address _to, uint256 _amount) external {
        if (msg.sender != minter) revert ONLY_MINTER();
        _mint(_to, _amount);
    }
}
