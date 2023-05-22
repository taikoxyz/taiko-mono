// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Uncomment if you want to compare fee/vs reward
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/common/AddressManager.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";
import {LibLn} from "./LibLn.sol";

uint16 constant INITIAL_PROOF_TIME_TARGET = 120; //sec. Approx testnet scenario

contract TaikoL1WithTestnetConfig is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.proofCooldownPeriod = 0;
        config.maxNumProposedBlocks = 40;
        config.ringBufferSize = 48;
    }
}

// Testing the base "math" and directions if all is good
contract TaikoL1LibTokenomicsTestnet is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithTestnetConfig();
    }

    function setUp() public override {
        proofTimeTarget = INITIAL_PROOF_TIME_TARGET; // Approx. testnet value
        // Calculating it for our needs based on testnet/mainnet proof vars.
        // See Brecht's comment https://github.com/taikoxyz/taiko-mono/pull/13564
        initProofTimeIssued =
            LibLn.calcInitProofTimeIssued(feeBase, proofTimeTarget, ADJUSTMENT_QUOTIENT);

        TaikoL1TestBase.setUp();

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);
    }

    /// @dev Test what happens when proof time increases
    function test_balanced_state_reward_and_fee_if_proof_time_increases_slowly_then_drastically()
        external
    {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            mine(blockId);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);
            // This is where new fee evaluated
            printVariables("after verify");

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            mine_huge();

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlock(Bob, Bob, meta, parentHash, 1000000, 1000000, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));
            verifyBlock(Carol, 1);
            // This is where new fee evaluated
            printVariables("after verify");

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time hectic couple of proposes, without prove, then some proofs
    function test_balanced_state_reward_and_fee_if_proof_time_hectic() external {
        mine(1);
        //Needs lot of token here - because there is lots of time elapsed between 2 'propose' blocks, which will raise the fee
        depositTaikoToken(Alice, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e8 * 1e8, 100 ether);

        TaikoData.BlockMetadata[] memory metas = new TaikoData.BlockMetadata[](
            20
        );
        uint64[] memory proposedAtArr = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks - but dont go above a certain iterationi count because the drastically increasing
        // proof time will be an issue
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            //printVariables("before propose");
            metas[blockId] = proposeBlock(Alice, 1000000, 1024);
            proposedAtArr[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                metas[blockId],
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAtArr[blockId]));

            verifyBlock(Carol, 1);

            printVariables("after verify");
            mine(blockId);
            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        // Run another iteration
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, 1000000, 1000000, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable below the target and proving consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_below_target_prooving_consecutive(
    ) external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(2);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable below the target and proving non consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_below_target_proving_non_consecutive(
    ) external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            30
        );
        uint64[] memory proposedAt = new uint64[](30);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1000000, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        //Prove and verify
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlock(
                Bob,
                Bob,
                meta[blockId],
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );

            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt[blockId]));

            verifyBlock(Carol, 1);

            mine(3);
            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreases() external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            20
        );
        uint64[] memory proposedAt = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1000000, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta[blockId],
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );

            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt[blockId]));

            verifyBlock(Carol, 1);
            mine(21 - blockId);
            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;
        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable above the target and proving consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_above_target_prooving_consecutive(
    ) external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(5);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable above the target and proving non consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_above_target_proving_non_consecutive(
    ) external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            30
        );
        uint64[] memory proposedAt = new uint64[](30);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose  blocks
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            //printVariables("before propose");
            meta[blockId] = proposeBlock(Alice, 1000000, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 30; blockId++) {
            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlock(
                Bob,
                Bob,
                meta[blockId],
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );

            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt[blockId]));

            verifyBlock(Carol, 1);
            mine(5);
            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreasses_then_stabilizes_consecutive(
    ) external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            printVariables("after propose");
            uint64 proposedAt = uint64(block.timestamp);
            mine(11 - blockId);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, 1000000, 1000000, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        assertEq(deposits, withdrawals);
    }

    /// @dev Test what happens when proof time decreases
    function test_balanced_state_reward_and_fee_if_proof_time_decreases_then_stabilizes_non_consecutive(
    ) external {
        mine(1);
        // Requires a bit more tokens
        depositTaikoToken(Alice, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e8 * 1e8, 100 ether);

        TaikoData.BlockMetadata[] memory metaArr = new TaikoData.BlockMetadata[](20);
        uint64[] memory proposedAtArr = new uint64[](20);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        // Propose blocks
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            //printVariables("before propose");
            metaArr[blockId] = proposeBlock(Alice, 1000000, 1024);
            proposedAtArr[blockId] = (uint64(block.timestamp));
            printVariables("after propose");
            mine(blockId);
        }

        // Wait random X
        mine(6);
        // Prove and verify
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                metaArr[blockId],
                parentHash,
                (blockId == 1 ? 0 : 1000000),
                1000000,
                blockHash,
                signalRoot
            );

            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAtArr[blockId]));

            verifyBlock(Carol, 1);
            mine(21 - blockId);
            parentHash = blockHash;
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, 1000000, 1000000, blockHash, signalRoot);
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances
        deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    /// @dev Test and see what happens when proof time is stable at the target and proving consecutive
    function test_balanced_state_reward_and_fee_if_proof_time_stable_consecutive() external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances

        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine_proofTime();

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    /// @dev Test a scenario which very close to a testnet behaviour
    function test_balanced_state_reward_and_fee_if_proof_time_stable_non_consecutive() external {
        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);

        // Need constants here and in loop counter to avoid stack too deep error
        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            200
        );
        uint64[] memory proposedAt = new uint64[](200);
        bytes32[] memory parentHashes = new bytes32[](200);
        bytes32[] memory blockHashes = new bytes32[](200);
        bytes32[] memory signalRoots = new bytes32[](200);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint8 proofTime = 10;
        console2.logBytes32(parentHash);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 150; blockId++) {
            {
                meta[blockId] = proposeBlock(Alice, 1000000, 1024);
                proposedAt[blockId] = (uint64(block.timestamp));
                printVariables("after propose");

                blockHashes[blockId] = bytes32(1e10 + blockId); //blockHash;
                signalRoots[blockId] = bytes32(1e9 + blockId); //signalRoot;

                if (blockId > proofTime) {
                    //Start proving with an offset
                    proveBlock(
                        Bob,
                        Bob,
                        meta[blockId - proofTime],
                        parentHashes[blockId - proofTime],
                        (blockId - proofTime == 1) ? 0 : 1000000,
                        1000000,
                        blockHashes[blockId - proofTime],
                        signalRoots[blockId - proofTime]
                    );

                    uint64 provenAt = uint64(block.timestamp);
                    console2.log(
                        "Proof reward is:",
                        L1.getProofReward(provenAt - proposedAt[blockId - proofTime])
                    );
                }

                mine_every_12_sec();

                parentHashes[blockId] = parentHash;
                parentHash = blockHashes[blockId];
                verifyBlock(Carol, 1);
            }
        }
        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        //Check end balances
        deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);
        // Assert their balance changed relatively the same way
        // 1e18 == within 100 % delta -> 1e17 10%, let's see if this is within that range
        assertApproxEqRel(deposits, withdrawals, 1e17);
    }

    /// @dev Test if testing proof time params works (changes) as expected
    function test_changing_proof_time_parameters() external {
        mine(1);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        // Check balances
        uint256 Alice_start_balance = L1.getTaikoTokenBalance(Alice);
        uint256 Bob_start_balance = L1.getTaikoTokenBalance(Bob);
        console2.log("Alice balance:", Alice_start_balance);
        console2.log("Bob balance:", Bob_start_balance);

        //parentHash = prove_with_increasing_time(parentHash, 10);
        for (uint256 blockId = 1; blockId < 20; blockId++) {
            // See if proof reward decreases faster than usual
            if (blockId == 8) {
                // 500 sec has the proofTimeIssued of 219263 (Calculated with 'forge script script/DetermineNewProofTimeIssued.s.sol')
                L1.setProofParams(500, 219263);
            }

            // See if proof reward increases now
            if (blockId == 15) {
                // 10 sec has the proofTimeIssued of 3759 (Calculated with 'forge script script/DetermineNewProofTimeIssued.s.sol')
                L1.setProofParams(10, 3759);
            }

            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            uint64 proposedAt = uint64(block.timestamp);
            printVariables("after propose");
            mine(5);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockId == 1 ? 0 : 1000000,
                1000000,
                blockHash,
                signalRoot
            );
            uint64 provenAt = uint64(block.timestamp);
            console2.log("Proof reward is:", L1.getProofReward(provenAt - proposedAt));

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }

        //Check end balances

        uint256 deposits = Alice_start_balance - L1.getTaikoTokenBalance(Alice);
        uint256 withdrawals = L1.getTaikoTokenBalance(Bob) - Bob_start_balance;

        console2.log("Deposits:", deposits);
        console2.log("withdrawals:", withdrawals);

        assertEq(deposits, withdrawals);
    }

    function mine_huge() internal {
        vm.warp(block.timestamp + 1200);
        vm.roll(block.number + 300);
    }

    function mine_every_12_sec() internal {
        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);
    }

    function mine_proofTime() internal {
        vm.warp(block.timestamp + 120);
        vm.roll(block.number + 5);
    }
}
