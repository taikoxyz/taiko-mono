// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/StdJson.sol";
import "../../contracts/bridge/BridgeErrors.sol";
import "../../contracts/bridge/IBridge.sol";
import "../../contracts/common/AddressResolver.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoL2} from "../../contracts/L2/TaikoL2.sol";
import {AddressManager} from "../../contracts/common/AddressManager.sol";
import {Bridge} from "../../contracts/bridge/Bridge.sol";
import {TokenVault} from "../../contracts/bridge/TokenVault.sol";
import {EtherVault} from "../../contracts/bridge/EtherVault.sol";
import {SignalService} from "../../contracts/signal/SignalService.sol";
import {LibBridgeStatus} from "../../contracts/bridge/libs/LibBridgeStatus.sol";
import {LibL2Consts} from "../../contracts/L2/LibL2Consts.sol";
import {RegularERC20} from "../../contracts/test/erc20/RegularERC20.sol";
import {TransparentUpgradeableProxy} from
    "../../contracts/thirdparty/TransparentUpgradeableProxy.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/test_config.json"));
    string private genesisAllocJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/deployments/genesis_alloc.json"));
    address private owner = configJSON.readAddress(".contractOwner");
    address private admin = configJSON.readAddress(".contractAdmin");

    uint64 public constant BLOCK_GAS_LIMIT = 30000000;

    function testContractDeployment() public {
        assertEq(block.chainid, 167);

        checkDeployedCode("ProxiedTaikoL2");
        checkDeployedCode("ProxiedTokenVault");
        checkDeployedCode("ProxiedEtherVault");
        checkDeployedCode("ProxiedBridge");
        checkDeployedCode("RegularERC20");
        checkDeployedCode("ProxiedAddressManager");
        checkDeployedCode("ProxiedSignalService");

        // check proxy implementations
        checkProxyImplementation("TaikoL2Proxy", "ProxiedTaikoL2");
        checkProxyImplementation("TokenVaultProxy", "ProxiedTokenVault");
        checkProxyImplementation("EtherVaultProxy", "ProxiedEtherVault");
        checkProxyImplementation("BridgeProxy", "ProxiedBridge");
        checkProxyImplementation("AddressManagerProxy", "ProxiedAddressManager");
        checkProxyImplementation("SignalServiceProxy", "ProxiedSignalService");

        // check proxies
        checkDeployedCode("TaikoL2Proxy");
        checkDeployedCode("TokenVaultProxy");
        checkDeployedCode("EtherVaultProxy");
        checkDeployedCode("BridgeProxy");
        checkDeployedCode("AddressManagerProxy");
        checkDeployedCode("SignalServiceProxy");
    }

    function testAddressManager() public {
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, addressManager.owner());

        checkSavedAddress(addressManager, "BridgeProxy", "bridge");
        checkSavedAddress(addressManager, "TokenVaultProxy", "token_vault");
        checkSavedAddress(addressManager, "EtherVaultProxy", "ether_vault");
        checkSavedAddress(addressManager, "TaikoL2Proxy", "taiko");
        checkSavedAddress(addressManager, "SignalServiceProxy", "signal_service");

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("AddressManagerProxy"))
        );

        AddressManager newAddressManager = new AddressManager();

        vm.startPrank(admin);

        proxy.upgradeTo(address(newAddressManager));

        assertEq(proxy.implementation(), address(newAddressManager));
        vm.stopPrank();
    }

    function testTaikoL2() public {
        TaikoL2 taikoL2 = TaikoL2(getPredeployedContractAddress("TaikoL2Proxy"));

        vm.startPrank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        for (uint64 i = 0; i < 300; i++) {
            vm.roll(block.number + 1);
            vm.warp(taikoL2.parentTimestamp() + 12);
            vm.fee(taikoL2.getBasefee(12, BLOCK_GAS_LIMIT, i + LibL2Consts.ANCHOR_GAS_COST));

            uint256 gasLeftBefore = gasleft();

            taikoL2.anchor(
                bytes32(block.difficulty),
                bytes32(block.difficulty),
                i,
                i + LibL2Consts.ANCHOR_GAS_COST
            );

            if (i == 299) {
                console2.log(
                    "TaikoL2.anchor gas cost after 256 L2 blocks:", gasLeftBefore - gasleft()
                );
            }
        }
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(getPredeployedContractAddress("TaikoL2Proxy")));

        TaikoL2 newTaikoL2 = new TaikoL2();

        proxy.upgradeTo(address(newTaikoL2));

        assertEq(proxy.implementation(), address(newTaikoL2));
        vm.stopPrank();
    }

    function testBridge() public {
        address payable bridgeAddress = payable(getPredeployedContractAddress("BridgeProxy"));
        Bridge bridge = Bridge(bridgeAddress);

        assertEq(owner, bridge.owner());

        vm.expectRevert(BridgeErrors.B_FORBIDDEN.selector);
        bridge.processMessage(
            IBridge.Message({
                id: 0,
                sender: address(0),
                srcChainId: 1,
                destChainId: 167,
                owner: address(0),
                to: address(0),
                refundAddress: address(0),
                depositValue: 0,
                callValue: 0,
                processingFee: 0,
                gasLimit: 0,
                data: "",
                memo: ""
            }),
            ""
        );

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(getPredeployedContractAddress("BridgeProxy")));

        Bridge newBridge = new Bridge();

        proxy.upgradeTo(address(newBridge));

        assertEq(proxy.implementation(), address(newBridge));
        vm.stopPrank();
    }

    function testEtherVault() public {
        address payable etherVaultAddress =
            payable(getPredeployedContractAddress("EtherVaultProxy"));
        EtherVault etherVault = EtherVault(etherVaultAddress);

        assertEq(owner, etherVault.owner());

        assertEq(etherVault.isAuthorized(getPredeployedContractAddress("BridgeProxy")), true);
        assertEq(etherVault.isAuthorized(etherVault.owner()), false);

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(getPredeployedContractAddress("EtherVaultProxy")));

        EtherVault newEtherVault = new EtherVault();

        proxy.upgradeTo(address(newEtherVault));

        assertEq(proxy.implementation(), address(newEtherVault));
        vm.stopPrank();
    }

    function testTokenVault() public {
        address tokenVaultAddress = getPredeployedContractAddress("TokenVaultProxy");
        address bridgeAddress = getPredeployedContractAddress("BridgeProxy");

        TokenVault tokenVault = TokenVault(tokenVaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, tokenVault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "token_vault", tokenVaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(getPredeployedContractAddress("TokenVaultProxy")));

        TokenVault newTokenVault = new TokenVault();

        proxy.upgradeTo(address(newTokenVault));

        assertEq(proxy.implementation(), address(newTokenVault));
        vm.stopPrank();
    }

    function testSignalService() public {
        SignalService signalService =
            SignalService(getPredeployedContractAddress("SignalServiceProxy"));

        assertEq(owner, signalService.owner());

        signalService.sendSignal(keccak256(abi.encodePacked(block.prevrandao)));

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SignalServiceProxy"))
        );

        SignalService newSignalService = new SignalService();

        proxy.upgradeTo(address(newSignalService));

        assertEq(proxy.implementation(), address(newSignalService));
        vm.stopPrank();
    }

    function testERC20() public {
        RegularERC20 regularERC20 = RegularERC20(getPredeployedContractAddress("RegularERC20"));

        assertEq(regularERC20.name(), "RegularERC20");
        assertEq(regularERC20.symbol(), "RGL");
    }

    function getPredeployedContractAddress(string memory contractName) private returns (address) {
        return configJSON.readAddress(string.concat(".contractAddresses.", contractName));
    }

    function checkDeployedCode(string memory contractName) private {
        address contractAddress = getPredeployedContractAddress(contractName);
        string memory deployedCode =
            genesisAllocJSON.readString(string.concat(".", vm.toString(contractAddress), ".code"));

        assertEq(address(contractAddress).code, vm.parseBytes(deployedCode));
    }

    function checkProxyImplementation(string memory proxyName, string memory contractName)
        private
    {
        vm.startPrank(admin);
        address contractAddress = getPredeployedContractAddress(contractName);
        address proxyAddress = getPredeployedContractAddress(proxyName);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(proxyAddress));

        assertEq(proxy.implementation(), address(contractAddress));

        assertEq(proxy.admin(), admin);

        vm.stopPrank();
    }

    function checkSavedAddress(
        AddressManager addressManager,
        string memory contractName,
        bytes32 name
    ) private {
        assertEq(
            getPredeployedContractAddress(contractName),
            addressManager.getAddress(block.chainid, name)
        );
    }
}
