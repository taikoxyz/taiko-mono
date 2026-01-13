// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/TaikoTokenBase.sol";
import "src/shared/vault/IBridgedERC20.sol";

import "./BridgedTaikoToken_Layout.sol"; // DO NOT DELETE

/// @title BridgedTaikoToken
/// @notice The TaikoToken on L2 to support checkpoints and voting. For testnets, we do not need to
/// use this contract.
/// @custom:security-contact security@taiko.xyz
contract BridgedTaikoToken is TaikoTokenBase, IBridgedERC20 {
    address public immutable erc20Vault;

    constructor(address _erc20Vault) {
        erc20Vault = _erc20Vault;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        __ERC20_init("Taiko Token", "TAIKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
    }

    function mint(
        address _account,
        uint256 _amount
    )
        external
        override
        whenNotPaused
        onlyFromOwnerOr(erc20Vault)
        nonReentrant
    {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount)
        external
        override
        whenNotPaused
        onlyFromOwnerOr(erc20Vault)
        nonReentrant
    {
        _burn(msg.sender, _amount);
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() public pure returns (address, uint256) {
        // 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 is the TAIKO token on Ethereum mainnet
        return (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 1);
    }

    function changeMigrationStatus(address, bool) public pure notImplemented { }
}
