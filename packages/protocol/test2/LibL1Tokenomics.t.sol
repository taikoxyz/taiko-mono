// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.sol";

contract TaikoL1WithConfig is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.enableTokenomics = true;
        config.constantFeeRewardBlocks = 0;
        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        // this value must be changed if `maxNumProposedBlocks` is changed.
        config.slotSmoothingFactor = 4160;

        config.proposingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 1024,
            dampingFactorBips: 5000
        });

        config.provingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 1024,
            dampingFactorBips: 5000
        });
    }
}

// Since the fee/reward calculation heavily depends on the baseFeeProof and the proofTime
// we need to simulate proposing/proving so that can calculate them.
contract LibL1TokenomicsTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithConfig();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();

        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);
    }

    /// @dev Test blockFee for first block
    function test_getBlockFee() external {
        uint32 gasLimit = 10000000;
        uint256 fee = L1.getBlockFee(gasLimit);

        // First block propoal has a symbolic 1 unit of baseFeeProof so here gasLimit and fee shall be equal
        assertEq(gasLimit, fee);
    }

    /// @dev Test what happens when proof time increases
    function test_reward_and_fee_if_proof_time_increases() external {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            printVariables("after propose");
            mine(blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test what happens when proof time decreases
    function test_reward_and_fee_if_proof_time_decreases() external {
        mine(1);
        _depositTaikoToken(Alice, 1E7 * 1E8, 1 ether);
        _depositTaikoToken(Bob, 1E7 * 1E8, 1 ether);
        _depositTaikoToken(Carol, 1E7 * 1E8, 1 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(11 - blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            printVariables("after proved");
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test what happens when proof time stable
    function test_reward_and_fee_if_proof_time_stable_and_below_time_target()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test blockFee when proof target is stable but slightly above the target
    function test_reward_and_fee_if_proof_time_stable_but_above_time_target()
        external
    {
        uint32 gasLimit = 10000000;
        uint256 fee = L1.getBlockFee(gasLimit);

        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 50; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            //Constant 5 means = 100 sec (90 sec is the target)
            mine(5);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        // First block propoal has a symbolic 1 unit of baseFeeProof so here gasLimit and fee shall be equal
        assertEq(gasLimit, fee);
    }

    /// @dev Test what happens when proof time decreasing then stabilizes
    function test_reward_and_fee_if_proof_time_decreasing_then_stabilizes()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        console2.log("Decreasing");
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(21 - blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        console2.log("Stable");
        for (uint256 blockId = 1; blockId < 40; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        uint256 Alice_end_balance = L1.getBalance(Alice);
        uint256 Bob_end_balance = L1.getBalance(Bob);

        console2.log("Alice balance:", Alice_end_balance);
        console2.log("Bob balance:", Bob_end_balance);

        // Now we need to check if Alice's balance changed (not 100% same but approx.) with the same amount
        // We know that Alice spent while Bob gets the rewards so no need to check for underflow for the sake of this test
        uint256 aliceChange = Alice_start_balance - Alice_end_balance;
        uint256 bobChange = Bob_end_balance - Bob_start_balance;

        console2.log("Alice change:", aliceChange);
        console2.log("Bob change:", bobChange);

        // Assert their balance changed relatively the same way
        // 1e18 == within 100 % delta -> 1e17 10%, let's see if this is within that range
        assertApproxEqRel(aliceChange, bobChange, 1e17);
    }

    /// @dev Test what happens when proof time increasing then stabilizes
    function test_reward_and_fee_if_proof_time_increasing_then_stabilizes_below_the_proof_time_target()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        console2.log("Increasing");
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        console2.log("Stable");
        for (uint256 blockId = 1; blockId < 40; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        uint256 Alice_end_balance = L1.getBalance(Alice);
        uint256 Bob_end_balance = L1.getBalance(Bob);

        console2.log("Alice balance:", Alice_end_balance);
        console2.log("Bob balance:", Bob_end_balance);

        // Now we need to check if Alice's balance changed (not 100% same but approx.) with the same amount
        // We know that Alice spent while Bob gets the rewards so no need to check for underflow for the sake of this test
        uint256 aliceChange = Alice_start_balance - Alice_end_balance;
        uint256 bobChange = Bob_end_balance - Bob_start_balance;

        console2.log("Alice change:", aliceChange);
        console2.log("Bob change:", bobChange);

        // Assert their balance changed relatively the same way
        // 1e18 == within 100 % delta -> 1e17 10%, let's see if this is within that range
        assertApproxEqRel(aliceChange, bobChange, 1e17);
    }

    /// @dev Test what happens when proof time fluctuates then stabilizes
    function test_reward_and_fee_if_proof_time_fluctuates_then_stabilizes()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E7 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E7 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        console2.log("Increasing");
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        console2.log("Decreasing");
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(21 - blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        console2.log("Stable");
        for (uint256 blockId = 1; blockId < 40; blockId++) {
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }

        uint256 Alice_end_balance = L1.getBalance(Alice);
        uint256 Bob_end_balance = L1.getBalance(Bob);

        console2.log("Alice balance:", Alice_end_balance);
        console2.log("Bob balance:", Bob_end_balance);

        // Now we need to check if Alice's balance changed (not 100% same but approx.) with the same amount
        // We know that Alice spent while Bob gets the rewards so no need to check for underflow for the sake of this test
        uint256 aliceChange = Alice_start_balance - Alice_end_balance;
        uint256 bobChange = Bob_end_balance - Bob_start_balance;

        console2.log("Alice change:", aliceChange);
        console2.log("Bob change:", bobChange);

        // Assert their balance changed relatively the same way
        // 1e18 == within 100 % delta -> 1e17 10%, let's see if this is within that range
        assertApproxEqRel(aliceChange, bobChange, 1e17);
    }

    /// @dev Test blockFee start decreasing when the proof time goes below proof target (given gas used is the same)
    function test_getBlockFee_is_higher_when_increasing_proof_time() external {
        uint32 gasLimit = 10000000;
        uint256 previousfee = L1.getBlockFee(gasLimit);
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            uint256 previousFee = L1.getBlockFee(gasLimit);
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
            uint256 actualFee = L1.getBlockFee(gasLimit);
            // Check that fee always increasing in this scenario
            assertGt(actualFee, previousFee);
        }
        printVariables("");
    }

    /// @dev Test blockFee starts decreasing when the proof time goes below proof target
    function test_getBlockFee_starts_decreasing_when_proof_time_falls_below_the_average()
        external
    {
        uint32 gasLimit = 10000000;
        uint256 fee = L1.getBlockFee(gasLimit);
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId;
        uint256 previousFee;
        uint256 actualFee;

        for (blockId = 1; blockId < 10; blockId++) {
            previousFee = L1.getBlockFee(gasLimit);
            printVariables(
                "before proposing - affected by verification (verifyBlock() updates)"
            );
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(50 - blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;

            actualFee = L1.getBlockFee(gasLimit);
            // Check that fee always increasing in this scenario
            assertGt(actualFee, previousFee);
        }

        // Start proving below proof time - will affect the next proposal only after
        mine(1);
        previousFee = L1.getBlockFee(gasLimit);
        printVariables("See still higher");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
        mine(1);

        bytes32 blockHash = bytes32(1E10 + blockId);
        bytes32 signalRoot = bytes32(1E9 + blockId);
        proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
        //After this verification - the proof time falls below the target average, so it will start decreasing
        verifyBlock(Carol, 1);

        actualFee = L1.getBlockFee(gasLimit);
        assertGt(previousFee, actualFee);
    }
}
