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

import "src/layer1/token/TaikoToken.sol"; // why we need Taiko token here? TODO

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

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        // Find the first null character to determine actual string length
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        // Create a string with the correct length and copy bytes
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < bytesArray.length; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
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

        console2.log(">", string.concat("'", bytes32ToString(name), "'"));
        console2.log("  proxy   :", proxy);
        console2.log("  impl    :", impl);
        console2.log("  owner   :", OwnableUpgradeable(proxy).owner());
        console2.log("  chain id:", block.chainid);
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
        console2.log("  resolver:", address(resolver));
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
        return SignalServiceNoProofCheck(
            deploy({
                name: "signal_service",
                impl: signalServiceImpl,
                data: abi.encodeCall(SignalService.init, (address(0), address(resolver))),
                resolver: resolver
            })
        );
    }

    function deployTaikoToken(DefaultResolver resolver) internal returns (TaikoToken) {
        return TaikoToken(
            deploy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(TaikoToken.init, (address(0), address(this))),
                resolver: resolver
            })
        );
    }

    function deployBridgedERC20(
        DefaultResolver resolver,
        address srcToken,
        uint256 srcChainId,
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
                impl: address(new BridgedERC20()),
                data: abi.encodeCall(
                    BridgedERC20.init,
                    (address(0), address(resolver), srcToken, srcChainId, decimals, symbol, name)
                )
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

    function deployERC20Vault(DefaultResolver resolver) internal returns (ERC20Vault) {
        return ERC20Vault(
            deploy({
                name: "erc20_vault",
                impl: address(new ERC20Vault()),
                data: abi.encodeCall(ERC20Vault.init, (address(0), address(resolver)))
            })
        );
    }

    function deployERC721Vault(DefaultResolver resolver) internal returns (ERC721Vault) {
        return ERC721Vault(
            deploy({
                name: "erc721_vault",
                impl: address(new ERC721Vault()),
                data: abi.encodeCall(ERC721Vault.init, (address(0), address(resolver)))
            })
        );
    }

    function deployERC1155Vault(DefaultResolver resolver) internal returns (ERC1155Vault) {
        return ERC1155Vault(
            deploy({
                name: "erc1155_vault",
                impl: address(new ERC1155Vault()),
                data: abi.encodeCall(ERC1155Vault.init, (address(0), address(resolver)))
            })
        );
    }
}
