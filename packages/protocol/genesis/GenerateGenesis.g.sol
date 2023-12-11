// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console2.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";
import "../contracts/common/EssentialContract.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/tokenvault/ERC1155Vault.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/tokenvault/ERC721Vault.sol";
import "../contracts/test/erc20/RegularERC20.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/L2/TaikoL2.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/deployments/genesis_config.json"));
    string private genesisAllocJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/deployments/genesis_alloc.json"));
    address private ownerTimelockController = configJSON.readAddress(".ownerTimelockController");
    address private ownerSecurityCouncil = configJSON.readAddress(".ownerSecurityCouncil");
    uint256 private ownerChainId = configJSON.readUint(".ownerChainId");

    function testSharedContractsDeployment() public {
        assertEq(block.chainid, 167);

        // check bytecode
        checkDeployedCode("ERC20Vault");
        checkDeployedCode("ERC721Vault");
        checkDeployedCode("ERC1155Vault");
        checkDeployedCode("Bridge");
        checkDeployedCode("SignalService");
        checkDeployedCode("SharedAddressManager");
        checkDeployedCode("BridgedERC20Impl");
        checkDeployedCode("BridgedERC721Impl");
        checkDeployedCode("BridgedERC1155Impl");

        // check proxy implementations
        checkProxyImplementation("ERC20Vault", "ERC20VaultImpl");
        checkProxyImplementation("ERC721Vault", "ERC721VaultImpl");
        checkProxyImplementation("ERC1155Vault", "ERC1155VaultImpl");
        checkProxyImplementation("Bridge", "BridgeImpl");
        checkProxyImplementation("SignalService", "SignalServiceImpl");
        checkProxyImplementation("SharedAddressManager", "SharedAddressManagerImpl");

        // // check proxies
        checkDeployedCode("ERC20Vault");
        checkDeployedCode("ERC721Vault");
        checkDeployedCode("ERC1155Vault");
        checkDeployedCode("Bridge");
        checkDeployedCode("SignalService");
        checkDeployedCode("SharedAddressManager");
    }

    function testRollupContractsDeployment() public {
        // check bytecode
        checkDeployedCode("TaikoL2");
        checkDeployedCode("RollupAddressManager");

        // check proxy implementations
        checkProxyImplementation("TaikoL2", "TaikoL2Impl", ownerTimelockController);
        checkProxyImplementation("RollupAddressManager", "RollupAddressManagerImpl");

        // check proxies
        checkDeployedCode("TaikoL2");
        checkDeployedCode("RollupAddressManager");
    }

    function testSharedAddressManager() public {
        AddressManager addressManagerProxy =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(ownerSecurityCouncil, addressManagerProxy.owner());

        checkSavedAddress(addressManagerProxy, "Bridge", "bridge");
        checkSavedAddress(addressManagerProxy, "ERC20Vault", "erc20_vault");
        checkSavedAddress(addressManagerProxy, "ERC721Vault", "erc721_vault");
        checkSavedAddress(addressManagerProxy, "ERC1155Vault", "erc1155_vault");
        checkSavedAddress(addressManagerProxy, "SignalService", "signal_service");

        AddressManager newAddressManager = new AddressManager();

        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManagerImpl"));

        vm.startPrank(addressManager.owner());

        addressManager.upgradeTo(address(newAddressManager));

        vm.stopPrank();
    }

    function testRollupAddressManager() public {
        AddressManager addressManagerProxy =
            AddressManager(getPredeployedContractAddress("RollupAddressManager"));

        assertEq(ownerSecurityCouncil, addressManagerProxy.owner());

        checkSavedAddress(addressManagerProxy, "TaikoL2", "taiko");
        checkSavedAddress(addressManagerProxy, "SignalService", "signal_service");

        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("RollupAddressManagerImpl"));

        AddressManager newAddressManager = new AddressManager();

        vm.startPrank(addressManager.owner());

        addressManager.upgradeTo(address(newAddressManager));

        vm.stopPrank();
    }

    function testTaikoL2() public {
        TaikoL2 taikoL2Proxy = TaikoL2(getPredeployedContractAddress("TaikoL2"));

        assertEq(ownerTimelockController, taikoL2Proxy.owner());
        assertEq(ownerChainId, taikoL2Proxy.ownerChainId());

        vm.startPrank(taikoL2Proxy.GOLDEN_TOUCH_ADDRESS());
        for (uint32 i = 0; i < 300; ++i) {
            vm.roll(block.number + 1);
            vm.warp(block.number + 12);
            vm.fee(taikoL2Proxy.getBasefee(12, i));

            uint256 gasLeftBefore = gasleft();

            taikoL2Proxy.anchor(
                keccak256(abi.encodePacked(block.timestamp, i)),
                keccak256(abi.encodePacked(block.timestamp, i)),
                i + 1,
                i + 1
            );

            if (i == 299) {
                console2.log(
                    "TaikoL2.anchor gas cost after 256 L2 blocks:", gasLeftBefore - gasleft()
                );
            }
        }
        vm.stopPrank();

        TaikoL2 taikoL2 = TaikoL2(getPredeployedContractAddress("TaikoL2Impl"));

        vm.startPrank(taikoL2.owner());

        TaikoL2 newTaikoL2 = new TaikoL2();

        taikoL2.upgradeTo(address(newTaikoL2));

        vm.stopPrank();
    }

    function testSingletonBridge() public {
        Bridge bridgeProxy = Bridge(payable(getPredeployedContractAddress("Bridge")));

        assertEq(ownerSecurityCouncil, bridgeProxy.owner());

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridgeProxy.processMessage(
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

        assertEq(bridgeProxy.paused(), false);

        vm.startPrank(ownerSecurityCouncil);
        bridgeProxy.pause();
        assertEq(bridgeProxy.paused(), true);

        vm.expectRevert(OwnerUUPSUpgradable.INVALID_PAUSE_STATUS.selector);
        bridgeProxy.processMessage(
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

        bridgeProxy.unpause();
        assertEq(bridgeProxy.paused(), false);

        Bridge bridge = Bridge(payable(getPredeployedContractAddress("BridgeImpl")));

        Bridge newBridge = new Bridge();

        bridge.upgradeTo(address(newBridge));

        vm.stopPrank();
    }

    function testSingletonERC20Vault() public {
        address erc20VaultAddress = getPredeployedContractAddress("ERC20Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        ERC20Vault erc20VaultProxy = ERC20Vault(erc20VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(ownerSecurityCouncil, erc20VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc20_vault", erc20VaultAddress);
        vm.stopPrank();

        ERC20Vault erc20Vault = ERC20Vault(getPredeployedContractAddress("ERC20VaultImpl"));

        vm.startPrank(erc20Vault.owner());

        ERC20Vault newERC20Vault = new ERC20Vault();

        erc20Vault.upgradeTo(address(newERC20Vault));

        vm.stopPrank();
    }

    function testSingletonERC721Vault() public {
        address erc721VaultAddress = getPredeployedContractAddress("ERC721Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        OwnerUUPSUpgradable erc721VaultProxy = OwnerUUPSUpgradable(erc721VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(ownerSecurityCouncil, erc721VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc721_vault", erc721VaultAddress);
        vm.stopPrank();

        ERC721Vault erc721Vault = ERC721Vault(getPredeployedContractAddress("ERC721VaultImpl"));

        vm.startPrank(erc721Vault.owner());
        ERC721Vault newERC721Vault = new ERC721Vault();

        erc721Vault.upgradeTo(address(newERC721Vault));

        vm.stopPrank();
    }

    function testSingletonERC1155Vault() public {
        address erc1155VaultProxyAddress = getPredeployedContractAddress("ERC1155Vault");
        address bridgeProxyAddress = getPredeployedContractAddress("Bridge");

        OwnerUUPSUpgradable erc1155VaultProxy = OwnerUUPSUpgradable(erc1155VaultProxyAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(ownerSecurityCouncil, erc1155VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeProxyAddress);
        addressManager.setAddress(1, "erc1155_vault", erc1155VaultProxyAddress);
        vm.stopPrank();

        address erc1155VaultAddress = getPredeployedContractAddress("ERC1155VaultImpl");

        ERC1155Vault erc1155Vault = ERC1155Vault(erc1155VaultAddress);

        vm.startPrank(erc1155Vault.owner());

        ERC1155Vault newERC1155Vault = new ERC1155Vault();

        erc1155Vault.upgradeTo(address(newERC1155Vault));

        vm.stopPrank();
    }

    function testSingletonSignalService() public {
        SignalService signalServiceProxy =
            SignalService(getPredeployedContractAddress("SignalService"));

        assertEq(ownerSecurityCouncil, signalServiceProxy.owner());

        signalServiceProxy.sendSignal(keccak256(abi.encodePacked(block.prevrandao)));

        assertEq(
            true,
            signalServiceProxy.isAuthorizedAs(
                getPredeployedContractAddress("TaikoL2"), bytes32((block.chainid))
            )
        );

        vm.startPrank(ownerSecurityCouncil);

        SignalService signalService =
            SignalService(payable(getPredeployedContractAddress("SignalServiceImpl")));

        SignalService newSignalService = new SignalService();

        signalService.upgradeTo(address(newSignalService));

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


    function checkProxyImplementation(
        string memory proxyName,
        string memory contractName
    )
        private
    {
        return checkProxyImplementation(proxyName, contractName, ownerSecurityCouncil);
    }

    function checkProxyImplementation(
        string memory proxyName,
        string memory contractName,
        address owner
    )
        private
    {
        vm.startPrank(owner);
        address contractAddress = getPredeployedContractAddress(contractName);
        address proxyAddress = getPredeployedContractAddress(proxyName);

        OwnerUUPSUpgradable proxy = OwnerUUPSUpgradable(payable(proxyAddress));

        assertEq(proxy.owner(), owner);

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
