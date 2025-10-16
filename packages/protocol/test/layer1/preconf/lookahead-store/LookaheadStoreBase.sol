// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { IBlacklist } from "src/layer1/preconf/iface/IBlacklist.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LookaheadStore } from "src/layer1/preconf/impl/LookaheadStore.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibLookaheadEncoder as Encoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";
import { MockPreconfWhitelist } from "test/layer1/preconf/mocks/MockPreconfWhitelist.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";

contract LookaheadStoreBase is CommonTest {
    MockPreconfWhitelist internal preconfWhitelist;
    LookaheadStore internal lookaheadStore;

    // Arbitrary epoch
    uint256 internal constant EPOCH_START =
        LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS + 5
        * LibPreconfConstants.SECONDS_IN_EPOCH;

    address internal inbox = vm.addr(uint256(bytes32("inbox")));
    address internal overseer = vm.addr(uint256(bytes32("overseer")));
    address internal fallbackPreconfer = vm.addr(uint256(bytes32("fallbackPreconfer")));
    address internal unifiedSlasher = vm.addr(uint256(bytes32("unifiedSlasher")));

    function setUpOnEthereum() internal virtual override {
        preconfWhitelist = new MockPreconfWhitelist();

        address[] memory overseers = new address[](1);
        overseers[0] = overseer;

        address lookaheadStoreImpl =
            address(new LookaheadStore(inbox, unifiedSlasher, address(preconfWhitelist)));
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

    // Internal helpers
    // ---------------------------------------------------------------------------------------------

    /// @dev Do not repeat slot positions
    function _setupLookahead(
        uint256 _epochTimestamp,
        uint256[] memory _slotPositions,
        bool _updateStorage
    )
        internal
        returns (ILookaheadStore.LookaheadSlot[] memory lookaheadSlots_)
    {
        lookaheadSlots_ = new ILookaheadStore.LookaheadSlot[](_slotPositions.length);

        for (uint256 i; i < _slotPositions.length; ++i) {
            uint256 registrationRootAndPrivateKey = i + 1;
            lookaheadSlots_[i] = ILookaheadStore.LookaheadSlot({
                committer: vm.addr(registrationRootAndPrivateKey),
                timestamp: uint48(
                    _epochTimestamp + _slotPositions[i] * LibPreconfConstants.SECONDS_IN_SLOT
                ),
                registrationRoot: bytes32(registrationRootAndPrivateKey),
                validatorLeafIndex: 0 // Safe to set it to 0 for testing the store
            });
        }

        if (_updateStorage) {
            _setLookaheadHash(
                _epochTimestamp,
                lookaheadStore.calculateLookaheadHash(
                    _epochTimestamp, Encoder.encode(lookaheadSlots_)
                )
            );
        }
    }

    function _setLookaheadHash(uint256 _epochTimestamp, bytes26 _lookaheadHash) internal {
        bytes32 key = bytes32(_epochTimestamp % lookaheadStore.LOOKAHEAD_BUFFER_SIZE());
        bytes32 slot = keccak256(abi.encode(key, 301)); // `lookahead` mapping is in slot 301
        bytes32 value = bytes32(abi.encodePacked(_lookaheadHash, uint48(_epochTimestamp)));

        vm.store(address(lookaheadStore), slot, value);
    }

    function _signLookaheadCommitment(
        bytes32 _registrationRoot,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        internal
        view
        returns (bytes memory signature_)
    {
        ISlasher.Commitment memory commitment = ISlasher.Commitment({
            commitmentType: 0,
            payload: abi.encode(keccak256(Encoder.encode(_lookaheadSlots))),
            slasher: unifiedSlasher
        });

        bytes32 commitmentHash = keccak256(abi.encode(commitment));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(_registrationRoot), commitmentHash);

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
            currLookahead: Encoder.encode(_currLookahead),
            nextLookahead: Encoder.encode(_nextLookahead),
            commitmentSignature: _signature
        });
        vm.resumeGasMetering();

        vm.prank(inbox);
        endOfSubmissionWindowTimestamp_ =
            lookaheadStore.checkProposer(_proposer, abi.encode(lookaheadData));
    }
}
