// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NonBondToken is ERC20 {
    constructor() ERC20("Test Token", "TST") {
        _mint(msg.sender, 1_000_000 * 10 ** 18); // Mint 1 million tokens
    }
}

contract InboxTest_OffchainProverAuth is InboxTestBase {
    using ECDSA for bytes32;

    uint256 constant WRONG_PRIVATE_KEY = 0x98765432;
    address prover = vm.addr(PROVER_PRIVATE_KEY);

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_proverAuth_validSignature() external transactBy(Alice) {
        _distributeBonds();

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
        _distributeBonds();

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

    function test_proverAuth_invalidBatchId() external transactBy(Alice) {
        _distributeBonds();

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

        // Create a ProverAuth struct with incorrect batchId
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = 5 ether;
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 999; // Incorrect batchId

        // Calculate tx list hash
        bytes memory txList = abi.encodePacked("txList");
        bytes32 txListHash = keccak256(txList);

        // Get the current chain ID
        uint64 chainId = uint64(167_000);

        batchParams.coinbase = Alice;
        bytes32 batchParamsHash = keccak256(abi.encode(batchParams));
        batchParams.proposer = address(0);

        // Sign the digest
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

        // Expect revert due to invalid batchId
        vm.expectRevert(LibProverAuth.InvalidBatchId.selector);
        inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");
    }

    function test_proverAuth_expiredValidUntil() external transactBy(Alice) {
        _distributeBonds();

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

        // Create a ProverAuth struct with expired validUntil
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = 5 ether;
        auth.validUntil = uint64(block.timestamp - 1); // Expired timestamp
        auth.batchId = 1;

        // Calculate tx list hash
        bytes memory txList = abi.encodePacked("txList");
        bytes32 txListHash = keccak256(txList);

        // Get the current chain ID
        uint64 chainId = uint64(167_000);

        batchParams.coinbase = Alice;
        bytes32 batchParamsHash = keccak256(abi.encode(batchParams));
        batchParams.proposer = address(0);

        // Sign the digest
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

        // Expect revert due to expired validUntil
        vm.expectRevert(LibProverAuth.InvalidValidUntil.selector);
        inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");
    }

    function test_proverAuth_zeroAddressProver() external transactBy(Alice) {
        _distributeBonds();

        // Create batch params
        ITaikoInbox.BatchParams memory batchParams;
        batchParams.blocks = new ITaikoInbox.BlockParams[](1);
        batchParams.proposer = Alice;
        batchParams.coinbase = Alice;

        vm.startPrank(Alice);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);

        // Create a ProverAuth struct with zero address
        LibProverAuth.ProverAuth memory auth;
        auth.prover = address(0); // Zero address
        auth.feeToken = address(bondToken);
        auth.fee = 5 ether;
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 1;

        // Create a dummy signature
        auth.signature = bytes("dummy");
        batchParams.proposer = address(0);

        // Encode the auth for passing it to the contract
        batchParams.proverAuth = abi.encode(auth);

        // Expect revert due to zero address prover
        vm.expectRevert(LibProverAuth.InvalidProver.selector);
        inbox.v4ProposeBatch(abi.encode(batchParams), abi.encodePacked("txList"), "");
    }

    function test_proverAuth_etherAsFeeToken() external transactBy(Alice) {
        _distributeBonds();

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

        // Create a ProverAuth struct with ETH as fee token
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(0); // ETH address
        auth.fee = 5 ether;
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 1;

        // Create a dummy signature
        auth.signature = bytes("dummy");

        // Calculate and set params hash
        batchParams.coinbase = Alice;
        batchParams.proposer = address(0);

        // Encode the auth for passing it to the contract
        batchParams.proverAuth = abi.encode(auth);

        // Expect revert due to ETH as fee token
        vm.expectRevert(LibProverAuth.EtherAsFeeTokenNotSupportedYet.selector);
        inbox.v4ProposeBatch(abi.encode(batchParams), abi.encodePacked("txList"), "");
    }

    function test_proverAuth_feeGreaterThanLivenessBond() external transactBy(Alice) {
        ITaikoInbox.Config memory config = v4GetConfig();
        uint96 feeLargerThanBond = uint96(config.livenessBond + 10 ether);

        _distributeBonds();

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

        // Create a ProverAuth struct with fee greater than liveness bond
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = feeLargerThanBond;
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

        // Sign the digest
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

        // Record initial bond balances
        uint256 aliceInitialBond = inbox.v4BondBalanceOf(Alice);
        uint256 proverInitialBond = inbox.v4BondBalanceOf(prover);

        // Execute the propose batch operation
        (, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

        // Verify prover was set correctly
        assertEq(meta.prover, auth.prover, "Prover should match");

        // Verify bond balances
        // Prover: initial balance - livenessBond + fee
        uint256 expectedProverBond = proverInitialBond + (feeLargerThanBond - config.livenessBond);
        // Alice: initial balance - fee
        uint256 expectedAliceBond = aliceInitialBond - feeLargerThanBond;

        assertEq(inbox.v4BondBalanceOf(prover), expectedProverBond, "Incorrect prover bond balance");
        assertEq(inbox.v4BondBalanceOf(Alice), expectedAliceBond, "Incorrect proposer bond balance");
    }

    function test_proverAuth_feeSmallerThanLivenessBond() external transactBy(Alice) {
        ITaikoInbox.Config memory config = v4GetConfig();
        uint96 feeSmallerThanBond = uint96(config.livenessBond - 10 ether);

        _distributeBonds();

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

        // Create a ProverAuth struct with fee smaller than liveness bond
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(bondToken);
        auth.fee = feeSmallerThanBond;
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

        // Sign the digest
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

        // Record initial bond balances
        uint256 aliceInitialBond = inbox.v4BondBalanceOf(Alice);
        uint256 proverInitialBond = inbox.v4BondBalanceOf(prover);

        // Execute the propose batch operation
        (, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

        // Verify prover was set correctly
        assertEq(meta.prover, auth.prover, "Prover should match");

        // Verify bond balances
        // Prover needs to pay the difference between livenessBond and fee
        uint256 expectedProverBond = proverInitialBond - (config.livenessBond - feeSmallerThanBond);
        // Alice pays the fee
        uint256 expectedAliceBond = aliceInitialBond - feeSmallerThanBond;

        assertEq(inbox.v4BondBalanceOf(prover), expectedProverBond, "Incorrect prover bond balance");
        assertEq(inbox.v4BondBalanceOf(Alice), expectedAliceBond, "Incorrect proposer bond balance");
    }

    function test_proverAuth_differentFeeToken() external transactBy(Alice) {
        // Deploy an ERC20 token to use as fee token
        NonBondToken differentFeeToken = new NonBondToken();

        // Fund accounts with bond tokens
        require(bondToken.transfer(Alice, 10_000 ether), "Transfer failed");
        require(bondToken.transfer(prover, 5000 ether), "Transfer failed");

        // Fund Alice with the different fee token
        require(differentFeeToken.transfer(Alice, 10_000 ether), "Transfer failed");

        // Create batch params
        ITaikoInbox.BatchParams memory batchParams;
        batchParams.blocks = new ITaikoInbox.BlockParams[](1);
        batchParams.proposer = Alice;

        // Deposit bond for both Alice and prover (using bond token)
        vm.startPrank(prover);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);
        vm.stopPrank();

        vm.startPrank(Alice);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.v4DepositBond(1000 ether);

        // Approve the different fee token for the inbox to spend
        differentFeeToken.approve(address(inbox), type(uint256).max);

        // Create a ProverAuth struct using the different fee token
        LibProverAuth.ProverAuth memory auth;
        auth.prover = prover;
        auth.feeToken = address(differentFeeToken);
        auth.fee = 5 ether; // 5 tokens fee
        auth.validUntil = uint64(block.timestamp + 1 hours);
        auth.batchId = 1; // Has to be known in advance (revert protection)

        // Calculate tx list hash
        bytes memory txList = abi.encodePacked("txList");
        bytes32 txListHash = keccak256(txList);

        // Get the current chain ID
        uint64 chainId = uint64(167_000);

        batchParams.coinbase = Alice;

        // Calculate hash with Alice as proposer for signature
        bytes32 batchParamsHash = keccak256(abi.encode(batchParams));

        // Now set proposer to address(0) as the contract expects
        batchParams.proposer = address(0);

        // Sign the digest
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

        // Check balances before
        uint256 aliceInitialBond = inbox.v4BondBalanceOf(Alice);
        uint256 proverInitialBond = inbox.v4BondBalanceOf(prover);
        uint256 aliceInitialDifferentToken = differentFeeToken.balanceOf(Alice);
        uint256 proverInitialDifferentToken = differentFeeToken.balanceOf(prover);

        // Execute the propose batch operation
        (, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

        // Verify prover was set correctly
        assertEq(meta.prover, auth.prover, "Prover should match");

        // Verify bond balances
        ITaikoInbox.Config memory config = v4GetConfig();

        // For this case, prover should just have livenessBond deducted from bond balance
        uint256 expectedProverBond = proverInitialBond - config.livenessBond;

        // Alice bond balance should remain unchanged since fee is in different token
        uint256 expectedAliceBond = aliceInitialBond;

        assertEq(inbox.v4BondBalanceOf(prover), expectedProverBond, "Incorrect prover bond balance");
        assertEq(inbox.v4BondBalanceOf(Alice), expectedAliceBond, "Incorrect proposer bond balance");

        // The fee token should be transferred from Alice to the prover
        assertEq(
            differentFeeToken.balanceOf(Alice),
            aliceInitialDifferentToken - auth.fee,
            "Incorrect Alice fee token balance"
        );
        assertEq(
            differentFeeToken.balanceOf(prover),
            proverInitialDifferentToken + auth.fee,
            "Incorrect prover fee token balance"
        );
    }

    function _distributeBonds() internal {
        require(bondToken.transfer(Alice, 10_000 ether), "Transfer failed");
        require(bondToken.transfer(prover, 5000 ether), "Transfer failed");
    }
}
