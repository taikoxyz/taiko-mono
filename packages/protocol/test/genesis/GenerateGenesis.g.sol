// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/console2.sol";
import "forge-std/src/StdJson.sol";
import "forge-std/src/Test.sol";
import "src/shared/common/AddressManager.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/shared/signal/SignalService.sol";
import "src/layer2/based/TaikoL2.sol";
import "../shared/token/RegularERC20.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_config.json"));
    string private genesisAllocJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_alloc.json"));
    address private contractOwner = configJSON.readAddress(".contractOwner");
    uint256 private l1ChainId = configJSON.readUint(".l1ChainId");

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
        checkProxyImplementation("ERC20Vault");
        checkProxyImplementation("ERC721Vault");
        checkProxyImplementation("ERC1155Vault");
        checkProxyImplementation("Bridge");
        checkProxyImplementation("SignalService");
        checkProxyImplementation("SharedAddressManager");

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
        checkProxyImplementation("TaikoL2", contractOwner);
        checkProxyImplementation("RollupAddressManager");

        // check proxies
        checkDeployedCode("TaikoL2");
        checkDeployedCode("RollupAddressManager");
    }

    function testSharedAddressManager() public {
        AddressManager addressManagerProxy =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(contractOwner, addressManagerProxy.owner());

        checkSavedAddress(addressManagerProxy, "Bridge", "bridge");
        checkSavedAddress(addressManagerProxy, "ERC20Vault", "erc20_vault");
        checkSavedAddress(addressManagerProxy, "ERC721Vault", "erc721_vault");
        checkSavedAddress(addressManagerProxy, "ERC1155Vault", "erc1155_vault");
        checkSavedAddress(addressManagerProxy, "SignalService", "signal_service");

        vm.startPrank(addressManagerProxy.owner());

        addressManagerProxy.upgradeTo(address(new AddressManager()));

        vm.stopPrank();
    }

    function testRollupAddressManager() public {
        AddressManager addressManagerProxy =
            AddressManager(getPredeployedContractAddress("RollupAddressManager"));

        assertEq(contractOwner, addressManagerProxy.owner());

        checkSavedAddress(addressManagerProxy, "TaikoL2", "taiko");
        checkSavedAddress(addressManagerProxy, "SignalService", "signal_service");

        vm.startPrank(addressManagerProxy.owner());

        addressManagerProxy.upgradeTo(address(new AddressManager()));

        vm.stopPrank();
    }

    function testTaikoL2() public {
        TaikoL2 taikoL2Proxy = TaikoL2(getPredeployedContractAddress("TaikoL2"));

        assertEq(contractOwner, taikoL2Proxy.owner());
        assertEq(l1ChainId, taikoL2Proxy.l1ChainId());

        vm.startPrank(taikoL2Proxy.owner());

        taikoL2Proxy.upgradeTo(address(new TaikoL2()));

        vm.stopPrank();
    }

    function testSingletonBridge() public {
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        Bridge bridgeProxy = Bridge(payable(bridgeAddress));
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        vm.stopPrank();

        assertEq(contractOwner, bridgeProxy.owner());

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridgeProxy.processMessage(
            IBridge.Message({
                id: 0,
                from: address(0),
                srcChainId: 1,
                destChainId: 167,
                srcOwner: address(0),
                destOwner: address(0),
                to: address(0),
                value: 0,
                fee: 0,
                gasLimit: 0,
                data: ""
            }),
            ""
        );

        assertEq(bridgeProxy.paused(), false);

        vm.startPrank(contractOwner);
        bridgeProxy.pause();
        assertEq(bridgeProxy.paused(), true);

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        bridgeProxy.processMessage(
            IBridge.Message({
                id: 0,
                from: address(0),
                srcChainId: 1,
                destChainId: 167,
                srcOwner: address(0),
                destOwner: address(0),
                to: address(0),
                value: 0,
                fee: 0,
                gasLimit: 0,
                data: ""
            }),
            ""
        );

        bridgeProxy.unpause();
        assertEq(bridgeProxy.paused(), false);

        bridgeProxy.upgradeTo(address(new Bridge()));

        vm.stopPrank();
    }

    function testSingletonERC20Vault() public {
        address erc20VaultAddress = getPredeployedContractAddress("ERC20Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        ERC20Vault erc20VaultProxy = ERC20Vault(erc20VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(contractOwner, erc20VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc20_vault", erc20VaultAddress);
        vm.stopPrank();

        vm.startPrank(erc20VaultProxy.owner());

        erc20VaultProxy.upgradeTo(address(new ERC20Vault()));

        vm.stopPrank();
    }

    function testSingletonERC721Vault() public {
        address erc721VaultAddress = getPredeployedContractAddress("ERC721Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        EssentialContract erc721VaultProxy = EssentialContract(erc721VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(contractOwner, erc721VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc721_vault", erc721VaultAddress);
        vm.stopPrank();

        vm.startPrank(erc721VaultProxy.owner());

        erc721VaultProxy.upgradeTo(address(new ERC721Vault()));

        vm.stopPrank();
    }

    function testSingletonERC1155Vault() public {
        address erc1155VaultProxyAddress = getPredeployedContractAddress("ERC1155Vault");
        address bridgeProxyAddress = getPredeployedContractAddress("Bridge");

        EssentialContract erc1155VaultProxy = EssentialContract(erc1155VaultProxyAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("SharedAddressManager"));

        assertEq(contractOwner, erc1155VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeProxyAddress);
        addressManager.setAddress(1, "erc1155_vault", erc1155VaultProxyAddress);
        vm.stopPrank();

        // address erc1155VaultAddress = getPredeployedContractAddress("ERC1155VaultImpl");

        vm.startPrank(erc1155VaultProxy.owner());

        erc1155VaultProxy.upgradeTo(address(new ERC1155Vault()));

        vm.stopPrank();
    }

    function testSingletonSignalService() public {
        SignalService signalServiceProxy =
            SignalService(getPredeployedContractAddress("SignalService"));

        assertEq(contractOwner, signalServiceProxy.owner());

        signalServiceProxy.sendSignal(keccak256(abi.encodePacked(block.prevrandao)));

        vm.startPrank(contractOwner);

        // SignalService signalService =
        //     SignalService(payable(getPredeployedContractAddress("SignalServiceImpl")));

        signalServiceProxy.upgradeTo(address(new SignalService()));

        vm.stopPrank();
    }

    function testERC20() public {
        RegularERC20 regularERC20 = RegularERC20(getPredeployedContractAddress("RegularERC20"));

        assertEq(regularERC20.name(), "RegularERC20");
        assertEq(regularERC20.symbol(), "RGL");
    }

    function getPredeployedContractAddress(string memory contractName)
        private
        view
        returns (address)
    {
        return configJSON.readAddress(string.concat(".contractAddresses.", contractName));
    }

    function checkDeployedCode(string memory contractName) private {
        address contractAddress = getPredeployedContractAddress(contractName);
        string memory deployedCode =
            genesisAllocJSON.readString(string.concat(".", vm.toString(contractAddress), ".code"));

        assertEq(address(contractAddress).code, vm.parseBytes(deployedCode));
    }

    function checkProxyImplementation(string memory proxyName) private {
        return checkProxyImplementation(proxyName, contractOwner);
    }

    function checkProxyImplementation(string memory proxyName, address owner) private {
        vm.startPrank(owner);
        // address contractAddress = getPredeployedContractAddress(contractName);
        address proxyAddress = getPredeployedContractAddress(proxyName);

        EssentialContract proxy = EssentialContract(payable(proxyAddress));

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
