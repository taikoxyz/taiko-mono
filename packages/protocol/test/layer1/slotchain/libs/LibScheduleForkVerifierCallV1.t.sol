// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IScheduleForkVerifierV1
} from "../../../../contracts/layer1/slotchain/iface/IScheduleForkVerifierV1.sol";
import {
    ScheduleSszMultiproofVerifierV1
} from "../../../../contracts/layer1/slotchain/impl/ScheduleSszMultiproofVerifierV1.sol";
import {
    LibScheduleForkVerifierCallV1
} from "../../../../contracts/layer1/slotchain/libs/LibScheduleForkVerifierCallV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract ScheduleForkVerifierCallHarness {
    LibScheduleForkVerifierCallV1.Route private _route;

    function setRoute(LibScheduleForkVerifierCallV1.Route calldata _route_) external {
        _route = _route_;
    }

    function configurationHash(
        bytes4 _forkDigest,
        LibScheduleForkVerifierCallV1.ForkConfiguration calldata _configuration,
        bytes4 _selector,
        uint64 _gasLimit
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibScheduleForkVerifierCallV1.configurationHash(
            _forkDigest, _configuration, _selector, _gasLimit
        );
    }

    function requireVerifier()
        external
        view
        returns (LibScheduleForkVerifierCallV1.ForkConfiguration memory configuration_)
    {
        LibScheduleForkVerifierCallV1.Route memory route = _route;
        return LibScheduleForkVerifierCallV1.requireVerifier(route);
    }

    function verifyCarrier(
        bytes4 _requestedForkDigest,
        uint64 _window,
        bytes calldata _forkWitness,
        bytes32 _beaconBlockRoot
    )
        external
        view
        returns (LibScheduleForkVerifierCallV1.Carrier memory carrier_)
    {
        return LibScheduleForkVerifierCallV1.verifyCarrier(
            _route, _requestedForkDigest, _window, _forkWitness, _beaconBlockRoot
        );
    }
}

contract ConfigurableScheduleForkVerifier {
    bytes4 private constant _CONFIG_SELECTOR = 0x44efa773;
    bytes4 private constant _VERIFY_SELECTOR = 0x7e981e0b;

    bytes private _configurationReturn;
    bytes private _carrierReturn;
    bytes32 private _expectedCarrierCalldataHash;
    uint256 private _bombLength;
    bool private _failConfiguration;
    bool private _failCarrier;
    bool private _enforceExactConfigurationCall;
    uint256 private _minimumConfigurationEntryGas;

    function configureReturns(
        bytes calldata _configuration,
        bytes calldata _carrier
    )
        external
    {
        _configurationReturn = _configuration;
        _carrierReturn = _carrier;
    }

    function setExpectedCarrierCalldataHash(bytes32 _hash) external {
        _expectedCarrierCalldataHash = _hash;
    }

    function setBombLength(uint256 _length) external {
        _bombLength = _length;
    }

    function setFailures(bool _configuration, bool _carrier) external {
        _failConfiguration = _configuration;
        _failCarrier = _carrier;
    }

    function enforceConfigurationCall(uint256 _minimumEntryGas) external {
        _enforceExactConfigurationCall = true;
        _minimumConfigurationEntryGas = _minimumEntryGas;
    }

    fallback() external {
        bytes4 selector = msg.sig;
        if (selector == _CONFIG_SELECTOR) {
            if (_failConfiguration) revert ForcedFailure();
            if (
                _enforceExactConfigurationCall
                    && (msg.data.length != 4
                        || gasleft() > 100_000
                        || gasleft() < _minimumConfigurationEntryGas)
            ) {
                revert UnexpectedConfigurationCall();
            }
            bytes memory response = _configurationReturn;
            assembly ("memory-safe") {
                return(add(response, 32), mload(response))
            }
        }
        if (selector == _VERIFY_SELECTOR) {
            if (_failCarrier) revert ForcedFailure();
            bytes32 expectedHash = _expectedCarrierCalldataHash;
            if (expectedHash != bytes32(0) && keccak256(msg.data) != expectedHash) {
                revert UnexpectedCarrierCalldata();
            }
            uint256 bombLength = _bombLength;
            if (bombLength != 0) {
                bytes memory bomb = new bytes(bombLength);
                assembly ("memory-safe") {
                    return(add(bomb, 32), mload(bomb))
                }
            }
            bytes memory response = _carrierReturn;
            assembly ("memory-safe") {
                return(add(response, 32), mload(response))
            }
        }
        revert UnexpectedSelector();
    }

    error ForcedFailure();
    error UnexpectedCarrierCalldata();
    error UnexpectedConfigurationCall();
    error UnexpectedSelector();
}

