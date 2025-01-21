// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "./EtherBridgeWrapper.h.sol";

contract TestEtherBridgeWrapper is CommonTest {
    // Contracts on Ethereum
    SignalService private eSignalService;
    PrankDestBridge private eBridge;
    PrankTaikoInbox private taikoInbox;
    EtherBridgeWrapper private eWrapper;

    // Contracts on Taiko
    SignalService private tSignalService;
    Bridge private tBridge;
    EtherBridgeWrapper private tWrapper;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalService(address(new SignalService_WithoutProofVerification()));
        eWrapper = deployEtherBridgeWrapper();
        eBridge = new PrankDestBridge(eWrapper);
        taikoInbox = new PrankTaikoInbox();

        register("bridge", address(eBridge));
        register("taiko", address(taikoInbox));

        vm.deal(address(eBridge), 100 ether);
        vm.deal(David, 100 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalService(address(new SignalService_WithoutProofVerification()));
        tBridge = deployBridge(address(new Bridge()));
        tWrapper = deployEtherBridgeWrapper();

        register("bridge", address(tBridge));

        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
    }

    function test_wrapper_send_ether_revert_if_insufficient_value() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);
        vm.expectRevert(EtherBridgeWrapper.InsufficientValue.selector);
        tWrapper.sendToken{ value: 0.9 ether }(
            EtherBridgeWrapper.EtherBridgeOp(
                ethereumChainId,
                address(0),
                Bob,
                0.1 ether, // fee
                1_000_000,
                1 ether, // amount
                0 // solverFee
            )
        );
    }

    function test_wrapper_send_ether_no_processing_fee() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 1 ether;
        uint256 aliceBalanceBefore = Alice.balance;
        uint256 wrapperBalanceBefore = address(tWrapper).balance;

        IBridge.Message memory message = tWrapper.sendToken{ value: amount }(
            EtherBridgeWrapper.EtherBridgeOp(
                ethereumChainId,
                address(0),
                Bob,
                0, // fee
                1_000_000,
                amount,
                0 // solverFee
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        uint256 wrapperBalanceAfter = address(tWrapper).balance;

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(wrapperBalanceAfter - wrapperBalanceBefore, 0);
        assertEq(message.value, amount);
    }

    function test_wrapper_send_ether_with_processing_fee() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 1 ether;
        uint256 fee = 0.1 ether;
        uint256 aliceBalanceBefore = Alice.balance;

        IBridge.Message memory message = tWrapper.sendToken{ value: amount + fee }(
            EtherBridgeWrapper.EtherBridgeOp(
                ethereumChainId,
                address(0),
                Bob,
                uint64(fee),
                1_000_000,
                amount,
                0 // solverFee
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount + fee);
        assertEq(message.value, amount);
        assertEq(message.fee, fee);
    }

    function test_wrapper_send_ether_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        vm.expectRevert(EtherBridgeWrapper.InvalidAmount.selector);
        tWrapper.sendToken(
            EtherBridgeWrapper.EtherBridgeOp(
                ethereumChainId,
                address(0),
                Bob,
                0,
                1_000_000,
                0, // amount = 0
                0
            )
        );
    }

    function test_wrapper_receive_ether() public {
        vm.startPrank(Alice);
        vm.chainId(ethereumChainId);

        uint256 amount = 1 ether;
        address to = Bob;
        uint256 toBalanceBefore = to.balance;

        eBridge.sendReceiveEtherToWrapper(
            Alice,
            to,
            amount,
            0, // solverFee
            bytes32(0), // solverCondition
            bytes32(0), // msgHash
            address(tWrapper),
            taikoChainId,
            amount // mockLibInvokeMsgValue
        );

        uint256 toBalanceAfter = to.balance;
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_wrapper_receive_ether_solved() public {
        vm.chainId(ethereumChainId);

        uint256 amount = 1 ether;
        uint256 solverFee = 0.1 ether;
        address to = Bob;
        address solver = David;
        bytes32 solverCondition = tWrapper.getSolverCondition(1, to, amount);

        vm.deal(solver, 10 ether);
        vm.startPrank(solver);

        uint256 solverBalanceBefore = solver.balance;
        uint256 toBalanceBefore = to.balance;

        {
            uint64 l2BatchId = 1;
            bytes32 l2BatchMetaHash = bytes32("metahash");

            ITaikoInbox.Batch memory batch;
            batch.metaHash = l2BatchMetaHash;
            taikoInbox.setBatch(batch);

            eWrapper.solve{ value: amount }(
                EtherBridgeWrapper.SolverOp(1, to, amount, l2BatchId, l2BatchMetaHash)
            );
        }

        uint256 totalValue = amount + solverFee;
        eBridge.sendReceiveEtherToWrapper(
            Alice,
            to,
            amount,
            solverFee,
            solverCondition,
            bytes32(0),
            address(tWrapper),
            taikoChainId,
            totalValue
        );

        uint256 toBalanceAfter = to.balance;
        assertEq(toBalanceAfter - toBalanceBefore, amount);

        uint256 solverBalanceAfter = solver.balance;
        assertEq(solverBalanceAfter - solverBalanceBefore, solverFee);

        assertTrue(eWrapper.solverConditionToSolver(solverCondition) == address(0));
    }

    function test_wrapper_solve_reverts_when_already_solved() public {
        vm.chainId(ethereumChainId);

        uint256 amount = 1 ether;
        address to = James;
        address solver = David;
        uint256 nonce = 1;

        vm.deal(solver, 10 ether);
        vm.startPrank(solver);

        uint64 l2BatchId = 1;
        bytes32 l2BatchMetaHash = bytes32("metahash1");

        ITaikoInbox.Batch memory batch;
        batch.metaHash = l2BatchMetaHash;
        taikoInbox.setBatch(batch);

        eWrapper.solve{ value: amount }(
            EtherBridgeWrapper.SolverOp(nonce, to, amount, l2BatchId, l2BatchMetaHash)
        );

        vm.expectRevert(EtherBridgeWrapper.VaultAlreadySolved.selector);
        eWrapper.solve{ value: amount }(
            EtherBridgeWrapper.SolverOp(nonce, to, amount, l2BatchId, l2BatchMetaHash)
        );
    }

    function test_wrapper_solve_reverts_when_metahash_mismatched() public {
        vm.chainId(ethereumChainId);

        uint256 amount = 1 ether;
        address to = James;
        address solver = David;
        uint256 nonce = 1;

        vm.startPrank(solver);

        uint64 l2BatchId = 1;
        bytes32 l2BatchMetaHash = bytes32("metahash1");
        bytes32 mismatchedMetaHash = bytes32("metahash2");

        ITaikoInbox.Batch memory batch;
        batch.metaHash = l2BatchMetaHash;
        taikoInbox.setBatch(batch);

        vm.expectRevert(EtherBridgeWrapper.VaultMetahashMismatch.selector);
        eWrapper.solve{ value: amount }(
            EtherBridgeWrapper.SolverOp(nonce, to, amount, l2BatchId, mismatchedMetaHash)
        );
    }
}
