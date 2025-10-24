// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/helpers/RegularERC20.sol";
import "forge-std/src/StdJson.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "src/layer2/core/Anchor.sol";
import "src/layer2/core/BondManager.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/vault/BridgedERC1155.sol";
import "src/shared/vault/BridgedERC20.sol";
import "src/shared/vault/BridgedERC721.sol";
import "src/shared/vault/ERC1155Vault.sol";
import "src/shared/vault/ERC20Vault.sol";
import "src/shared/vault/ERC721Vault.sol";

contract TestGenerateGenesis is Test {
    using stdJson for string;

    string private configJSON;
    string private genesisDataPath;
    address private contractOwner;
    uint256 private l1ChainId;
    uint256 private shastaForkHeight;
    uint256 private livenessBond;
    uint256 private provabilityBond;
    address private bondToken;
    uint256 private minBond;
    uint48 private withdrawalDelay;
    bool private configInitialized;
    mapping(address => bytes32) private genesisCodeHashes;

    // forge coverage redeploys this test contract often, so we lazily read and cache the ~289 KB genesis JSON here
    // instead of the constructor to avoid running out of gas when the instrumented build sets up the suite.
    function setUp() public virtual {
        if (configInitialized) {
            return;
        }

        genesisDataPath = string.concat(vm.projectRoot(), "/test/genesis/data/");
        configJSON = vm.readFile(string.concat(genesisDataPath, "genesis_config.json"));

        contractOwner = configJSON.readAddress(".contractOwner");
        l1ChainId = configJSON.readUint(".l1ChainId");
        shastaForkHeight = configJSON.readUint(".shastaForkHeight");
        livenessBond = configJSON.readUint(".livenessBond");
        provabilityBond = configJSON.readUint(".provabilityBond");
        bondToken = configJSON.readAddress(".bondToken");
        minBond = configJSON.readUint(".minBond");
        withdrawalDelay = uint48(configJSON.readUint(".withdrawalDelay"));
        vm.chainId(configJSON.readUint(".chainId"));

        string memory genesisAllocJSON = vm.readFile(string.concat(genesisDataPath, "genesis_alloc.json"));
        _applyGenesisAlloc(genesisAllocJSON);

        configInitialized = true;
    }

    function _applyGenesisAlloc(string memory genesisAllocJSON) private {
        string[22] memory contractNames = [
            "BridgeImpl",
            "ERC20VaultImpl",
            "ERC721VaultImpl",
            "ERC1155VaultImpl",
            "SignalServiceImpl",
            "SharedResolverImpl",
            "BridgedERC20Impl",
            "BridgedERC721Impl",
            "BridgedERC1155Impl",
            "RegularERC20",
            "TaikoAnchorImpl",
            "RollupResolverImpl",
            "BondManagerImpl",
            "Bridge",
            "ERC20Vault",
            "ERC721Vault",
            "ERC1155Vault",
            "SignalService",
            "SharedResolver",
            "TaikoAnchor",
            "RollupResolver",
            "BondManager"
        ];

        for (uint256 i; i < contractNames.length; ++i) {
            _loadContractState(genesisAllocJSON, contractNames[i]);
        }
    }

    function _loadContractState(string memory genesisAllocJSON, string memory contractName) private {
        address contractAddress = getPredeployedContractAddress(contractName);
        _loadContractCode(genesisAllocJSON, contractAddress);
        _loadContractStorage(genesisAllocJSON, contractAddress);
    }

    function _loadContractCode(string memory genesisAllocJSON, address contractAddress) private {
        string memory contractKey = vm.toString(contractAddress);
        string memory codePath = string.concat(".", contractKey, ".code");
        bytes memory codeBytes = bytes("");
        if (genesisAllocJSON.keyExists(codePath)) {
            codeBytes = vm.parseBytes(genesisAllocJSON.readString(codePath));
        }
        vm.etch(contractAddress, codeBytes);
        genesisCodeHashes[contractAddress] = keccak256(codeBytes);
    }

    function _loadContractStorage(string memory genesisAllocJSON, address contractAddress) private {
        string memory contractKey = vm.toString(contractAddress);
        string memory storagePath = string.concat(".", contractKey, ".storage");
        if (!genesisAllocJSON.keyExists(storagePath)) {
            return;
        }

        string[] memory slotKeys = vm.parseJsonKeys(genesisAllocJSON, storagePath);
        for (uint256 j; j < slotKeys.length; ++j) {
            bytes32 slot = vm.parseBytes32(slotKeys[j]);
            string memory valueLocation = string.concat(storagePath, ".", slotKeys[j]);
            bytes memory valueBytes = vm.parseBytes(genesisAllocJSON.readString(valueLocation));
            bytes32 value;
            if (valueBytes.length != 0) {
                assembly {
                    value := mload(add(valueBytes, 32))
                }
                if (valueBytes.length < 32) {
                    value = value >> ((32 - valueBytes.length) * 8);
                }
            }
            vm.store(contractAddress, slot, value);
        }
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

        // check proxies
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

        Anchor taikoAnchor = Anchor(getPredeployedContractAddress("TaikoAnchor"));
        assertEq(contractOwner, taikoAnchor.owner());

        // check proxy implementations
        checkProxyImplementation("RollupResolver");
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
        Anchor taikoAnchor = Anchor(getPredeployedContractAddress("TaikoAnchor"));

        assertEq(contractOwner, taikoAnchor.owner());
        assertEq(l1ChainId, taikoAnchor.l1ChainId());
        assertEq(
            getPredeployedContractAddress("SignalService"), address(taikoAnchor.checkpointStore())
        );
        assertEq(getPredeployedContractAddress("BondManager"), address(taikoAnchor.bondManager()));
        assertEq(livenessBond, taikoAnchor.livenessBond());
        assertEq(provabilityBond, taikoAnchor.provabilityBond());
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

        address authorizedSyncer = getPredeployedContractAddress("TaikoAnchor");
        address remoteSignalService = contractOwner;

        signalServiceProxy.upgradeTo(
            address(new SignalService(authorizedSyncer, remoteSignalService))
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

    function checkDeployedCode(string memory contractName) private {
        address contractAddress = getPredeployedContractAddress(contractName);
        bytes32 expectedHash = genesisCodeHashes[contractAddress];
        bytes32 actualHash = keccak256(address(contractAddress).code);
        assertEq(actualHash, expectedHash);
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