contract LibScheduleForkVerifierCallV1Test is Test {
    bytes4 private constant _FORK_DIGEST = 0x46554c55;
    bytes4 private constant _SUCCESSOR_DIGEST = 0x4e455854;
    bytes4 private constant _CONFIG_MAGIC = 0x53465631;
    bytes4 private constant _CARRIER_MAGIC = 0x53464331;
    bytes4 private constant _CONFIG_SELECTOR = 0x44efa773;
    bytes4 private constant _VERIFY_SELECTOR = 0x7e981e0b;

    uint64 private constant _FIRST_WINDOW = 10;
    uint64 private constant _WINDOW = 42;
    uint64 private constant _PARENT_SLOT = 123_456;
    uint64 private constant _EXECUTION_BLOCK = 987_654;
    uint64 private constant _PAYLOAD_TIMESTAMP = 1_700_000_000;
    uint64 private constant _DEFAULT_GAS_LIMIT = 1_000_000;

    bytes32 private constant _BEACON_ROOT = keccak256("beacon-root");
    bytes32 private constant _BLOCK_HASH = keccak256("block-hash");
    bytes32 private constant _STATE_ROOT = keccak256("state-root");
    bytes32 private constant _PREV_RANDAO = keccak256("prev-randao");
    bytes32 private constant _WITNESS_SCHEMA_HASH =
        0x4d3c1d3a7f2921c2f8e7526a2e8aa2c47dc6bdcd3dc9e2b14c58f2b9d39ed30f;
    bytes32 private constant _INDEPENDENT_ROOT =
        0xd97d74b27bcf682f7261641d7cea2ab9c9336b1360054c3670a920e251d90817;

    ScheduleForkVerifierCallHarness private _harness;
    ConfigurableScheduleForkVerifier private _mock;

    function setUp() public {
        _harness = new ScheduleForkVerifierCallHarness();
        _mock = new ConfigurableScheduleForkVerifier();
        _installMockRoute(_DEFAULT_GAS_LIMIT, bytes4(0), 0);
    }

    function test_configurationHash_AgreesWithIndependentFormulaAndRealVerifier() external {
        LibScheduleForkVerifierCallV1.ForkConfiguration memory configuration = _configuration();
        bytes32 independent = _independentConfigurationHash(_FORK_DIGEST, _DEFAULT_GAS_LIMIT);
        assertEq(
            _harness.configurationHash(
                _FORK_DIGEST, configuration, _VERIFY_SELECTOR, _DEFAULT_GAS_LIMIT
            ),
            independent
        );

        ScheduleSszMultiproofVerifierV1 real =
            new ScheduleSszMultiproofVerifierV1(_FORK_DIGEST, _DEFAULT_GAS_LIMIT);
        (,,,,,,,,, bytes32 verifierHash) = real.scheduleForkVerifierConfigV1();
        assertEq(verifierHash, independent);

        _harness.setRoute(_route(address(real), _DEFAULT_GAS_LIMIT, bytes4(0), 0));
        LibScheduleForkVerifierCallV1.ForkConfiguration memory read = _harness.requireVerifier();
        _assertConfiguration(read);
    }

    function test_configurationHash_RevertWhen_AnyCommittedFieldIsInvalid() external {
        LibScheduleForkVerifierCallV1.ForkConfiguration memory configuration = _configuration();

        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector);
        _harness.configurationHash(bytes4(0), configuration, _VERIFY_SELECTOR, _DEFAULT_GAS_LIMIT);

        for (uint256 index; index < 6; ++index) {
            LibScheduleForkVerifierCallV1.ForkConfiguration memory changed = _configuration();
            if (index == 0) changed.beaconSlotGindex = 0;
            if (index == 1) changed.executionPayloadGindex = 0;
            if (index == 2) changed.stateRootGindex = 0;
            if (index == 3) changed.prevRandaoGindex = 0;
            if (index == 4) changed.timestampGindex = 0;
            if (index == 5) changed.blockHashGindex = 0;
            vm.expectRevert(
                LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector
            );
            _harness.configurationHash(_FORK_DIGEST, changed, _VERIFY_SELECTOR, _DEFAULT_GAS_LIMIT);
        }

        configuration.witnessSchemaHash = bytes32(0);
        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector);
        _harness.configurationHash(
            _FORK_DIGEST, configuration, _VERIFY_SELECTOR, _DEFAULT_GAS_LIMIT
        );

        configuration = _configuration();
        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector);
        _harness.configurationHash(
            _FORK_DIGEST, configuration, bytes4(uint32(_VERIFY_SELECTOR) + 1), _DEFAULT_GAS_LIMIT
        );

        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector);
        _harness.configurationHash(_FORK_DIGEST, configuration, _VERIFY_SELECTOR, 99_999);

        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleVerifierConfiguration.selector);
        _harness.configurationHash(_FORK_DIGEST, configuration, _VERIFY_SELECTOR, 5_000_001);
    }

    function test_requireVerifier_AcceptsInclusiveMinimumAndMaximumGasRoutes() external {
        _installMockRoute(100_000, bytes4(0), 0);
        _assertConfiguration(_harness.requireVerifier());

        _installMockRoute(5_000_000, bytes4(0), 0);
        _assertConfiguration(_harness.requireVerifier());
    }

    function test_requireVerifier_UsesExactFourByteSelectorAndFixedGasStipend() external {
        _mock.enforceConfigurationCall(70_000);
        _assertConfiguration(_harness.requireVerifier());
    }

    function test_requireVerifier_RevertWhen_RouteDigestOrSuccessorIsMalformed() external {
        LibScheduleForkVerifierCallV1.Route memory route =
            _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);

        route.forkDigest = bytes4(0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), _FIRST_WINDOW + 1);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, _SUCCESSOR_DIGEST, 0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, _FORK_DIGEST, _FIRST_WINDOW + 1);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, _SUCCESSOR_DIGEST, _FIRST_WINDOW);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );
    }

    function test_requireVerifier_RevertWhen_RouteFieldsAreMalformed() external {
        LibScheduleForkVerifierCallV1.Route memory route =
            _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);

        route.verifier = address(0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);
        route.runtimeHash = bytes32(0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);
        route.configurationHash = bytes32(0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);
        route.selector = bytes4(uint32(_VERIFY_SELECTOR) + 1);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), 99_999, bytes4(0), 0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );

        route = _route(address(_mock), 5_000_001, bytes4(0), 0);
        _expectRequireVerifierRevert(
            route, LibScheduleForkVerifierCallV1.InvalidScheduleVerifierRoute.selector
        );
    }

    function test_requireVerifier_RevertWhen_RuntimeHashDoesNotMatch() external {
        LibScheduleForkVerifierCallV1.Route memory route =
            _route(address(_mock), _DEFAULT_GAS_LIMIT, bytes4(0), 0);
        route.runtimeHash = bytes32(uint256(1));
        _harness.setRoute(route);
        vm.expectRevert(LibScheduleForkVerifierCallV1.ScheduleVerifierRuntimeMismatch.selector);
        _harness.requireVerifier();
    }

    function test_requireVerifier_RevertWhen_Sfv1CallFailsOrLengthIsNotExact() external {
        _mock.setFailures(true, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierCallFailed.selector, address(_mock)
            )
        );
        _harness.requireVerifier();
        _mock.setFailures(false, false);

        bytes memory valid = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
        _mock.configureReturns(_slice(valid, 0, 319), _validCarrierReturn(_WINDOW));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierReturnLengthMismatch.selector,
                319,
                320
            )
        );
        _harness.requireVerifier();

        _mock.configureReturns(bytes.concat(valid, hex"00"), _validCarrierReturn(_WINDOW));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierReturnLengthMismatch.selector,
                321,
                320
            )
        );
        _harness.requireVerifier();
    }

    function test_requireVerifier_RevertWhen_Sfv1MagicDigestOrUint64IsMalformed() external {
        bytes memory raw = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
        _writeWord(raw, 0, bytes32(bytes4(0xdeadbeef)));
        _expectMalformedConfiguration(raw);

        raw = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
        _writeWord(raw, 32, bytes32(_SUCCESSOR_DIGEST));
        _expectMalformedConfiguration(raw);

        for (uint256 index = 2; index <= 7; ++index) {
            raw = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
            _writeWord(raw, index * 32, bytes32(uint256(type(uint64).max) + 1));
            _mock.configureReturns(raw, _validCarrierReturn(_WINDOW));
            vm.expectRevert(
                LibScheduleForkVerifierCallV1.NonCanonicalScheduleVerifierUint64.selector
            );
            _harness.requireVerifier();
        }
    }

    function test_requireVerifier_RevertWhen_ConfigurationCommitmentIsInconsistent() external {
        bytes memory raw = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
        _writeWord(raw, 9 * 32, keccak256("wrong-embedded-hash"));
        _mock.configureReturns(raw, _validCarrierReturn(_WINDOW));
        vm.expectRevert(
            LibScheduleForkVerifierCallV1.ScheduleVerifierConfigurationMismatch.selector
        );
        _harness.requireVerifier();

        raw = _validConfigurationReturn(_DEFAULT_GAS_LIMIT);
        _writeWord(raw, 8 * 32, keccak256("different-schema"));
        _mock.configureReturns(raw, _validCarrierReturn(_WINDOW));
        vm.expectRevert(
            LibScheduleForkVerifierCallV1.ScheduleVerifierConfigurationMismatch.selector
        );
        _harness.requireVerifier();
    }

    function test_verifyCarrier_AcceptsRouteAndReturnsAuthenticatedCarrier() external {
        bytes memory witness = hex"010203";
        _prepareCarrierCall(witness, _WINDOW);
        LibScheduleForkVerifierCallV1.Carrier memory carrier =
            _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT);
        _assertCarrier(carrier, _WINDOW);
    }

    function test_verifyCarrier_AcceptsInclusiveMinimumAndMaximumGasStipends() external {
        bytes memory witness = hex"01";

        _installMockRoute(100_000, bytes4(0), 0);
        _prepareCarrierCallForGas(witness, _WINDOW, 100_000);
        _assertCarrier(
            _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT), _WINDOW
        );

        _installMockRoute(5_000_000, bytes4(0), 0);
        _prepareCarrierCallForGas(witness, _WINDOW, 5_000_000);
        _assertCarrier(
            _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT), _WINDOW
        );
    }

    function test_verifyCarrier_AcceptsBothEndsOfBoundedForkInterval() external {
        uint64 successorWindow = 100;
        _installMockRoute(_DEFAULT_GAS_LIMIT, _SUCCESSOR_DIGEST, successorWindow);
        bytes memory witness = hex"01";

        _prepareCarrierCall(witness, _FIRST_WINDOW);
        _assertCarrier(
            _harness.verifyCarrier(_FORK_DIGEST, _FIRST_WINDOW, witness, _BEACON_ROOT),
            _FIRST_WINDOW
        );

        _prepareCarrierCall(witness, successorWindow - 1);
        _assertCarrier(
            _harness.verifyCarrier(_FORK_DIGEST, successorWindow - 1, witness, _BEACON_ROOT),
            successorWindow - 1
        );
    }

    function test_verifyCarrier_RevertWhen_DigestOrWindowIsOutsideRoute() external {
        _installMockRoute(_DEFAULT_GAS_LIMIT, _SUCCESSOR_DIGEST, 100);
        bytes memory witness = hex"01";

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ForkWindowOutsideInterval.selector, _WINDOW
            )
        );
        _harness.verifyCarrier(_SUCCESSOR_DIGEST, _WINDOW, witness, _BEACON_ROOT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ForkWindowOutsideInterval.selector, _FIRST_WINDOW - 1
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, _FIRST_WINDOW - 1, witness, _BEACON_ROOT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ForkWindowOutsideInterval.selector, 100
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, 100, witness, _BEACON_ROOT);
    }

    function test_verifyCarrier_RevertWhen_WitnessOrBeaconRootIsInvalid() external {
        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleCarrierContext.selector);
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, "", _BEACON_ROOT);

        bytes memory oversized = new bytes(131_073);
        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleCarrierContext.selector);
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, oversized, _BEACON_ROOT);

        vm.expectRevert(LibScheduleForkVerifierCallV1.InvalidScheduleCarrierContext.selector);
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, hex"01", bytes32(0));
    }

    function test_verifyCarrier_EmitsCanonicalDynamicAbiAcrossPaddingBoundaries() external {
        uint256[6] memory lengths = [uint256(1), 31, 32, 33, 672, 131_072];
        for (uint256 i; i < lengths.length; ++i) {
            bytes memory witness = new bytes(lengths[i]);
            witness[0] = hex"03";
            witness[witness.length / 2] = hex"5a";
            witness[witness.length - 1] = hex"a5";
            _prepareCarrierCall(witness, _WINDOW);
            _assertCarrier(
                _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT), _WINDOW
            );
        }
    }

    function test_verifyCarrier_RevertWhen_Sfc1CallFailsOrLengthIsNotExact() external {
        bytes memory witness = hex"01";
        _prepareCarrierCall(witness, _WINDOW);
        _mock.setFailures(false, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierCallFailed.selector, address(_mock)
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT);
        _mock.setFailures(false, false);

        bytes memory valid = _validCarrierReturn(_WINDOW);
        _mock.configureReturns(_validConfigurationReturn(_DEFAULT_GAS_LIMIT), _slice(valid, 0, 255));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierReturnLengthMismatch.selector,
                255,
                256
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT);

        _mock.configureReturns(
            _validConfigurationReturn(_DEFAULT_GAS_LIMIT), bytes.concat(valid, hex"00")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierReturnLengthMismatch.selector,
                257,
                256
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT);
    }

    function test_verifyCarrier_RevertWhen_Sfc1MagicOrUint64IsMalformed() external {
        bytes memory witness = hex"01";
        _prepareCarrierCall(witness, _WINDOW);
        bytes memory raw = _validCarrierReturn(_WINDOW);
        _writeWord(raw, 0, bytes32(bytes4(0xdeadbeef)));
        _expectCarrierRevert(
            witness, raw, LibScheduleForkVerifierCallV1.MalformedScheduleCarrierReturn.selector
        );

        for (uint256 index = 2; index <= 4; ++index) {
            raw = _validCarrierReturn(_WINDOW);
            _writeWord(raw, index * 32, bytes32(uint256(type(uint64).max) + 1));
            _expectCarrierRevert(
                witness,
                raw,
                LibScheduleForkVerifierCallV1.NonCanonicalScheduleVerifierUint64.selector
            );
        }
    }

    function test_verifyCarrier_RevertWhen_AnyAuthenticatedOutputIsZero() external {
        bytes memory witness = hex"01";
        _prepareCarrierCall(witness, _WINDOW);
        for (uint256 index = 1; index < 8; ++index) {
            bytes memory raw = _validCarrierReturn(_WINDOW);
            _writeWord(raw, index * 32, bytes32(0));
            _expectCarrierRevert(
                witness, raw, LibScheduleForkVerifierCallV1.MalformedScheduleCarrierReturn.selector
            );
        }
    }

    function test_verifyCarrier_RevertWhen_StatementDoesNotBindOracleContext() external {
        bytes memory witness = hex"01";
        _prepareCarrierCall(witness, _WINDOW);
        bytes memory raw = _validCarrierReturn(_WINDOW);
        _writeWord(raw, 32, keccak256("unbound-statement"));
        _expectCarrierRevert(
            witness, raw, LibScheduleForkVerifierCallV1.ScheduleCarrierStatementMismatch.selector
        );
    }

    function test_verifyCarrier_RejectsReturndataBombWithoutCopyingIt() external {
        bytes memory witness = hex"01";
        _prepareCarrierCall(witness, _WINDOW);
        _mock.setBombLength(262_144);

        uint256 gasBefore = gasleft();
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleForkVerifierCallV1.ScheduleVerifierReturnLengthMismatch.selector,
                262_144,
                256
            )
        );
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _BEACON_ROOT);
        assertLt(gasBefore - gasleft(), 1_000_000);
    }

    function test_requireVerifier_RevertBeforeCallWhen_PreCallGasIsTooLow() external {
        bytes memory input = abi.encodeCall(ScheduleForkVerifierCallHarness.requireVerifier, ());
        (bool success, bytes memory returndata) = address(_harness).call{ gas: 110_000 }(input);
        assertFalse(success);
        assertEq(
            bytes4(returndata),
            LibScheduleForkVerifierCallV1.InsufficientScheduleVerifierCallGas.selector
        );
    }

    function test_verifyCarrier_AcceptsIndependentRealSszGolden() external {
        ScheduleSszMultiproofVerifierV1 real =
            new ScheduleSszMultiproofVerifierV1(_FORK_DIGEST, 4_000_000);
        _harness.setRoute(_route(address(real), 4_000_000, bytes4(0), 0));
        bytes memory witness = _validSszWitness();

        LibScheduleForkVerifierCallV1.Carrier memory carrier =
            _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, witness, _INDEPENDENT_ROOT);
        assertEq(carrier.parentSlot, _PARENT_SLOT);
        assertEq(carrier.executionBlockNumber, _EXECUTION_BLOCK);
        assertEq(carrier.payloadTimestamp, _PAYLOAD_TIMESTAMP);
        assertEq(carrier.blockHash, sha256("block-hash"));
        assertEq(carrier.stateRoot, sha256("state-root"));
        assertEq(carrier.prevRandao, sha256("prev-randao"));
    }

    function _installMockRoute(
        uint64 _gasLimit,
        bytes4 _successorDigest,
        uint64 _successorWindow
    )
        private
    {
        _mock.configureReturns(_validConfigurationReturn(_gasLimit), _validCarrierReturn(_WINDOW));
        _mock.setExpectedCarrierCalldataHash(bytes32(0));
        _mock.setBombLength(0);
        _mock.setFailures(false, false);
        _harness.setRoute(_route(address(_mock), _gasLimit, _successorDigest, _successorWindow));
    }

    function _route(
        address _verifier,
        uint64 _gasLimit,
        bytes4 _successorDigest,
        uint64 _successorWindow
    )
        private
        view
        returns (LibScheduleForkVerifierCallV1.Route memory route_)
    {
        bytes32 runtimeHash;
        assembly ("memory-safe") {
            runtimeHash := extcodehash(_verifier)
        }
        route_ = LibScheduleForkVerifierCallV1.Route({
            forkDigest: _FORK_DIGEST,
            firstWindow: _FIRST_WINDOW,
            successorForkDigest: _successorDigest,
            successorFirstWindow: _successorWindow,
            verifier: _verifier,
            runtimeHash: runtimeHash,
            configurationHash: _independentConfigurationHash(_FORK_DIGEST, _gasLimit),
            selector: _VERIFY_SELECTOR,
            gasLimit: _gasLimit
        });
    }

    function _configuration()
        private
        pure
        returns (LibScheduleForkVerifierCallV1.ForkConfiguration memory configuration_)
    {
        configuration_ = LibScheduleForkVerifierCallV1.ForkConfiguration({
            beaconSlotGindex: 8,
            executionPayloadGindex: 201,
            stateRootGindex: 6434,
            prevRandaoGindex: 6437,
            timestampGindex: 6441,
            blockHashGindex: 6444,
            witnessSchemaHash: _WITNESS_SCHEMA_HASH
        });
    }

    function _validConfigurationReturn(uint64 _gasLimit) private pure returns (bytes memory raw_) {
        return abi.encode(
            _CONFIG_MAGIC,
            _FORK_DIGEST,
            uint64(8),
            uint64(201),
            uint64(6434),
            uint64(6437),
            uint64(6441),
            uint64(6444),
            _WITNESS_SCHEMA_HASH,
            _independentConfigurationHash(_FORK_DIGEST, _gasLimit)
        );
    }

    function _validCarrierReturn(uint64 _window) private view returns (bytes memory raw_) {
        return abi.encode(
            _CARRIER_MAGIC,
            _statementHash(_window),
            _PARENT_SLOT,
            _EXECUTION_BLOCK,
            _PAYLOAD_TIMESTAMP,
            _BLOCK_HASH,
            _STATE_ROOT,
            _PREV_RANDAO
        );
    }

    function _prepareCarrierCall(bytes memory _witness, uint64 _window) private {
        _prepareCarrierCallForGas(_witness, _window, _DEFAULT_GAS_LIMIT);
    }

    function _prepareCarrierCallForGas(
        bytes memory _witness,
        uint64 _window,
        uint64 _gasLimit
    )
        private
    {
        _mock.configureReturns(_validConfigurationReturn(_gasLimit), _validCarrierReturn(_window));
        _mock.setExpectedCarrierCalldataHash(
            keccak256(
                abi.encodeCall(
                    IScheduleForkVerifierV1.verifyScheduleCarrierV1, (_witness, _BEACON_ROOT)
                )
            )
        );
    }

    function _statementHash(uint64 _window) private view returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked(
                "slot-chain-schedule-carrier-statement-v1",
                block.chainid,
                address(_harness),
                _FORK_DIGEST,
                _window,
                _BEACON_ROOT,
                _PARENT_SLOT,
                _EXECUTION_BLOCK,
                _PAYLOAD_TIMESTAMP,
                _BLOCK_HASH,
                _STATE_ROOT,
                _PREV_RANDAO
            )
        );
    }

    function _independentConfigurationHash(
        bytes4 _forkDigest,
        uint64 _gasLimit
    )
        private
        pure
        returns (bytes32 hash_)
    {
        bytes32 constantsHash = keccak256(
            abi.encodePacked(
                "slot-chain-schedule-fork-constants-v1",
                uint64(8),
                uint64(201),
                uint64(6434),
                uint64(6437),
                uint64(6441),
                uint64(6444)
            )
        );
        bytes32 outputSchemaHash = keccak256(
            "ScheduleCarrierOutputV1(bytes32 statementHash,uint64 parentSlot,uint64 executionBlockNumber,uint64 payloadTimestamp,bytes32 blockHash,bytes32 stateRoot,bytes32 prevRandao)"
        );
        return keccak256(
            abi.encodePacked(
                "slot-chain-schedule-fork-verifier-config-v1",
                _forkDigest,
                constantsHash,
                _WITNESS_SCHEMA_HASH,
                outputSchemaHash,
                _VERIFY_SELECTOR,
                _gasLimit
            )
        );
    }

    function _validSszWitness() private pure returns (bytes memory witness_) {
        witness_ = abi.encodePacked(
            bytes8(_WINDOW),
            bytes8(_PARENT_SLOT),
            bytes8(_EXECUTION_BLOCK),
            bytes8(_PAYLOAD_TIMESTAMP),
            sha256("block-hash"),
            sha256("state-root"),
            sha256("prev-randao")
        );
        for (uint256 i; i < 17; ++i) {
            witness_ = bytes.concat(witness_, sha256(abi.encodePacked("helper-", vm.toString(i))));
        }
    }

    function _assertConfiguration(LibScheduleForkVerifierCallV1.ForkConfiguration memory _value)
        private
        pure
    {
        assertEq(_value.beaconSlotGindex, 8);
        assertEq(_value.executionPayloadGindex, 201);
        assertEq(_value.stateRootGindex, 6434);
        assertEq(_value.prevRandaoGindex, 6437);
        assertEq(_value.timestampGindex, 6441);
        assertEq(_value.blockHashGindex, 6444);
        assertEq(_value.witnessSchemaHash, _WITNESS_SCHEMA_HASH);
    }

    function _assertCarrier(
        LibScheduleForkVerifierCallV1.Carrier memory _carrier,
        uint64 _window
    )
        private
        view
    {
        assertEq(_carrier.statementHash, _statementHash(_window));
        assertEq(_carrier.parentSlot, _PARENT_SLOT);
        assertEq(_carrier.executionBlockNumber, _EXECUTION_BLOCK);
        assertEq(_carrier.payloadTimestamp, _PAYLOAD_TIMESTAMP);
        assertEq(_carrier.blockHash, _BLOCK_HASH);
        assertEq(_carrier.stateRoot, _STATE_ROOT);
        assertEq(_carrier.prevRandao, _PREV_RANDAO);
    }

    function _expectRequireVerifierRevert(
        LibScheduleForkVerifierCallV1.Route memory _route_,
        bytes4 _selector
    )
        private
    {
        _harness.setRoute(_route_);
        vm.expectRevert(_selector);
        _harness.requireVerifier();
    }

    function _expectMalformedConfiguration(bytes memory _raw) private {
        _mock.configureReturns(_raw, _validCarrierReturn(_WINDOW));
        vm.expectRevert(
            LibScheduleForkVerifierCallV1.MalformedScheduleVerifierConfiguration.selector
        );
        _harness.requireVerifier();
    }

    function _expectCarrierRevert(
        bytes memory _witness,
        bytes memory _raw,
        bytes4 _selector
    )
        private
    {
        _mock.configureReturns(_validConfigurationReturn(_DEFAULT_GAS_LIMIT), _raw);
        vm.expectRevert(_selector);
        _harness.verifyCarrier(_FORK_DIGEST, _WINDOW, _witness, _BEACON_ROOT);
    }

    function _slice(
        bytes memory _value,
        uint256 _start,
        uint256 _length
    )
        private
        pure
        returns (bytes memory result_)
    {
        result_ = new bytes(_length);
        for (uint256 i; i < _length; ++i) {
            result_[i] = _value[_start + i];
        }
    }

    function _writeWord(bytes memory _value, uint256 _offset, bytes32 _word) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_value, 32), _offset), _word)
        }
    }
}
