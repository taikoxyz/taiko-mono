// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SwapTokenL2
/// @notice Bridged ERC20 representation on L2 for cross-chain DEX POC
/// @custom:security-contact security@taiko.xyz
contract SwapTokenL2 is ERC20 {
    address public minter;
    uint8 private immutable _tokenDecimals;

    error ONLY_MINTER();

    constructor(
        string memory _name,
        string memory _symbol,
        address _minter,
        uint256 _initialSupply,
        uint8 _decimals
    )
        ERC20(_name, _symbol)
    {
        minter = _minter;
        _tokenDecimals = _decimals;
        if (_initialSupply > 0) {
            _mint(_minter, _initialSupply);
        }
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    /// @notice Transfers minting authority to a new address
    /// @param _newMinter The new minter address
    function setMinter(address _newMinter) external {
        if (msg.sender != minter) revert ONLY_MINTER();
        minter = _newMinter;
    }

    /// @notice Allows minter to mint tokens
    /// @param _to Recipient address
    /// @param _amount Amount to mint
    function mint(address _to, uint256 _amount) external {
        if (msg.sender != minter) revert ONLY_MINTER();
        _mint(_to, _amount);
    }

    /// @notice Allows minter to burn tokens
    /// @param _from Address to burn from
    /// @param _amount Amount to burn
    function burn(address _from, uint256 _amount) external {
        if (msg.sender != minter) revert ONLY_MINTER();
        _burn(_from, _amount);
    }
}
