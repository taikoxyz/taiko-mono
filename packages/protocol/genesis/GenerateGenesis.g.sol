// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AddressManager } from "../contracts/common/AddressManager.sol";
import { AddressResolver } from "../contracts/common/AddressResolver.sol";
import { Bridge } from "../contracts/bridge/Bridge.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";
import { ERC1155Vault } from "../contracts/tokenvault/ERC1155Vault.sol";
import { ERC20Vault } from "../contracts/tokenvault/ERC20Vault.sol";
import { ERC721Vault } from "../contracts/tokenvault/ERC721Vault.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { IBridge } from "../contracts/bridge/IBridge.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { RegularERC20 } from "../contracts/test/erc20/RegularERC20.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { TaikoL2 } from "../contracts/L2/TaikoL2.sol";
import { Test } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON = vm.readFile(
        string.concat(vm.projectRoot(), "/genesis/test_config.json")
    );
    string private genesisAllocJSON = vm.readFile(
        string.concat(vm.projectRoot(), "/deployments/genesis_alloc.json")
    );
    address private owner = configJSON.readAddress(".contractOwner");
    address private admin = configJSON.readAddress(".contractAdmin");

    // uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    function testContractDeployment() public {
        assertEq(block.chainid, 167);

        checkDeployedCode("ProxiedTaikoL2");
        checkDeployedCode("ProxiedERC20Vault");
        checkDeployedCode("ProxiedERC721Vault");
        checkDeployedCode("ProxiedERC1155Vault");
        checkDeployedCode("ProxiedEtherVault");
        checkDeployedCode("ProxiedBridge");
        checkDeployedCode("RegularERC20");
        checkDeployedCode("ProxiedAddressManager");
        checkDeployedCode("ProxiedSignalService");

        // check proxy implementations
        checkProxyImplementation("TaikoL2Proxy", "ProxiedTaikoL2");
        checkProxyImplementation("ERC20VaultProxy", "ProxiedERC20Vault");
        checkProxyImplementation("ERC721VaultProxy", "ProxiedERC721Vault");
        checkProxyImplementation("ERC1155VaultProxy", "ProxiedERC1155Vault");
        checkProxyImplementation("EtherVaultProxy", "ProxiedEtherVault");
        checkProxyImplementation("BridgeProxy", "ProxiedBridge");
        checkProxyImplementation("AddressManagerProxy", "ProxiedAddressManager");
        checkProxyImplementation("SignalServiceProxy", "ProxiedSignalService");

        // check proxies
        checkDeployedCode("TaikoL2Proxy");
        checkDeployedCode("ERC20VaultProxy");
        checkDeployedCode("ERC721VaultProxy");
        checkDeployedCode("ERC1155VaultProxy");
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
        checkSavedAddress(addressManager, "ERC20VaultProxy", "erc20_vault");
        checkSavedAddress(addressManager, "ERC721VaultProxy", "erc721_vault");
        checkSavedAddress(addressManager, "ERC1155VaultProxy", "erc1155_vault");
        checkSavedAddress(addressManager, "EtherVaultProxy", "ether_vault");
        checkSavedAddress(addressManager, "TaikoL2Proxy", "taiko");
        checkSavedAddress(
            addressManager, "SignalServiceProxy", "signal_service"
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

    function testTaikoL2() public {
        TaikoL2 taikoL2 = TaikoL2(getPredeployedContractAddress("TaikoL2Proxy"));

        vm.startPrank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        for (uint32 i = 0; i < 300; i++) {
            vm.roll(block.number + 1);
            vm.warp(taikoL2.parentTimestamp() + 12);
            vm.fee(taikoL2.getBasefee(12, i));

            uint256 gasLeftBefore = gasleft();

            taikoL2.anchor(
                bytes32(block.prevrandao), bytes32(block.prevrandao), i, i
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
            payable(getPredeployedContractAddress("TaikoL2Proxy"))
        );

        TaikoL2 newTaikoL2 = new TaikoL2();

        proxy.upgradeTo(address(newTaikoL2));

        assertEq(proxy.implementation(), address(newTaikoL2));
        vm.stopPrank();
    }

    function testBridge() public {
        address payable bridgeAddress =
            payable(getPredeployedContractAddress("BridgeProxy"));
        Bridge bridge = Bridge(bridgeAddress);

        assertEq(owner, bridge.owner());

        vm.expectRevert(BridgeErrors.B_FORBIDDEN.selector);
        bridge.processMessage(
            IBridge.Message({
                id: 0,
                from: address(0),
                srcChainId: 1,
                destChainId: 167,
                user: address(0),
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

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("BridgeProxy"))
        );

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

        assertEq(
            etherVault.isAuthorized(
                getPredeployedContractAddress("BridgeProxy")
            ),
            true
        );
        assertEq(etherVault.isAuthorized(etherVault.owner()), false);

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("EtherVaultProxy"))
        );

        EtherVault newEtherVault = new EtherVault();

        proxy.upgradeTo(address(newEtherVault));

        assertEq(proxy.implementation(), address(newEtherVault));
        vm.stopPrank();
    }

    function testERC20Vault() public {
        address erc20VaultAddress =
            getPredeployedContractAddress("ERC20VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("BridgeProxy");

        ERC20Vault erc20Vault = ERC20Vault(erc20VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, erc20Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc20_vault", erc20VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("ERC20VaultProxy"))
        );

        ERC20Vault newERC20Vault = new ERC20Vault();

        proxy.upgradeTo(address(newERC20Vault));

        assertEq(proxy.implementation(), address(newERC20Vault));
        vm.stopPrank();
    }

    function testERC721Vault() public {
        address erc721VaultAddress =
            getPredeployedContractAddress("ERC721VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("BridgeProxy");

        ERC721Vault erc721Vault = ERC721Vault(erc721VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, erc721Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc721_vault", erc721VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("ERC721VaultProxy"))
        );

        ERC721Vault newERC721Vault = new ERC721Vault();

        proxy.upgradeTo(address(newERC721Vault));

        assertEq(proxy.implementation(), address(newERC721Vault));
        vm.stopPrank();
    }

    function testERC1155Vault() public {
        address erc1155VaultAddress =
            getPredeployedContractAddress("ERC1155VaultProxy");
        address bridgeAddress = getPredeployedContractAddress("BridgeProxy");

        ERC1155Vault erc1155Vault = ERC1155Vault(erc1155VaultAddress);
        AddressManager addressManager =
            AddressManager(getPredeployedContractAddress("AddressManagerProxy"));

        assertEq(owner, erc1155Vault.owner());

        vm.startPrank(addressManager.owner());
        addressManager.setAddress(1, "bridge", bridgeAddress);
        addressManager.setAddress(1, "erc1155_vault", erc1155VaultAddress);
        vm.stopPrank();

        vm.startPrank(admin);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(getPredeployedContractAddress("ERC1155VaultProxy"))
        );

        ERC1155Vault newERC1155Vault = new ERC1155Vault();

        proxy.upgradeTo(address(newERC1155Vault));

        assertEq(proxy.implementation(), address(newERC1155Vault));
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
            addressManager.getAddress(block.chainid, name)
        );
    }
}
