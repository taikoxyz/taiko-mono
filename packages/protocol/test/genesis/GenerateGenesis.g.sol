// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/helpers/RegularERC20.sol";
import "forge-std/src/StdJson.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "src/layer2/core/Anchor.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { BridgedTaikoToken } from "src/layer2/mainnet/BridgedTaikoToken.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import { EtnaSignalService } from "src/shared/signal/EtnaSignalService.sol";
import "src/shared/signal/ICheckpointStore.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/vault/BridgedERC1155.sol";
import "src/shared/vault/BridgedERC20.sol";
import "src/shared/vault/BridgedERC721.sol";
import "src/shared/vault/ERC1155Vault.sol";
import "src/shared/vault/ERC20Vault.sol";
import "src/shared/vault/ERC721Vault.sol";
import { EtnaVoteKeys } from "test/layer2/etna/EtnaVoteKeys.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @notice The generator output that both genesis suites read, and the helpers they share.
abstract contract GenerateGenesisTestBase is Test {
    using stdJson for string;

    string internal configJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_config.json"));
    string internal genesisAllocJSON =
        vm.readFile(string.concat(vm.projectRoot(), "/test/genesis/data/genesis_alloc.json"));
    address internal contractOwner = configJSON.readAddress(".contractOwner");
    uint256 internal l1ChainId = configJSON.readUint(".l1ChainId");

    function getPredeployedContractAddress(string memory contractName)
        internal
        view
        returns (address)
    {
        return configJSON.readAddress(string.concat(".contractAddresses.", contractName));
    }

    function checkDeployedCode(string memory contractName) internal view {
        address contractAddress = getPredeployedContractAddress(contractName);
        string memory deployedCode =
            genesisAllocJSON.readString(string.concat(".", vm.toString(contractAddress), ".code"));

        assertEq(address(contractAddress).code, vm.parseBytes(deployedCode));
    }
}

