// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/layer1/preconf/impl/PreconfRouter2.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "test/layer1/preconf/mocks/MockLookaheadStore.sol";
import "test/layer1/preconf/mocks/MockPreconfWhitelist.sol";
import "test/layer1/preconf/mocks/MockTaikoInbox.sol";
import "test/layer1/preconf/mocks/MockURC.sol";
import "test/shared/CommonTest.sol";

abstract contract PreconfRouter2TestBase is CommonTest {
    MockLookaheadStore internal lookaheadStore;
    MockPreconfWhitelist internal preconfWhitelist;
    MockTaikoInbox internal taikoInbox;
    MockURC internal urc;
    PreconfRouter2 internal preconfRouter;

    // Local test cache
    uint256 internal cachedSlotIndex;
    ILookaheadStore.LookaheadSlot[] internal cachedCurrentLookaheadSlots;
    ILookaheadStore.LookaheadSlot[] internal cachedNextLookaheadSlots;

    bytes32 internal registrationRoot = bytes32("registration_root");
    address internal committer = vm.addr(uint256(bytes32("committer")));
    address internal fallbackPreconfer = vm.addr(uint256(bytes32("fallbackPreconfer")));
    address internal whitelistOperator = vm.addr(uint256(bytes32("whitelistOperator")));
    address internal preconfSlasher = vm.addr(uint256(bytes32("preconfSlasher")));
    address internal protector = vm.addr(uint256(bytes32("protector")));

    uint256 internal constant EPOCH_START = LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS
        + 5 * LibPreconfConstants.SECONDS_IN_EPOCH;

    function setUpOnEthereum() internal virtual override {
        lookaheadStore = new MockLookaheadStore();
        preconfWhitelist = new MockPreconfWhitelist();
        taikoInbox = new MockTaikoInbox(taikoChainId);
        urc = new MockURC();

        address preconfRouterImpl = address(
            new PreconfRouter2(
                address(lookaheadStore),
                address(preconfWhitelist),
                address(taikoInbox),
                preconfSlasher,
                address(urc),
                fallbackPreconfer,
                protector
            )
        );
        preconfRouter = PreconfRouter2(
            deploy(
                "",
                preconfRouterImpl,
                abi.encodeWithSelector(PreconfRouter2.init.selector, (address(0)))
            )
        );

        // Setup a whitelist operator
        preconfWhitelist.setOperatorForCurrentEpoch(whitelistOperator);

        // Wrap time to the beginning of an arbitrary epoch
        vm.warp(EPOCH_START);
    }

    // Modifiers
    // --------------------------------------------------------------------------------------------

    /// @dev Use mainnet chainid since we are using mainnet genesis as reference
    modifier useMainnet() {
        vm.chainId(LibNetwork.ETHEREUM_MAINNET);
        _;
    }

    modifier setupValidPreconfOperator() {
        _setupOperator(false, false, false);
        _;
    }

    modifier setupEmptyCurrentLookahead() {
        _setupEmptyLookahead(0);
        _;
    }

    modifier setupEmptyNextLookahead() {
        _setupEmptyLookahead(1);
        _;
    }

    modifier setupCurrentLookaheadSlots(uint256 _slotIndex) {
        _slotIndex = bound(_slotIndex, 0, 5);
        _setupLookaheadSlots(_slotIndex, 0);
        _;
    }

    modifier setupNextLookaheadSlots() {
        _setupLookaheadSlots(0, 1);
        _;
    }

    modifier clearCurrentLookahead() {
        _clearLookahead(0);
        _;
    }

    modifier clearNextLookahead() {
        _clearLookahead(1);
        _;
    }

    // Internal Helpers
    // --------------------------------------------------------------------------------------------

    function _setupOperator(bool _unregistered, bool _slashed, bool _isOptedOut) internal {
        urc.setOperatorData(
            registrationRoot,
            committer,
            1 ether,
            10,
            block.timestamp - 1 days,
            _unregistered ? block.timestamp - 1 days : 0,
            _slashed ? block.timestamp - 1 days : 0
        );

        if (!_isOptedOut) {
            urc.setSlasherCommitment(
                registrationRoot, preconfSlasher, block.timestamp - 1 days, 0, committer
            );
        }
    }

    function _clearLookahead(uint256 _offset) internal {
        uint256 epochTimestamp = EPOCH_START + _offset * LibPreconfConstants.SECONDS_IN_EPOCH;
        lookaheadStore.setLookaheadHash(epochTimestamp, 0);
    }

    function _setupEmptyLookahead(uint256 _offset) internal {
        uint256 epochTimestamp = EPOCH_START + _offset * LibPreconfConstants.SECONDS_IN_EPOCH;
        lookaheadStore.setLookaheadHash(
            epochTimestamp,
            lookaheadStore.calculateLookaheadHash(
                epochTimestamp, new ILookaheadStore.LookaheadSlot[](0)
            )
        );
    }

    /// @dev An `_offset` of 0 means current lookahead, while 1 means next lookahead
    function _setupLookaheadSlots(uint256 _slotIndex, uint256 _offset) internal {
        // This allows us to conditionally keep the last slot empty if we want to test advanced
        // proposals into the next epoch
        uint256 numSlots = _slotIndex == 5 ? 6 : 5;
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots =
            new ILookaheadStore.LookaheadSlot[](numSlots);

        uint256 epochTimestamp = EPOCH_START + _offset * LibPreconfConstants.SECONDS_IN_EPOCH;

        for (uint256 i = 0; i < _lookaheadSlots.length; ++i) {
            if (i == _slotIndex) {
                _lookaheadSlots[i].committer = committer;
                _lookaheadSlots[i].registrationRoot = registrationRoot;
            }
            _lookaheadSlots[i].slotTimestamp =
                epochTimestamp + 5 * (i + 1) * LibPreconfConstants.SECONDS_IN_SLOT;
        }

        lookaheadStore.setLookaheadHash(
            epochTimestamp, lookaheadStore.calculateLookaheadHash(epochTimestamp, _lookaheadSlots)
        );

        ILookaheadStore.LookaheadSlot[] storage lookaheadSlots;
        if (_offset == 0) {
            cachedSlotIndex = _slotIndex;
            lookaheadSlots = cachedCurrentLookaheadSlots;
        } else {
            require(_slotIndex == 0, "PreconfRouter2TestBase: Next lookahead slot index must be 0");
            lookaheadSlots = cachedNextLookaheadSlots;
        }

        for (uint256 i = 0; i < _lookaheadSlots.length; ++i) {
            lookaheadSlots.push(_lookaheadSlots[i]);
        }
    }

    function _loadLookaheads()
        internal
        view
        returns (ILookaheadStore.LookaheadSlot[] memory, ILookaheadStore.LookaheadSlot[] memory)
    {
        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            new ILookaheadStore.LookaheadSlot[](cachedCurrentLookaheadSlots.length);
        for (uint256 i = 0; i < cachedCurrentLookaheadSlots.length; ++i) {
            currLookahead[i] = cachedCurrentLookaheadSlots[i];
        }

        ILookaheadStore.LookaheadSlot[] memory nextLookahead =
            new ILookaheadStore.LookaheadSlot[](cachedNextLookaheadSlots.length);
        for (uint256 i = 0; i < cachedNextLookaheadSlots.length; ++i) {
            nextLookahead[i] = cachedNextLookaheadSlots[i];
        }

        return (currLookahead, nextLookahead);
    }

    function _proposeBatch()
        internal
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        (
            ILookaheadStore.LookaheadSlot[] memory currLookahead,
            ILookaheadStore.LookaheadSlot[] memory nextLookahead
        ) = _loadLookaheads();

        ITaikoInbox.BatchParams memory batchParams;
        (, address sender,) = vm.readCallers();
        batchParams.proposer = sender;

        bytes memory params = abi.encode(batchParams);
        bytes memory lookaheadData = abi.encode(
            cachedSlotIndex,
            registrationRoot,
            currLookahead,
            nextLookahead,
            sender == committer ? bytes("signature") : bytes("")
        );

        return preconfRouter.v4ProposeBatch(params, "", lookaheadData);
    }
}
