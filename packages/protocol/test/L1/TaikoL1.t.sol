// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { LibDepositing } from "../../contracts/L1/libs/LibDepositing.sol";
import { TaikoData } from "../../contracts/L1/TaikoData.sol";
import { TaikoL1 } from "../../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.sol";

contract TaikoL1_NoCooldown is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoL1.getConfig();

        config.blockTxListExpiry = 5 minutes;
        config.blockMaxVerificationsPerTx = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 12;
        config.proofRegularCooldown = 15 minutes;
        config.skipProverAssignmentVerificaiton = true;
        config.proofBond = 1e18; // 1 Taiko token
        config.proposerRewardPerSecond = 1e15; // 0.001 Taiko token
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Test is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1_NoCooldown();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();

        registerAddress(L1.getVerifierName(100), address(new Verifier()));
    }

    /// @dev Test we can propose, prove, then verify more blocks than
    /// 'blockMaxProposals'
    function test_L1_more_blocks_than_ring_buffer_size() external {
        giveEthAndTko(Alice, 1e8 ether, 100 ether);
        // This is a very weird test (code?) issue here.
        // If this line (or Bob's query balance) is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            //printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, blockHash, signalRoot);
            vm.roll(block.number + 15 * 12);
            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_L1_multiple_blocks_in_one_L1_block() external {
        giveEthAndTko(Alice, 1000 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= 2; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlock(Bob, Bob, meta, parentHash, blockHash, signalRoot);
            vm.roll(block.number + 15 * 12);
            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);
            verifyBlock(Alice, 2);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test verifying multiple blocks in one transaction
    function test_L1_verifying_multiple_blocks_once() external {
        giveEthAndTko(Alice, 1000 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= conf.blockMaxProposals; blockId++)
        {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlock(Bob, Bob, meta, parentHash, blockHash, signalRoot);
            parentHash = blockHash;
        }

        vm.roll(block.number + 15 * 12);
        vm.warp(block.timestamp + conf.proofRegularCooldown + 1);
        verifyBlock(Alice, conf.blockMaxProposals - 1);
        printVariables("after verify");
        verifyBlock(Alice, conf.blockMaxProposals);
        printVariables("after verify");
    }

    function test_L1_EthDepositsToL2Reverts() external {
        uint96 minAmount = conf.ethDepositMinAmount;
        uint96 maxAmount = conf.ethDepositMaxAmount;

        giveEthAndTko(Alice, 0, maxAmount + 1 ether);
        vm.prank(Alice, Alice);
        vm.expectRevert();
        L1.depositEtherToL2{ value: minAmount - 1 }(address(0));

        vm.prank(Alice, Alice);
        vm.expectRevert();
        L1.depositEtherToL2{ value: maxAmount + 1 }(address(0));

        assertEq(L1.getStateVariables().nextEthDepositToProcess, 0);
        assertEq(L1.getStateVariables().numEthDeposits, 0);
    }

    function test_L1_EthDepositsToL2Gas() external {
        vm.fee(25 gwei);

        bytes32 emptyDepositsRoot =
            0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;
        giveEthAndTko(Alice, 0, 100_000 ether);
        giveEthAndTko(Bob, 1e6 ether, 0);

        proposeBlock(Alice, Bob, 1_000_000, 1024);
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, Bob, 1_000_000, 1024);
        assertEq(meta.depositsProcessed.length, 0);

        uint256 count = conf.ethDepositMaxCountPerBlock;

        printVariables("before sending ethers");
        for (uint256 i; i < count; ++i) {
            vm.prank(Alice, Alice);
            L1.depositEtherToL2{ value: (i + 1) * 1 ether }(address(0));
        }
        printVariables("after sending ethers");

        uint256 gas = gasleft();
        meta = proposeBlock(Alice, Bob, 1_000_000, 1024);
        uint256 gasUsedWithDeposits = gas - gasleft();
        console2.log("gas used with eth deposits:", gasUsedWithDeposits);

        printVariables("after processing send-ethers");
        assertTrue(
            LibDepositing.hashEthDeposits(meta.depositsProcessed)
                != emptyDepositsRoot
        );
        assertEq(meta.depositsProcessed.length, count);

        gas = gasleft();
        meta = proposeBlock(Alice, Bob, 1_000_000, 1024);
        uint256 gasUsedWithoutDeposits = gas - gasleft();

        console2.log("gas used without eth deposits:", gasUsedWithoutDeposits);

        uint256 gasPerEthDeposit =
            (gasUsedWithDeposits - gasUsedWithoutDeposits) / count;

        console2.log("gas per eth deposit:", gasPerEthDeposit);
        console2.log("ethDepositMaxCountPerBlock:", count);
    }

    /// @dev getCrossChainBlockHash tests
    function test_L1_getCrossChainBlockHash0() external {
        bytes32 genHash = L1.getCrossChainBlockHash(0);
        assertEq(GENESIS_BLOCK_HASH, genHash);

        // Not yet avail.
        assertEq(L1.getCrossChainBlockHash(1), bytes32(0));
    }

    /// @dev getCrossChainSignalRoot tests
    function test_L1_getCrossChainSignalRoot() external {
        uint64 count = 10;
        // Declare here so that block prop/prove/verif. can be used in 1 place
        TaikoData.BlockMetadata memory meta;
        bytes32 blockHash;
        bytes32 signalRoot;
        bytes32[] memory parentHashes = new bytes32[](count);
        parentHashes[0] = GENESIS_BLOCK_HASH;

        giveEthAndTko(Alice, 1e6 ether, 100_000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e7 ether, 100_000 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));

        // Bob is the staker / prover
        vm.prank(Bob, Bob);

        // Propose blocks
        for (uint64 blockId = 1; blockId < count; blockId++) {
            printVariables("before propose");
            meta = proposeBlock(Alice, Bob, 1_000_000, 1024);
            mine(5);

            blockHash = bytes32(1e10 + uint256(blockId));
            signalRoot = bytes32(1e9 + uint256(blockId));

            proveBlock(
                Bob, Bob, meta, parentHashes[blockId - 1], blockHash, signalRoot
            );

            vm.roll(block.number + 15 * 12);
            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            // Querying written blockhash
            assertEq(L1.getCrossChainBlockHash(blockId), blockHash);

            mine(5);
            parentHashes[blockId] = blockHash;
        }

        uint64 queriedBlockId = 1;
        bytes32 expectedSR = bytes32(1e9 + uint256(queriedBlockId));

        assertEq(expectedSR, L1.getCrossChainSignalRoot(queriedBlockId));

        // 2nd
        queriedBlockId = 2;
        expectedSR = bytes32(1e9 + uint256(queriedBlockId));
        assertEq(expectedSR, L1.getCrossChainSignalRoot(queriedBlockId));

        // Not found
        assertEq(bytes32(0), L1.getCrossChainSignalRoot((count + 1)));
    }

    function test_L1_deposit_hash_creation() external {
        giveEthAndTko(Zachary, 1e6 ether, 0);
        // uint96 minAmount = conf.ethDepositMinAmount;
        uint96 maxAmount = conf.ethDepositMaxAmount;

        // We need 8 depostis otherwise we are not processing them !
        giveEthAndTko(Alice, 1e6 ether, maxAmount + 1 ether);
        giveEthAndTko(Bob, 0, maxAmount + 1 ether);
        giveEthAndTko(Carol, 0, maxAmount + 1 ether);
        giveEthAndTko(David, 0, maxAmount + 1 ether);
        giveEthAndTko(Emma, 0, maxAmount + 1 ether);
        giveEthAndTko(Frank, 0, maxAmount + 1 ether);
        giveEthAndTko(Grace, 0, maxAmount + 1 ether);
        giveEthAndTko(Henry, 0, maxAmount + 1 ether);

        // So after this point we have 8 deposits
        vm.prank(Alice, Alice);
        L1.depositEtherToL2{ value: 1 ether }(address(0));
        vm.prank(Bob, Bob);
        L1.depositEtherToL2{ value: 2 ether }(address(0));
        vm.prank(Carol, Carol);
        L1.depositEtherToL2{ value: 3 ether }(address(0));
        vm.prank(David, David);
        L1.depositEtherToL2{ value: 4 ether }(address(0));
        vm.prank(Emma, Emma);
        L1.depositEtherToL2{ value: 5 ether }(address(0));
        vm.prank(Frank, Frank);
        L1.depositEtherToL2{ value: 6 ether }(address(0));
        vm.prank(Grace, Grace);
        L1.depositEtherToL2{ value: 7 ether }(address(0));
        vm.prank(Henry, Henry);
        L1.depositEtherToL2{ value: 8 ether }(address(0));

        assertEq(L1.getStateVariables().numEthDeposits, 8); // The number of
            // deposits
        assertEq(L1.getStateVariables().nextEthDepositToProcess, 0); // The
            // index / cursos of the next deposit

        // We shall invoke proposeBlock() because this is what will call the
        // processDeposits()
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, Zachary, 1_000_000, 1024);

        // Expected:
        // 0x41c71a2af0eaa668a1241d7e1b09ac30d0e9ea6b6eb4a5a151029e87158d46f3  (pre
        // calculated with these values)
        //console2.logBytes32(meta.depositsRoot);
        assertEq(
            LibDepositing.hashEthDeposits(meta.depositsProcessed),
            0x41c71a2af0eaa668a1241d7e1b09ac30d0e9ea6b6eb4a5a151029e87158d46f3
        );
    }
}
