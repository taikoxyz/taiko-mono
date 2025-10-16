// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibNetwork.sol";
import "src/layer1/preconf/iface/IBlacklist.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/impl/LookaheadStore.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "test/layer1/preconf/mocks/MockURC.sol";
import "test/layer1/preconf/mocks/MockPreconfWhitelist.sol";
import "test/shared/CommonTest.sol";
import "@eth-fabric/urc/ISlasher.sol";

contract LookaheadStoreBase is CommonTest {
    struct SetupOperator {
        bytes32 registrationRoot;
        uint256 collateralWei;
        uint256 numKeys;
        uint256 registeredAt;
        uint256 unregisteredAt;
        uint256 slashedAt;
        uint256 optedInAt;
        uint256 optedOutAt;
        address committer;
        address slasher;
    }

    MockURC internal urc;
    MockPreconfWhitelist internal preconfWhitelist;
    LookaheadStore internal lookaheadStore;

    uint256 internal constant MIN_OPERATORS = 5;
    uint256 internal constant MAX_OPERATORS = 15;
    uint256 internal constant EPOCH_START =
        LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS + 5
        * LibPreconfConstants.SECONDS_IN_EPOCH;

    address internal inbox = vm.addr(uint256(bytes32("inbox")));
    address internal overseer = vm.addr(uint256(bytes32("overseer")));
    address internal fallbackPreconfer = vm.addr(uint256(bytes32("fallbackPreconfer")));
    address internal unifiedSlasher = vm.addr(uint256(bytes32("unifiedSlasher")));

    function setUpOnEthereum() internal virtual override {
        urc = new MockURC();
        preconfWhitelist = new MockPreconfWhitelist();

        address[] memory overseers = new address[](1);
        overseers[0] = overseer;

        address lookaheadStoreImpl = address(
            new LookaheadStore(address(urc), unifiedSlasher, inbox, address(preconfWhitelist))
        );
        lookaheadStore = LookaheadStore(
            deploy(
                "lookahead_store",
                lookaheadStoreImpl,
                abi.encodeCall(LookaheadStore.init, (address(this), overseers))
            )
        );

        preconfWhitelist.setOperatorForCurrentEpoch(fallbackPreconfer);

        // Wrap time to the beginning of an arbitrary epoch
        vm.warp(EPOCH_START);
    }

    // Modifiers
    // ---------------------------------------------------------------------------------------------

    /// @dev Use mainnet chainid since we are using mainnet genesis as reference
    modifier useMainnet() {
        vm.chainId(LibNetwork.ETHEREUM_MAINNET);
        _;
    }

    modifier setupOperators(SetupOperator[] memory _operators) {
        _setupOperators(_operators);
        _;
    }

    // Internal helpers
    // ---------------------------------------------------------------------------------------------

    function _setupOperators(SetupOperator[] memory _operators) internal {
        vm.assume(_operators.length >= MIN_OPERATORS && _operators.length <= MAX_OPERATORS);

        for (uint256 i; i < _operators.length; ++i) {
            bytes32 registrationRoot = bytes32(i + 1);
            address committer = vm.addr(uint256(registrationRoot));

            _operators[i].registrationRoot = registrationRoot;
            _operators[i].committer = committer;
            _operators[i].slasher = unifiedSlasher;

            if (_operators[i].unregisteredAt == 0) {
                _operators[i].unregisteredAt = type(uint48).max;
            }

            _boundSetupOperatorData(
                _operators[i], lookaheadStore.getLookaheadStoreConfig().minCollateral
            );

            _insertOperatorInURC(_operators[i]);
        }
    }

    function _boundSetupOperatorData(SetupOperator memory _operator, uint256 _minCollateralWei)
        internal
        pure
    {
        uint256 previousEpochTimestamp = EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH;

        // Max keys allowed by URC
        _operator.numKeys = bound(_operator.numKeys, 1, type(uint16).max);

        // Must register and opt-in before the beginning of the previous epoch
        _operator.registeredAt = bound(_operator.registeredAt, 1, previousEpochTimestamp - 1);
        _operator.optedInAt =
            bound(_operator.optedInAt, _operator.registeredAt, previousEpochTimestamp - 1);

        // Any Opt outs, unregisters and slashing must be within the previous or current epoch
        if (_operator.optedOutAt != 0) {
            _operator.optedOutAt = bound(_operator.optedOutAt, previousEpochTimestamp, EPOCH_START);
        }
        if (_operator.unregisteredAt != type(uint48).max) {
            _operator.unregisteredAt =
                bound(_operator.unregisteredAt, previousEpochTimestamp, EPOCH_START);
        }
        if (_operator.slashedAt != 0) {
            _operator.slashedAt = bound(_operator.slashedAt, previousEpochTimestamp, EPOCH_START);
        }

        // Must have the minimum required collateral
        _operator.collateralWei =
            bound(_operator.collateralWei, _minCollateralWei, type(uint80).max);
    }

    function _insertOperatorInURC(SetupOperator memory _operator) internal {
        urc.setOperatorData(
            _operator.registrationRoot,
            _operator.committer,
            _operator.collateralWei,
            _operator.numKeys,
            _operator.registeredAt,
            _operator.unregisteredAt,
            _operator.slashedAt
        );

        urc.setSlasherCommitment(
            _operator.registrationRoot,
            _operator.slasher,
            _operator.optedInAt,
            _operator.optedOutAt,
            _operator.committer
        );

        urc.setHistoricalCollateral(
            _operator.registrationRoot,
            LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS,
            _operator.collateralWei
        );
    }

    /// @dev Do not repeat slot positions
    function _setupLookahead(
        uint256 _epochTimestamp,
        SetupOperator[] memory _operators,
        uint256[] memory _slotPositions,
        bool _updateStorage
    )
        internal
        returns (ILookaheadStore.LookaheadSlot[] memory lookaheadSlots_)
    {
        require(_slotPositions.length <= _operators.length, "LookaheadStoreBase: Too many slots");

        lookaheadSlots_ = new ILookaheadStore.LookaheadSlot[](_slotPositions.length);

        for (uint256 i; i < _slotPositions.length; ++i) {
            lookaheadSlots_[i] = ILookaheadStore.LookaheadSlot({
                committer: _operators[i].committer,
                timestamp: _epochTimestamp + _slotPositions[i]
                    * LibPreconfConstants.SECONDS_IN_SLOT,
                registrationRoot: _operators[i].registrationRoot,
                validatorLeafIndex: 0
            });
        }

        if (_updateStorage) {
            _setLookaheadHash(
                _epochTimestamp,
                lookaheadStore.calculateLookaheadHash(_epochTimestamp, lookaheadSlots_)
            );
        }
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes26 _lookaheadHash) internal {
        bytes32 key =
            bytes32(_epochTimestamp % lookaheadStore.getLookaheadStoreConfig().lookaheadBufferSize);
        bytes32 slot = keccak256(abi.encode(key, 301)); // `lookahead` mapping is in slot 301
        bytes32 value = bytes32(abi.encodePacked(_lookaheadHash, uint48(_epochTimestamp)));

        vm.store(address(lookaheadStore), slot, value);
    }

    function _signLookaheadCommitment(
        SetupOperator memory _operator,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        internal
        view
        returns (bytes memory signature_)
    {
        ISlasher.Commitment memory commitment = ISlasher.Commitment({
            commitmentType: 0, payload: abi.encode(_lookaheadSlots), slasher: unifiedSlasher
        });

        bytes32 commitmentHash = keccak256(abi.encode(commitment));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(uint256(_operator.registrationRoot), commitmentHash);

        signature_ = abi.encodePacked(r, s, v);
    }

    function _checkProposer(
        uint256 _slotIndex,
        address _proposer,
        ILookaheadStore.LookaheadSlot[] memory _currLookahead,
        ILookaheadStore.LookaheadSlot[] memory _nextLookahead,
        bytes memory _signature
    )
        internal
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        vm.pauseGasMetering();
        ILookaheadStore.LookaheadData memory lookaheadData = ILookaheadStore.LookaheadData({
            slotIndex: _slotIndex,
            currLookahead: _currLookahead,
            nextLookahead: _nextLookahead,
            commitmentSignature: _signature
        });
        vm.resumeGasMetering();

        vm.prank(inbox);
        endOfSubmissionWindowTimestamp_ =
            lookaheadStore.checkProposer(_proposer, abi.encode(lookaheadData));
    }
}
