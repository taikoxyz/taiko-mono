// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibEthDepositing } from "../contracts/L1/libs/LibEthDepositing.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.t.sol";

contract TaikoL1_NoCooldown is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        config.proofCooldownPeriod = 0;
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
    /// 'maxNumProposedBlocks'
    function test_more_blocks_than_ring_buffer_size() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Carol, 1);
            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_multiple_blocks_in_one_L1_block() external {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (uint256 blockId = 1; blockId <= 2; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Alice,
                Alice,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );
            verifyBlock(Alice, 2);
            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test verifying multiple blocks in one transaction
    function test_verifying_multiple_blocks_once() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 1000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1; blockId <= conf.maxNumProposedBlocks; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Alice,
                Alice,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );
            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }

        verifyBlock(Alice, conf.maxNumProposedBlocks - 1);
        printVariables("after verify");
        verifyBlock(Alice, conf.maxNumProposedBlocks);
        printVariables("after verify");
    }

    function testEthDepositsToL2Reverts() external {
        uint96 minAmount = conf.ethDepositMinAmount;
        uint96 maxAmount = conf.ethDepositMaxAmount;

        depositTaikoToken(Alice, 0, maxAmount + 1 ether);

        vm.prank(Alice, Alice);
        vm.expectRevert();
        L1.depositEtherToL2{ value: minAmount - 1 }(address(0));

        vm.prank(Alice, Alice);
        vm.expectRevert();
        L1.depositEtherToL2{ value: maxAmount + 1 }(address(0));

        assertEq(L1.getStateVariables().nextEthDepositToProcess, 0);
        assertEq(L1.getStateVariables().numEthDeposits, 0);
    }

    function testEthDepositsToL2Gas() external {
        vm.fee(25 gwei);

        bytes32 emptyDepositsRoot =
            0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;
        depositTaikoToken(Alice, 1e6 * 1e8, 100_000 ether);

        proposeBlock(Alice, 1_000_000, 1024);
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, 1_000_000, 1024);
        assertEq(meta.depositsProcessed.length, 0);

        uint256 count = conf.ethDepositMaxCountPerBlock;

        printVariables("before sending ethers");
        for (uint256 i; i < count; ++i) {
            vm.prank(Alice, Alice);
            L1.depositEtherToL2{ value: (i + 1) * 1 ether }(address(0));
        }
        printVariables("after sending ethers");

        uint256 gas = gasleft();
        meta = proposeBlock(Alice, 1_000_000, 1024);
        uint256 gasUsedWithDeposits = gas - gasleft();
        console2.log("gas used with eth deposits:", gasUsedWithDeposits);

        printVariables("after processing send-ethers");
        assertTrue(
            LibEthDepositing.hashEthDeposits(meta.depositsProcessed)
                != emptyDepositsRoot
        );
        assertEq(meta.depositsProcessed.length, count);

        gas = gasleft();
        meta = proposeBlock(Alice, 1_000_000, 1024);
        uint256 gasUsedWithoutDeposits = gas - gasleft();

        console2.log("gas used without eth deposits:", gasUsedWithoutDeposits);

        uint256 gasPerEthDeposit =
            (gasUsedWithDeposits - gasUsedWithoutDeposits) / count;

        console2.log("gas per eth deposit:", gasPerEthDeposit);
        console2.log("ethDepositMaxCountPerBlock:", count);
    }

    /// @dev getCrossChainBlockHash tests
    function test_getCrossChainBlockHash0() external {
        bytes32 genHash = L1.getCrossChainBlockHash(0);
        assertEq(GENESIS_BLOCK_HASH, genHash);

        // Not yet avail.
        genHash = L1.getCrossChainBlockHash(1);
        assertEq(bytes32(0), genHash);
    }

    /// @dev getCrossChainSignalRoot tests
    function test_getCrossChainSignalRoot() external {
        uint256 iterationCnt = 10;
        // Declare here so that block prop/prove/verif. can be used in 1 place
        TaikoData.BlockMetadata memory meta;
        bytes32 blockHash;
        bytes32 signalRoot;
        bytes32[] memory parentHashes = new bytes32[](iterationCnt);
        parentHashes[0] = GENESIS_BLOCK_HASH;

        depositTaikoToken(Alice, 1e6 * 1e8, 100_000 ether);

        // Propose blocks
        for (uint256 blockId = 1; blockId < iterationCnt; blockId++) {
            //printVariables("before propose");
            meta = proposeBlock(Alice, 1_000_000, 1024);
            mine(5);

            blockHash = bytes32(1e10 + blockId);
            signalRoot = bytes32(1e9 + blockId);

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHashes[blockId - 1],
                blockId == 1 ? 0 : 1_000_000,
                1_000_000,
                blockHash,
                signalRoot
            );
            verifyBlock(Carol, 1);

            // Querying written blockhash
            bytes32 genHash = L1.getCrossChainBlockHash(blockId);
            assertEq(blockHash, genHash);

            mine(5);
            parentHashes[blockId] = blockHash;
        }

        // 1st
        uint256 queriedBlockId = 1;
        bytes32 expectedSR = bytes32(1e9 + queriedBlockId);

        assertEq(expectedSR, L1.getCrossChainSignalRoot(queriedBlockId));

        // 2nd
        queriedBlockId = 2;
        expectedSR = bytes32(1e9 + queriedBlockId);
        assertEq(expectedSR, L1.getCrossChainSignalRoot(queriedBlockId));

        // Not found
        assertEq(bytes32(0), L1.getCrossChainSignalRoot((iterationCnt + 1)));
    }

    function test_deposit_hash_creation() external {
        // uint96 minAmount = conf.ethDepositMinAmount;
        uint96 maxAmount = conf.ethDepositMaxAmount;

        // We need 8 depostis otherwise we are not processing them !
        depositTaikoToken(Alice, 1e6 * 1e8, maxAmount + 1 ether);
        depositTaikoToken(Bob, 0, maxAmount + 1 ether);
        depositTaikoToken(Carol, 0, maxAmount + 1 ether);
        depositTaikoToken(Dave, 0, maxAmount + 1 ether);
        depositTaikoToken(Eve, 0, maxAmount + 1 ether);
        depositTaikoToken(Frank, 0, maxAmount + 1 ether);
        depositTaikoToken(George, 0, maxAmount + 1 ether);
        depositTaikoToken(Hilbert, 0, maxAmount + 1 ether);

        // So after this point we have 8 deposits
        vm.prank(Alice, Alice);
        L1.depositEtherToL2{ value: 1 ether }(address(0));
        vm.prank(Bob, Bob);
        L1.depositEtherToL2{ value: 2 ether }(address(0));
        vm.prank(Carol, Carol);
        L1.depositEtherToL2{ value: 3 ether }(address(0));
        vm.prank(Dave, Dave);
        L1.depositEtherToL2{ value: 4 ether }(address(0));
        vm.prank(Eve, Eve);
        L1.depositEtherToL2{ value: 5 ether }(address(0));
        vm.prank(Frank, Frank);
        L1.depositEtherToL2{ value: 6 ether }(address(0));
        vm.prank(George, George);
        L1.depositEtherToL2{ value: 7 ether }(address(0));
        vm.prank(Hilbert, Hilbert);
        L1.depositEtherToL2{ value: 8 ether }(address(0));

        assertEq(L1.getStateVariables().numEthDeposits, 8); // The number of
            // deposits
        assertEq(L1.getStateVariables().nextEthDepositToProcess, 0); // The
            // index / cursos of the next deposit

        // We shall invoke proposeBlock() because this is what will call the
        // processDeposits()
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, 1_000_000, 1024);

        // Expected:
        // 0x60386add6a400d9b23968e1239bd600d22d2eea4709246895c0e5d8f5ae49dc3  (pre
        // calculated with these values)
        //console2.logBytes32(meta.depositsRoot);
        assertEq(
            LibEthDepositing.hashEthDeposits(meta.depositsProcessed),
            0x60386add6a400d9b23968e1239bd600d22d2eea4709246895c0e5d8f5ae49dc3
        );
    }
}
