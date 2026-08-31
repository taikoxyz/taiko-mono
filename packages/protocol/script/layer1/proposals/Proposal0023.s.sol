// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

// To print the proposal action data: `P=0023 pnpm proposal`
// To dryrun the proposal on L1: `P=0023 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0023 pnpm proposal:dryrun:l2`
/// @custom:security-contact security@taiko.xyz
contract Proposal0023 is BuildProposal {
    /// @dev Deployed by `DeployBridgeUpgradeL1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC&newimpl=0x8636d9707ED54443808bA89F1B1b74f4b134AAa6&chainid=1
    address public constant BRIDGE_NEW_IMPL_L1 = 0x8636d9707ED54443808bA89F1B1b74f4b134AAa6;

    /// @dev Deployed by `DeployBridgeUpgradeL2` on Taiko Alethia.
    /// https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000001&newimpl=0x097BBBef669AaD66030aB223195D200eF9A47dc3&chainid=167000
    address public constant BRIDGE_NEW_IMPL_L2 = 0x097BBBef669AaD66030aB223195D200eF9A47dc3;

    /// @dev The new L2 resolver, an ERC1967 proxy over implementation
    /// `0x4F750D13005444407D44dAA30922128db0374ca1`, owned by the DelegateController. It has no
    /// predecessor to diff against: the legacy registry `0x1670…0006` is a different contract that
    /// stays in place for the L2 vaults.
    address public constant L2_SHARED_RESOLVER = 0x2dfef0339009Ce10786fc118C883BB97af3163eD;

    uint256 private constant _L1_CHAIN_ID = 1;
    uint256 private constant _L2_CHAIN_ID = 167_000;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        return buildL1Actions(BRIDGE_NEW_IMPL_L1);
    }

    /// @dev Encodes the L1 leg against an injectable implementation address so tests can assert
    /// the encoding while the constant above is still a placeholder.
    /// @param _bridgeNewImplL1 The L1 `Bridge` implementation to upgrade to.
    /// @return actions The single L1 action.
    function buildL1Actions(address _bridgeNewImplL1)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(_bridgeNewImplL1 != address(0), ImplementationNotDeployed());

        actions = new Controller.Action[](1);

        // Upgrade the mainnet bridge to the implementation carrying the EIP-8037 Ether send cap.
        actions[0] = buildUpgradeAction(L1.BRIDGE, _bridgeNewImplL1);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        return buildL2Actions(L2_SHARED_RESOLVER, BRIDGE_NEW_IMPL_L2);
    }

    /// @dev Encodes the L2 leg against injectable addresses, for the same reason as the L1
    /// overload.
    /// @param _l2SharedResolver The newly deployed L2 `DefaultResolver` proxy.
    /// @param _bridgeNewImplL2 The L2 `Bridge` implementation to upgrade to.
    /// @return l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @return l2GasLimit The gas limit carried by the L1 to L2 message.
    /// @return actions The three L2 actions, in execution order.
    function buildL2Actions(
        address _l2SharedResolver,
        address _bridgeNewImplL2
    )
        internal
        pure
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        require(
            _l2SharedResolver != address(0) && _bridgeNewImplL2 != address(0),
            ImplementationNotDeployed()
        );

        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](3);

        // 0-1: Populate the new resolver before action 2 makes the implementation that reads it
        // live. Action 0 is the load-bearing one: `Bridge`'s three resolver lookups
        // (isDestChainEnabled, _proveSignalReceived, _isSignalReceived) all pass an explicit chain
        // id, and on L2 every reachable path passes the counterparty id 1, so the chain-1 entry is
        // what the new implementation reads on every sendMessage and processMessage. The legacy L2
        // registry `0x1670…0006` predates IResolver and cannot serve those calls, so registering
        // after the upgrade, or not at all, would revert both. Action 1 adds the chain-167000
        // entry for symmetry with the L1 resolver and for future consumers of the block.chainid
        // overload (the vaults' onlyFromNamed(B_BRIDGE), still on the legacy registry today); the
        // bridge itself never reads it.
        actions[0] = Controller.Action({
            target: _l2SharedResolver,
            value: 0,
            data: abi.encodeCall(
                DefaultResolver.registerAddress, (_L1_CHAIN_ID, LibNames.B_BRIDGE, L1.BRIDGE)
            )
        });
        actions[1] = Controller.Action({
            target: _l2SharedResolver,
            value: 0,
            data: abi.encodeCall(
                DefaultResolver.registerAddress, (_L2_CHAIN_ID, LibNames.B_BRIDGE, L2.BRIDGE)
            )
        });

        // 2: Upgrade the L2 bridge. This executes inside the bridge's own processMessage frame,
        // which is safe: _authorizeUpgrade carries no reentrancy guard, the DelegateController
        // reads the call context before executing actions, and the new implementation's transient
        // reentry slot starts at zero rather than _TRUE.
        actions[2] = buildUpgradeAction(L2.BRIDGE, _bridgeNewImplL2);
    }
}
