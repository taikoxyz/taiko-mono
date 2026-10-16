// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";

/// @title ExportEtnaGenesis
/// @notice Constructs the immutable vault in the local Foundry VM and exports its runtime JSON.
/// @dev Requires explicit L1_CHAIN_ID, L1_INBOX and ETNA_RUNTIME_OUTPUT environment variables.
/// No broadcast is started; this script does not deploy to a network. Do not add --broadcast.
/// @custom:security-contact security@taiko.xyz
contract ExportEtnaGenesis is Script {
    /// @notice Exports runtime with fully initialized immutables to ETNA_RUNTIME_OUTPUT.
    /// @return runtime_ The actual deployed code constructed from the explicit L1 identity.
    function run() external returns (bytes memory runtime_) {
        uint256 l1ChainId = vm.envUint("L1_CHAIN_ID");
        address l1Inbox = vm.envAddress("L1_INBOX");
        return exportRuntime(l1ChainId, l1Inbox, vm.envString("ETNA_RUNTIME_OUTPUT"));
    }

    /// @notice Constructs and saves runtime for an explicit L1 identity without broadcasting.
    /// @param _l1ChainId The nonzero L1 chain ID.
    /// @param _l1Inbox The nonzero L1 Inbox address.
    /// @param _output The output path, within Foundry's permitted deployments directory.
    /// @return runtime_ The fully initialized deployed runtime.
    function exportRuntime(
        uint256 _l1ChainId,
        address _l1Inbox,
        string memory _output
    )
        public
        returns (bytes memory runtime_)
    {
        runtime_ = address(new L2FeeVault(_l1ChainId, _l1Inbox)).code;
        string memory object = "etnaVaultRuntime";
        vm.serializeString(object, "l1ChainId", vm.toString(_l1ChainId));
        vm.serializeAddress(object, "l1Inbox", _l1Inbox);
        string memory json = vm.serializeBytes(object, "runtime", runtime_);
        vm.writeJson(json, _output);
    }
}