contract TestGenerateGenesis is GenerateGenesisTestBase {
    using stdJson for string;

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

    function testTaikoAnchor() public {
        Anchor taikoAnchorProxy = Anchor(getPredeployedContractAddress("TaikoAnchor"));

        assertEq(contractOwner, taikoAnchorProxy.owner());
        assertEq(l1ChainId, taikoAnchorProxy.l1ChainId());
        assertEq(
            getPredeployedContractAddress("SignalService"),
            address(taikoAnchorProxy.checkpointStore())
        );

        vm.startPrank(taikoAnchorProxy.owner());

        UUPSUpgradeable(address(taikoAnchorProxy))
            .upgradeTo(
                address(
                    new Anchor(
                        ICheckpointStore(getPredeployedContractAddress("SignalService")),
                        uint64(l1ChainId)
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
                    getPredeployedContractAddress("SignalService"),
                    address(0),
                    address(0),
                    false
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
            address(new ERC20Vault(getPredeployedContractAddress("SharedResolver"), address(0)))
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

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        signalServiceProxy.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(1))
            })
        );
        vm.stopPrank();

        vm.prank(authorizedSyncer);
        signalServiceProxy.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(1))
            })
        );

        vm.prank(remoteSignalService);
        signalServiceProxy.sendSignal(keccak256("genesis_signal"));
    }

    function testERC20() public view {
        RegularERC20 regularERC20 = RegularERC20(getPredeployedContractAddress("RegularERC20"));

        assertEq(regularERC20.name(), "RegularERC20");
        assertEq(regularERC20.symbol(), "RGL");
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

/// @notice Checks the EtnaStaking and bridged TAIKO predeploys that the example Etna devnet
/// configuration, `data/genesis_config_etna.js`, generates, on a node started from that genesis.
/// `genesis.test.sh` runs this contract alone against that node, and the contract above against
/// the default genesis.
contract TestGenerateEtnaGenesis is GenerateGenesisTestBase {
    using stdJson for string;

    /// @dev The ERC-1967 implementation slot.
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The ERC-7201 base slot T of `taiko.etna.staking`.
    bytes32 private constant T = 0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00;

    /// @dev EssentialContract's flags slot and the word `init` leaves there: `__paused` 1 (not
    /// paused) in byte 1, and byte 0, the deprecated `__reentry`, never written.
    bytes32 private constant FLAGS_SLOT = bytes32(uint256(201));
    bytes32 private constant INIT_FLAGS = bytes32(uint256(0x0100));

    EtnaStaking private staking = EtnaStaking(getPredeployedContractAddress("EtnaStaking"));
    BridgedTaikoToken private btoken =
        BridgedTaikoToken(getPredeployedContractAddress("BridgedTaikoToken"));

    function test_etnaStaking_ProxyOwnerImplementationAndImmutables() public {
        assertEq(block.chainid, 167_001);
        // The addresses alethia-reth and taiko-client-rs build in for chain 167001.
        address impl = getPredeployedContractAddress("EtnaStakingImpl");
        assertEq(address(staking), 0x1670010000000000000000000000000000010003);
        assertEq(impl, 0x0167001000000000000000000000000000010003);
        checkDeployedCode("EtnaStaking");
        checkDeployedCode("EtnaStakingImpl");
        assertEq(vm.load(address(staking), IMPLEMENTATION_SLOT), bytes32(uint256(uint160(impl))));
        assertEq(staking.impl(), impl);

        assertEq(staking.owner(), configJSON.readAddress(".etna.stakingOwner"));
        assertEq(staking.pendingOwner(), address(0));
        assertEq(vm.load(address(staking), FLAGS_SLOT), INIT_FLAGS);
        assertFalse(staking.paused());
        assertEq(staking.resolver(), address(0));

        assertEq(staking.token(), address(btoken));
        assertEq(staking.l1ChainId(), l1ChainId);
        assertEq(staking.inbox(), configJSON.readAddress(".etna.inbox"));
        assertEq(staking.minStake(), etnaUint("minStake"));
        assertEq(staking.vpUnit(), etnaUint("vpUnit"));
        assertEq(staking.nMax(), etnaUint("nMax"));
        assertEq(staking.missLimit(), etnaUint("missLimit"));
        assertEq(staking.missSlashBps(), etnaUint("missSlashBps"));
        assertEq(staking.withdrawalDelay(), etnaUint("withdrawalDelay"));
        assertEq(staking.slashBountyBps(), etnaUint("slashBountyBps"));
        assertEq(staking.slashSink(), configJSON.readAddress(".etna.slashSink"));
        assertEq(staking.forfeitBps(), etnaUint("forfeitBps"));

        // T, T + 1, the key-to-seat mapping's slot and the 128 snapshot records are all zero.
        for (uint256 i; i <= 258; ++i) {
            assertEq(vm.load(address(staking), bytes32(uint256(T) + i)), bytes32(0));
        }
        assertEq(staking.bondCount(), 0);
        assertEq(staking.lastGeneration(), 0);

        // The implementation is predeployed as its constructor leaves it: never initializable.
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaStaking(impl).init(address(this));
    }

    /// @dev The L2 SignalService is the root-only `EtnaSignalService` with `usesBeaconRoots` true,
    /// behind the proxy the default genesis also uses.
    function test_signalService_IsTheEtnaSignalServiceWithBeaconRoots() public view {
        address impl = getPredeployedContractAddress("SignalServiceImpl");
        EtnaSignalService signalService =
            EtnaSignalService(getPredeployedContractAddress("SignalService"));
        checkDeployedCode("SignalService");
        checkDeployedCode("SignalServiceImpl");
        assertEq(
            vm.load(address(signalService), IMPLEMENTATION_SLOT), bytes32(uint256(uint160(impl)))
        );
        assertEq(signalService.owner(), contractOwner);
        assertEq(signalService.VERSION(), 1);
        assertTrue(signalService.usesBeaconRoots());
    }

    function test_etnaStaking_RegisterThenBlockStartRoundTrip() public {
        (address seed,) = premintAt(0);
        uint256 minStake = staking.minStake();
        bytes memory publicKey = EtnaTestKeys.publicKey(1);
        bytes memory pop = EtnaVoteKeys.popSig(1, staking, seed);

        vm.startPrank(seed);
        btoken.approve(address(staking), minStake);
        uint256 bondId = staking.register(publicKey, minStake, pop);
        vm.stopPrank();

        assertEq(bondId, 0);
        assertEq(staking.bondCount(), 1);
        assertEq(btoken.balanceOf(address(staking)), minStake);
        (bool holdsSeat, uint8 seat) = staking.seatOfBond(bondId);
        assertTrue(holdsSeat);
        assertEq(seat, 0);

        // The next block's block-start call writes the snapshot that nodes read from T.
        vm.roll(block.number + 1);
        address systemCaller = staking.SYSTEM_CALLER();
        vm.prank(systemCaller);
        staking.onBlockStart(0, 0);

        (uint8 ckPrefix, bytes32 ckX) = EtnaTestKeys.fallbackKey(1);
        uint256 power = minStake / staking.vpUnit();
        assertEq(uint256(vm.load(address(staking), T)), block.number);
        assertEq(uint256(vm.load(address(staking), bytes32(uint256(T) + 1))), minStake);
        assertEq(vm.load(address(staking), bytes32(uint256(T) + 3)), ckX);
        assertEq(
            uint256(vm.load(address(staking), bytes32(uint256(T) + 4))),
            uint256(ckPrefix) | (power << 8)
        );
    }

    function test_bridgedTaiko_PremintVotesCheckpointAndBurn() public {
        address vault = getPredeployedContractAddress("ERC20Vault");
        address impl = getPredeployedContractAddress("BridgedTaikoTokenImpl");
        assertEq(address(btoken), 0x1670010000000000000000000000000000000007);
        assertEq(impl, 0x0167001000000000000000000000000000000007);
        checkDeployedCode("BridgedTaikoToken");
        checkDeployedCode("BridgedTaikoTokenImpl");
        assertEq(vm.load(address(btoken), IMPLEMENTATION_SLOT), bytes32(uint256(uint160(impl))));
        assertEq(btoken.owner(), contractOwner);
        assertEq(vm.load(address(btoken), FLAGS_SLOT), INIT_FLAGS);
        assertFalse(btoken.paused());
        assertEq(btoken.erc20Vault(), vault);
        assertEq(btoken.name(), "Taiko Token");
        assertEq(btoken.symbol(), "TAIKO");
        assertEq(btoken.decimals(), 18);

        uint256 total;
        for (uint256 i; hasPremintAt(i); ++i) {
            (address account, uint256 amount) = premintAt(i);
            assertEq(btoken.balanceOf(account), amount);
            total += amount;
        }
        (address seed,) = premintAt(0);
        assertEq(btoken.balanceOf(seed), 7_812_500 ether);
        assertEq(btoken.totalSupply(), total);

        // The clock is the timestamp, so a block-number timepoint would find no checkpoint and
        // pass for any genesis.
        assertEq(btoken.CLOCK_MODE(), "mode=timestamp");
        vm.warp(block.timestamp + 1);
        assertEq(btoken.getPastTotalSupply(block.timestamp - 1), total);

        // The vault mints and burns as the bridge does; both revert unless the token is
        // initialized and not paused.
        vm.startPrank(vault);
        btoken.mint(vault, 1 ether);
        assertEq(btoken.totalSupply(), total + 1 ether);
        btoken.burn(1 ether);
        vm.stopPrank();
        assertEq(btoken.totalSupply(), total);

        // Bridging preminted TAIKO back burns more than was minted after genesis, which only the
        // genesis checkpoint keeps from underflowing.
        vm.prank(seed);
        assertTrue(btoken.transfer(vault, 2 ether));
        vm.prank(vault);
        btoken.burn(2 ether);
        assertEq(btoken.totalSupply(), total - 2 ether);
        vm.warp(block.timestamp + 1);
        assertEq(btoken.getPastTotalSupply(block.timestamp - 1), total - 2 ether);

        // The implementation is predeployed as its constructor leaves it: never initializable.
        vm.expectRevert("Initializable: contract is already initialized");
        BridgedTaikoToken(impl).init(address(this));
    }

    function test_bridgedTaiko_PermitDomainIsTaikoToken() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Taiko Token"),
                keccak256("1"),
                block.chainid,
                address(btoken)
            )
        );
        assertEq(btoken.DOMAIN_SEPARATOR(), domainSeparator);
        (, string memory name, string memory version,,,,) = btoken.eip712Domain();
        assertEq(name, "Taiko Token");
        assertEq(version, "1");

        // A permit signed over that domain sets the allowance.
        uint256 holderKey = 0xA11CE;
        address holder = vm.addr(holderKey);
        address spender = address(0xB0B);
        uint256 deadline = block.timestamp + 1;
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                holder,
                spender,
                1 ether,
                btoken.nonces(holder),
                deadline
            )
        );
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(holderKey, keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash)));
        btoken.permit(holder, spender, 1 ether, deadline, v, r, s);
        assertEq(btoken.allowance(holder, spender), 1 ether);
        assertEq(btoken.nonces(holder), 1);
    }

    function test_erc20Vault_MapsTheCanonicalTaiko() public view {
        ERC20Vault vault = ERC20Vault(getPredeployedContractAddress("ERC20Vault"));
        address l1TaikoToken = configJSON.readAddress(".etna.l1TaikoToken");

        (uint64 chainId, address addr, uint8 decimals, string memory symbol, string memory name) =
            vault.bridgedToCanonical(address(btoken));
        assertEq(chainId, l1ChainId);
        assertEq(addr, l1TaikoToken);
        assertEq(decimals, 18);
        assertEq(symbol, "TAIKO");
        assertEq(name, "Taiko Token");
        assertEq(vault.canonicalToBridged(l1ChainId, l1TaikoToken), address(btoken));
        // Unlike the token, the vault is predeployed paused.
        assertTrue(vault.paused());
    }

    function etnaUint(string memory _name) private view returns (uint256) {
        return configJSON.readUint(string.concat(".etna.", _name));
    }

    function hasPremintAt(uint256 _index) private view returns (bool) {
        return vm.keyExistsJson(configJSON, premintKey(_index));
    }

    function premintAt(uint256 _index) private view returns (address account_, uint256 amount_) {
        string memory key = premintKey(_index);
        string[] memory accounts = vm.parseJsonKeys(configJSON, key);
        assertEq(accounts.length, 1);
        account_ = vm.parseAddress(accounts[0]);
        amount_ = configJSON.readUint(string.concat(key, ".", accounts[0]));
    }

    function premintKey(uint256 _index) private pure returns (string memory) {
        return string.concat(".etna.premint[", vm.toString(_index), "]");
    }
}
