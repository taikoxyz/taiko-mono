// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// Uncomment if you want to compare fee/vs reward
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";

contract TaikoL1WithNonMintingConfig is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
        config.maxNumProposedBlocks = 40;
        config.ringBufferSize = 48;
        config.allowMinting = false;
    }
}

// Since the fee/reward calculation heavily depends on the baseFeeProof and the proofTime
// we need to simulate proposing/proving so that can calculate them.
contract LibL1TokenomicsTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithNonMintingConfig();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();

        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);
    }

    /// @dev Test what happens when proof time increases
    function test_balanced_state_reward_and_fee_if_proof_time_increases_slowly_then_drastically()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_huge();

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time hectic couple of proposes, without prove, then some proofs
    function test_balanced_state_reward_and_fee_if_proof_time_hectic()
        external
    {
        mine(1);
        //Needs lot of token here - because there is lots of time elapsed between 2 'propose' blocks, which will raise the fee
        _depositTaikoToken(Alice, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E8 * 1E8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            20
        );
        uint64[] memory proposedAt = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta[blockId], parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt[blockId])
            );

            verifyBlock(Carol, 1);
            mine(blockId);
            parentHash = blockHash;
        }

        /// @dev Long term the sum of deposits / withdrawals converge towards the balance
        /// @dev The best way to assert this is to observ: the higher the loop counter
        /// @dev the smaller the difference between deposits / withrawals

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;
        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);

        // Run another sessioins
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable below the target and proving consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_below_target_prooving_consecutive()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(2);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable below the target and proving non consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_below_target_proving_non_consecutive()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            30
        );
        uint64[] memory proposedAt = new uint64[](30);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        //Prove and verify
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);

            proveBlock(Bob, meta[blockId], parentHash, blockHash, signalRoot);

            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt[blockId])
            );

            verifyBlock(Carol, 1);
            mine(3);
            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreases()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            20
        );
        uint64[] memory proposedAt = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta[blockId], parentHash, blockHash, signalRoot);

            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt[blockId])
            );

            verifyBlock(Carol, 1);
            mine(21 - blockId);
            parentHash = blockHash;
        }

        /// @dev Long term the sum of deposits / withdrawals converge towards the balance
        /// @dev The best way to assert this is to observ: the higher the loop counter
        /// @dev the smaller the difference between deposits / withrawals

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;
        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable above the target and proving consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_above_target_prooving_consecutive()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(5);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable above the target and proving non consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_above_target_proving_non_consecutive()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            30
        );
        uint64[] memory proposedAt = new uint64[](30);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose  blocks
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);

            proveBlock(Bob, meta[blockId], parentHash, blockHash, signalRoot);

            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt[blockId])
            );

            verifyBlock(Carol, 1);
            mine(5);
            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreasses_then_stabilizes_consecutive()
        external
    {
        mine(1);
        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            printVariables("after propose");
            uint64 proposedAt = uint64(block.timestamp);
            mine(11 - blockId);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreasses_then_stabilizes_non_consecutive()
        external
    {
        mine(1);
        // Requires a bit more tokens
        _depositTaikoToken(Alice, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E8 * 1E8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            20
        );
        uint64[] memory proposedAt = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta[blockId], parentHash, blockHash, signalRoot);

            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt[blockId])
            );

            verifyBlock(Carol, 1);
            mine(21 - blockId);
            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        console2.log(
            "Alice current balance after first iteration:",
            L1.getBalance(Alice)
        );
        console2.log(
            "Bob current balance after first iteration:",
            L1.getBalance(Bob)
        );
        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log(
                "Proof reward is:",
                L1.getProofReward(provenAt, proposedAt)
            );
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    function mine_huge() internal {
        vm.warp(block.timestamp + 1200);
        vm.roll(block.number + 300);
    }

    // Currently set to 85s proofTimeTarget
    function mine_proofTime() internal {
        vm.warp(block.timestamp + 85);
        vm.roll(block.number + 4);
    }
}
