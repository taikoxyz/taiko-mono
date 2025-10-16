// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../mocks/MockURC.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@eth-fabric/urc/ISlasher.sol";
import "src/layer1/preconf/impl/LookaheadStore.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "src/shared/libs/LibNetwork.sol";
import "test/shared/CommonTest.sol";

contract LookaheadStoreBase is CommonTest {
    /**
     * struct SetupOperator {
     *         bytes32 registrationRoot;
     *         uint256 collateralWei;
     *         uint256 numKeys;
     *         uint256 registeredAt;
     *         uint256 unregisteredAt;
     *         uint256 slashedAt;
     *         uint256 optedInAt;
     *         uint256 optedOutAt;
     *         address committer;
     *         address slasher;
     *     }
     *
     *     MockURC internal urc;
     *     LookaheadStore internal lookaheadStore;
     *
     *     uint256 internal constant NUM_OPERATORS = 10;
     *     uint256 internal constant EPOCH_START =
     * LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS
     *         + 5 * LibPreconfConstants.SECONDS_IN_EPOCH;
     *
     *     address internal overseer = vm.addr(uint256(bytes32("overseer")));
     *     address internal lookaheadSlasher = vm.addr(uint256(bytes32("lookaheadSlasher")));
     *     address internal preconfSlasher = vm.addr(uint256(bytes32("preconfSlasher")));
     *     address internal preconfRouter = vm.addr(uint256(bytes32("preconfRouter")));
     *     bytes32 internal posterRegistrationRoot = bytes32("poster_registration_root");
     *     address internal posterOwnerAndCommitter = vm.addr(uint256(posterRegistrationRoot));
     *
     *     function setUpOnEthereum() internal virtual override {
     *         urc = new MockURC();
     *         lookaheadStore =
     *             new LookaheadStore(address(urc), lookaheadSlasher, preconfSlasher, address(0),
     * overseer);
     *
     *         // Wrap time to the beginning of an arbitrary epoch
     *         vm.warp(EPOCH_START);
     *     }
     *
     *     // Modifiers
     *     //
     * ---------------------------------------------------------------------------------------------
     *
     *     /// @dev Use mainnet chainid since we are using mainnet genesis as reference
     *     modifier useMainnet() {
     *         vm.chainId(LibNetwork.ETHEREUM_MAINNET);
     *         _;
     *     }
     *
     *     modifier setupURCAndPrepareInputsFuzz(
     *         SetupOperator memory _lookaheadPostingOperator,
     *         SetupOperator[] memory _lookaheadOperators,
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
     *     ) {
     *         _setupLookaheadPostingOperator(_lookaheadPostingOperator);
     *         _setupOperatorsInLookahead(_lookaheadOperators);
     *         _validateLookaheadSlots(_lookaheadSlots, _lookaheadOperators);
     *         _;
     *     }
     *
     *     // Internal helpers
     *     //
     * ---------------------------------------------------------------------------------------------
     *
     *     function _setupURCAndPrepareInputs(uint256 _numOperators)
     *         internal
     *         returns (
     *             SetupOperator memory,
     *             SetupOperator[] memory,
     *             ILookaheadStore.LookaheadSlot[] memory
     *         )
     *     {
     *         SetupOperator memory _lookaheadPostingOperator;
     *         SetupOperator[] memory _lookaheadOperators = new SetupOperator[](_numOperators);
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots =
     *             new ILookaheadStore.LookaheadSlot[](_numOperators);
     *
     *         _setupLookaheadPostingOperator(_lookaheadPostingOperator);
     *         _setupOperatorsInLookahead(_lookaheadOperators);
     *         _validateLookaheadSlots(_lookaheadSlots, _lookaheadOperators);
     *
     *         return (_lookaheadPostingOperator, _lookaheadOperators, _lookaheadSlots);
     *     }
     *
     *     function _setupOperatorsInLookahead(SetupOperator[] memory _operators) internal {
     *         vm.assume(_operators.length <= NUM_OPERATORS);
     *
     *         for (uint256 i; i < _operators.length; ++i) {
     *             bytes32 registrationRoot = bytes32(0x16700000 + i);
     *             address ownerAndCommitter = vm.addr(uint256(registrationRoot));
     *
     *             _operators[i].registrationRoot = registrationRoot;
     *             _operators[i].committer = ownerAndCommitter;
     *             _operators[i].slasher = preconfSlasher;
     *
     *             if (_operators[i].unregisteredAt == 0) {
     *                 _operators[i].unregisteredAt = type(uint48).max;
     *             }
     *
     *             _validateSetupOperatorData(
     *                 _operators[i],
     * lookaheadStore.getLookaheadStoreConfig().minCollateralForPreconfing
     *             );
     *
     *             _insertOperatorInURC(_operators[i]);
     *         }
     *     }
     *
     *     function _setupLookaheadPostingOperator(SetupOperator memory _operator) internal {
     *         _operator.optedOutAt = 0;
     *         _operator.unregisteredAt = type(uint48).max;
     *         _operator.slashedAt = 0;
     *
     *         _operator.registrationRoot = posterRegistrationRoot;
     *         _operator.committer = posterOwnerAndCommitter;
     *         _operator.slasher = lookaheadSlasher;
     *
     *         _validateSetupOperatorData(
     *             _operator, lookaheadStore.getLookaheadStoreConfig().minCollateralForPosting
     *         );
     *
     *         _insertOperatorInURC(_operator);
     *     }
     *
     *     function _validateSetupOperatorData(
     *         SetupOperator memory _operator,
     *         uint256 _minCollateralWei
     *     )
     *         internal
     *         view
     *     {
     *         _operator.numKeys = bound(_operator.numKeys, 1, type(uint16).max);
     *         _operator.registeredAt =
     *             bound(_operator.registeredAt, 1, EPOCH_START - 2 *
     * LibPreconfConstants.SECONDS_IN_SLOT);
     *         _operator.optedInAt = bound(
     *             _operator.optedInAt,
     *             _operator.registeredAt,
     *             EPOCH_START - 2 * LibPreconfConstants.SECONDS_IN_SLOT
     *         );
     *
     *         if (_operator.optedOutAt != 0) {
     *             _operator.optedOutAt = bound(_operator.optedOutAt, EPOCH_START, block.timestamp);
     *         }
     *
     *         if (_operator.unregisteredAt != type(uint48).max) {
     *             _operator.unregisteredAt = bound(_operator.unregisteredAt, EPOCH_START,
     * block.timestamp);
     *         }
     *
     *         if (_operator.slashedAt != 0) {
     *             _operator.slashedAt = bound(_operator.slashedAt, EPOCH_START, block.timestamp);
     *         }
     *
     *         _operator.collateralWei =
     *             bound(_operator.collateralWei, _minCollateralWei, type(uint80).max);
     *     }
     *
     *     function _insertOperatorInURC(SetupOperator memory _operator) internal {
     *         urc.setOperatorData(
     *             _operator.registrationRoot,
     *             _operator.committer,
     *             _operator.collateralWei,
     *             _operator.numKeys,
     *             _operator.registeredAt,
     *             _operator.unregisteredAt,
     *             _operator.slashedAt
     *         );
     *
     *         urc.setSlasherCommitment(
     *             _operator.registrationRoot,
     *             _operator.slasher,
     *             _operator.optedInAt,
     *             _operator.optedOutAt,
     *             _operator.committer
     *         );
     *
     *         urc.setHistoricalCollateral(
     *             _operator.registrationRoot,
     *             LibPreconfConstants.ETHEREUM_MAINNET_BEACON_GENESIS,
     *             _operator.collateralWei
     *         );
     *     }
     *
     *     /// @notice Helper function to set blacklist status for operators in tests
     *     /// @param _registrationRoot The operator registration root
     *     /// @param _blacklistedAt Timestamp when blacklisted (0 means never blacklisted)
     *     /// @param _unblacklistedAt Timestamp when unblacklisted (0 means never unblacklisted)
     *     function _setOperatorBlacklistStatus(
     *         bytes32 _registrationRoot,
     *         uint48 _blacklistedAt,
     *         uint48 _unblacklistedAt
     *     )
     *         internal
     *     {
     *         // First blacklist the operator if needed
     *         if (_blacklistedAt > 0) {
     *             vm.warp(_blacklistedAt);
     *             vm.prank(overseer);
     *             lookaheadStore.blacklistOperator(_registrationRoot);
     *         }
     *
     *         // Then unblacklist the operator if needed
     *         if (_unblacklistedAt > 0 && _unblacklistedAt > _blacklistedAt) {
     *             vm.warp(_unblacklistedAt);
     *             vm.prank(overseer);
     *             lookaheadStore.unblacklistOperator(_registrationRoot);
     *         }
     *
     *         // Reset time back to EPOCH_START
     *         vm.warp(EPOCH_START);
     *     }
     *
     *     function _validateLookaheadSlots(
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots,
     *         SetupOperator[] memory _operators
     *     )
     *         internal
     *         pure
     *     {
     *         vm.assume(_lookaheadSlots.length >= _operators.length);
     *
     *         uint256 nextEpochStart = EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
     *
     *         for (uint256 i; i < _operators.length; ++i) {
     *             ILookaheadStore.LookaheadSlot memory lookaheadSlot = _lookaheadSlots[i];
     *             SetupOperator memory operator = _operators[i];
     *
     *             lookaheadSlot.timestamp = nextEpochStart + i *
     * LibPreconfConstants.SECONDS_IN_SLOT;
     *             lookaheadSlot.committer = operator.committer;
     *             lookaheadSlot.registrationRoot = operator.registrationRoot;
     *             lookaheadSlot.validatorLeafIndex =
     *                 bound(lookaheadSlot.validatorLeafIndex, 0, operator.numKeys - 1);
     *         }
     *     }
     *
     *     function _buildLookaheadCommitment(
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots,
     *         uint256 _numLookaheadSlots
     *     )
     *         internal
     *         view
     *         returns (ISlasher.SignedCommitment memory)
     *     {
     *         ISlasher.Commitment memory commitment = ISlasher.Commitment({
     *             commitmentType: 0,
     *             payload: abi.encode(_trimLookaheadSlots(_lookaheadSlots, _numLookaheadSlots)),
     *             slasher: lookaheadSlasher
     *         });
     *
     *         bytes32 commitmentHash = keccak256(abi.encode(commitment));
     *         // `posterRegistrationRoot` is essentially treated as the private key by foundry
     *         (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(posterRegistrationRoot),
     * commitmentHash);
     *
     *         return ISlasher.SignedCommitment({
     *             commitment: commitment,
     *             signature: abi.encodePacked(r, s, v)
     *         });
     *     }
     *
     *     function _updateLookahead(ISlasher.SignedCommitment memory _signedCommitment)
     *         internal
     *         returns (bytes26)
     *     {
     *         return lookaheadStore.updateLookahead(posterRegistrationRoot,
     * abi.encode(_signedCommitment));
     *     }
     *
     *     function _updateLookahead(
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots,
     *         uint256 _numLookaheadSlots
     *     )
     *         internal
     *         returns (bytes26)
     *     {
     *         return lookaheadStore.updateLookahead(
     *             bytes32(0), abi.encode(_trimLookaheadSlots(_lookaheadSlots, _numLookaheadSlots))
     *         );
     *     }
     *
     *     /// @dev This is required because the size of lookahead slots array may exceed the length
     * of
     * the
     *     /// the total available operators
     *     function _trimLookaheadSlots(
     *         ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots,
     *         uint256 _numLookaheadSlots
     *     )
     *         internal
     *         pure
     *         returns (ILookaheadStore.LookaheadSlot[] memory)
     *     {
     *         ILookaheadStore.LookaheadSlot[] memory lookaheadSlots =
     *             new ILookaheadStore.LookaheadSlot[](_numLookaheadSlots);
     *
     *         for (uint256 i; i < _numLookaheadSlots; ++i) {
     *             lookaheadSlots[i] = _lookaheadSlots[i];
     *         }
     *
     *         return lookaheadSlots;
     *     }
     */

    }
