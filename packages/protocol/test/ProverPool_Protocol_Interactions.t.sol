// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibUtils } from "../contracts/L1/libs/LibUtils.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { ProverPool } from "../contracts/L1/ProverPool.sol";
import { TaikoErrors } from "../contracts/L1/TaikoErrors.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.t.sol";

contract TaikoL1ProverPoolTests is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.blockTxListExpiry = 5 minutes;
        config.blockMaxVerificationsPerTx = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 12;
        config.proofRegularCooldown = 15 minutes;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1ProverPool is TaikoL1TestBase {
    ProverPool public realProverPool;
    // The additional ones for proving - needs more than 32
    address public Ivy = 0x200708D76EB1b69761C23821809D53f65049938E;
    address public Iris = 0x200708d76eb1b69761C23821809d53F65049769e;
    address public John = 0x300C9B60E19634e12Fc6D68b7FeA7bFB26c23419;
    address public Jude = 0x300c9B60e19634E12Fc6D68B7fEa7Bfb26C26619;
    address public Kai = 0x400147C0EB43d8D71b2B03037bb7b31F8F78EA2f;
    address public Khloe = 0x400147C0EB43d8D71b2b03037bb7B31f8F7a3F5F;
    address public Luca = 0x50081b12838240B1Ba02b3177153bCA678A86a58;
    address public Lucy = 0x50081b12838240B1bA02B3177153BcA67a860A68;
    address public Mia = 0x430C9b60e19634e12fc6d687fea7bFb26C2e41A7;
    address public Mila = 0x430C9b60e19634e12FC6d8b7FEA7BfB26C2e4a89;
    address public Nora = 0x520147C0eb43D8D71B2b03037bb7b31f8F78eF5b;
    address public Ned = 0x520147c0eb43d8D71B2b03037BB7b31F8F78ef5c;
    address public Olivia = 0x61081b12838240b1Ba02B3177153BCA678a8b478;
    address public Ollie = 0x61081B12838240a1a302B3177153BCA678a8b478;
    address public Paris = 0x200708D76eb1b69761C23821809D53F65049b59e;
    address public Paige = 0x200708D76EB1B69761c23821809d53F65049B69e;
    address public Quincy = 0x300c9b60E19634e12FC6D68b7FEa7bfb26CB7419;
    address public Quinn = 0x300c9B60E19634e12FC6D68B7fEA7BFb26c2b819;
    address public Ryan = 0x400147C0Eb43D8d71B2b03037Bb7b31f8F78Eb9f;
    address public Reynolds = 0x400147c0eB43d8d71b2B03037BB7B31F8b18eF5f;
    address public Sarah = 0x50081B12838240B1Ba02b317713bcA678Ab26078;
    address public Sky = 0x5001B12838240b1BA02b3177153bCa67b3A86078;
    address public Theo = 0x430C9b60E19634e12fC6d68B7FeA7bFbc1c2e419;
    address public Tod = 0x430c9B60E19634E12fC6D68B7feA7BFb2c32E419;
    address public Uma = 0x520147C0eb43D8d71B2b03037bB7b31F8C48Ef5F;
    address public Ulani = 0x520147c0Eb43D8D71b2b03037Bb7B31C5f78Ef5f;
    address public Vera = 0x61081B12838240b1ba02B3177153Bca6c6a86078;
    address public Vida = 0x61081b12838240b1ba02b3177153Bca6c7a86078;
    address public Wanda = 0x50081B12838240B1BA02b3177153BcaC88a86078;
    address public Wyatt = 0x50081b12838240b1Ba02B3177153bCac98A86078;
    address public Xia = 0x430c9B60E19634E12fc6d68B7fea7Bfb2d12e419;
    address public Xenia = 0x430c9B60e19634e12fC6D68b7FEa7BFD26C2E419;
    address public Yara = 0x520147c0Eb43d8d71B2b03037Bb7b31fD378eF5f;
    address public Yue = 0x520147C0EB43d8D71b2b03037bB7b31f8D48EF5F;
    address public Zoe = 0x61081b12838240b1Ba02b3177153bCa67D586078;
    address public Zuri = 0x61081B12838240b1Ba02B3177153bCA6D6A86078;

    mapping(uint8 id => string name) idToNames;

    address[36] public proverArray;

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1ProverPoolTests();
        proverArray[0] = Ivy;
        proverArray[1] = Iris;
        proverArray[2] = John;
        proverArray[3] = Jude;
        proverArray[4] = Kai;
        proverArray[5] = Khloe;
        proverArray[6] = Luca;
        proverArray[7] = Lucy;
        proverArray[8] = Mia;
        proverArray[9] = Mila;
        proverArray[10] = Nora;
        proverArray[11] = Ned;
        proverArray[12] = Olivia;
        proverArray[13] = Ollie;
        proverArray[14] = Paris;
        proverArray[15] = Paige;
        proverArray[16] = Quincy;
        proverArray[17] = Quinn;
        proverArray[18] = Ryan;
        proverArray[19] = Reynolds;
        proverArray[20] = Sarah;
        proverArray[21] = Sky;
        proverArray[22] = Theo;
        proverArray[23] = Tod;
        proverArray[24] = Uma;
        proverArray[25] = Ulani;
        proverArray[26] = Vera;
        proverArray[27] = Vida;
        proverArray[28] = Wanda;
        proverArray[29] = Wyatt;
        proverArray[30] = Xia;
        proverArray[31] = Xenia;
        proverArray[32] = Yara;
        proverArray[33] = Yue;
        proverArray[34] = Zoe;
        proverArray[35] = Zuri;

        idToNames[0] = "Ivy";
        idToNames[1] = "Iris";
        idToNames[2] = "John";
        idToNames[3] = "Jude";
        idToNames[4] = "Kai";
        idToNames[5] = "Khloe";
        idToNames[6] = "Luca";
        idToNames[7] = "Lucy";
        idToNames[8] = "Mia";
        idToNames[9] = "Mila";
        idToNames[10] = "Nora";
        idToNames[11] = "Ned";
        idToNames[12] = "Olivia";
        idToNames[13] = "Ollie";
        idToNames[14] = "Paris";
        idToNames[15] = "Paige";
        idToNames[16] = "Quincy";
        idToNames[17] = "Quinn";
        idToNames[18] = "Ryan";
        idToNames[19] = "Reynolds";
        idToNames[20] = "Sarah";
        idToNames[21] = "Sky";
        idToNames[22] = "Theo";
        idToNames[23] = "Tod";
        idToNames[24] = "Uma";
        idToNames[25] = "Ulani";
        idToNames[26] = "Vera";
        idToNames[27] = "Vida";
        idToNames[28] = "Wanda";
        idToNames[29] = "Wyatt";
        idToNames[30] = "Xia";
        idToNames[31] = "Xenia";
        idToNames[32] = "Yara";
        idToNames[33] = "Yue";
        idToNames[34] = "Zoe";
        idToNames[35] = "Zuri";
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        registerAddress(L1.getVerifierName(100), address(new Verifier()));
        realProverPool = new ProverPool();
        realProverPool.init(address(addressManager));
        registerAddress("prover_pool", address(realProverPool));

        for (uint256 index; index < proverArray.length; index++) {
            //Deposit Taiko token to all
            depositTaikoToken(proverArray[index], 1e7 * 1e8, 100 ether);
            console2.log(
                "proverArray[",
                index,
                "] balance:",
                tko.balanceOf(proverArray[index])
            );
        }
    }

    // The function will stake incrementally
    function stakeProversIncreasingOrder() public {
        // According to this Xenia will have the most chance to prove
        // and Ivy the least
        // 32 slots we have
        for (uint256 index; index < 32; index++) {
            vm.prank(proverArray[index], proverArray[index]);
            realProverPool.stake(uint64(index + 1) * 1e8, 10, 128);
        }
    }

    // The function will stake incrementally
    function stakeButOnly5Provers() public {
        // According to this Xenia will have the most chance to prove
        // and Ivy the least
        // 32 slots we have
        for (uint256 index; index < 5; index++) {
            vm.prank(proverArray[index], proverArray[index]);
            realProverPool.stake(uint64(index + 1) * 1e8, 10, 128);
        }
    }

    function getNameFromAddress(address prover)
        public
        view
        returns (string memory retVal)
    {
        retVal = "0x0";
        for (uint8 index; index < proverArray.length; index++) {
            if (proverArray[index] == prover) {
                return idToNames[index];
            }
        }
    }

    function test_asigned_prover_distribution_if_prover_pool_is_full()
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        stakeProversIncreasingOrder();

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 9; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                prover,
                prover,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;

            console2.log("gasLeft:", gasleft());
        }
        printVariables("");
    }

    function test_asigned_prover_distribution_if_only_have_1_prover()
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        vm.prank(Ivy, Ivy);
        realProverPool.stake(uint64(2) * 1e8, 10, 128);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 9; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Ivy,
                Ivy,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;

            console2.log("gasLeft:", gasleft());
        }
        printVariables("");
    }

    function test_everyone_can_prove_if_there_are_no_stakers() public {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 9; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            if (blockId % 2 == 0) {
                proveBlock(
                    Ivy,
                    Ivy,
                    meta,
                    parentHash,
                    parentGasUsed,
                    gasUsed,
                    blockHash,
                    signalRoot
                );
            } else {
                proveBlock(
                    Zoe,
                    Zoe,
                    meta,
                    parentHash,
                    parentGasUsed,
                    gasUsed,
                    blockHash,
                    signalRoot
                );
            }

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;

            console2.log("gasLeft:", gasleft());
        }
        printVariables("");
    }

    function test_asigned_prover_distribution_if_prover_pool_is_not_full()
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        stakeButOnly5Provers();

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 9; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                prover,
                prover,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;

            console2.log("gasLeft:", gasleft());
        }
        printVariables("");
    }

    function test_distribution_if_biggest_staker_exits_and_a_new_biggest_comes_in(
    )
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        stakeButOnly5Provers();

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 9; blockId++
        ) {
            if (blockId == (conf.blockMaxProposals * 9 / 2)) {
                // Kai is the top staker at this point
                vm.prank(Kai, Kai);
                realProverPool.stake(0, 0, 0);

                // Now Khloe will be the new top staker
                vm.prank(Khloe, Khloe);
                realProverPool.stake(uint64(6) * 1e8, 10, 128); // 6 * 1e8 is
                    // the biggest, Kai
                    // was 5 * 1e8
            }
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                prover,
                prover,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    function test_slashing_and_that_outside_proof_window_others_can_prove()
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        stakeButOnly5Provers();

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 1; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId

            // Wait long so will be slashed
            vm.warp(block.timestamp + 2 hours);
            (, ProverPool.Prover memory proverObjBeforeSlash) =
                realProverPool.getStaker(prover);

            //Outside the proof window others can submit proofs
            proveBlock(
                Zoe,
                Zoe,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + conf.proofRegularCooldown + 1);

            verifyBlock(Carol, 1);

            (, ProverPool.Prover memory proverObjAfterSlash) =
                realProverPool.getStaker(prover);

            assertTrue(
                proverObjAfterSlash.stakedAmount
                    < proverObjBeforeSlash.stakedAmount
            );

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    function test_others_cannot_prove_within_proof_window() external {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        stakeButOnly5Provers();

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        // Use multiplier 9 instead of 10, because we are at the edge of
        // gassing-out
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 1; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            (,,,,,,,, address prover,,) = L1.getBlock(blockId);
            console2.log("Prover address:", getNameFromAddress(prover));

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId

            // Wait long so will be slashed
            vm.warp(block.timestamp + 1 minutes);
            vm.expectRevert(TaikoErrors.L1_NOT_PROVEABLE.selector);
            proveBlock(
                Zoe,
                Zoe,
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
        printVariables("");
    }
}
