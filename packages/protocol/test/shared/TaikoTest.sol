// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

import "src/shared/common/DefaultResolver.sol";
import "src/shared/tokenvault/BridgedERC20V2.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/bridge/QuotaManager.sol";
import "./token/FreeMintERC20.sol";
import "./token/RegularERC20.sol";
import "./token/MayFailFreeMintERC20.sol";
import "./HelperContracts.sol";

abstract contract TaikoTest is Test, Script {
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

    // TODO: delete this
    function randAddress() internal returns (address) {
        bytes32 randomHash = keccak256(abi.encodePacked("address", _seed++));
        return address(bytes20(randomHash));
    }

    // TODO: delete this
    function randBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked("bytes32", _seed++));
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
        string memory _name = Strings.toString(uint256(name));
        vm.writeJson(
            vm.serializeAddress("deployment", _name, proxy),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );

        console2.log(">", _name);
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
        console2.log("  owner      :", OwnableUpgradeable(proxy).owner());
    }

    function deploy(
        bytes32 name,
        address impl,
        bytes memory data,
        DefaultResolver resolver
    )
        internal
        returns (address proxy)
    {
        require(address(resolver) != address(0), "resolver is address(0)");
        proxy = deploy(name, impl, data);
        console2.log("  registered :", address(resolver));
        resolver.setAddress(block.chainid, name, proxy);
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

    function deploySignalService(
        DefaultResolver resolver,
        address signalServiceImpl
    )
        internal
        returns (SignalService)
    {
        return SkipProofCheckSignal(
            deploy({
                name: "signal_service",
                impl: signalServiceImpl,
                data: abi.encodeCall(SignalService.init, (address(0), address(resolver))),
                resolver: resolver
            })
        );
    }

    function deployBridge(DefaultResolver resolver, address bridgeImpl) internal returns (Bridge) {
        return Bridge(
            deploy({
                name: "bridge",
                impl: bridgeImpl,
                data: abi.encodeCall(Bridge.init, (address(0), address(resolver))),
                resolver: resolver
            })
        );
    }

    function deployQuotaManager(DefaultResolver resolver) internal returns (QuotaManager) {
         return QuotaManager(
                deploy({
                    name: "quota_manager",
                    impl: address(new QuotaManager()),
                    data: abi.encodeCall(QuotaManager.init, (address(0), address(resolver), 24 hours))
                })
        );

    }
}
