pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Init3Bridge.sol";
import "src/shared/tokenvault/Init3ERC20Vault.sol";
import "src/shared/tokenvault/Init3ERC721Vault.sol";
import "src/shared/tokenvault/Init3ERC1155Vault.sol";
import "src/shared/tokenvault/Init3BridgedERC20.sol";
import "src/shared/tokenvault/Init3BridgedERC721.sol";
import "src/shared/tokenvault/Init3BridgedERC1155.sol";

contract UpgradeHeklaPacayaL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public init3Bridge = vm.envAddress("INIT3_BRIDGE");
    address public init3ERC20Vault = vm.envAddress("INIT3_ERC20_VAULT");
    address public init3ERC721Vault = vm.envAddress("INIT3_ERC721_VAULT");
    address public init3ERC1155Vault = vm.envAddress("INIT3_ERC1155_VAULT");
    address public init3BridgedERC20 = vm.envAddress("INIT3_BRIDGED_ERC20");
    address public init3BridgedERC721 = vm.envAddress("INIT3_BRIDGED_ERC721");
    address public init3BridgedERC1155 = vm.envAddress("INIT3_BRIDGED_ERC1155");
    address public sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](21);
        // upgrade bridge
        calls[0].target = 0x1670090000000000000000000000000000000001;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3Bridge));
        calls[1].target = 0x1670090000000000000000000000000000000001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(Init3Bridge.init3, (sharedAddressManager));
        // upgrade vault token
        calls[2].target = 0x1670090000000000000000000000000000000002;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3ERC20Vault));
        calls[3].target = 0x1670090000000000000000000000000000000002;
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(Init3ERC20Vault.init3, (sharedAddressManager));
        calls[4].target = 0x1670090000000000000000000000000000000003;
        calls[4].allowFailure = false;
        calls[4].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3ERC721Vault));
        calls[5].target = 0x1670090000000000000000000000000000000003;
        calls[5].allowFailure = false;
        calls[5].callData = abi.encodeCall(Init3ERC721Vault.init3, (sharedAddressManager));
        calls[6].target = 0x1670090000000000000000000000000000000004;
        calls[6].allowFailure = false;
        calls[6].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3ERC1155Vault));
        calls[7].target = 0x1670090000000000000000000000000000000004;
        calls[7].allowFailure = false;
        calls[7].callData = abi.encodeCall(Init3ERC1155Vault.init3, (sharedAddressManager));
        // upgrade bridged token
        calls[8].target = 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF;
        calls[8].allowFailure = false;
        calls[8].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3BridgedERC20));
        calls[9].target = 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF;
        calls[9].allowFailure = false;
        calls[9].callData = abi.encodeCall(Init3BridgedERC20.init3, (sharedAddressManager));
        calls[10].target = 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566;
        calls[10].allowFailure = false;
        calls[10].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3BridgedERC721));
        calls[11].target = 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566;
        calls[11].allowFailure = false;
        calls[11].callData = abi.encodeCall(Init3BridgedERC721.init3, (sharedAddressManager));
        calls[12].target = 0xb190786090Fc4308c4C40808f3bEB55c4463c152;
        calls[12].allowFailure = false;
        calls[12].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (init3BridgedERC1155));
        calls[13].target = 0xb190786090Fc4308c4C40808f3bEB55c4463c152;
        calls[13].allowFailure = false;
        calls[13].callData = abi.encodeCall(Init3BridgedERC1155.init3, (sharedAddressManager));
        // revert to original impl
        calls[14].target = 0x1670090000000000000000000000000000000001;
        calls[14].allowFailure = false;
        calls[14].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x50216f60163ef399E22026fa1300aEa8eebA3462));
        calls[15].target = 0x1670090000000000000000000000000000000002;
        calls[15].allowFailure = false;
        calls[15].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x4A5AE0837cfb6C40c7DaF0885ac6c35e2EE644f1));
        calls[16].target = 0x1670090000000000000000000000000000000003;
        calls[16].allowFailure = false;
        calls[16].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x2DdAad1110F2F69238Eb834851437fc05DAb62b9));
        calls[17].target = 0x1670090000000000000000000000000000000004;
        calls[17].allowFailure = false;
        calls[17].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x58366150b4E1B18dd0D3F043Ba45a9BECb53cd85));
        calls[18].target = 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF;
        calls[18].allowFailure = false;
        calls[18].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF));
        calls[19].target = 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566;
        calls[19].allowFailure = false;
        calls[19].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x45327BDbe23c1a3F0b437C78a19E813f9b11E566));
        calls[20].target = 0xb190786090Fc4308c4C40808f3bEB55c4463c152;
        calls[20].allowFailure = false;
        calls[20].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (0xb190786090Fc4308c4C40808f3bEB55c4463c152));

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 0,
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        bytes memory cData = abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall));
        console.logBytes(cData);
    }
}
