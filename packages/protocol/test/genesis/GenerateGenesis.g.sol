// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/console2.sol";
import "forge-std/src/StdJson.sol";
import "forge-std/src/Test.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/signal/SignalService.sol";
import "src/layer2/based/TaikoAnchor.sol";
import "src/layer2/based/BondManager.sol";
import "../shared/helpers/RegularERC20.sol";

contract TestGenerateGenesis is Test {
    using stdJson for string;

    string private configJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_config.json"));
    string private genesisAllocJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_alloc.json"));
    address private contractOwner = configJSON.readAddress(".contractOwner");
    uint256 private l1ChainId = configJSON.readUint(".l1ChainId");
    uint256 private pacayaForkHeight = configJSON.readUint(".pacayaForkHeight");
    uint256 private shastaForkHeight = configJSON.readUint(".shastaForkHeight");
    uint48 private livenessBondGwei = uint48(configJSON.readUint(".livenessBondGwei"));
    uint48 private provabilityBondGwei = uint48(configJSON.readUint(".provabilityBondGwei"));
    address private bondToken = configJSON.readAddress(".bondToken");
    uint256 private minBond = configJSON.readUint(".minBond");
    uint48 private withdrawalDelay = uint48(configJSON.readUint(".withdrawalDelay"));
    uint16 private maxCheckpointHistory = uint16(configJSON.readUint(".maxCheckpointHistory"));

    function setUp() public {
        // Skip all genesis tests - these require specific deployment configuration
        vm.skip(true);
    }

    function testSharedContractsDeployment() public {
        assertEq(block.chainid, 167);

        // check bytecode
        checkDeployedCode("ERC20Vault");
        checkDeployedCode("ERC721Vault");
        checkDeployedCode("ERC1155Vault");
        checkDeployedCode("Bridge");
        checkDeployedCode("SignalService");
        checkDeployedCode("SharedResolver");
        checkDeployedCode("BridgedERC20Impl");
        checkDeployedCode("BridgedERC721Impl");
        checkDeployedCode("BridgedERC1155Impl");

        // check proxy implementations
        checkProxyImplementation("ERC20Vault");
        checkProxyImplementation("ERC721Vault");
        checkProxyImplementation("ERC1155Vault");
        checkProxyImplementation("Bridge");
        checkProxyImplementation("SignalService");
        checkProxyImplementation("SharedResolver");

        // // check proxies
        checkDeployedCode("ERC20Vault");
        checkDeployedCode("ERC721Vault");
        checkDeployedCode("ERC1155Vault");
        checkDeployedCode("Bridge");
        checkDeployedCode("SignalService");
        checkDeployedCode("SharedResolver");
    }

    function testRollupContractsDeployment() public {
        // check bytecode
        checkDeployedCode("TaikoAnchor");
        checkDeployedCode("RollupResolver");

        // check proxy implementations
        checkProxyImplementation("TaikoAnchor", contractOwner);
        checkProxyImplementation("RollupResolver");

        // check proxies
        checkDeployedCode("TaikoAnchor");
        checkDeployedCode("RollupResolver");
    }

    function testSharedResolver() public {
        DefaultResolver resolverProxy =
            DefaultResolver(getPredeployedContractAddress("SharedResolver"));

        assertEq(contractOwner, resolverProxy.owner());

        checkSavedAddress(resolverProxy, "Bridge", "bridge");
        checkSavedAddress(resolverProxy, "ERC20Vault", "erc20_vault");
        checkSavedAddress(resolverProxy, "ERC721Vault", "erc721_vault");
        checkSavedAddress(resolverProxy, "ERC1155Vault", "erc1155_vault");
        checkSavedAddress(resolverProxy, "SignalService", "signal_service");
        checkSavedAddress(resolverProxy, "TaikoAnchor", "taiko");

        vm.startPrank(resolverProxy.owner());

        resolverProxy.upgradeTo(address(new DefaultResolver()));

        vm.stopPrank();
    }

    function testRollupResolver() public {
        DefaultResolver resolverProxy =
            DefaultResolver(getPredeployedContractAddress("RollupResolver"));

        assertEq(contractOwner, resolverProxy.owner());

        checkSavedAddress(resolverProxy, "TaikoAnchor", "taiko");
        checkSavedAddress(resolverProxy, "SignalService", "signal_service");

        vm.startPrank(resolverProxy.owner());

        resolverProxy.upgradeTo(address(new DefaultResolver()));

        vm.stopPrank();
    }

    function testBondManager() public {
        address bondManagerAddress = getPredeployedContractAddress("BondManager");
        EssentialContract bondManagerProxy = EssentialContract(bondManagerAddress);

        assertEq(contractOwner, bondManagerProxy.owner());
        assertEq(
            getPredeployedContractAddress("TaikoAnchor"),
            BondManager(bondManagerAddress).authorized()
        );
        assertEq(bondToken, address(BondManager(bondManagerAddress).bondToken()));
        assertEq(minBond, BondManager(bondManagerAddress).minBond());
        assertEq(withdrawalDelay, BondManager(bondManagerAddress).withdrawalDelay());

        vm.startPrank(bondManagerProxy.owner());

        bondManagerProxy.upgradeTo(
            address(
                new BondManager(
                    getPredeployedContractAddress("TaikoAnchor"),
                    getPredeployedContractAddress("RegularERC20"),
                    1 ether,
                    7 days
                )
            )
        );

        vm.stopPrank();
    }

    function testTaikoAnchor() public {
        TaikoAnchor taikoAnchorProxy = TaikoAnchor(getPredeployedContractAddress("TaikoAnchor"));

        assertEq(contractOwner, taikoAnchorProxy.owner());
        assertEq(l1ChainId, taikoAnchorProxy.l1ChainId());
        assertEq(uint64(pacayaForkHeight), taikoAnchorProxy.pacayaForkHeight());
        assertEq(uint64(shastaForkHeight), taikoAnchorProxy.shastaForkHeight());
        assertEq(
            getPredeployedContractAddress("SignalService"),
            address(taikoAnchorProxy.signalService())
        );
        assertEq(
            getPredeployedContractAddress("BondManager"), address(taikoAnchorProxy.bondManager())
        );
        assertEq(livenessBondGwei, taikoAnchorProxy.livenessBondGwei());
        assertEq(provabilityBondGwei, taikoAnchorProxy.provabilityBondGwei());
        assertEq(maxCheckpointHistory, taikoAnchorProxy.maxCheckpointHistory());

        vm.startPrank(taikoAnchorProxy.owner());

        taikoAnchorProxy.upgradeTo(
            address(
                new TaikoAnchor(
                    10_000_000, // livenessBondGwei
                    10_000_000, // provabilityBondGwei
                    getPredeployedContractAddress("SignalService"),
                    uint64(pacayaForkHeight),
                    uint64(shastaForkHeight),
                    uint16(100), // maxCheckpointHistory - default value
                    address(0) // bondManager - to be set later
                )
            )
        );

        vm.stopPrank();
    }

    function testSingletonBridge() public {
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        Bridge bridgeProxy = Bridge(payable(bridgeAddress));
        DefaultResolver addressManager =
            DefaultResolver(getPredeployedContractAddress("SharedResolver"));

        vm.startPrank(addressManager.owner());
        addressManager.registerAddress(1, "bridge", bridgeAddress);
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
        assertEq(
            getPredeployedContractAddress("SignalService"), address(bridgeProxy.signalService())
        );

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

        bridgeProxy.upgradeTo(
            address(
                new Bridge(
                    getPredeployedContractAddress("SharedResolver"),
                    getPredeployedContractAddress("SignalService")
                )
            )
        );

        vm.stopPrank();
    }

    function testBridgedERC20() public view {
        address bridgedERC20 = getPredeployedContractAddress("BridgedERC20Impl");
        assertEq(
            getPredeployedContractAddress("ERC20Vault"), BridgedERC20(bridgedERC20).erc20Vault()
        );
    }

    function testBridgedERC721() public view {
        address bridgedERC721 = getPredeployedContractAddress("BridgedERC721Impl");
        assertEq(
            getPredeployedContractAddress("ERC721Vault"), BridgedERC721(bridgedERC721).erc721Vault()
        );
    }

    function testBridgedERC1155() public view {
        address bridgedERC1155 = getPredeployedContractAddress("BridgedERC1155Impl");
        assertEq(
            getPredeployedContractAddress("ERC1155Vault"),
            BridgedERC1155(bridgedERC1155).erc1155Vault()
        );
    }

    function testSingletonERC20Vault() public {
        address erc20VaultAddress = getPredeployedContractAddress("ERC20Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        ERC20Vault erc20VaultProxy = ERC20Vault(erc20VaultAddress);
        DefaultResolver addressManager =
            DefaultResolver(getPredeployedContractAddress("SharedResolver"));

        assertEq(contractOwner, erc20VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.registerAddress(1, "bridge", bridgeAddress);
        addressManager.registerAddress(1, "erc20_vault", erc20VaultAddress);
        vm.stopPrank();

        vm.startPrank(erc20VaultProxy.owner());

        erc20VaultProxy.upgradeTo(
            address(new ERC20Vault(getPredeployedContractAddress("SharedResolver")))
        );

        vm.stopPrank();
    }

    function testERC721Vault() public {
        address erc721VaultAddress = getPredeployedContractAddress("ERC721Vault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        EssentialContract erc721VaultProxy = EssentialContract(erc721VaultAddress);
        DefaultResolver addressManager =
            DefaultResolver(getPredeployedContractAddress("SharedResolver"));

        assertEq(contractOwner, erc721VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.registerAddress(1, "bridge", bridgeAddress);
        addressManager.registerAddress(1, "erc721_vault", erc721VaultAddress);
        vm.stopPrank();

        vm.startPrank(erc721VaultProxy.owner());

        erc721VaultProxy.upgradeTo(
            address(new ERC721Vault(getPredeployedContractAddress("SharedResolver")))
        );

        vm.stopPrank();
    }

    function testERC1155Vault() public {
        address erc1155VaultProxyAddress = getPredeployedContractAddress("ERC1155Vault");
        address bridgeProxyAddress = getPredeployedContractAddress("Bridge");

        EssentialContract erc1155VaultProxy = EssentialContract(erc1155VaultProxyAddress);
        DefaultResolver addressManager =
            DefaultResolver(getPredeployedContractAddress("SharedResolver"));

        assertEq(contractOwner, erc1155VaultProxy.owner());

        vm.startPrank(addressManager.owner());
        addressManager.registerAddress(1, "bridge", bridgeProxyAddress);
        addressManager.registerAddress(1, "erc1155_vault", erc1155VaultProxyAddress);
        vm.stopPrank();

        vm.startPrank(erc1155VaultProxy.owner());

        erc1155VaultProxy.upgradeTo(
            address(new ERC1155Vault(getPredeployedContractAddress("SharedResolver")))
        );

        vm.stopPrank();
    }

    function testSignalService() public {
        SignalService signalServiceProxy =
            SignalService(getPredeployedContractAddress("SignalService"));

        assertEq(contractOwner, signalServiceProxy.owner());

        signalServiceProxy.sendSignal(keccak256(abi.encodePacked(block.prevrandao)));

        vm.startPrank(contractOwner);

        signalServiceProxy.upgradeTo(
            address(new SignalService(getPredeployedContractAddress("SharedResolver")))
        );

        vm.stopPrank();
    }

    function testERC20() public view {
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

    function checkDeployedCode(string memory contractName) private view {
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

        address proxyAddress = getPredeployedContractAddress(proxyName);

        EssentialContract proxy = EssentialContract(payable(proxyAddress));

        assertEq(proxy.owner(), owner);

        vm.stopPrank();
    }

    function checkSavedAddress(
        ResolverBase resolver,
        string memory contractName,
        bytes32 name
    )
        private
        view
    {
        assertEq(
            getPredeployedContractAddress(contractName),
            resolver.resolve(uint64(block.chainid), name, false)
        );
    }
}
