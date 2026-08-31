// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";

/// @title DeployBridgeUpgradeL2
/// @notice Deploys the L2 resolver and `Bridge` implementation that Proposal0022 wires up.
/// @dev Deploys new contracts only. It does not upgrade the bridge proxy and registers no names:
/// Proposal0022 registers the `bridge` name for chains 1 and 167000 as DAO actions, which is why
/// the resolver is initialised with the DelegateController as its owner.
///
/// A new resolver is required because the live L2 bridge implementation (`0x95ae2918…`, protocol
/// 1.10.0) predates the resolver refactor. The legacy L2 registry `0x1670…0006` only answers
/// `getAddress(uint64,bytes32)`, while `Bridge` on `main` calls
/// `IResolver.resolve(uint256,bytes32,bool)`. This mirrors the split L1 made in May 2025, where
/// the NFT vaults still resolve through the legacy shared_address_manager.
/// @custom:security-contact security@taiko.xyz
contract DeployBridgeUpgradeL2 is Script {
    struct Deployment {
        address resolverImpl;
        address resolverProxy;
        address bridgeImpl;
    }

    error ImmutableMismatch();
    error ResolverOwnerMismatch();

    /// @notice Deploys the contracts and logs the addresses Proposal0022 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployContracts();
        vm.stopBroadcast();

        _checkDeployment(deployment);

        console2.log("L2_SHARED_RESOLVER:", deployment.resolverProxy);
        console2.log("  resolver impl   :", deployment.resolverImpl);
        console2.log("BRIDGE_NEW_IMPL_L2:", deployment.bridgeImpl);
    }

    /// @dev Deploys the resolver behind an ERC1967 proxy owned by the DelegateController, then
    /// the bridge implementation that reads from it.
    /// @return deployment_ The three newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.resolverImpl = address(new DefaultResolver());
        deployment_.resolverProxy = address(
            new ERC1967Proxy(
                deployment_.resolverImpl,
                abi.encodeCall(DefaultResolver.init, (LibL2Addrs.DELEGATE_CONTROLLER))
            )
        );

        // No quota manager and no pauser on L2. `quota_manager`, `chain_watchdog` and
        // `bridge_watchdog` are all unset on the legacy L2 registry, so L2 has no Ether quota and
        // only the owner can pause today; zero preserves both. The 1.10.0 implementation has no
        // `receive()` at all, so the pauser-only `receive()` is not a regression either.
        deployment_.bridgeImpl = address(
            new Bridge(deployment_.resolverProxy, LibL2Addrs.SIGNAL_SERVICE, address(0), address(0))
        );
    }

    /// @dev Aborts if a constructor argument landed in the wrong position or the resolver did not
    /// take the DelegateController as its owner.
    /// @param _deployment The addresses to check.
    function _checkDeployment(Deployment memory _deployment) private view {
        require(
            DefaultResolver(_deployment.resolverProxy).owner() == LibL2Addrs.DELEGATE_CONTROLLER,
            ResolverOwnerMismatch()
        );

        Bridge bridgeImpl = Bridge(payable(_deployment.bridgeImpl));
        require(
            bridgeImpl.resolver() == _deployment.resolverProxy
                && address(bridgeImpl.signalService()) == LibL2Addrs.SIGNAL_SERVICE
                && address(bridgeImpl.quotaManager()) == address(0)
                && bridgeImpl.pauser() == address(0),
            ImmutableMismatch()
        );
    }
}
