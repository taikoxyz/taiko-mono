// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import  "forge-std/console2.sol";
import  "forge-std/StdJson.sol";
import  "forge-std/Test.sol";

import  "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import  "../contracts/common/AddressManager.sol";
import  "../contracts/common/AddressResolver.sol";
import  "../contracts/common/EssentialContract.sol";
import  "../contracts/bridge/Bridge.sol";
import  "../contracts/tokenvault/ERC1155Vault.sol";
import  "../contracts/tokenvault/ERC20Vault.sol";
import  "../contracts/tokenvault/ERC721Vault.sol";
import  "../contracts/bridge/IBridge.sol";
import  "../contracts/test/erc20/RegularERC20.sol";
import  "../contracts/signal/SignalService.sol";
import  "../contracts/L2/TaikoL2.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON = vm.readFile(
        string.concat(vm.projectRoot(), "/deployments/genesis_config.json")
    );
    string private genesisAllocJSON = vm.readFile(
        string.concat(vm.projectRoot(), "/deployments/genesis_alloc.json")
    );
    address private owner = configJSON.readAddress(".contractOwner");
    address private admin = configJSON.readAddress(".contractAdmin");

    function testSingletonContractDeployment() public {
        assertEq(block.chainid, 167);

        // check bytecode
        checkDeployedCode("ProxiedSingletonERC20Vault");
        checkDeployedCode("ProxiedSingletonERC721Vault");
        checkDeployedCode("ProxiedSingletonERC1155Vault");
        checkDeployedCode("ProxiedSingletonBridge");
        checkDeployedCode("ProxiedSingletonSignalService");
        checkDeployedCode("ProxiedSingletonAddressManagerForSingletons");
        checkDeployedCode("ProxiedBridgedERC20");
        checkDeployedCode("ProxiedBridgedERC721");
        checkDeployedCode("ProxiedBridgedERC1155");

        // check proxy implementations
        checkProxyImplementation("SingletonERC20VaultProxy", "ProxiedSingletonERC20Vault");
        checkProxyImplementation("SingletonERC721VaultProxy", "ProxiedSingletonERC721Vault");
        checkProxyImplementation("SingletonERC1155VaultProxy", "ProxiedSingletonERC1155Vault");
        checkProxyImplementation("SingletonBridgeProxy", "ProxiedSingletonBridge");
        checkProxyImplementation("SingletonSignalServiceProxy", "ProxiedSingletonSignalService");
        checkProxyImplementation(
            "SingletonAddressManagerForSingletonsProxy", "ProxiedSingletonAddressManagerForSingletons"
        );

        // check proxies
        checkDeployedCode("SingletonERC20VaultProxy");
        checkDeployedCode("SingletonERC721VaultProxy");
        checkDeployedCode("SingletonERC1155VaultProxy");
        checkDeployedCode("SingletonBridgeProxy");
        checkDeployedCode("SingletonSignalServiceProxy");
        checkDeployedCode("SingletonAddressManagerForSingletonsProxy");
    }

    function testNonSingletonContractDeployment() public {
        // check bytecode
        checkDeployedCode("ProxiedSingletonTaikoL2");
        checkDeployedCode("ProxiedAddressManager");

        // check proxy implementations
        checkProxyImplementation("SingletonTaikoL2Proxy", "ProxiedSingletonTaikoL2");
        checkProxyImplementation("AddressManagerProxy", "ProxiedAddressManager");

        // check proxies
        checkDeployedCode("SingletonTaikoL2Proxy");
        checkDeployedCode("AddressManagerProxy");
    }

    function testAddressManager() public {
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, addressManager.owner());

        checkSavedAddress(addressManager, "SingletonTaikoL2Proxy", "taiko");
        checkSavedAddress(
            addressManager, "SingletonSignalServiceProxy", "signal_service"
        );

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("AddressManagerProxy"))
        );

        AddressManager newAddressManager = new AddressManager();

        vm.startPrank(admin);

        proxy.upgradeTo(address(newAddressManager));

        assertEq(proxy.implementation(), address(newAddressManager));
        vm.stopPrank();
    }

    function testSingletonAddressManagerForSingletons() public {
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SingletonAddressManagerForSingletonsProxy"));

        assertEq(owner, addressManager.owner());

        checkSavedAddress(addressManager, "SingletonBridgeProxy", "bridge");
        checkSavedAddress(addressManager, "SingletonERC20VaultProxy", "erc20_vault");
        checkSavedAddress(addressManager, "SingletonERC721VaultProxy", "erc721_vault");
        checkSavedAddress(addressManager, "SingletonERC1155VaultProxy", "erc1155_vault");
        checkSavedAddress(
            addressManager, "SingletonSignalServiceProxy", "signal_service"
        );

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonAddressManagerForSingletonsProxy"))
        );

        AddressManager newAddressManager = new AddressManager();

        vm.startPrank(admin);

        proxy.upgradeTo(address(newAddressManager));

        assertEq(proxy.implementation(), address(newAddressManager));
        vm.stopPrank();
    }

    function testTaikoL2() public {
        TaikoL2 taikoL2 = TaikoL2(getPredeployedContractAddress("SingletonTaikoL2Proxy"));

        vm.startPrank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        for (uint32 i = 0; i < 300; ++i) {
            vm.roll(block.number + 1);
            vm.warp(block.number + 12);
            vm.fee(taikoL2.getBasefee(12, i));

            uint256 gasLeftBefore = gasleft();

            taikoL2.anchor(
                keccak256(abi.encodePacked(block.timestamp, i)),
                keccak256(abi.encodePacked(block.timestamp, i)),
                i + 1,
                i + 1
            );

            if (i == 299) {
                console2.log(
                    "TaikoL2.anchor gas cost after 256 L2 blocks:",
                    gasLeftBefore - gasleft()
                );
            }
        }
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonTaikoL2Proxy"))
        );

        TaikoL2 newTaikoL2 = new TaikoL2();

        proxy.upgradeTo(address(newTaikoL2));

        assertEq(proxy.implementation(), address(newTaikoL2));
        vm.stopPrank();
    }

    function testSingletonBridge() public {
        address payable bridgeAddress =
            payable(getPredeployedContractAddress("SingletonBridgeProxy"));
        Bridge bridge = Bridge(bridgeAddress);

        assertEq(owner, bridge.owner());

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(
            IBridge.Message({
                id: 0,
                from: address(0),
                srcChainId: 1,
                destChainId: 167,
                owner: address(0),
                to: address(0),
                refundTo: address(0),
                value: 0,
                fee: 0,
                gasLimit: 0,
                data: "",
                memo: ""
            }),
            ""
        );

        assertEq(bridge.paused(), false);

        vm.startPrank(owner);
        bridge.pause();
        assertEq(bridge.paused(), true);

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        bridge.processMessage(
            IBridge.Message({
                id: 0,
                from: address(0),
                srcChainId: 1,
                destChainId: 167,
                owner: address(0),
                to: address(0),
                refundTo: address(0),
                value: 0,
                fee: 0,
                gasLimit: 0,
                data: "",
                memo: ""
            }),
            ""
        );

        bridge.unpause();
        assertEq(bridge.paused(), false);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonBridgeProxy"))
        );

        Bridge newBridge = new Bridge();

        proxy.upgradeTo(address(newBridge));

        assertEq(proxy.implementation(), address(newBridge));
        vm.stopPrank();
    }


    function testSingletonERC20Vault() public {
        address erc20VaultAddress =
            getPredeployedContractAddress("SingletonERC20VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("SingletonBridgeProxy");

        ERC20Vault erc20Vault = ERC20Vault(erc20VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SingletonAddressManagerForSingletonsProxy"));

        assertEq(owner, erc20Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc20_vault", erc20VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonERC20VaultProxy"))
        );

        ERC20Vault newERC20Vault = new ERC20Vault();

        proxy.upgradeTo(address(newERC20Vault));

        assertEq(proxy.implementation(), address(newERC20Vault));
        vm.stopPrank();
    }

    function testSingletonERC721Vault() public {
        address erc721VaultAddress =
            getPredeployedContractAddress("SingletonERC721VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("SingletonBridgeProxy");

        ERC721Vault erc721Vault = ERC721Vault(erc721VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SingletonAddressManagerForSingletonsProxy"));

        assertEq(owner, erc721Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc721_vault", erc721VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonERC721VaultProxy"))
        );

        ERC721Vault newERC721Vault = new ERC721Vault();

        proxy.upgradeTo(address(newERC721Vault));

        assertEq(proxy.implementation(), address(newERC721Vault));
        vm.stopPrank();
    }

    function testSingletonERC1155Vault() public {
        address erc1155VaultAddress =
            getPredeployedContractAddress("SingletonERC1155VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("SingletonBridgeProxy");

        ERC1155Vault erc1155Vault = ERC1155Vault(erc1155VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SingletonAddressManagerForSingletonsProxy"));

        assertEq(owner, erc1155Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc1155_vault", erc1155VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonERC1155VaultProxy"))
        );

        ERC1155Vault newERC1155Vault = new ERC1155Vault();

        proxy.upgradeTo(address(newERC1155Vault));

        assertEq(proxy.implementation(), address(newERC1155Vault));
        vm.stopPrank();
    }

    function testSingletonSignalService() public {
        SignalService signalService =
            SignalService(getPredeployedContractAddress("SingletonSignalServiceProxy"));

        assertEq(owner, signalService.owner());

        signalService.sendSignal(keccak256(abi.encodePacked(block.prevrandao)));

        assertEq(true, signalService.isAuthorizedAs(getPredeployedContractAddress("SingletonTaikoL2Proxy"), bytes32((block.chainid))));

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("SingletonSignalServiceProxy"))
        );

        SignalService newSignalService = new SignalService();

        proxy.upgradeTo(address(newSignalService));

        assertEq(proxy.implementation(), address(newSignalService));
        vm.stopPrank();
    }

    function testERC20() public {
        RegularERC20 regularERC20 =
            RegularERC20(getPredeployedContractAddress("RegularERC20"));

        assertEq(regularERC20.name(), "RegularERC20");
        assertEq(regularERC20.symbol(), "RGL");
    }

    function getPredeployedContractAddress(string memory contractName)
        private
        returns (address)
    {
        return configJSON.readAddress(
            string.concat(".contractAddresses.", contractName)
        );
    }

    function checkDeployedCode(string memory contractName) private {
        address contractAddress = getPredeployedContractAddress(contractName);
        string memory deployedCode = genesisAllocJSON.readString(
            string.concat(".", vm.toString(contractAddress), ".code")
        );

        assertEq(address(contractAddress).code, vm.parseBytes(deployedCode));
    }

    function checkProxyImplementation(
        string memory proxyName,
        string memory contractName
    )
        private
    {
        vm.startPrank(admin);
        address contractAddress = getPredeployedContractAddress(contractName);
        address proxyAddress = getPredeployedContractAddress(proxyName);

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(proxyAddress));

        assertEq(proxy.implementation(), address(contractAddress));

        assertEq(proxy.admin(), admin);

        vm.stopPrank();
    }

    function checkSavedAddress(
        AddressManager addressManager,
        string memory contractName,
        bytes32 name
    )
        private
    {
        assertEq(
            getPredeployedContractAddress(contractName),
            addressManager.getAddress(uint64(block.chainid), name)
        );
    }
}
