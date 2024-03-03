// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1_NoCooldown is TaikoL1 {
    function getConfig() public view override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        // over-write the following
        config.maxBlocksToVerifyPerProposal = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 12;
        config.livenessBond = 1e18; // 1 Taiko token
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Test is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(
                deployProxy({ name: "taiko", impl: address(new TaikoL1_NoCooldown()), data: "" })
            )
        );
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

        for (uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++) {
            //printVariables("before propose");
            (TaikoData.BlockMetadata memory meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);

            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider().getTier(minTier).cooldownWindow * 60 + 1);

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

        for (uint256 blockId = 1; blockId <= 20; ++blockId) {
            printVariables("before propose");
            (TaikoData.BlockMetadata memory meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Bob, Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);
            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider().getTier(minTier).cooldownWindow * 60 + 1);

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

        for (uint256 blockId = 1; blockId <= conf.blockMaxProposals; blockId++) {
            printVariables("before propose");
            (TaikoData.BlockMetadata memory meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Bob, Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            parentHash = blockHash;
        }

        vm.roll(block.number + 15 * 12);
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

        (TaikoData.SlotA memory a,) = L1.getStateVariables();

        assertEq(a.nextEthDepositToProcess, 0);
        assertEq(a.numEthDeposits, 0);
    }

    function test_L1_EthDepositsToL2Gas() external {
        vm.fee(25 gwei);

        bytes32 emptyDepositsRoot =
            0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;
        giveEthAndTko(Alice, 0, 100_000 ether);
        giveEthAndTko(Bob, 1e6 ether, 0);

        proposeBlock(Alice, Bob, 1_000_000, 1024);
        (, TaikoData.EthDeposit[] memory depositsProcessed) =
            proposeBlock(Alice, Bob, 1_000_000, 1024);
        assertEq(depositsProcessed.length, 0);

        uint256 count = conf.ethDepositMaxCountPerBlock;

        printVariables("before sending ethers");
        for (uint256 i; i < count; ++i) {
            vm.prank(Alice, Alice);
            L1.depositEtherToL2{ value: (i + 1) * 1 ether }(address(0));
        }
        printVariables("after sending ethers");

        uint256 gas = gasleft();
        TaikoData.BlockMetadata memory meta;
        (meta, depositsProcessed) = proposeBlock(Alice, Bob, 1_000_000, 1024);
        uint256 gasUsedWithDeposits = gas - gasleft();
        console2.log("gas used with eth deposits:", gasUsedWithDeposits);

        printVariables("after processing send-ethers");
        assertTrue(keccak256(abi.encode(depositsProcessed)) != emptyDepositsRoot);
        assertEq(depositsProcessed.length, count);

        gas = gasleft();
        (meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);
        uint256 gasUsedWithoutDeposits = gas - gasleft();

        console2.log("gas used without eth deposits:", gasUsedWithoutDeposits);

        uint256 gasPerEthDeposit = (gasUsedWithDeposits - gasUsedWithoutDeposits) / count;

        console2.log("gas per eth deposit:", gasPerEthDeposit);
        console2.log("ethDepositMaxCountPerBlock:", count);
    }

    function test_L1_deposit_hash_creation() external {
        giveEthAndTko(Bob, 1e6 ether, 100 ether);
        giveEthAndTko(Zachary, 1e6 ether, 0);
        // uint96 minAmount = conf.ethDepositMinAmount;
        uint96 maxAmount = conf.ethDepositMaxAmount;

        // We need 8 deposits otherwise we are not processing them !
        giveEthAndTko(Alice, 1e6 ether, maxAmount + 1 ether);
        giveEthAndTko(Bob, 1e6 ether, maxAmount + 1 ether);
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

        (TaikoData.SlotA memory a,) = L1.getStateVariables();

        // The number of deposits
        assertEq(a.numEthDeposits, 8);
        // The index / cursor of the next deposit
        assertEq(a.nextEthDepositToProcess, 0);

        // We shall invoke proposeBlock() because this is what will call the
        // processDeposits()
        (, TaikoData.EthDeposit[] memory depositsProcessed) =
            proposeBlock(Alice, Bob, 1_000_000, 1024);
        // Expected:
        // 0x3b61cf81fd007398a8efd07a055ac8fb542bcfa62d76cf6dc28a889371afb21e  (pre
        // calculated with these values)
        //console2.logBytes32(meta.depositsRoot);

        assertEq(
            keccak256(abi.encode(depositsProcessed)),
            0x3b61cf81fd007398a8efd07a055ac8fb542bcfa62d76cf6dc28a889371afb21e
        );
    }
}
