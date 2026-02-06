// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./PreconfRouterTestBase.sol";
import "../mocks/MockBeaconBlockRoot.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "test/shared/ForkTestBase.sol";

contract PreconfRouterForkTest is ForkTestBase {
    // Mainnet contract addresses
    address constant MAINNET_ROUTER = 0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a;
    address constant MAINNET_INBOX = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    address constant MAINNET_WRAPPER = 0x9F9D2fC7abe74C79f86F0D1212107692430eef72;
    address constant MAINNET_WHITELIST = 0xFD019460881e6EeC632258222393d5821029b2ac;
    address constant MAINNET_FORCED_INCLUSION = 0x05d88855361808fA1d7fc28084Ef3fCa191c4e03;
    address constant PROOF_VERIFIER = 0xB16931e78d0cE3c9298bbEEf3b5e2276D34b8da1;
    address constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address constant SIGNAL_SERVICE = 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
    address constant OLD_FORK = 0x904Da4C5bD76f932fE09fF32Ae5D7E3d2A5D2264;
    address constant PROPOSER = 0x5F62d006C10C009ff50C878Cd6157aC861C99990;
    address constant FORK_ROUTER = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;

    // Fork configuration
    uint256 constant FORK_BLOCK = 23_147_260; // Block before tx
        // 0x2c65e26d179f301c8d5367e0e80c9f281bc208bdf77fb05677aace4f8b7bf3ee
    string constant TX_HASH = "0x2c65e26d179f301c8d5367e0e80c9f281bc208bdf77fb05677aace4f8b7bf3ee";

    function setUp() public override {
        _createMainnetFork(FORK_BLOCK);
        super.setUp();
    }

    function test_preconfRouter_proposeBatch_L1Calldata_forked() external requiresMainnetFork {
        _selectMainnetFork();

        // Verify fork block
        assertEq(block.number, FORK_BLOCK, "Fork not at expected block");

        // Read calldata from file (named after the transaction hash)
        bytes memory realCalldata = _readCalldataFromFile(string.concat(TX_HASH, ".txt"));
        (bytes memory params, bytes memory txList) = abi.decode(realCalldata, (bytes, bytes));

        // Setup blob hashes (2 blobs for this transaction)
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(1));
        blobHashes[1] = bytes32(uint256(2));
        vm.blobhashes(blobHashes);

        // Get contract owner for upgrades
        address owner = Ownable2StepUpgradeable(MAINNET_ROUTER).owner();

        // Deploy optimized implementations
        PreconfRouter routerImpl =
            new PreconfRouter(MAINNET_WRAPPER, MAINNET_WHITELIST, address(0), type(uint64).max);
        TaikoWrapper wrapperImpl =
            new TaikoWrapper(MAINNET_INBOX, MAINNET_FORCED_INCLUSION, MAINNET_ROUTER);
        address forkImpl =
            address(
                new MainnetInbox(
                    MAINNET_WRAPPER,
                    PROOF_VERIFIER,
                    TAIKO_TOKEN,
                    SIGNAL_SERVICE,
                    type(uint64).max
                )
            );
        address pacayaRouter = address(new PacayaForkRouter(OLD_FORK, forkImpl));

        // Upgrade contracts to optimized implementations
        vm.startPrank(owner);
        UUPSUpgradeable(MAINNET_ROUTER).upgradeTo(address(routerImpl));
        UUPSUpgradeable(MAINNET_WRAPPER).upgradeTo(address(wrapperImpl));
        UUPSUpgradeable(FORK_ROUTER).upgradeTo(pacayaRouter);
        vm.stopPrank();

        // Measure gas with actual mainnet calldata
        vm.startSnapshotGas("ProposeAndProve", "proposeBatchWithL1Calldata_Forked");

        // Execute as original proposer
        vm.prank(PROPOSER);
        (bool success,) = MAINNET_ROUTER.call(
            abi.encodeWithSignature("proposeBatch(bytes,bytes)", params, txList)
        );
        require(success, "proposeBatch failed");

        vm.stopSnapshotGas();
    }

    function _readCalldataFromFile(string memory filename) internal view returns (bytes memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/layer1/preconf/router/testdata/", filename);
        string memory fileContent = vm.readFile(path);
        return vm.parseBytes(fileContent);
    }
}

contract PreconfRouterTest is PreconfRouterTestBase {
    // Transaction hash constant for test data file
    string constant TX_HASH = "0x2c65e26d179f301c8d5367e0e80c9f281bc208bdf77fb05677aace4f8b7bf3ee";

    /// forge-config: default.isolate = true
    function test_preconfRouter_proposeBatch() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Carol with bond tokens
        vm.deal(Carol, 100 ether);
        bondToken.transfer(Carol, 1000 ether);
        vm.startPrank(Carol);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0, // First block must have timeShift = 0
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        blobParams.numBlobs = 1; // Required for normal batches
        blobParams.firstBlobIndex = 0;

        ITaikoInbox.BatchParams memory params;
        params.proposer = Carol;
        params.blobParams = blobParams;
        params.blocks = blockParams;

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // TaikoWrapper expects (bytes, bytes): first is forced inclusion, second is normal batch
        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        vm.startSnapshotGas("ProposeAndProve", "proposeBatchWithRouter");
        vm.prank(Carol);
        (ITaikoInbox.BatchMetadata memory meta,) = router.proposeBatch(wrappedParams, "");
        vm.stopSnapshotGas();

        assertEq(meta.proposer, Carol);
    }

    function test_preconfRouter_proposeBatch_notOperator() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // David is not the selected operator (Carol is)
        vm.prank(David);
        vm.expectRevert(IPreconfRouter.NotPreconferOrFallback.selector);
        router.proposeBatch("", "");
    }

    function test_preconfRouter_proposeBatch_proposerNotSender() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Bob with bond tokens
        vm.deal(Bob, 100 ether);
        bondToken.transfer(Bob, 1000 ether);
        vm.startPrank(Bob);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0,
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        blobParams.numBlobs = 1;
        blobParams.firstBlobIndex = 0;

        ITaikoInbox.BatchParams memory params;
        params.proposer = Bob; // Different from sender (Carol)
        params.blobParams = blobParams;
        params.blocks = blockParams;

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        // Carol is the selected operator but tries to propose with Bob as proposer
        vm.prank(Carol);
        vm.expectRevert(IPreconfRouter.ProposerIsNotPreconfer.selector);
        router.proposeBatch(wrappedParams, "");
    }

    function _setupMockBeacon(uint256 epochOneStart, MockBeaconBlockRoot mockBeacon) internal {
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol as operator
        vm.etch(LibPreconfConstants.getBeaconBlockRootContract(), address(mockBeacon).code);
        MockBeaconBlockRoot(payable(LibPreconfConstants.getBeaconBlockRootContract())).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );
    }
}
