// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/impl/InboxBase.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibDecoder.sol";
import "contracts/shared/based/libs/LibBondOperation.sol";
import "contracts/shared/based/iface/IBondManager.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title ShastaInboxTestBase
/// @notice Base contract for all Shasta Inbox tests providing common setup and helper functions
/// @dev Uses Foundry's testing features for mocking and stubbing dependencies
/// @dev Test scenarios covered:
///      - Proposal submission workflows
///      - Proving workflows  
///      - Finalization workflows
///      - Event verification patterns
///      - State management helpers
abstract contract ShastaInboxTestBase is CommonTest {
    using LibDecoder for bytes;

    // Main contract under test
    TestInbox internal inbox;

    // Mock addresses for dependencies
    address internal bondToken;
    address internal bondManager;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Default test configuration
    IInbox.Config internal defaultConfig;

    // Test constants
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint48 internal constant DEFAULT_PROVABILITY_BOND = 1000 gwei;
    uint48 internal constant DEFAULT_LIVENESS_BOND = 500 gwei;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    uint256 internal constant DEFAULT_MIN_BOND_BALANCE = 1 ether;

    // Genesis block hash for testing
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events to test
    event CoreStateSet(IInbox.CoreState coreState);
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);
    event Proved(IInbox.Proposal proposal, IInbox.ClaimRecord claimRecord);
    event BondWithdrawn(address indexed user, uint256 amount);
    event BondRequest(LibBondOperation.BondOperation bondOperation);

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = address(new MockERC20());
        bondManager = address(new StubBondManager());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());

        // Setup default configuration
        defaultConfig = IInbox.Config({
            forkActivationHeight: 0, // Fork is active by default
            bondToken: bondToken,
            provabilityBondGwei: DEFAULT_PROVABILITY_BOND,
            livenessBondGwei: DEFAULT_LIVENESS_BOND,
            provingWindow: DEFAULT_PROVING_WINDOW,
            extendedProvingWindow: DEFAULT_EXTENDED_PROVING_WINDOW,
            minBondBalance: DEFAULT_MIN_BOND_BALANCE,
            maxFinalizationCount: DEFAULT_MAX_FINALIZATION_COUNT,
            ringBufferSize: DEFAULT_RING_BUFFER_SIZE,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            bondManager: bondManager,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });

        // Deploy and initialize inbox using proxy pattern to avoid initializer issues
        TestInbox impl = new TestInbox();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        // Create a simple proxy that delegates to implementation
        inbox = TestInbox(deployProxy(address(impl), initData));
        inbox.setConfig(defaultConfig);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);

        // Setup default blob hashes for testing
        setupDefaultBlobHashes();
    }

    // -------------------------------------------------------------------
    // Helper Functions for Mocking with Foundry
    // -------------------------------------------------------------------

    /// @notice Setup standard mocks for a valid proposer
    /// @dev Commonly used combination of mocks for testing proposals
    function setupStandardProposerMocks(address _proposer) internal {
        mockProposerAllowed(_proposer);
        mockHasSufficientBond(_proposer, true);
        mockForcedInclusionDue(false);
    }

    /// @notice Setup standard mocks for a valid proposer with forced inclusion
    function setupForcedInclusionProposerMocks(address _proposer) internal {
        mockProposerAllowed(_proposer);
        mockHasSufficientBond(_proposer, true);
        mockForcedInclusionDue(true);
        mockConsumeForcedInclusion(_proposer);
    }

    /// @notice Get the correct event signature for Proposed event
    function getProposedEventSignature() internal pure returns (bytes32) {
        return keccak256(
            "Proposed((uint48,address,uint48,uint48,bool,uint8,uint48,uint48,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32))"
        );
    }

    /// @notice Count Proposed events in logs
    function countProposedEvents(Vm.Log[] memory logs) internal pure returns (uint256) {
        bytes32 eventSig = getProposedEventSignature();
        uint256 count = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSig) {
                count++;
            }
        }
        return count;
    }

    /// @notice Create standard proposal data for testing
    function createStandardProposalData(
        IInbox.CoreState memory _coreState,
        uint256 _blobSeed
    )
        internal
        returns (bytes memory)
    {
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(_blobSeed);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        return encodeProposeProposeData(_coreState, blobRef, claimRecords);
    }

    // -------------------------------------------------------------------
    // Original Helper Functions for Mocking with Foundry
    // -------------------------------------------------------------------

    /// @notice Mock a successful proposer check
    function mockProposerAllowed(address _proposer) internal {
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode()
        );
    }

    /// @notice Mock a failed proposer check
    function mockProposerNotAllowed(address _proposer) internal {
        vm.mockCallRevert(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode("Proposer not allowed")
        );
    }

    /// @notice Mock bond sufficiency check
    function mockHasSufficientBond(address _account, bool _sufficient) internal {
        vm.mockCall(
            bondManager,
            abi.encodeWithSelector(IBondManager.hasSufficientBond.selector, _account, 0),
            abi.encode(_sufficient)
        );
    }

    /// @notice Mock proof verification result
    function mockProofVerification(bool _valid) internal {
        if (_valid) {
            vm.mockCall(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode()
            );
        } else {
            vm.mockCallRevert(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode("Invalid proof")
            );
        }
    }

    /// @notice Mock forced inclusion check
    function mockForcedInclusionDue(bool _isDue) internal {
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
            abi.encode(_isDue)
        );
    }

    /// @notice Mock blobhash opcode to return valid hashes for testing
    /// @dev Uses Foundry's cheatcode to mock the blobhash opcode
    function mockBlobHash(uint256 _index, bytes32 _hash) internal {
        // Mock the blobhash opcode using Foundry's vm.blobhashes
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i == _index) {
                hashes[i] = _hash;
            } else if (i < 10) {
                // Set some default hashes for common indices
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }

    /// @notice Setup default blob hashes for testing
    function setupDefaultBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                // Set default hashes for indices 0-9
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }

    /// @notice Mock forced inclusion consumption
    function mockConsumeForcedInclusion(address _proposer) internal {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(999));

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion = IForcedInclusionStore
            .ForcedInclusion({
            feeInGwei: 1000,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(
                IForcedInclusionStore.consumeOldestForcedInclusion.selector, _proposer
            ),
            abi.encode(forcedInclusion)
        );
    }

    /// @notice Expect a synced block save
    function expectSyncedBlockSave(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        vm.expectCall(
            syncedBlockManager,
            abi.encodeWithSelector(
                ISyncedBlockManager.saveSyncedBlock.selector, _blockNumber, _blockHash, _stateRoot
            )
        );
    }

    /// @notice Expect a bond debit
    function expectBondDebit(address _from, uint96 _amount) internal {
        vm.expectCall(
            bondManager, abi.encodeWithSelector(IBondManager.debitBond.selector, _from, _amount)
        );
    }

    /// @notice Expect a bond credit
    function expectBondCredit(address _to, uint96 _amount) internal {
        vm.expectCall(
            bondManager, abi.encodeWithSelector(IBondManager.creditBond.selector, _to, _amount)
        );
    }

    // -------------------------------------------------------------------
    // Helper Functions for Creating Test Data
    // -------------------------------------------------------------------

    /// @notice Creates a valid proposal for testing
    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(_id));

        return IInbox.Proposal({
            id: _id,
            proposer: Alice,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            provabilityBondGwei: DEFAULT_PROVABILITY_BOND,
            livenessBondGwei: DEFAULT_LIVENESS_BOND,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    /// @notice Creates a valid claim for testing
    function createValidClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash
    )
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return IInbox.Claim({
            proposalHash: keccak256(abi.encode(_proposal)),
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _proposal.id * 100,
            endBlockHash: keccak256(abi.encode(_proposal.id, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(_proposal.id, "stateRoot")),
            designatedProver: _proposal.proposer,
            actualProver: _proposal.proposer
        });
    }

    /// @notice Creates a valid core state for testing
    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedId
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;

        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedId,
            lastFinalizedClaimHash: _lastFinalizedId == 0
                ? keccak256(abi.encode(genesisClaim))
                : bytes32(uint256(_lastFinalizedId)),
            bondOperationsHash: bytes32(0)
        });
    }

    /// @notice Creates encoded propose data
    function encodeProposeProposeData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_coreState, _blobRef, _claimRecords);
    }

    /// @notice Creates encoded prove data
    function encodeProveData(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_proposals, _claims);
    }

    /// @notice Advances time for testing bond windows
    function advanceTime(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Advances blocks
    function advanceBlocks(uint256 _blocks) internal {
        vm.roll(block.number + _blocks);
    }

    /// @notice Gets the current core state hash from inbox
    function getCurrentCoreStateHash() internal view returns (bytes32) {
        return inbox.getCoreStateHash();
    }

    /// @notice Deploys a simple proxy to enable initialization
    function deployProxy(address _impl, bytes memory _initData) internal returns (address proxy) {
        // Use ERC1967Proxy from OpenZeppelin
        proxy = address(new ERC1967Proxy(_impl, _initData));
    }

    /// @notice Creates a valid blob reference
    function createValidBlobReference(uint256 _seed)
        internal
        returns (LibBlobs.BlobReference memory)
    {
        // Always use index 0-9 which are already mocked in setupDefaultBlobHashes
        uint48 index = uint48(_seed % 10);

        // Ensure the blob hash is mocked for this index
        mockBlobHash(index, keccak256(abi.encode("blob", index)));

        return LibBlobs.BlobReference({ blobStartIndex: index, numBlobs: 1, offset: 0 });
    }
    // ---------------------------------------------------------------
    // High-Level Helper Functions for Common Test Patterns
    // ---------------------------------------------------------------

    /// @notice Submits a proposal with standard setup and returns the actual stored proposal
    /// @param _proposer Address that will submit the proposal
    /// @param _proposalId The proposal ID to use
    /// @param _lastFinalizedId Last finalized proposal ID
    /// @param _lastFinalizedHash Last finalized claim hash
    /// @return The actual proposal that was stored by the inbox
    function submitStandardProposal(
        address _proposer,
        uint48 _proposalId,
        uint48 _lastFinalizedId,
        bytes32 _lastFinalizedHash
    )
        internal
        returns (IInbox.Proposal memory)
    {
        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(_proposalId, _lastFinalizedId);
        coreState.lastFinalizedClaimHash = _lastFinalizedHash;
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));
        
        // Setup proposer mocks
        setupStandardProposerMocks(_proposer);
        
        // Create and submit proposal
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(_proposalId);
        IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposeData = encodeProposeProposeData(coreState, blobRef, emptyClaimRecords);
        
        vm.prank(_proposer);
        inbox.propose(bytes(""), proposeData);
        
        // Recreate and return the actual stored proposal
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", blobRef.blobStartIndex));
        
        return IInbox.Proposal({
            id: _proposalId,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
            provabilityBondGwei: defaultConfig.provabilityBondGwei,
            livenessBondGwei: defaultConfig.livenessBondGwei,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: blobRef.offset,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    /// @notice Submits a proof for a proposal
    /// @param _prover Address that will submit the proof
    /// @param _proposal The proposal to prove
    /// @param _claim The claim to prove
    /// @param _parentClaimHash Parent claim hash for the claim
    function submitProofForProposal(
        address _prover,
        IInbox.Proposal memory _proposal,
        IInbox.Claim memory _claim,
        bytes32 _parentClaimHash
    )
        internal
    {
        // Ensure claim has correct proposal hash
        _claim.proposalHash = inbox.getProposalHash(_proposal.id);
        _claim.parentClaimHash = _parentClaimHash;
        
        // Setup proof verification
        mockProofVerification(true);
        
        // Create proof data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = _claim;
        
        bytes memory proveData = encodeProveData(proposals, claims);
        bytes memory proof = bytes("valid_proof");
        
        // Submit proof
        vm.prank(_prover);
        inbox.prove(proveData, proof);
    }


    /// @notice Verifies that a proposal was proven with the expected claim
    /// @param _proposalId The proposal ID to check
    /// @param _parentClaimHash The parent claim hash
    function verifyProposalProven(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
    {
        bytes32 claimRecordHash = inbox.getClaimRecordHash(_proposalId, _parentClaimHash);
        assertTrue(claimRecordHash != bytes32(0), "Proposal should be proven");
    }

    /// @notice Creates a standard claim record for testing
    /// @param _proposal The proposal
    /// @param _claim The claim  
    /// @param _bondDecision The bond decision
    /// @return The created claim record
    function createStandardClaimRecord(
        IInbox.Proposal memory _proposal,
        IInbox.Claim memory _claim,
        IInbox.BondDecision _bondDecision
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory)
    {
        return IInbox.ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: _proposal.id + 1,
            bondDecision: _bondDecision
        });
    }
}

