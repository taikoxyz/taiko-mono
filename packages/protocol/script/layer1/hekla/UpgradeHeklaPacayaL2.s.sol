pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";

contract UpgradeHeklaPacayaL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newTaikoAnchor = vm.envAddress("TAIKO_ANCHOR");
    address public newResolver = vm.envAddress("NEW_RESOLVER");
    address public newBridgeL2 = vm.envAddress("NEW_BRIDGE_L2");
    address public newSignalService = vm.envAddress("NEW_SIGNAL_SERVICE");
    address public newErc20Vault = vm.envAddress("NEW_ERC20_VAULT");
    address public newErc721Vault = vm.envAddress("NEW_ERC721_VAULT");
    address public newErc1155Vault = vm.envAddress("NEW_ERC1155_VAULT");
    address public newBridgedErc20 = vm.envAddress("NEW_Bridged_ERC20");
    address public newBridgedErc721 = vm.envAddress("NEW_Bridged_ERC721");
    address public newBridgedErc1155 = vm.envAddress("NEW_Bridged_ERC1155");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](12);
        // Taiko Anchor
        calls[0].target = 0x1670090000000000000000000000000000010001;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newTaikoAnchor));
        // Bridge
        calls[1].target = 0x1670090000000000000000000000000000000001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newBridgeL2));
        // Rollup resolver
        calls[2].target = 0x1670090000000000000000000000000000010002;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newResolver));
        // Shared resolver
        calls[3].target = 0x1670090000000000000000000000000000000006;
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newResolver));
        // SignalService
        calls[4].target = 0x1670090000000000000000000000000000000005;
        calls[4].allowFailure = false;
        calls[4].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newSignalService));
        // VaultToken
        calls[5].target = 0x1670090000000000000000000000000000000002;
        calls[5].allowFailure = false;
        calls[5].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newErc20Vault));
        calls[6].target = 0x1670090000000000000000000000000000000003;
        calls[6].allowFailure = false;
        calls[6].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newErc721Vault));
        calls[7].target = 0x1670090000000000000000000000000000000004;
        calls[7].allowFailure = false;
        calls[7].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newErc1155Vault));
        // Register Bridged Token
        calls[8].target = 0x1670090000000000000000000000000000000006;
        calls[8].allowFailure = false;
        calls[8].callData = abi.encodeCall(
            DefaultResolver.registerAddress,
            (167_009, bytes32(bytes("bridged_erc20")), newBridgedErc20)
        );
        calls[9].target = 0x1670090000000000000000000000000000000006;
        calls[9].allowFailure = false;
        calls[9].callData = abi.encodeCall(
            DefaultResolver.registerAddress,
            (167_009, bytes32(bytes("bridged_erc721")), newBridgedErc721)
        );
        calls[10].target = 0x1670090000000000000000000000000000000006;
        calls[10].allowFailure = false;
        calls[10].callData = abi.encodeCall(
            DefaultResolver.registerAddress,
            (167_009, bytes32(bytes("bridged_erc1155")), newBridgedErc1155)
        );
        // Register B_TAIKO
        calls[11].target = 0x1670090000000000000000000000000000000006;
        calls[11].allowFailure = false;
        calls[11].callData = abi.encodeCall(
            DefaultResolver.registerAddress,
            (167_009, bytes32(bytes("taiko")), 0x1670090000000000000000000000000000010001)
        );

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 0,
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 5_000_000,
            from: msg.sender,
            srcChainId: 17_000,
            srcOwner: msg.sender,
            destChainId: 167_009,
            destOwner: delegateOwner,
            to: delegateOwner,
            value: 0,
            data: abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall))
        });

        IBridge(0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807).sendMessage(message);
    }
}
