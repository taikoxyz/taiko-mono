// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC20Vault.h.sol";
import "../helpers/FreeMintERC20Token.sol";
import "src/layer1/based/ITaikoInbox.sol";

contract TestERC20Vault_solver is CommonTest {
    address private quotaManager = address(0);

    // Contracts on Ethereum
    SignalService private eSignalService;
    PrankTaikoInbox private taikoInbox;
    PrankDestBridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20Token private eERC20Token1;
    FreeMintERC20Token private eERC20Token2;

    // Contracts on Taiko
    SignalService private tSignalService;
    Bridge private tBridge;
    ERC20Vault private tVault;
    BridgedERC20 private tUSDC;
    BridgedERC20 private tUSDT;
    BridgedERC20 private tStETH;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalService(
            address(new SignalService_WithoutProofVerification(address(resolver)))
        );
        eVault = deployERC20Vault();
        eBridge = new PrankDestBridge(eVault);
        taikoInbox = new PrankTaikoInbox();

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(Alice);

        eERC20Token2 = new FreeMintERC20Token("", "123456abcdefgh");
        eERC20Token2.mint(Alice);

        register("bridge", address(eBridge));
        register("taiko", address(taikoInbox));

        vm.deal(address(eBridge), 100 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalService(
            address(new SignalService_WithoutProofVerification(address(resolver)))
        );
        tVault = deployERC20Vault();
        tBridge = deployBridge(
            address(new Bridge(address(resolver), address(tSignalService), quotaManager))
        );

        register("bridge", address(tBridge));
        register("bridged_erc20", address(new BridgedERC20(address(tVault))));

        tUSDC = deployBridgedERC20(address(tVault), randAddress(), 100, 18, "USDC", "USDC coin");
        tUSDT = deployBridgedERC20(address(tVault), randAddress(), 100, 18, "USDT", "USDT coin");
        tStETH =
            deployBridgedERC20(address(tVault), randAddress(), 100, 18, "tStETH", "Lido Staked ETH");

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function test_20vault_send_erc20_with_solver_fee() public {
        vm.chainId(taikoChainId);

        vm.startPrank(deployer);

        vm.warp(block.timestamp + 91 days);
        tVault.changeBridgedToken(erc20ToCanonicalERC20(ethereumChainId), address(tUSDC));
        tUSDC.mint(Alice, 3);

        vm.stopPrank();

        vm.startPrank(Alice);

        uint256 amount = 2;
        uint256 solverFee = 1;

        uint256 aliceBalanceBefore = tUSDC.balanceOf(Alice);

        tUSDC.approve(address(tVault), 3);
        tVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, 0, address(tUSDC), 1_000_000, amount, solverFee
            )
        );

        uint256 aliceBalanceAfter = tUSDC.balanceOf(Alice);
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount + solverFee);
    }

    function test_20Vault_receive_erc20_solved() public {
        eERC20Token1.mint(address(eVault));

        uint64 amount = 1;
        uint64 solverFee = 2;
        address to = Bob;
        address solver = David;
        bytes32 solverCondition = eVault.getSolverCondition(1, address(eERC20Token1), to, amount);

        eERC20Token1.mint(address(solver));

        vm.startPrank(solver);

        uint256 solverBalanceBefore = eERC20Token1.balanceOf(solver);
        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));
        uint256 toBalanceBefore = eERC20Token1.balanceOf(to);

        {
            uint64 blockId = 1;
            bytes32 blockMetaHash = bytes32("metahash");

            ITaikoInbox.Batch memory batch;
            batch.metaHash = blockMetaHash;
            taikoInbox.setBatch(batch);

            eERC20Token1.approve(address(eVault), 2);

            eVault.solve(
                ERC20Vault.SolverOp(1, address(eERC20Token1), to, amount, blockId, blockMetaHash)
            );
        }

        eBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            to,
            amount,
            solverFee,
            solverCondition,
            bytes32(0),
            address(tVault),
            taikoChainId,
            0
        );

        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount + solverFee);

        uint256 toBalanceAfter = eERC20Token1.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);

        uint256 solverBalanceAfter = eERC20Token1.balanceOf(solver);
        assertEq(solverBalanceAfter - solverBalanceBefore, solverFee);

        assertTrue(eVault.solverConditionToSolver(solverCondition) == address(0));
    }

    function test_20Vault_receive_erc20_solved_with_ether_to_james() public {
        eERC20Token1.mint(address(eVault));

        uint64 amount = 1;
        uint64 solverFee = 2;
        address to = James;
        address solver = David;
        bytes32 solverCondition = eVault.getSolverCondition(1, address(eERC20Token1), to, amount);
        uint256 etherAmount = 0.1 ether;

        eERC20Token1.mint(address(solver));

        vm.startPrank(solver);

        uint256 solverBalanceBefore = eERC20Token1.balanceOf(solver);
        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));
        uint256 toBalanceBefore = eERC20Token1.balanceOf(to);

        {
            uint64 blockId = 1;
            bytes32 blockMetaHash = bytes32("metahash");

            ITaikoInbox.Batch memory batch;
            batch.metaHash = blockMetaHash;
            taikoInbox.setBatch(batch);

            eERC20Token1.approve(address(eVault), 2);

            eVault.solve(
                ERC20Vault.SolverOp(1, address(eERC20Token1), to, amount, blockId, blockMetaHash)
            );
        }

        eBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            to,
            amount,
            solverFee,
            solverCondition,
            bytes32(0),
            address(tVault),
            taikoChainId,
            etherAmount
        );

        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount + solverFee);

        uint256 toBalanceAfter = eERC20Token1.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);

        uint256 solverBalanceAfter = eERC20Token1.balanceOf(solver);
        assertEq(solverBalanceAfter - solverBalanceBefore, solverFee);

        assertEq(James.balance, etherAmount);
        assertTrue(eVault.solverConditionToSolver(solverCondition) == address(0));
    }

    function test_20Vault_solve_reverts_when_already_solved() public {
        uint64 amount = 1;
        address to = James;
        address solver = David;

        eERC20Token1.mint(address(solver));

        vm.startPrank(solver);

        uint64 blockId = 1;
        bytes32 blockMetaHash = bytes32("metahash1");

        ITaikoInbox.Batch memory batch;
        batch.metaHash = blockMetaHash;
        taikoInbox.setBatch(batch);

        eERC20Token1.approve(address(eVault), 2);
        eVault.solve(
            ERC20Vault.SolverOp(1, address(eERC20Token1), to, amount, blockId, blockMetaHash)
        );

        vm.expectRevert(ERC20Vault.VAULT_ALREADY_SOLVED.selector);
        eVault.solve(
            ERC20Vault.SolverOp(1, address(eERC20Token1), to, amount, blockId, blockMetaHash)
        );
    }

    function test_20Vault_solve_reverts_when_metadata_is_mismatched() public {
        uint64 amount = 1;
        address to = James;
        address solver = David;

        eERC20Token1.mint(address(solver));

        vm.startPrank(solver);

        uint64 blockId = 1;
        bytes32 blockMetaHash = bytes32("metahash1");
        bytes32 mismatchedBlockMetahash = bytes32("metahash2");

        ITaikoInbox.Batch memory batch;
        batch.metaHash = blockMetaHash;
        taikoInbox.setBatch(batch);

        vm.expectRevert(ERC20Vault.VAULT_METAHASH_MISMATCH.selector);
        eVault.solve(
            ERC20Vault.SolverOp(
                1, address(eERC20Token1), to, amount, blockId, mismatchedBlockMetahash
            )
        );
    }

    function erc20ToCanonicalERC20(uint64 chainId)
        internal
        view
        returns (ERC20Vault.CanonicalERC20 memory)
    {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(eERC20Token1),
            decimals: eERC20Token1.decimals(),
            symbol: eERC20Token1.symbol(),
            name: eERC20Token1.name()
        });
    }

    function test_20Vault_send_ether_revert_if_insufficient_value() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_INSUFFICIENT_ETHER.selector);
        tVault.sendToken{ value: 0 }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, 0, address(0), 1_000_000, 1 wei, 0
            )
        );
    }

    function test_20Vault_send_ether_no_processing_fee() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        uint256 aliceBalanceBefore = Alice.balance;

        tVault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, 0, address(0), 1_000_000, amount, 0
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
    }

    function test_20Vault_send_ether_processing_fee_reverts_if_msg_value_too_low() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        uint64 fee = 1 wei;

        vm.expectRevert(ERC20Vault.VAULT_INSUFFICIENT_ETHER.selector);
        tVault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, fee, address(0), 1_000_000, amount, 0
            )
        );
    }

    function test_20Vault_send_ether_processing_fee() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        uint64 fee = 1 wei;
        uint256 totalValue = amount + fee;

        uint256 aliceBalanceBefore = Alice.balance;

        tVault.sendToken{ value: totalValue }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, fee, address(0), 1_000_000, amount, 0
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceBefore - aliceBalanceAfter, totalValue);
    }

    function test_20Vault_send_ether_with_solver_fee() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        uint64 fee = 1 wei;
        uint256 solverFee = 1 wei;
        uint256 totalValue = amount + fee + solverFee;

        uint256 aliceBalanceBefore = Alice.balance;

        tVault.sendToken{ value: totalValue }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, fee, address(0), 1_000_000, amount, solverFee
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceBefore - aliceBalanceAfter, totalValue);
    }

    function test_20Vault_solve_ether() public {
        uint256 amount = 1 wei;
        address to = James;
        address solver = David;

        vm.deal(solver, 1 wei);

        vm.startPrank(solver);

        uint256 solverBalanceBefore = solver.balance;
        uint256 toBalanceBefore = to.balance;

        uint64 blockId = 1;
        bytes32 blockMetaHash = bytes32("metahash");

        ITaikoInbox.Batch memory batch;
        batch.metaHash = blockMetaHash;
        taikoInbox.setBatch(batch);

        eVault.solve{ value: amount }(
            ERC20Vault.SolverOp(1, address(0), to, amount, blockId, blockMetaHash)
        );

        uint256 toBalanceAfter = to.balance;
        uint256 solverBalanceAfter = solver.balance;

        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(solverBalanceBefore - solverBalanceAfter, amount);
    }

    function test_20Vault_onMessageRecalled_ether() public {
        vm.chainId(taikoChainId);
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        uint256 aliceBalanceBefore = Alice.balance;

        IBridge.Message memory message = tVault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                ethereumChainId, address(0), Bob, 0, address(0), 1_000_000, amount, 0
            )
        );

        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);

        tBridge.recallMessage(message, bytes(""));

        uint256 aliceBalanceAfterRecall = Alice.balance;
        assertEq(aliceBalanceAfterRecall, aliceBalanceBefore);
    }

    function test_20Vault_receive_ether_solved() public {
        uint64 amount = 1 ether;
        uint64 solverFee = 0.1 ether;
        address to = Bob;
        address solver = David;
        bytes32 solverCondition = eVault.getSolverCondition(1, address(0), to, amount);

        vm.deal(solver, amount);

        vm.startPrank(solver);

        uint256 solverBalanceBefore = solver.balance;
        uint256 toBalanceBefore = to.balance;

        {
            uint64 blockId = 1;
            bytes32 blockMetaHash = bytes32("metahash");

            ITaikoInbox.Batch memory batch;
            batch.metaHash = blockMetaHash;
            taikoInbox.setBatch(batch);

            eVault.solve{ value: amount }(
                ERC20Vault.SolverOp(1, address(0), to, amount, blockId, blockMetaHash)
            );
        }

        uint256 ethAmount = amount + solverFee;
        eBridge.sendReceiveEtherToERC20Vault(
            Alice,
            to,
            amount,
            solverFee,
            solverCondition,
            bytes32(0),
            address(tVault),
            taikoChainId,
            ethAmount
        );

        uint256 toBalanceAfter = to.balance;
        assertEq(toBalanceAfter - toBalanceBefore, amount);

        uint256 solverBalanceAfter = solver.balance;
        assertEq(solverBalanceAfter - solverBalanceBefore, solverFee);

        assertTrue(eVault.solverConditionToSolver(solverCondition) == address(0));
    }
}