/// @title TestInbox
/// @notice Test implementation of Inbox that exposes internal functions and state
contract TestInbox is Inbox {
    IInbox.Config private _config;

    function setConfig(IInbox.Config memory _newConfig) external {
        _config = _newConfig;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return _config;
    }

    // Expose internal state for testing
    function getCoreStateHash() external view returns (bytes32) {
        return coreStateHash;
    }

    function getBondBalance(address _account) external view returns (uint256) {
        return bondBalance[_account];
    }

    // Expose internal functions for direct testing
    function exposed_setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external {
        _setProposalHash(_config, _proposalId, _proposalHash);
    }

    function exposed_setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external
    {
        _setClaimRecordHash(_config, _proposalId, _parentClaimHash, _claimRecordHash);
    }

    function exposed_getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32)
    {
        return getClaimRecordHash(_proposalId, _parentClaimHash);
    }

    function exposed_aggregateClaimRecords(
        uint48[] memory _proposalIds,
        ClaimRecord[] memory _claimRecords
    )
        external
        pure
        returns (uint48[] memory, ClaimRecord[] memory)
    {
        return _aggregateClaimRecords(_proposalIds, _claimRecords);
    }

    function exposed_setCoreStateHash(bytes32 _hash) external {
        _setCoreStateHash(_hash);
    }
}

