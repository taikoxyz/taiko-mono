// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { EtnaSignalService } from "src/shared/signal/EtnaSignalService.sol";

/// @title EtnaSignalServiceUpgradeGuard
/// @notice Read-only checks around the L2 readiness message's `SignalService` upgrade (Etna
/// SWITCH.md section 3, ANCHORLESS.md section 8, step 3). The message's actions are
/// `checkBeforeUpgrade`, the proxy's `upgradeTo` and `checkAfterUpgrade`, in that order. The
/// `DelegateController` checks only call success, so every check reverts on failure, and a failed
/// check reverts the whole batch and leaves the message retriable with the proxy unchanged.
/// @dev Holds no state and no time: the batch carries no deadline or fork time, and the EIP-4788
/// read tells a block before Etna from an Etna block.
/// @custom:security-contact security@taiko.xyz
contract EtnaSignalServiceUpgradeGuard {
    /// @notice The canonical EIP-4788 beacon roots contract.
    address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice `keccak256` of the canonical EIP-4788 runtime bytecode.
    bytes32 public constant BEACON_ROOTS_CODE_HASH =
        0xf57acd40259872606d76197ef052f3d35588dadf919ee1f0e3cb9b62d3f4b02c;

    /// @notice Reverts unless the upgrade may run: `_proxy` still uses `_preEtnaImpl`, the
    /// EIP-4788 contract has its canonical runtime code, and it returns a zero root for the current
    /// block's timestamp. The last two show that the execution engine makes the EIP-4788 call and
    /// that this is a block before Etna, so the upgraded `SignalService` still accepts the
    /// `Anchor`'s checkpoints.
    /// @param _proxy The L2 `SignalService` proxy.
    /// @param _preEtnaImpl The implementation the proxy must still use; any other one, such as the
    /// one a superseding message installed, rejects.
    function checkBeforeUpgrade(address _proxy, address _preEtnaImpl) external view {
        if (EssentialContract(_proxy).impl() != _preEtnaImpl) revert UnexpectedImplementation();
        if (BEACON_ROOTS.codehash != BEACON_ROOTS_CODE_HASH) revert BeaconRootsCodeMismatch();
        // The whole calldata is the 32-byte timestamp. A timestamp without an entry reverts.
        (bool ok, bytes memory ret) = BEACON_ROOTS.staticcall(abi.encode(block.timestamp));
        if (!ok || ret.length != 32 || abi.decode(ret, (bytes32)) != 0) revert NotBeforeEtna();
    }

    /// @notice Reverts unless `_proxy` uses `_expectedImpl`, whose runtime code hashes to
    /// `_expectedCodeHash`, and that `EtnaSignalService` implementation reports `usesBeaconRoots()`
    /// true. The syncer and remote are immutables without getters; the builder computes the hash
    /// from the implementation rebuilt with the expected syncer, remote, pauser and flag, so the
    /// batch itself rejects any other code.
    /// @param _proxy The L2 `SignalService` proxy.
    /// @param _expectedImpl The Etna L2 `SignalService` implementation, an `EtnaSignalService`.
    /// @param _expectedCodeHash `keccak256` of that implementation's runtime code.
    function checkAfterUpgrade(
        address _proxy,
        address _expectedImpl,
        bytes32 _expectedCodeHash
    )
        external
        view
    {
        if (EssentialContract(_proxy).impl() != _expectedImpl) revert UnexpectedImplementation();
        if (_expectedImpl.codehash != _expectedCodeHash) revert UnexpectedCodeHash();
        if (!EtnaSignalService(_proxy).usesBeaconRoots()) revert BeaconRootsUnused();
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BeaconRootsCodeMismatch();
    error BeaconRootsUnused();
    error NotBeforeEtna();
    error UnexpectedCodeHash();
    error UnexpectedImplementation();
}
