// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { IRegistry } from "@eth-fabric/urc/IRegistry.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LookaheadStore } from "src/layer1/preconf/impl/LookaheadStore.sol";
import { LibLookaheadEncoder as Encoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract GasBenchMockURC {
    function getOperatorData(bytes32) external pure returns (IRegistry.OperatorData memory) {
        return IRegistry.OperatorData({
            owner: address(1),
            collateralWei: 1 ether,
            numKeys: 1,
            registeredAt: 1,
            unregisteredAt: 0,
            slashedAt: 0,
            deleted: false,
            equivocated: false
        });
    }

    function getSlasherCommitment(
        bytes32,
        address
    )
        external
        pure
        returns (IRegistry.SlasherCommitment memory)
    {
        return IRegistry.SlasherCommitment({
            committer: address(1), optedInAt: 1, optedOutAt: 0, slashed: false
        });
    }
}

contract GasBenchHarness is LookaheadStore {
    constructor(
        address _inbox,
        address _preconfSlasherL1,
        address _preconfWhitelist,
        address _urc
    )
        LookaheadStore(_inbox, _preconfSlasherL1, _preconfWhitelist, _urc)
    { }

    function setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) external {
        _setLookaheadHash(_epochTimestamp, _hash);
    }
}

contract LookaheadStoreGasBench is CommonTest {
    GasBenchHarness internal lookaheadStore;

    address internal overseer;
    address internal preconfSlasherL1;
    address internal inbox;
    address internal preconfWhitelist;
    address internal urc;

    uint256 internal constant EPOCH_OFFSET = 10_000;
    uint256 internal constant EPOCH_START = EPOCH_OFFSET * LibPreconfConstants.SECONDS_IN_EPOCH;
    uint256 internal constant SLOT = LibPreconfConstants.SECONDS_IN_SLOT;
    uint256 internal constant EPOCH = LibPreconfConstants.SECONDS_IN_EPOCH;

    uint256 internal constant COMMITTER_PK = 0xA11CE;

    string internal constant P_SAME = "preconf/same_epoch_proposal";
    string internal constant P_CROSS = "preconf/cross_epoch_proposal";
    string internal constant P_POST = "preconf/same_epoch_proposal_with_lookahead_posting";
    string internal constant P_REUSE =
        "preconf/same_epoch_proposal_with_lookahead_posting_reuse_slot";

    function setUpOnEthereum() internal override {
        overseer = makeAddr("overseer");
        preconfSlasherL1 = makeAddr("preconfSlasherL1");
        inbox = makeAddr("inbox");
        preconfWhitelist = makeAddr("preconfWhitelist");
        urc = address(new GasBenchMockURC());

        GasBenchHarness impl = new GasBenchHarness(inbox, preconfSlasherL1, preconfWhitelist, urc);
        lookaheadStore = GasBenchHarness(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(LookaheadStore.init, (address(this), overseer))
                )
            )
        );

        vm.warp(EPOCH_START);
    }

    // ---------------------------------------------------------------
    // Scenario 1: Same-epoch proposal (next lookahead already exists)
    // ---------------------------------------------------------------

    function test_gas_sameEpoch_1op() external {
        _benchSameEpochProposal(1, "1_operator_in_current_lookahead");
    }

    function test_gas_sameEpoch_5ops() external {
        _benchSameEpochProposal(5, "5_operators_in_current_lookahead");
    }

    function test_gas_sameEpoch_10ops() external {
        _benchSameEpochProposal(10, "10_operators_in_current_lookahead");
    }

    function test_gas_sameEpoch_15ops() external {
        _benchSameEpochProposal(15, "15_operators_in_current_lookahead");
    }

    // ---------------------------------------------------------------
    // Scenario 2: Cross-epoch proposal (both lookaheads pre-stored)
    // ---------------------------------------------------------------

    function test_gas_crossEpoch_1op() external {
        _benchCrossEpochProposal(1, "1_operator_in_each_lookahead");
    }

    function test_gas_crossEpoch_5ops() external {
        _benchCrossEpochProposal(5, "5_operators_in_each_lookahead");
    }

    function test_gas_crossEpoch_10ops() external {
        _benchCrossEpochProposal(10, "10_operators_in_each_lookahead");
    }

    function test_gas_crossEpoch_15ops() external {
        _benchCrossEpochProposal(15, "15_operators_in_each_lookahead");
    }

    // ---------------------------------------------------------------
    // Scenario 3: Same-epoch + lookahead posting (cold SSTORE)
    // ---------------------------------------------------------------

    function test_gas_sameEpochPost_1op() external {
        _benchSameEpochWithPosting(1, "1_operator_in_both_lookaheads", false);
    }

    function test_gas_sameEpochPost_5ops() external {
        _benchSameEpochWithPosting(5, "5_operators_in_both_lookaheads", false);
    }

    function test_gas_sameEpochPost_10ops() external {
        _benchSameEpochWithPosting(10, "10_operators_in_both_lookaheads", false);
    }

    function test_gas_sameEpochPost_15ops() external {
        _benchSameEpochWithPosting(15, "15_operators_in_both_lookaheads", false);
    }

    // ---------------------------------------------------------------
    // Scenario 4: Same-epoch + lookahead posting (warm SSTORE / reuse slot)
    // ---------------------------------------------------------------

    function test_gas_sameEpochPostReuse_1op() external {
        _benchSameEpochWithPosting(1, "1_operator_in_both_lookaheads", true);
    }

    function test_gas_sameEpochPostReuse_5ops() external {
        _benchSameEpochWithPosting(5, "5_operators_in_both_lookaheads", true);
    }

    function test_gas_sameEpochPostReuse_10ops() external {
        _benchSameEpochWithPosting(10, "10_operators_in_both_lookaheads", true);
    }

    function test_gas_sameEpochPostReuse_15ops() external {
        _benchSameEpochWithPosting(15, "15_operators_in_both_lookaheads", true);
    }

    // ---------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------

    /// @dev Scenario 1: Same-epoch proposer, next lookahead already on-chain.
    /// checkProposer early-returns from _handleNextEpochLookahead.
    function _benchSameEpochProposal(uint256 _numOps, string memory _benchName) internal {
        uint256 epochTimestamp = EPOCH_START;
        uint256 nextEpochTimestamp = epochTimestamp + EPOCH;

        // Build and store current epoch lookahead
        ILookaheadStore.LookaheadSlot[] memory currSlots = _buildSlots(epochTimestamp, _numOps);
        bytes memory currEncoded = Encoder.encodeLookahead(currSlots);
        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currEncoded);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        // Store next epoch lookahead (so _handleNextEpochLookahead early-returns)
        ILookaheadStore.LookaheadSlot[] memory nextSlots = _buildSlots(nextEpochTimestamp, 1);
        bytes memory nextEncoded = Encoder.encodeLookahead(nextSlots);
        bytes26 nextHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextEncoded);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, nextHash);

        // Proposer is slot 0 of current epoch
        address proposer = currSlots[0].committer;

        // Warp into submission window: [epochTimestamp, slot[0].timestamp]
        vm.warp(epochTimestamp + 1);

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: 0, currLookahead: currEncoded, nextLookahead: "", commitmentSignature: ""
        });

        bytes memory encodedData = abi.encode(data);

        vm.prank(inbox);
        vm.startSnapshotGas(P_SAME, _benchName);
        lookaheadStore.checkProposer(proposer, encodedData);
        vm.stopSnapshotGas();
    }

    /// @dev Scenario 2: Cross-epoch proposer, both lookaheads pre-stored on-chain.
    /// checkProposer validates both curr and next lookahead hashes.
    function _benchCrossEpochProposal(uint256 _numOps, string memory _benchName) internal {
        uint256 epochTimestamp = EPOCH_START;
        uint256 nextEpochTimestamp = epochTimestamp + EPOCH;

        // Build and store current epoch lookahead
        ILookaheadStore.LookaheadSlot[] memory currSlots = _buildSlots(epochTimestamp, _numOps);
        bytes memory currEncoded = Encoder.encodeLookahead(currSlots);
        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currEncoded);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        // Build and store next epoch lookahead
        ILookaheadStore.LookaheadSlot[] memory nextSlots = _buildSlots(nextEpochTimestamp, _numOps);
        bytes memory nextEncoded = Encoder.encodeLookahead(nextSlots);
        bytes26 nextHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextEncoded);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, nextHash);

        // Cross-epoch proposer is first preconfer of next epoch
        address proposer = nextSlots[0].committer;

        // Warp: within [lastCurrSlot.timestamp - SLOT, nextSlots[0].timestamp]
        uint256 lastCurrTimestamp = currSlots[_numOps - 1].timestamp;
        vm.warp(lastCurrTimestamp);

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: type(uint256).max,
            currLookahead: currEncoded,
            nextLookahead: nextEncoded,
            commitmentSignature: ""
        });

        bytes memory encodedData = abi.encode(data);

        vm.prank(inbox);
        vm.startSnapshotGas(P_CROSS, _benchName);
        lookaheadStore.checkProposer(proposer, encodedData);
        vm.stopSnapshotGas();
    }

    /// @dev Scenarios 3 & 4: Same-epoch proposer posts next lookahead during checkProposer.
    /// When _warmSlot is true, the storage slot is pre-warmed (reuse scenario).
    function _benchSameEpochWithPosting(
        uint256 _numOps,
        string memory _benchName,
        bool _warmSlot
    )
        internal
    {
        uint256 epochTimestamp = EPOCH_START;
        uint256 nextEpochTimestamp = epochTimestamp + EPOCH;
        address committer = vm.addr(COMMITTER_PK);

        bytes memory currEncoded;
        bytes memory nextEncoded;

        // Build and store current epoch lookahead (committer is our proposer at slot 0)
        {
            ILookaheadStore.LookaheadSlot[] memory currSlots =
                _buildSlotsWithCommitter(epochTimestamp, _numOps, committer);
            currEncoded = Encoder.encodeLookahead(currSlots);
            bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currEncoded);
            lookaheadStore.setLookaheadHash(epochTimestamp, currHash);
        }

        // Build next epoch lookahead (NOT stored — will be posted by checkProposer)
        {
            ILookaheadStore.LookaheadSlot[] memory nextSlots =
                _buildSlots(nextEpochTimestamp, _numOps);
            nextEncoded = Encoder.encodeLookahead(nextSlots);
        }

        // Warm the storage slot if needed (scenario 4)
        if (_warmSlot) {
            uint256 warmEpoch = nextEpochTimestamp + lookaheadStore.LOOKAHEAD_BUFFER_SIZE() * EPOCH;
            lookaheadStore.setLookaheadHash(warmEpoch, bytes26(uint208(1)));
        }

        // Sign the commitment
        bytes memory sig;
        {
            ISlasher.Commitment memory commitment =
                lookaheadStore.buildLookaheadCommitment(nextEpochTimestamp, nextEncoded);
            bytes32 digest = keccak256(abi.encode(commitment));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(COMMITTER_PK, digest);
            sig = abi.encodePacked(r, s, v);
        }

        // Warp into submission window (must be > epochTimestamp for posting path)
        vm.warp(epochTimestamp + 1);

        bytes memory encodedData = abi.encode(
            ILookaheadStore.LookaheadData({
                slotIndex: 0,
                currLookahead: currEncoded,
                nextLookahead: nextEncoded,
                commitmentSignature: sig
            })
        );

        vm.prank(inbox);
        vm.startSnapshotGas(_warmSlot ? P_REUSE : P_POST, _benchName);
        lookaheadStore.checkProposer(committer, encodedData);
        vm.stopSnapshotGas();
    }

    // ---------------------------------------------------------------
    // Slot builders
    // ---------------------------------------------------------------

    function _buildSlots(
        uint256 _epochTimestamp,
        uint256 _numSlots
    )
        internal
        returns (ILookaheadStore.LookaheadSlot[] memory slots_)
    {
        slots_ = new ILookaheadStore.LookaheadSlot[](_numSlots);
        for (uint256 i; i < _numSlots; ++i) {
            slots_[i] = ILookaheadStore.LookaheadSlot({
                committer: makeAddr(string.concat("committer_", vm.toString(i))),
                timestamp: uint48(_epochTimestamp + (i + 1) * SLOT),
                validatorLeafIndex: uint16(i),
                registrationRoot: keccak256(abi.encodePacked("operator", i))
            });
        }
    }

    /// @dev Same as _buildSlots but sets slot[0].committer to the given address.
    function _buildSlotsWithCommitter(
        uint256 _epochTimestamp,
        uint256 _numSlots,
        address _committer
    )
        internal
        returns (ILookaheadStore.LookaheadSlot[] memory slots_)
    {
        slots_ = _buildSlots(_epochTimestamp, _numSlots);
        slots_[0].committer = _committer;
    }
}