/// @title Stub contracts for testing
/// @dev Minimal implementations that can be controlled via Foundry's vm.mockCall

contract StubBondManager is IBondManager {
    function hasSufficientBond(address, uint96) external pure returns (bool) {
        return true;
    }

    function debitBond(address, uint96) external pure returns (uint96) {
        return 0;
    }

    function creditBond(address, uint96) external { }

    function getBondBalance(address) external pure returns (uint96) {
        return 1_000_000;
    }

    function deposit(uint96) external { }

    function withdraw(address, uint96) external { }

    function requestWithdrawal() external { }

    function cancelWithdrawal() external { }
}

contract StubSyncedBlockManager is ISyncedBlockManager {
    function saveSyncedBlock(uint48, bytes32, bytes32) external { }

    function getSyncedBlock(uint48) external pure returns (uint48, bytes32, bytes32) {
        return (0, bytes32(0), bytes32(0));
    }

    function getLatestSyncedBlockNumber() external pure returns (uint48) {
        return 0;
    }

    function getNumberOfSyncedBlocks() external pure returns (uint48) {
        return 0;
    }
}

contract StubForcedInclusionStore is IForcedInclusionStore {
    function isOldestForcedInclusionDue() external pure returns (bool) {
        return false;
    }

    function storeForcedInclusion(LibBlobs.BlobReference memory) external payable { }

    function consumeOldestForcedInclusion(address) external pure returns (ForcedInclusion memory) {
        return ForcedInclusion({
            feeInGwei: 0,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: new bytes32[](0), offset: 0, timestamp: 0 })
        });
    }
}

contract StubProofVerifier is IProofVerifier {
    function verifyProof(bytes32, bytes calldata) external pure { }
}

contract StubProposerChecker is IProposerChecker {
    function checkProposer(address) external pure { }
}

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    // Test helper
    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }
}
