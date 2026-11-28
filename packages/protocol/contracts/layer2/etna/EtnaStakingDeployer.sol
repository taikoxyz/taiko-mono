// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStaking } from "./EtnaStaking.sol";
import { IEtnaStaking } from "./iface/IEtnaStaking.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title EtnaStakingDeployer
/// @notice Deploys the `EtnaStaking` implementation and its proxy, initialized with its owner, in
/// its constructor, so that creating this contract is the one L2 transaction that deploys
/// `EtnaStaking` on a network that switches from Unzen (spec section 10, step 1).
/// @dev Both contracts are created with CREATE2 and salt zero, so their addresses follow from this
/// contract's address and their init code: the implementation's from `_config`, the proxy's from
/// the implementation's address and `_owner`. Created through a CREATE2 factory with init code
/// that commits to `_config` and `_owner`, this contract fixes all three addresses in advance. The
/// proxy is initialized in the call that creates it, so no one else can initialize it. The
/// contract holds no state; it only reports the two addresses.
/// @custom:security-contact security@taiko.xyz
contract EtnaStakingDeployer {
    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The `EtnaStaking` implementation.
    address public immutable implementation;

    /// @notice The `EtnaStaking` proxy, initialized with the owner.
    address public immutable proxy;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Deploys the implementation with `_config`, then the proxy initialized with
    /// `_owner`.
    /// @param _config The implementation's immutable parameters, which its constructor checks.
    /// @param _owner The proxy's owner, the DAO's execution address on L2; nonzero, because `init`
    /// would replace a zero owner with its caller, this contract.
    constructor(IEtnaStaking.Config memory _config, address _owner) {
        require(_owner != address(0), ZeroOwner());
        address impl = address(new EtnaStaking{ salt: bytes32(0) }(_config));
        implementation = impl;
        proxy = address(
            new ERC1967Proxy{ salt: bytes32(0) }(impl, abi.encodeCall(EtnaStaking.init, (_owner)))
        );
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error ZeroOwner();
}
