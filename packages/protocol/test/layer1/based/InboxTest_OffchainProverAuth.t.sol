// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract InboxTest_OffchainProverAuth is InboxTestBase {
    using ECDSA for bytes32;

    uint256 constant PROVER_PRIVATE_KEY = 0x12345678;
    uint256 constant WRONG_PRIVATE_KEY = 0x98765432;
    address prover;
    address wrongSigner;

    function setUpOnEthereum() internal override {
        // Derive the prover address from the private key
        prover = vm.addr(PROVER_PRIVATE_KEY);
        wrongSigner = vm.addr(WRONG_PRIVATE_KEY);

        console2.log("Setting up Ethereum environment");
        // Deploy the base test contracts
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_proverAuth_validSignature() external transactBy(Alice) {
        bondToken.transfer(Alice, 10_000 ether);
        bondToken.transfer(prover, 5000 ether);

        // Create batch params
        ITaikoInbox.BatchParams memory batchParams;
        batchParams.blocks = new ITaikoInbox.BlockParams[](1);
        // We have to put together a batchParams.proposer = Alice, to match the has BUT before
        // sending it shall be erased from the batchParams.proposer cause of auto-fill!
        batchParams.proposer = Alice;

        // Deposit bond for both Alice and prover
        vm.startPrank(prover);

        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);

        vm.stopPrank();

        vm.startPrank(Alice);

        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);

        // Create a ProverAuth struct
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = 5 ether; // 5 TKO token fee
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 1; // Has to be known in advance (revert protection)

        // Calculate tx list hash
        bytes memory txList = abi.encodePacked("txList");
        bytes32 txListHash = keccak256(txList);

        // Get the current chain ID
        uint64 chainId = uint64(167_000);

        batchParams.coinbase = Alice;

        bytes32 batchParamsHash = keccak256(abi.encode(batchParams));
        batchParams.proposer = address(0);

        auth.signature = _signDigest(
            keccak256(
                abi.encode(
                    "PROVER_AUTHENTICATION",
                    chainId,
                    batchParamsHash,
                    txListHash,
                    _getAuthWithoutSignature(auth)
                )
            ),
            PROVER_PRIVATE_KEY
        );

        // Encode the auth for passing it to the contract
        batchParams.proverAuth = abi.encode(auth);

        // Execute the propose batch operation
        (, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

        // Verify prover was set correctly
        assertEq(meta.prover, auth.prover, "Prover should match");

        // Verify bond balances - prover should have livenessBond amount deducted but also credit
        // the fee added
        ITaikoInbox.Config memory config = v4GetConfig();
        // For prover, debit the livenessbond, but also credit the auth.fee at the same time
        uint256 expectedProverBond = 1000 ether - config.livenessBond + auth.fee;

        // Alice as proposer should have fee amount deducted
        uint256 expectedAliceBond = 1000 ether - auth.fee;

        assertEq(inbox.v4BondBalanceOf(prover), expectedProverBond, "Incorrect prover bond balance");
        assertEq(inbox.v4BondBalanceOf(Alice), expectedAliceBond, "Incorrect proposer bond balance");
    }

    function test_proverAuth_invalidSignature() external transactBy(Alice) {
        bondToken.transfer(Alice, 10_000 ether);
        bondToken.transfer(prover, 5000 ether);

        // Create batch params
        ITaikoInbox.BatchParams memory batchParams;
        batchParams.blocks = new ITaikoInbox.BlockParams[](1);
        batchParams.proposer = Alice;

        // Deposit bond for both Alice and prover
        vm.startPrank(prover);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);
        vm.stopPrank();

        vm.startPrank(Alice);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);

        // Create a ProverAuth struct
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = 5 ether;
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 1;

        // Calculate tx list hash
        bytes memory txList = abi.encodePacked("txList");
        bytes32 txListHash = keccak256(txList);

        // Get the current chain ID
        uint64 chainId = uint64(167_000);

        batchParams.coinbase = Alice;
        bytes32 batchParamsHash = keccak256(abi.encode(batchParams));
        batchParams.proposer = address(0);

        // Sign with wrong private key
        auth.signature = _signDigest(
            keccak256(
                abi.encode(
                    "PROVER_AUTHENTICATION",
                    chainId,
                    batchParamsHash,
                    txListHash,
                    _getAuthWithoutSignature(auth)
                )
            ),
            WRONG_PRIVATE_KEY
        );

        // Encode the auth for passing it to the contract
        batchParams.proverAuth = abi.encode(auth);

        // Expect revert due to invalid signature
        vm.expectRevert(LibProverAuth.InvalidSignature.selector);
        inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");
    }

    // Helper functions to create a valid signature
    function _signDigest(
        bytes32 _digest,
        uint256 _privateKey
    )
        internal
        pure
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, _digest);
        return abi.encodePacked(r, s, v);
    }

    // Helper to get auth struct without signature for proper digest calculation
    function _getAuthWithoutSignature(LibProverAuth.ProverAuth memory _auth)
        internal
        pure
        returns (LibProverAuth.ProverAuth memory)
    {
        LibProverAuth.ProverAuth memory authCopy = _auth;
        authCopy.signature = "";
        return authCopy;
    }
}
