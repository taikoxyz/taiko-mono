// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { DelegateController } from "src/layer2/governance/DelegateController.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { Layer2Test } from "test/layer2/Layer2Test.sol";

/// @dev Accepts Ether with a storage write, which costs more than the 2300-gas stipend.
contract GasHungryRecipient {
    uint256 public received;

    receive() external payable {
        received += msg.value;
    }
}

/// @dev Rejects every Ether transfer.
contract RejectingRecipient {
    receive() external payable {
        revert();
    }
}

/// @dev Owns a vault and withdraws to itself again from inside the Ether transfer.
contract ReentrantOwner {
    L2FeeVault public vault;
    bytes public reentryError;

    function setVault(L2FeeVault _vault) external {
        vault = _vault;
    }

    function withdraw(uint256 _amount) external {
        vault.withdraw(address(this), _amount);
    }

    receive() external payable {
        try vault.withdraw(address(this), msg.value) { }
        catch (bytes memory reason) {
            reentryError = reason;
        }
    }
}

contract L2FeeVaultTest is Layer2Test {
    // Contracts on Ethereum
    address private daoController = randAddress();

    // Contracts on Taiko
    Bridge private tBridge;
    DelegateController private tDelegateController;
    L2FeeVault private vault;

    function setUpOnEthereum() internal override {
        register("bridge", daoController);
    }

    function setUpOnTaiko() internal override {
        SignalService signalService = deploySignalServiceWithoutProof(
            address(this),
            address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_LAYER2")))),
            deployer
        );
        tBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(signalService), address(0), address(0), false)
            )
        );
        tDelegateController =
            deployDelegateController(ethereumChainId, address(tBridge), daoController);
        vault = _deployVault(address(tDelegateController));
    }

    // ---------------------------------------------------------------
    // init
    // ---------------------------------------------------------------

    function test_init_SetsOwner() external view {
        assertEq(vault.owner(), address(tDelegateController));
        assertFalse(vault.paused());
    }

    function test_init_RevertWhen_CalledTwice() external {
        vm.expectRevert("Initializable: contract is already initialized");
        vault.init(Alice);
    }

    // ---------------------------------------------------------------
    // receive
    // ---------------------------------------------------------------

    function test_receive_AcceptsEther() external {
        vm.deal(Bob, 1 ether);

        vm.prank(Bob);
        (bool success,) = address(vault).call{ value: 1 ether }("");

        assertTrue(success);
        assertEq(address(vault).balance, 1 ether);
        assertEq(Bob.balance, 0);
    }

    // ---------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------

    function test_withdraw_SendsEtherAndEmits() external {
        // Block fees reach the coinbase without a call, like vm.deal.
        vm.deal(address(vault), 3 ether);

        vm.expectEmit();
        emit L2FeeVault.FeesWithdrawn(Alice, 1 ether);

        vm.prank(address(tDelegateController));
        vault.withdraw(Alice, 1 ether);

        assertEq(Alice.balance, 1 ether);
        assertEq(address(vault).balance, 2 ether);
    }

    function test_withdraw_SendsWholeBalance() external {
        vm.deal(address(vault), 3 ether);

        vm.prank(address(tDelegateController));
        vault.withdraw(Alice, 3 ether);

        assertEq(Alice.balance, 3 ether);
        assertEq(address(vault).balance, 0);
    }

    function test_withdraw_ZeroAmountEmitsWithoutTransfer() external {
        vm.deal(address(vault), 1 ether);
        RejectingRecipient recipient = new RejectingRecipient();

        vm.expectEmit();
        emit L2FeeVault.FeesWithdrawn(address(recipient), 0);

        vm.prank(address(tDelegateController));
        vault.withdraw(address(recipient), 0);

        assertEq(address(vault).balance, 1 ether);
    }

    function test_withdraw_ForwardsAllGasToContractRecipient() external {
        vm.deal(address(vault), 1 ether);
        GasHungryRecipient recipient = new GasHungryRecipient();

        vm.prank(address(tDelegateController));
        vault.withdraw(address(recipient), 1 ether);

        assertEq(recipient.received(), 1 ether);
        assertEq(address(recipient).balance, 1 ether);
        assertEq(address(vault).balance, 0);
    }

    function test_withdraw_ByDelegateControllerViaBridge() external onTaiko {
        vm.deal(address(vault), 2 ether);

        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: address(vault),
            value: 0,
            data: abi.encodeCall(L2FeeVault.withdraw, (Alice, 1.5 ether))
        });

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation,
            (abi.encodePacked(uint64(1), abi.encode(actions)))
        );
        message.to = address(tDelegateController);

        vm.expectEmit();
        emit L2FeeVault.FeesWithdrawn(Alice, 1.5 ether);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        assertTrue(tBridge.messageStatus(tBridge.hashMessage(message)) == IBridge.Status.DONE);
        assertEq(tDelegateController.lastExecutionId(), 1);
        assertEq(Alice.balance, 1.5 ether);
        assertEq(address(vault).balance, 0.5 ether);
    }

    function test_withdraw_RevertWhen_NotOwner() external {
        vm.deal(address(vault), 1 ether);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(Alice);
        vault.withdraw(Alice, 1 ether);

        assertEq(address(vault).balance, 1 ether);
    }

    function test_withdraw_RevertWhen_RecipientIsZeroAddress() external {
        vm.deal(address(vault), 1 ether);

        vm.expectRevert(L2FeeVault.InvalidAddress.selector);
        vm.prank(address(tDelegateController));
        vault.withdraw(address(0), 1 ether);
    }

    function test_withdraw_RevertWhen_AmountExceedsBalance() external {
        vm.deal(address(vault), 1 ether);

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        vm.prank(address(tDelegateController));
        vault.withdraw(Alice, 1 ether + 1);
    }

    function test_withdraw_RevertWhen_RecipientRejectsEther() external {
        vm.deal(address(vault), 1 ether);
        RejectingRecipient recipient = new RejectingRecipient();

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        vm.prank(address(tDelegateController));
        vault.withdraw(address(recipient), 1 ether);
    }

    function test_withdraw_RevertWhen_Reentered() external {
        ReentrantOwner reentrantOwner = new ReentrantOwner();
        L2FeeVault ownedVault = _deployVault(address(reentrantOwner));
        reentrantOwner.setVault(ownedVault);
        vm.deal(address(ownedVault), 3 ether);

        reentrantOwner.withdraw(1 ether);

        assertEq(
            reentrantOwner.reentryError(),
            abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector)
        );
        assertEq(address(reentrantOwner).balance, 1 ether);
        assertEq(address(ownedVault).balance, 2 ether);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _deployVault(address _owner) private returns (L2FeeVault) {
        return L2FeeVault(
            payable(deploy({
                    name: "",
                    impl: address(new L2FeeVault()),
                    data: abi.encodeCall(L2FeeVault.init, (_owner))
                }))
        );
    }
}
