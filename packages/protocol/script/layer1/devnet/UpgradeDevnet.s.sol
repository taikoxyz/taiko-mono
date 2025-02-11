// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/devnet/verifiers/OpVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/DevnetInbox.sol";

contract UpgradeDevnet is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public oldFork = vm.envAddress("OLD_FORK");
    address public taikoInbox = vm.envAddress("TAIKO_INBOX");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(oldFork != address(0), "invalid old fork");
        require(taikoInbox != address(0), "invalid taiko inbox");
        require(sgxVerifier != address(0), "invalid sgx verifier");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address rollupResolver = 0x44D002e1b67d0D90829fB1dB90D26785BEe55372;
        // TaikoInbox
        address newFork = address(new DevnetInbox(rollupResolver));
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));

        // Verifier
        TaikoInbox taikoInboxImpl = TaikoInbox(newFork);
        uint64 l2ChainId = taikoInboxImpl.pacayaConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");
        UUPSUpgradeable(sgxVerifier).upgradeTo(address(new SgxVerifier(rollupResolver, l2ChainId)));

    }
}
