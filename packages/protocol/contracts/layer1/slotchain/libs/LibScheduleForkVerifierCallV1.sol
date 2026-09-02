// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IScheduleForkVerifierV1 } from "../iface/IScheduleForkVerifierV1.sol";

/// @title Exact authenticated calls to a Schedule fork verifier
/// @custom:security-contact security@taiko.xyz
library LibScheduleForkVerifierCallV1 {
    bytes4 internal constant CONFIG_MAGIC = 0x53465631; // SFV1
    bytes4 internal constant CARRIER_MAGIC = 0x53464331; // SFC1
    bytes4 internal constant CONFIG_SELECTOR = 0x44efa773;
    bytes4 internal constant VERIFY_SELECTOR = 0x7e981e0b;

    uint256 internal constant CONFIGURATION_READ_GAS = 100_000;
    uint256 internal constant CONFIGURATION_RETURN_BYTES = 320;
    uint256 internal constant CARRIER_RETURN_BYTES = 256;
    uint256 internal constant MAX_FORK_WITNESS_BYTES = 131_072;
    uint64 internal constant MIN_VERIFICATION_GAS = 100_000;
    uint64 internal constant MAX_VERIFICATION_GAS = 5_000_000;

    uint256 private constant _PRECALL_GAS_MARGIN = 10_000;
    uint256 private constant _VERIFY_FIXED_CALLDATA_BYTES = 100;
    uint256 private constant _VERIFY_WITNESS_OFFSET_WORD = 0x40;

    bytes32 private constant _OUTPUT_SCHEMA_HASH =
        0x3a480130319b3cebce02d217988e89c83c6bd6e71ff93c25bc4fc38e51fbe2c0;

    string private constant _CONSTANTS_DOMAIN = "slot-chain-schedule-fork-constants-v1";
    string private constant _CONFIGURATION_DOMAIN = "slot-chain-schedule-fork-verifier-config-v1";
    string private constant _STATEMENT_DOMAIN = "slot-chain-schedule-carrier-statement-v1";

    /// @dev The immutable route words retained by ScheduleOracle.
    struct Route {
        bytes4 forkDigest;
        uint64 firstWindow;
        bytes4 successorForkDigest;
        uint64 successorFirstWindow;
        address verifier;
        bytes32 runtimeHash;
        bytes32 configurationHash;
        bytes4 selector;
        uint64 gasLimit;
    }

    /// @dev The complete SFV1 fork-specific configuration committed by one route.
    struct ForkConfiguration {
        uint64 beaconSlotGindex;
        uint64 executionPayloadGindex;
        uint64 stateRootGindex;
        uint64 prevRandaoGindex;
        uint64 timestampGindex;
        uint64 blockHashGindex;
        bytes32 witnessSchemaHash;
    }

    /// @dev The exact authenticated SFC1 result used by Schedule's carrier/header join.
    struct Carrier {
        bytes32 statementHash;
        uint64 parentSlot;
        uint64 executionBlockNumber;
        uint64 payloadTimestamp;
        bytes32 blockHash;
        bytes32 stateRoot;
        bytes32 prevRandao;
    }

    /// @dev Recomputes the normative configuration commitment from explicit typed fields.
    /// @param _forkDigest The nonzero L1 fork digest.
    /// @param _configuration The six generalized indices and witness-schema commitment.
    /// @param _selector The exact SFC1 verification selector.
    /// @param _gasLimit The bounded verification stipend.
    /// @return hash_ The exact fork-verifier configuration hash.
    function configurationHash(
        bytes4 _forkDigest,
        ForkConfiguration memory _configuration,
        bytes4 _selector,
        uint64 _gasLimit
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        _requireConfigurationFields(_forkDigest, _configuration, _selector, _gasLimit);
        bytes32 constantsHash = keccak256(
            abi.encodePacked(
                _CONSTANTS_DOMAIN,
                _configuration.beaconSlotGindex,
                _configuration.executionPayloadGindex,
                _configuration.stateRootGindex,
                _configuration.prevRandaoGindex,
                _configuration.timestampGindex,
                _configuration.blockHashGindex
            )
        );
        return keccak256(
            abi.encodePacked(
                _CONFIGURATION_DOMAIN,
                _forkDigest,
                constantsHash,
                _configuration.witnessSchemaHash,
                _OUTPUT_SCHEMA_HASH,
                _selector,
                _gasLimit
            )
        );
    }

    /// @dev Rechecks an immutable verifier's runtime and exact 320-byte SFV1 configuration.
    /// @param _route The ScheduleOracle-retained immutable route words.
    /// @return configuration_ The authenticated fork-specific configuration.
    function requireVerifier(Route memory _route)
        internal
        view
        returns (ForkConfiguration memory configuration_)
    {
        _requireRoute(_route);
        address verifier = _route.verifier;
        _requireRuntime(verifier, _route.runtimeHash);

        bytes memory raw = _staticcallExact(
            verifier,
            abi.encodePacked(CONFIG_SELECTOR),
            CONFIGURATION_READ_GAS,
            CONFIGURATION_RETURN_BYTES
        );
        if (_word(raw, 0) != bytes32(CONFIG_MAGIC) || _word(raw, 1) != bytes32(_route.forkDigest)) {
            revert MalformedScheduleVerifierConfiguration();
        }

        configuration_.beaconSlotGindex = _u64(raw, 2);
        configuration_.executionPayloadGindex = _u64(raw, 3);
        configuration_.stateRootGindex = _u64(raw, 4);
        configuration_.prevRandaoGindex = _u64(raw, 5);
        configuration_.timestampGindex = _u64(raw, 6);
        configuration_.blockHashGindex = _u64(raw, 7);
        configuration_.witnessSchemaHash = _word(raw, 8);
        if (
            _word(raw, 9) != _route.configurationHash
                || configurationHash(
                        _route.forkDigest, configuration_, _route.selector, _route.gasLimit
                    ) != _route.configurationHash
        ) {
            revert ScheduleVerifierConfigurationMismatch();
        }
    }

    /// @dev Reauthenticates the route, dispatches the exact canonical dynamic call, decodes the
    ///      exact SFC1 result and independently recomputes its statement binding in Oracle context.
    /// @param _storedRoute The ScheduleOracle-retained immutable route words.
    /// @param _requestedForkDigest The caller-selected mapping key, repeated for exact binding.
    /// @param _window The public Schedule window independently bound into the interval and statement.
    /// @param _forkWitness The exact zero-copy fork-specific witness slice.
    /// @param _beaconBlockRoot The nonzero root obtained by ScheduleOracle from EIP-4788.
    /// @return carrier_ The authenticated carrier result.
    function verifyCarrier(
        Route storage _storedRoute,
        bytes4 _requestedForkDigest,
        uint64 _window,
        bytes calldata _forkWitness,
        bytes32 _beaconBlockRoot
    )
        internal
        view
        returns (Carrier memory carrier_)
    {
        Route memory route = _storedRoute;
        _requireCarrierContext(
            route, _requestedForkDigest, _window, _forkWitness.length, _beaconBlockRoot
        );
        requireVerifier(route);

        bytes memory input = _encodeCarrierCall(_forkWitness, _beaconBlockRoot);
        // The configuration read cannot mutate code under STATICCALL, but the second check is an
        // explicit defense-in-depth join immediately adjacent to the output-authority call.
        _requireRuntime(route.verifier, route.runtimeHash);
        bytes memory raw =
            _staticcallExact(route.verifier, input, route.gasLimit, CARRIER_RETURN_BYTES);
        if (_word(raw, 0) != bytes32(CARRIER_MAGIC)) revert MalformedScheduleCarrierReturn();

        carrier_.statementHash = _word(raw, 1);
        carrier_.parentSlot = _u64(raw, 2);
        carrier_.executionBlockNumber = _u64(raw, 3);
        carrier_.payloadTimestamp = _u64(raw, 4);
        carrier_.blockHash = _word(raw, 5);
        carrier_.stateRoot = _word(raw, 6);
        carrier_.prevRandao = _word(raw, 7);
        if (
            carrier_.statementHash == bytes32(0) || carrier_.parentSlot == 0
                || carrier_.executionBlockNumber == 0 || carrier_.payloadTimestamp == 0
                || carrier_.blockHash == bytes32(0) || carrier_.stateRoot == bytes32(0)
                || carrier_.prevRandao == bytes32(0)
        ) {
            revert MalformedScheduleCarrierReturn();
        }

        bytes32 expectedStatement = keccak256(
            abi.encodePacked(
                _STATEMENT_DOMAIN,
                block.chainid,
                address(this),
                route.forkDigest,
                _window,
                _beaconBlockRoot,
                carrier_.parentSlot,
                carrier_.executionBlockNumber,
                carrier_.payloadTimestamp,
                carrier_.blockHash,
                carrier_.stateRoot,
                carrier_.prevRandao
            )
        );
        if (carrier_.statementHash != expectedStatement) {
            revert ScheduleCarrierStatementMismatch();
        }
    }

    /// @dev Constructs the sole ABI encoding accepted by `verifyScheduleCarrierV1`.
    function _encodeCarrierCall(
        bytes calldata _witness,
        bytes32 _beaconBlockRoot
    )
        private
        pure
        returns (bytes memory input_)
    {
        uint256 witnessLength = _witness.length;
        uint256 paddedLength = (witnessLength + 31) & ~uint256(31);
        input_ = new bytes(_VERIFY_FIXED_CALLDATA_BYTES + paddedLength);
        bytes4 selector = VERIFY_SELECTOR;
        assembly ("memory-safe") {
            let data := add(input_, 32)
            mstore(data, selector)
            mstore(add(data, 4), _VERIFY_WITNESS_OFFSET_WORD)
            mstore(add(data, 36), _beaconBlockRoot)
            mstore(add(data, 68), witnessLength)
            calldatacopy(add(data, _VERIFY_FIXED_CALLDATA_BYTES), _witness.offset, witnessLength)
        }
    }

    /// @dev Performs a zero-value bounded STATICCALL and copies only exact-size returndata.
    function _staticcallExact(
        address _target,
        bytes memory _input,
        uint256 _gasLimit,
        uint256 _returnLength
    )
        private
        view
        returns (bytes memory output_)
    {
        uint256 minimumGas = _gasLimit + (_gasLimit + 62) / 63 + _PRECALL_GAS_MARGIN;
        if (gasleft() < minimumGas) revert InsufficientScheduleVerifierCallGas();

        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := staticcall(_gasLimit, _target, add(_input, 32), mload(_input), 0, 0)
            actualLength := returndatasize()
        }
        if (!success) revert ScheduleVerifierCallFailed(_target);
        if (actualLength != _returnLength) {
            revert ScheduleVerifierReturnLengthMismatch(actualLength, _returnLength);
        }
        output_ = new bytes(_returnLength);
        assembly ("memory-safe") {
            returndatacopy(add(output_, 32), 0, _returnLength)
        }
    }

    /// @dev Rejects an empty or internally inconsistent retained route before any external call.
    function _requireRoute(Route memory _route) private pure {
        bool noSuccessor =
            _route.successorForkDigest == bytes4(0) && _route.successorFirstWindow == 0;
        bool validSuccessor = _route.successorForkDigest != bytes4(0)
            && _route.successorForkDigest != _route.forkDigest
            && _route.successorFirstWindow > _route.firstWindow;
        if (
            _route.forkDigest == bytes4(0) || _route.verifier == address(0)
                || _route.runtimeHash == bytes32(0) || _route.configurationHash == bytes32(0)
                || _route.selector != VERIFY_SELECTOR || _route.gasLimit < MIN_VERIFICATION_GAS
                || _route.gasLimit > MAX_VERIFICATION_GAS || (!noSuccessor && !validSuccessor)
                || IScheduleForkVerifierV1.scheduleForkVerifierConfigV1.selector != CONFIG_SELECTOR
                || IScheduleForkVerifierV1.verifyScheduleCarrierV1.selector != VERIFY_SELECTOR
        ) {
            revert InvalidScheduleVerifierRoute();
        }
    }

    /// @dev Rejects digest substitution, an obsolete fork interval and invalid dynamic inputs
    ///      before invoking either verifier entry point.
    function _requireCarrierContext(
        Route memory _route,
        bytes4 _requestedForkDigest,
        uint64 _window,
        uint256 _witnessLength,
        bytes32 _beaconBlockRoot
    )
        private
        pure
    {
        _requireRoute(_route);
        if (
            _requestedForkDigest == bytes4(0) || _requestedForkDigest != _route.forkDigest
                || _window < _route.firstWindow
                || (_route.successorForkDigest != bytes4(0)
                    && _window >= _route.successorFirstWindow)
        ) {
            revert ForkWindowOutsideInterval(_window);
        }
        if (
            _witnessLength == 0 || _witnessLength > MAX_FORK_WITNESS_BYTES
                || _beaconBlockRoot == bytes32(0)
        ) {
            revert InvalidScheduleCarrierContext();
        }
    }

    /// @dev Rechecks one manifest-pinned immutable verifier runtime.
    function _requireRuntime(address _verifier, bytes32 _runtimeHash) private view {
        bytes32 actualRuntimeHash;
        assembly ("memory-safe") {
            actualRuntimeHash := extcodehash(_verifier)
        }
        if (actualRuntimeHash != _runtimeHash) revert ScheduleVerifierRuntimeMismatch();
    }

    /// @dev Validates fields before committing or trusting their configuration hash.
    function _requireConfigurationFields(
        bytes4 _forkDigest,
        ForkConfiguration memory _configuration,
        bytes4 _selector,
        uint64 _gasLimit
    )
        private
        pure
    {
        if (
            _forkDigest == bytes4(0) || _configuration.beaconSlotGindex == 0
                || _configuration.executionPayloadGindex == 0 || _configuration.stateRootGindex == 0
                || _configuration.prevRandaoGindex == 0 || _configuration.timestampGindex == 0
                || _configuration.blockHashGindex == 0
                || _configuration.witnessSchemaHash == bytes32(0) || _selector != VERIFY_SELECTOR
                || _gasLimit < MIN_VERIFICATION_GAS || _gasLimit > MAX_VERIFICATION_GAS
        ) {
            revert InvalidScheduleVerifierConfiguration();
        }
    }

    /// @dev Loads one ABI word from an already exact-sized return buffer.
    function _word(bytes memory _raw, uint256 _index) private pure returns (bytes32 word_) {
        assembly ("memory-safe") {
            word_ := mload(add(add(_raw, 32), mul(_index, 32)))
        }
    }

    /// @dev Decodes one canonically zero-padded uint64 ABI word.
    function _u64(bytes memory _raw, uint256 _index) private pure returns (uint64 value_) {
        uint256 value = uint256(_word(_raw, _index));
        if (value > type(uint64).max) revert NonCanonicalScheduleVerifierUint64();
        return uint64(value);
    }

    error InsufficientScheduleVerifierCallGas();
    error ForkWindowOutsideInterval(uint64 window);
    error InvalidScheduleCarrierContext();
    error InvalidScheduleVerifierConfiguration();
    error InvalidScheduleVerifierRoute();
    error MalformedScheduleCarrierReturn();
    error MalformedScheduleVerifierConfiguration();
    error NonCanonicalScheduleVerifierUint64();
    error ScheduleCarrierStatementMismatch();
    error ScheduleVerifierCallFailed(address verifier);
    error ScheduleVerifierConfigurationMismatch();
    error ScheduleVerifierReturnLengthMismatch(uint256 actual, uint256 expected);
    error ScheduleVerifierRuntimeMismatch();
}
