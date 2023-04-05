// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/StdJson.sol";
import "../../contracts/bridge/BridgeErrors.sol";
import "../../contracts/bridge/IBridge.sol";
import "../../contracts/common/AddressResolver.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoL2} from "../../contracts/L2/TaikoL2.sol";
import {AddressManager} from "../../contracts/thirdparty/AddressManager.sol";
import {Bridge} from "../../contracts/bridge/Bridge.sol";
import {TokenVault} from "../../contracts/bridge/TokenVault.sol";
import {EtherVault} from "../../contracts/bridge/EtherVault.sol";
import {SignalService} from "../../contracts/signal/SignalService.sol";
import {LibBridgeStatus} from "../../contracts/bridge/libs/LibBridgeStatus.sol";
import {TestERC20} from "../../contracts/test/thirdparty/TestERC20.sol";

contract TestGenerateGenesis is Test, AddressResolver {
    using stdJson for string;

    string private configJSON =
        vm.readFile(
            string.concat(vm.projectRoot(), "/test2/genesis/test_config.json")
        );
    string private genesisAllocJSON =
        vm.readFile(
            string.concat(vm.projectRoot(), "/deployments/genesis_alloc.json")
        );
    address private owner = configJSON.readAddress(".contractOwner");
    uint64 public constant BLOCK_GAS_LIMIT = 6000000;

    function testContractDeployment() public {
        assertEq(block.chainid, 167);

        checkDeployedCode("TaikoL2");
        checkDeployedCode("TokenVault");
        checkDeployedCode("EtherVault");
        checkDeployedCode("Bridge");
        checkDeployedCode("TestERC20");
        checkDeployedCode("AddressManager");
        checkDeployedCode("SignalService");
    }

    function testAddressManager() public {
        AddressManager addressManager = AddressManager(
            getPredeployedContractAddress("AddressManager")
        );

        assertEq(owner, addressManager.owner());

        checkSavedAddress(addressManager, "Bridge", "bridge");
        checkSavedAddress(addressManager, "TokenVault", "token_vault");
        checkSavedAddress(addressManager, "EtherVault", "ether_vault");
        checkSavedAddress(addressManager, "TaikoL2", "taiko");
        checkSavedAddress(addressManager, "SignalService", "signal_service");
    }

    function testTaikoL2() public {
        TaikoL2 taikoL2 = TaikoL2(getPredeployedContractAddress("TaikoL2"));

        vm.startPrank(taikoL2.GOLDEN_TOUCH_ADDRESS());
        for (uint64 i = 0; i < 300; i++) {
            vm.roll(block.number + 1);
            vm.warp(taikoL2.parentTimestamp() + 12);
            vm.fee(
                taikoL2.getBasefee(
                    0,
                    BLOCK_GAS_LIMIT,
                    i + taikoL2.ANCHOR_GAS_COST()
                )
            );

            uint256 gasLeftBefore = gasleft();

            taikoL2.anchor(
                bytes32(block.prevrandao),
                bytes32(block.prevrandao),
                i,
                i + taikoL2.ANCHOR_GAS_COST()
            );

            if (i == 299) {
                console2.log(
                    "TaikoL2.anchor gas cost after 256 L2 blocks:",
                    gasLeftBefore - gasleft()
                );
            }
        }
        vm.stopPrank();
    }

    function testBridge() public {
        address payable bridgeAddress = payable(
            getPredeployedContractAddress("Bridge")
        );
        Bridge bridge = Bridge(bridgeAddress);

        assertEq(owner, bridge.owner());

        vm.expectRevert(BridgeErrors.B_FORBIDDEN.selector);
        bridge.processMessage(
            IBridge.Message({
                id: 0,
                sender: address(0),
                srcChainId: 1,
                destChainId: 167,
                owner: address(0),
                to: address(0),
                refundAddress: address(0),
                depositValue: 0,
                callValue: 0,
                processingFee: 0,
                gasLimit: 0,
                data: "",
                memo: ""
            }),
            ""
        );
    }

    function testTokenVault() public {
        address tokenVaultAddress = getPredeployedContractAddress("TokenVault");
        address bridgeAddress = getPredeployedContractAddress("Bridge");

        TokenVault tokenVault = TokenVault(tokenVaultAddress);
        AddressManager addressManager = AddressManager(
            getPredeployedContractAddress("AddressManager")
        );

        assertEq(owner, tokenVault.owner());

        vm.prank(addressManager.owner());
        addressManager.setAddress(keyForName(1, "bridge"), bridgeAddress);
        vm.prank(addressManager.owner());
        addressManager.setAddress(
            keyForName(1, "token_vault"),
            tokenVaultAddress
        );

        tokenVault.sendEther{value: 1}(
            1,
            tokenVault.owner(),
            100,
            0,
            tokenVault.owner(),
            ""
        );
    }

    function testEtherVault() public {
        address payable etherVaultAddress = payable(
            getPredeployedContractAddress("EtherVault")
        );
        EtherVault etherVault = EtherVault(etherVaultAddress);

        assertEq(owner, etherVault.owner());

        assertEq(
            etherVault.isAuthorized(getPredeployedContractAddress("Bridge")),
            true
        );
        assertEq(etherVault.isAuthorized(etherVault.owner()), false);
    }

    function testSignalService() public {
        SignalService signalService = SignalService(
            getPredeployedContractAddress("SignalService")
        );

        assertEq(owner, signalService.owner());

        signalService.sendSignal(bytes32(block.prevrandao));
    }

    function testERC20() public {
        TestERC20 testErc20 = TestERC20(
            getPredeployedContractAddress("TestERC20")
        );

        assertEq(testErc20.name(), "PredeployERC20");
        assertEq(testErc20.symbol(), "PRE");
    }

    function getPredeployedContractAddress(
        string memory contractName
    ) private returns (address) {
        return
            configJSON.readAddress(
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

    function checkSavedAddress(
        AddressManager addressManager,
        string memory contractName,
        string memory key
    ) private {
        assertEq(
            getPredeployedContractAddress(contractName),
            addressManager.getAddress(keyForName(block.chainid, key))
        );
    }
}
