// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";

/// @title DeployBridgeUpgradeL1
/// @notice Deploys the L1 `Bridge` implementation that Proposal0022 upgrades the mainnet bridge
/// proxy to.
/// @dev Deploys a new implementation only. It does not upgrade the proxy and does not call any
/// initializer.
///
/// The four constructor arguments reproduce the immutables the live implementation
/// (`0x1c94D798CFA08F396E5BA9F81697289c53273381`, deployed by Proposal0017) already carries.
/// Diffing the implementation's dependency tree from that commit to `main` leaves `Bridge.sol`,
/// `EssentialContract.sol` and an unused `LibNames` constant; the transient-storage refactor of
/// #22058 reuses the exact slot constants `MainnetBridge` and `LibFasterReentryLock` already
/// used. So the only behavioural change this implementation ships is `_SEND_ETHER_GAS_LIMIT`
/// rising from 35,000 to 135,000 gas (#22077).
/// @custom:security-contact security@taiko.xyz
contract DeployBridgeUpgradeL1 is Script {
    error ImmutableMismatch();

    /// @notice Deploys the implementation and logs the address Proposal0022 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        Bridge bridgeImpl = new Bridge(
            LibL1Addrs.SHARED_RESOLVER,
            LibL1Addrs.SIGNAL_SERVICE,
            LibL1Addrs.QUOTA_MANAGER,
            LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
        );
        vm.stopBroadcast();

        _checkImmutables(bridgeImpl);

        console2.log("BRIDGE_NEW_IMPL_L1:", address(bridgeImpl));
    }

    /// @dev Aborts if a constructor argument landed in the wrong position. All four are
    /// addresses, so a swapped pair compiles cleanly and would otherwise only surface once the
    /// proxy is pointed at it.
    /// @param _bridgeImpl The freshly deployed implementation.
    function _checkImmutables(Bridge _bridgeImpl) private view {
        require(
            _bridgeImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(_bridgeImpl.signalService()) == LibL1Addrs.SIGNAL_SERVICE
                && address(_bridgeImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER
                && _bridgeImpl.pauser() == LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
            ImmutableMismatch()
        );
    }
}
