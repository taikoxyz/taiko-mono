// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title DeployERC20VaultUpgradeL1
/// @notice Deploys the L1 `ERC20Vault` implementation that Proposal0023 upgrades the mainnet ERC20
/// vault proxy to.
/// @dev Deploys a new implementation only. It does not upgrade the proxy and does not call any
/// initializer.
///
/// The two constructor arguments reproduce the immutables the live implementation
/// (`0x024253C6FDC27d3161aFd43fb0241411A28dDc3c`, a `MainnetERC20Vault` deployed by Proposal0017)
/// already carries, and the script reads them back from the live proxy before broadcasting so a
/// drifted `LibL1Addrs` constant aborts the run instead of baking into the new immutables.
///
/// Diffing the implementation's dependency tree from that commit to `main` leaves `ERC20Vault.sol`
/// with the new `IPermit2.sol` (#22093), `EssentialContract.sol` (#22058, which folded
/// `MainnetERC20Vault`'s transient-storage reentry lock into the base contract at the same slot
/// constant) and an unused `LibNames` constant. So the behavioural change this implementation
/// ships is EIP-2612 permit and Permit2 support on the send path; the vault is otherwise the one
/// already live.
/// @custom:security-contact security@taiko.xyz
contract DeployERC20VaultUpgradeL1 is Script {
    error ImmutableMismatch();
    error LiveProxyMismatch();

    /// @notice Deploys the implementation and logs the address Proposal0023 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        _checkLiveProxy();

        vm.startBroadcast(privateKey);
        ERC20Vault vaultImpl = new ERC20Vault(LibL1Addrs.SHARED_RESOLVER, LibL1Addrs.QUOTA_MANAGER);
        vm.stopBroadcast();

        _checkImmutables(vaultImpl);

        console2.log("ERC20_VAULT_NEW_IMPL_L1:", address(vaultImpl));
    }

    /// @dev Aborts unless the live proxy answers the resolver and quota manager this script is
    /// about to compile into the new implementation. Both are reproduced from `LibL1Addrs`, and
    /// the whole point of the upgrade is to keep them.
    function _checkLiveProxy() private view {
        ERC20Vault live = ERC20Vault(LibL1Addrs.ERC20_VAULT);
        require(
            live.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(live.quotaManager()) == LibL1Addrs.QUOTA_MANAGER,
            LiveProxyMismatch()
        );
    }

    /// @dev Aborts if a constructor argument landed in the wrong position. Both are addresses, so
    /// a swapped pair compiles cleanly and would otherwise only surface once the proxy is pointed
    /// at it.
    /// @param _vaultImpl The freshly deployed implementation.
    function _checkImmutables(ERC20Vault _vaultImpl) private view {
        require(
            _vaultImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(_vaultImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER,
            ImmutableMismatch()
        );
    }
}
