// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/TaikoTokenBase.sol";
import "src/shared/vault/IBridgedERC20.sol";
import "src/shared/vault/IShadowERC20.sol";

import "./BridgedTaikoToken_Layout.sol"; // DO NOT DELETE

/// @title BridgedTaikoToken
/// @notice The TaikoToken on L2 to support checkpoints and voting. For testnets, we do not need to
/// use this contract.
/// @custom:security-contact security@taiko.xyz
contract BridgedTaikoToken is TaikoTokenBase, IBridgedERC20, IShadowERC20 {
    address public immutable erc20Vault;
    address private immutable _shadow;

    error BTOKEN_AMOUNT_TOO_LARGE();

    constructor(address _erc20Vault, address shadow_) {
        erc20Vault = _erc20Vault;
        _shadow = shadow_;
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

    /// @inheritdoc IShadowERC20
    function shadowAddress() external view returns (address) {
        return _shadow;
    }

    /// @inheritdoc IShadowERC20
    function shadowMint(address _to, uint256 _amount) external onlyFrom(_shadow) {
        require(_amount <= maxShadowMintAmount(), BTOKEN_AMOUNT_TOO_LARGE());
        // Mint tokens without changing totalSupply. _mint increases balance, emits Transfer,
        // and updates voting checkpoints; assembly then reverts the totalSupply increase.
        // _totalSupply is at storage slot 303.
        _mint(_to, _amount);
        assembly {
            sstore(303, sub(sload(303), _amount))
        }
    }

    /// @inheritdoc IShadowERC20
    /// @dev _balances is at slot 301 in BridgedTaikoToken's storage layout.
    function balanceSlot() external pure returns (uint256) {
        return 301;
    }

    /// @inheritdoc IShadowERC20
    function maxShadowMintAmount() public pure returns (uint256) {
        return 1_000_000 ether;
    }
}
