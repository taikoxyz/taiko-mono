// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoTokenBase.sol";

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of precision.
/// @dev Labeled in AddressResolver as "taiko_token"
/// @dev On Ethereum, this contract is deployed behind a proxy at
/// 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 (token.taiko.eth)
/// @custom:security-contact security@taiko.xyz
contract TaikoToken is TaikoTokenBase {
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _recipient The address to receive initial token minting.
    function init(address _owner, address _recipient) public initializer {
        __Essential_init(_owner);
        __ERC20_init("Taiko Token", "TKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }
}
