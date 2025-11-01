// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@optimism/packages/contracts-bedrock/src/EAS/Common.sol";

import "src/layer1/mainnet/TaikoToken.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/vault/BridgedERC1155.sol";
import "src/shared/vault/BridgedERC20V2.sol";
import "src/shared/vault/BridgedERC721.sol";
import "src/shared/vault/ERC1155Vault.sol";
import "src/shared/vault/ERC20Vault.sol";
import "src/shared/vault/ERC721Vault.sol";
import "test/shared/helpers/SignalService_WithoutProofVerification.sol";

abstract contract CommonTest is Test, Script {
    uint256 private _seed = 0x12345678;
    address internal Alice = vm.addr(0x1);
    address internal Bob = vm.addr(0x2);
    address internal Carol = vm.addr(0x3);
    address internal David = vm.addr(0x4);
    address internal Emma = vm.addr(0x5);
    address internal Frank = randAddress();
    address internal Grace = randAddress();
    address internal Henry = randAddress();
    address internal Isabella = randAddress();
    address internal James = randAddress();
    address internal Katherine = randAddress();
    address internal Liam = randAddress();
    address internal Mia = randAddress();
    address internal Noah = randAddress();
    address internal Olivia = randAddress();
    address internal Patrick = randAddress();
    address internal Quinn = randAddress();
    address internal Rachel = randAddress();
    address internal Samuel = randAddress();
    address internal Taylor = randAddress();
    address internal Ulysses = randAddress();
    address internal Victoria = randAddress();
    address internal William = randAddress();
    address internal Xavier = randAddress();
    address internal Yasmine = randAddress();
    address internal Zachary = randAddress();

    address internal deployer = msg.sender;
    DefaultResolver internal resolver;
    uint64 ethereumChainId;
    uint64 taikoChainId;

    modifier onEthereum() {
        vm.chainId(ethereumChainId);
        _;
    }

    modifier onTaiko() {
        vm.chainId(taikoChainId);
        _;
        vm.chainId(ethereumChainId);
    }

    modifier transactBy(address transactor) virtual {
        vm.deal(transactor, 100 ether);
        vm.startPrank(transactor);

        _;
        vm.stopPrank();
    }

    function setUp() public virtual {
        console2.log("deployer: ", deployer);
        vm.deal(deployer, 100 ether);
        vm.startPrank(deployer);

        ethereumChainId = uint64(block.chainid);
        taikoChainId = ethereumChainId + 10_000;

        resolver = deployDefaultResolver();

        setUpOnEthereum();

        vm.chainId(taikoChainId);
        setUpOnTaiko();
        vm.chainId(ethereumChainId);
        vm.stopPrank();
    }

    function setUpOnEthereum() internal virtual { }
    function setUpOnTaiko() internal virtual { }

    function randAddress() internal returns (address) {
        bytes32 randomHash = keccak256(abi.encodePacked("address", _seed++));
        return address(bytes20(randomHash));
    }

    function randBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked("bytes32", _seed++));
    }

    function mineOneBlockAndWrap(uint256 time) internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + time);
    }

    function register(bytes32 name, address addr) internal {
        if (name != "") {
            resolver.registerAddress(block.chainid, name, addr);
            console2.log(">", string.concat("'", bytes32ToString(name), "'"));
            console2.log("  addr    :", addr);
            console2.log("  chain id:", block.chainid);
        }
    }

    function deploy(
        bytes32 name,
        address impl,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        proxy = address(new ERC1967Proxy(impl, data));
        console2.log(">", string.concat("'", bytes32ToString(name), "'"));
        console2.log("  proxy   :", proxy);
        console2.log("  impl    :", impl);
        console2.log("  owner   :", OwnableUpgradeable(proxy).owner());
        console2.log("  chain id:", block.chainid);
        if (name != "" && resolver != IResolver(address(0))) {
            console2.log("  resolver:", address(resolver));
            resolver.registerAddress(block.chainid, name, proxy);
        }
    }

    function deployDefaultResolver() internal returns (DefaultResolver) {
        return DefaultResolver(
            deploy({
                name: "resolver",
                impl: address(new DefaultResolver()),
                data: abi.encodeCall(DefaultResolver.init, (address(0)))
            })
        );
    }

    function registerSignalService(SignalService signalService) internal returns (SignalService) {
        register("signal_service", address(signalService));
        return signalService;
    }

    function deploySignalService(
        address authorizedSyncer,
        address remoteSignalService,
        address owner
    )
        internal
        returns (SignalService)
    {
        SignalService impl = new SignalService(authorizedSyncer, remoteSignalService);
        SignalService proxy = SignalService(
            deploy({
                name: "", impl: address(impl), data: abi.encodeCall(SignalService.init, (owner))
            })
        );
        return registerSignalService(proxy);
    }

    function deploySignalServiceWithoutProof(
        address authorizedSyncer,
        address remoteSignalService,
        address owner
    )
        internal
        returns (SignalService)
    {
        SignalService_WithoutProofVerification impl =
            new SignalService_WithoutProofVerification(authorizedSyncer, remoteSignalService);
        SignalService proxy = SignalService(
            deploy({
                name: "", impl: address(impl), data: abi.encodeCall(SignalService.init, (owner))
            })
        );
        return registerSignalService(proxy);
    }

    function deployTaikoToken() internal returns (TaikoToken) {
        return TaikoToken(
            deploy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(TaikoToken.init, (address(0), address(this)))
            })
        );
    }

    function deployBridgedERC20(
        address erc20Vault,
        address srcToken,
        uint256 _ethereumChainId,
        uint8 decimals,
        string memory symbol,
        string memory name
    )
        internal
        returns (BridgedERC20)
    {
        return BridgedERC20(
            deploy({
                name: "erc20_token",
                impl: address(new BridgedERC20(erc20Vault)),
                data: abi.encodeCall(
                    BridgedERC20.init,
                    (address(0), srcToken, _ethereumChainId, decimals, symbol, name)
                )
            })
        );
    }

    function deployBridge(address bridgeImpl) internal returns (Bridge) {
        return Bridge(
            deploy({
                name: "bridge", impl: bridgeImpl, data: abi.encodeCall(Bridge.init, (address(0)))
            })
        );
    }

    function deployERC20Vault() internal returns (ERC20Vault) {
        return ERC20Vault(
            deploy({
                name: "erc20_vault",
                impl: address(new ERC20Vault(address(resolver))),
                data: abi.encodeCall(ERC20Vault.init, (address(0)))
            })
        );
    }

    function deployERC721Vault() internal returns (ERC721Vault) {
        return ERC721Vault(
            deploy({
                name: "erc721_vault",
                impl: address(new ERC721Vault(address(resolver))),
                data: abi.encodeCall(ERC721Vault.init, (address(0)))
            })
        );
    }

    function deployERC1155Vault() internal returns (ERC1155Vault) {
        return ERC1155Vault(
            deploy({
                name: "erc1155_vault",
                impl: address(new ERC1155Vault(address(resolver))),
                data: abi.encodeCall(ERC1155Vault.init, (address(0)))
            })
        );
    }
}
