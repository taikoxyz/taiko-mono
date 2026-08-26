// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/Bridge.sol";

import "./MainnetBridge_Layout.sol"; // DO NOT DELETE

/// @title MainnetBridge
/// @dev Deployed on Ethereum for Taiko mainnet. Behavior is identical to the parent contract
/// since the transient-storage reentry lock and call context became the defaults; the contract
/// is retained for deployment identity.
/// @notice At genesis, this contract's initial balance is 999,999,600 Ether. Additionally, two
/// other addresses have non-zero balances:
/// - 0x69AA0361Dbb0527d4F1e5312403Bd41788fe61Fe holds 199 Ether
/// - 0x00000968bfe78aa27cd380d629d61c89bd6b03e8 holds 1 Ether
/// Together, these three accounts have a total premint Ether balance of 999,999,800 on Taiko
/// Alethia layer 2. Initially, the plan was to mint 1,000,000,000 Ether, but a minor error
/// occurred.
/// The combined balance of the L1 and L2 bridges must be no less than 999,999,800 Ether.
/// @notice See the documentation in {Bridge}.
/// @custom:security-contact security@taiko.xyz
contract MainnetBridge is Bridge {
    /// @notice Initializes the mainnet bridge's immutable state.
    /// @param _resolver The address of the resolver contract.
    /// @param _signalService The address of the signal service contract.
    /// @param _quotaManager The address of the quota manager contract. Optional (may be zero).
    /// @param _pauser Address authorized to pause/unpause alongside the owner, and to fund the
    /// bridge via plain Ether transfers. Optional (may be zero, which disables direct funding).
    constructor(
        address _resolver,
        address _signalService,
        address _quotaManager,
        address _pauser
    )
        Bridge(_resolver, _signalService, _quotaManager, _pauser)
    { }
}
