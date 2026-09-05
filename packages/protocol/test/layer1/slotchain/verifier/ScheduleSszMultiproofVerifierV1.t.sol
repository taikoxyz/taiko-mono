// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IScheduleForkVerifierV1
} from "../../../../contracts/layer1/slotchain/iface/IScheduleForkVerifierV1.sol";
import {
    ScheduleSszMultiproofVerifierV1
} from "../../../../contracts/layer1/slotchain/impl/ScheduleSszMultiproofVerifierV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract ScheduleSszMultiproofVerifierV1Test is Test {
    bytes4 private constant _FORK_DIGEST = 0x46554c55;
    uint64 private constant _VERIFICATION_GAS_LIMIT = 4_000_000;

    bytes4 private constant _SFV1_MAGIC = 0x53465631;
    bytes4 private constant _SFC1_MAGIC = 0x53464331;
    bytes4 private constant _CONFIG_SELECTOR = 0x44efa773;
    bytes4 private constant _VERIFY_SELECTOR = 0x7e981e0b;

    bytes32 private constant _WITNESS_SCHEMA_HASH =
        0x4d3c1d3a7f2921c2f8e7526a2e8aa2c47dc6bdcd3dc9e2b14c58f2b9d39ed30f;
    bytes32 private constant _FORK_CONSTANTS_HASH =
        0xc17afdd5367849af551b3a2f322a2c351321e916ad913a78b646586fe34f59fc;
    bytes32 private constant _OUTPUT_SCHEMA_HASH =
        0x3a480130319b3cebce02d217988e89c83c6bd6e71ff93c25bc4fc38e51fbe2c0;
    bytes32 private constant _CONFIGURATION_HASH =
        0x1da8967f889fec4feab5d16645a31f75613c265a5ff494e97c4af6ff061666e5;

    bytes32 private constant _INDEPENDENT_ROOT =
        0xd97d74b27bcf682f7261641d7cea2ab9c9336b1360054c3670a920e251d90817;

    uint64 private constant _WINDOW = 42;
    uint64 private constant _PARENT_SLOT = 123_456;
    uint64 private constant _EXECUTION_BLOCK = 987_654;
    uint64 private constant _PAYLOAD_TIMESTAMP = 1_700_000_000;

    ScheduleSszMultiproofVerifierV1 private _verifier;

    function setUp() public {
        _verifier = new ScheduleSszMultiproofVerifierV1(_FORK_DIGEST, _VERIFICATION_GAS_LIMIT);
    }

    function test_constructor_AcceptsInclusiveGasBoundaries() external {
        new ScheduleSszMultiproofVerifierV1(hex"00000001", 100_000);
        new ScheduleSszMultiproofVerifierV1(hex"ffffffff", 5_000_000);
    }

    function test_constructor_RevertWhen_ConfigurationIsOutOfRange() external {
        vm.expectRevert(ScheduleSszMultiproofVerifierV1.InvalidForkVerifierConfiguration.selector);
        new ScheduleSszMultiproofVerifierV1(bytes4(0), _VERIFICATION_GAS_LIMIT);

        vm.expectRevert(ScheduleSszMultiproofVerifierV1.InvalidForkVerifierConfiguration.selector);
        new ScheduleSszMultiproofVerifierV1(_FORK_DIGEST, 99_999);

        vm.expectRevert(ScheduleSszMultiproofVerifierV1.InvalidForkVerifierConfiguration.selector);
        new ScheduleSszMultiproofVerifierV1(_FORK_DIGEST, 5_000_001);
    }

    function test_scheduleForkVerifierConfigV1_ReturnsExactFrozenConfiguration() external view {
        assertEq(IScheduleForkVerifierV1.scheduleForkVerifierConfigV1.selector, _CONFIG_SELECTOR);
        assertEq(IScheduleForkVerifierV1.verifyScheduleCarrierV1.selector, _VERIFY_SELECTOR);

        (
            bytes4 magic,
            bytes4 forkDigest,
            uint64 beaconSlotGindex,
            uint64 executionPayloadGindex,
            uint64 stateRootGindex,
            uint64 prevRandaoGindex,
            uint64 timestampGindex,
            uint64 blockHashGindex,
            bytes32 witnessSchemaHash,
            bytes32 configurationHash
        ) = _verifier.scheduleForkVerifierConfigV1();

        assertEq(magic, _SFV1_MAGIC);
        assertEq(forkDigest, _FORK_DIGEST);
        assertEq(beaconSlotGindex, 8);
        assertEq(executionPayloadGindex, 201);
        assertEq(stateRootGindex, 6434);
        assertEq(prevRandaoGindex, 6437);
        assertEq(timestampGindex, 6441);
        assertEq(blockHashGindex, 6444);
        assertEq(witnessSchemaHash, _WITNESS_SCHEMA_HASH);
        assertEq(_forkConstantsHash(), _FORK_CONSTANTS_HASH);
        assertEq(_outputSchemaHash(), _OUTPUT_SCHEMA_HASH);
        assertEq(configurationHash, _CONFIGURATION_HASH);
        assertEq(configurationHash, _configurationHash(_FORK_DIGEST, _VERIFICATION_GAS_LIMIT));
    }

    function test_scheduleForkVerifierConfigV1_ReturnDataIsExactly320Bytes() external view {
        (bool success, bytes memory returndata) =
            address(_verifier).staticcall(abi.encodeWithSelector(_CONFIG_SELECTOR));
        assertTrue(success);
        assertEq(returndata.length, 320);
    }

    function test_verifyScheduleCarrierV1_AcceptsIndependentSha256GoldenProof() external view {
        bytes memory witness = _validWitness();
        assertEq(witness.length, 672);
        bytes memory calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );
        assertEq(calldata_.length, 772);

        (
            bytes4 magic,
            bytes32 statementHash,
            uint64 parentSlot,
            uint64 executionBlockNumber,
            uint64 payloadTimestamp,
            bytes32 blockHash,
            bytes32 stateRoot,
            bytes32 prevRandao
        ) = _verifier.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);

        assertEq(magic, _SFC1_MAGIC);
        assertEq(parentSlot, _PARENT_SLOT);
        assertEq(executionBlockNumber, _EXECUTION_BLOCK);
        assertEq(payloadTimestamp, _PAYLOAD_TIMESTAMP);
        assertEq(blockHash, sha256("block-hash"));
        assertEq(stateRoot, sha256("state-root"));
        assertEq(prevRandao, sha256("prev-randao"));
        assertEq(
            statementHash,
            _statementHash(
                _FORK_DIGEST,
                _WINDOW,
                _INDEPENDENT_ROOT,
                _PARENT_SLOT,
                _EXECUTION_BLOCK,
                _PAYLOAD_TIMESTAMP,
                blockHash,
                stateRoot,
                prevRandao,
                address(this)
            )
        );
    }

    function test_verifyScheduleCarrierV1_ReturnDataIsExactly256Bytes() external view {
        bytes memory witness = _validWitness();
        (bool success, bytes memory returndata) = address(_verifier)
            .staticcall(
                abi.encodeCall(
                    IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
                )
            );
        assertTrue(success);
        assertEq(returndata.length, 256);
    }

    function test_verifyScheduleCarrierV1_BindsCallerChainForkWindowRootAndEveryOutput() external {
        bytes memory witness = _validWitness();
        address caller = address(0xb0b);
        vm.chainId(16_700);
        vm.prank(caller);
        (, bytes32 statementHash,,,,,,) =
            _verifier.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);

        assertEq(
            statementHash,
            _statementHash(
                _FORK_DIGEST,
                _WINDOW,
                _INDEPENDENT_ROOT,
                _PARENT_SLOT,
                _EXECUTION_BLOCK,
                _PAYLOAD_TIMESTAMP,
                sha256("block-hash"),
                sha256("state-root"),
                sha256("prev-randao"),
                caller
            )
        );

        bytes32 baseline = statementHash;
        bytes memory changed = _copy(witness);
        _setU64(changed, 0, _WINDOW + 1);
        vm.prank(caller);
        (, statementHash,,,,,,) = _verifier.verifyScheduleCarrierV1(changed, _INDEPENDENT_ROOT);
        assertTrue(statementHash != baseline);

        changed = _copy(witness);
        _setU64(changed, 16, _EXECUTION_BLOCK + 1);
        vm.prank(caller);
        (, statementHash,,,,,,) = _verifier.verifyScheduleCarrierV1(changed, _INDEPENDENT_ROOT);
        assertTrue(statementHash != baseline);

        ScheduleSszMultiproofVerifierV1 otherFork =
            new ScheduleSszMultiproofVerifierV1(hex"01020304", _VERIFICATION_GAS_LIMIT);
        vm.prank(caller);
        (, statementHash,,,,,,) = otherFork.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);
        assertTrue(statementHash != baseline);
    }

    function test_verifyScheduleCarrierV1_AllowsZeroWindowAndBindsIt() external view {
        bytes memory witness = _validWitness();
        _setU64(witness, 0, 0);
        (, bytes32 statementHash,,,,,,) =
            _verifier.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);
        assertEq(
            statementHash,
            _statementHash(
                _FORK_DIGEST,
                0,
                _INDEPENDENT_ROOT,
                _PARENT_SLOT,
                _EXECUTION_BLOCK,
                _PAYLOAD_TIMESTAMP,
                sha256("block-hash"),
                sha256("state-root"),
                sha256("prev-randao"),
                address(this)
            )
        );
    }

    function test_verifyScheduleCarrierV1_AcceptsAllUint64MaximumBoundaries() external view {
        bytes memory witness = _validWitness();
        _setU64(witness, 0, type(uint64).max);
        _setU64(witness, 8, type(uint64).max);
        _setU64(witness, 16, type(uint64).max);
        _setU64(witness, 24, type(uint64).max);
        bytes32 maximumRoot = 0x9a5bc8db943c42a1a259d1f8d252f8048b0c03f220c5324a5a2bcc1f7920fd91;

        (,, uint64 parentSlot, uint64 executionBlock, uint64 payloadTimestamp,,,) =
            _verifier.verifyScheduleCarrierV1(witness, maximumRoot);
        assertEq(parentSlot, type(uint64).max);
        assertEq(executionBlock, type(uint64).max);
        assertEq(payloadTimestamp, type(uint64).max);
    }

    function test_verifyScheduleCarrierV1_RevertWhen_CalldataHasSuffixGapOrWrongLength() external {
        bytes memory witness = _validWitness();
        bytes memory canonical = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );

        _assertCallRevertsWith(
            bytes.concat(canonical, hex"00"),
            ScheduleSszMultiproofVerifierV1.NonCanonicalScheduleCarrierCalldata.selector
        );

        bytes memory gap = bytes.concat(
            _VERIFY_SELECTOR,
            bytes32(uint256(0x60)),
            _INDEPENDENT_ROOT,
            bytes32(0),
            bytes32(uint256(672)),
            witness
        );
        _assertCallRevertsWith(
            gap, ScheduleSszMultiproofVerifierV1.NonCanonicalScheduleCarrierCalldata.selector
        );

        bytes memory shortWitness = new bytes(671);
        for (uint256 i; i < shortWitness.length; ++i) {
            shortWitness[i] = witness[i];
        }
        _assertCallRevertsWith(
            abi.encodeCall(
                IScheduleForkVerifierV1.verifyScheduleCarrierV1, (shortWitness, _INDEPENDENT_ROOT)
            ),
            ScheduleSszMultiproofVerifierV1.NonCanonicalScheduleCarrierCalldata.selector
        );

        bytes memory longWitness = bytes.concat(witness, hex"00");
        _assertCallRevertsWith(
            abi.encodeCall(
                IScheduleForkVerifierV1.verifyScheduleCarrierV1, (longWitness, _INDEPENDENT_ROOT)
            ),
            ScheduleSszMultiproofVerifierV1.NonCanonicalScheduleCarrierCalldata.selector
        );
    }

    function test_verifyScheduleCarrierV1_RevertWhen_DynamicHeadOrLengthIsNoncanonical() external {
        bytes memory witness = _validWitness();
        bytes memory calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );

        _writeWord(calldata_, 4, bytes32(uint256(0x60)));
        _assertAnyRevert(calldata_);

        calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );
        _writeWord(calldata_, 68, bytes32(uint256(671)));
        _assertCallRevertsWith(
            calldata_, ScheduleSszMultiproofVerifierV1.NonCanonicalScheduleCarrierCalldata.selector
        );

        calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );
        _writeWord(calldata_, 4, bytes32(uint256(0x20)));
        _assertAnyRevert(calldata_);

        calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );
        _writeWord(calldata_, 68, bytes32(uint256(1) << 128 | uint256(672)));
        _assertAnyRevert(calldata_);
    }

    function test_verifyScheduleCarrierV1_RevertWhen_RootOrAnyProvedNodeChanges() external {
        bytes memory witness = _validWitness();

        vm.expectRevert(ScheduleSszMultiproofVerifierV1.InvalidBeaconBlockRoot.selector);
        _verifier.verifyScheduleCarrierV1(witness, bytes32(0));

        vm.expectRevert(ScheduleSszMultiproofVerifierV1.ScheduleCarrierRootMismatch.selector);
        _verifier.verifyScheduleCarrierV1(witness, bytes32(uint256(_INDEPENDENT_ROOT) ^ 1));

        uint256[6] memory offsets = [uint256(8), 24, 32, 64, 96, 128];
        for (uint256 i; i < offsets.length; ++i) {
            bytes memory changed = _copy(witness);
            changed[offsets[i]] = bytes1(uint8(changed[offsets[i]]) ^ 1);
            vm.expectRevert(ScheduleSszMultiproofVerifierV1.ScheduleCarrierRootMismatch.selector);
            _verifier.verifyScheduleCarrierV1(changed, _INDEPENDENT_ROOT);
        }

        bytes memory swappedHelpers = _copy(witness);
        bytes32 first = _word(swappedHelpers, 128);
        bytes32 second = _word(swappedHelpers, 160);
        _writeWord(swappedHelpers, 128, second);
        _writeWord(swappedHelpers, 160, first);
        vm.expectRevert(ScheduleSszMultiproofVerifierV1.ScheduleCarrierRootMismatch.selector);
        _verifier.verifyScheduleCarrierV1(swappedHelpers, _INDEPENDENT_ROOT);
    }

    function test_verifyScheduleCarrierV1_RevertWhen_RequiredContextOrOutputIsZero() external {
        bytes memory witness = _validWitness();
        uint256[6] memory offsets = [uint256(8), 16, 24, 32, 64, 96];
        uint256[6] memory widths = [uint256(8), 8, 8, 32, 32, 32];
        for (uint256 i; i < offsets.length; ++i) {
            bytes memory changed = _copy(witness);
            for (uint256 j; j < widths[i]; ++j) {
                changed[offsets[i] + j] = 0;
            }
            vm.expectRevert(ScheduleSszMultiproofVerifierV1.InvalidScheduleCarrierWitness.selector);
            _verifier.verifyScheduleCarrierV1(changed, _INDEPENDENT_ROOT);
        }
    }

    function test_verifyScheduleCarrierV1_UsesCanonicalLittleEndianSszUint64AndHashOrder()
        external
        view
    {
        bytes memory witness = _validWitness();
        // The root was generated independently with Python hashlib. It uses the big-endian outer
        // fields, little-endian SSZ chunks, helper order from the specification, and
        // SHA256(left || right). Any endian, hash, or child-order change misses this golden root.
        (bytes4 magic,,,,,,,) = _verifier.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);
        assertEq(magic, _SFC1_MAGIC);
    }

    function test_verifyScheduleCarrierV1_SucceedsWithExactConfiguredGasStipend() external view {
        bytes memory witness = _validWitness();
        bytes memory calldata_ = abi.encodeCall(
            IScheduleForkVerifierV1.verifyScheduleCarrierV1, (witness, _INDEPENDENT_ROOT)
        );
        (bool success, bytes memory returndata) =
            address(_verifier).staticcall{ gas: _VERIFICATION_GAS_LIMIT }(calldata_);
        assertTrue(success);
        assertEq(returndata.length, 256);
    }

    function test_verifyScheduleCarrierV1_GasBenchmark() external {
        bytes memory witness = _validWitness();
        uint256 gasBefore = gasleft();
        _verifier.verifyScheduleCarrierV1(witness, _INDEPENDENT_ROOT);
        uint256 used = gasBefore - gasleft();
        emit log_named_uint("ScheduleSszMultiproofVerifierV1 gas", used);
        assertLt(used, _VERIFICATION_GAS_LIMIT);
    }

    function _validWitness() private pure returns (bytes memory witness_) {
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

    function _forkConstantsHash() private pure returns (bytes32 hash_) {
        return keccak256(
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
    }

    function _outputSchemaHash() private pure returns (bytes32 hash_) {
        return keccak256(
            "ScheduleCarrierOutputV1(bytes32 statementHash,uint64 parentSlot,uint64 executionBlockNumber,uint64 payloadTimestamp,bytes32 blockHash,bytes32 stateRoot,bytes32 prevRandao)"
        );
    }

    function _configurationHash(
        bytes4 _forkDigest,
        uint64 _gasLimit
    )
        private
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-schedule-fork-verifier-config-v1",
                _forkDigest,
                _FORK_CONSTANTS_HASH,
                _WITNESS_SCHEMA_HASH,
                _OUTPUT_SCHEMA_HASH,
                _VERIFY_SELECTOR,
                _gasLimit
            )
        );
    }

    function _statementHash(
        bytes4 _forkDigest,
        uint64 _window,
        bytes32 _root,
        uint64 _parentSlot,
        uint64 _executionBlock,
        uint64 _payloadTimestamp,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        bytes32 _prevRandao,
        address _caller
    )
        private
        view
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-schedule-carrier-statement-v1",
                block.chainid,
                _caller,
                _forkDigest,
                _window,
                _root,
                _parentSlot,
                _executionBlock,
                _payloadTimestamp,
                _blockHash,
                _stateRoot,
                _prevRandao
            )
        );
    }

    function _setU64(bytes memory _value, uint256 _offset, uint64 _number) private pure {
        for (uint256 i; i < 8; ++i) {
            _value[_offset + i] = bytes1(uint8(_number >> ((7 - i) * 8)));
        }
    }

    function _copy(bytes memory _value) private pure returns (bytes memory copy_) {
        copy_ = new bytes(_value.length);
        for (uint256 i; i < _value.length; ++i) {
            copy_[i] = _value[i];
        }
    }

    function _word(bytes memory _value, uint256 _offset) private pure returns (bytes32 word_) {
        assembly ("memory-safe") {
            word_ := mload(add(add(_value, 32), _offset))
        }
    }

    function _writeWord(
        bytes memory _value,
        uint256 _offset,
        bytes32 _newWord
    )
        private
        pure
    {
        assembly ("memory-safe") {
            mstore(add(add(_value, 32), _offset), _newWord)
        }
    }

    function _assertCallRevertsWith(bytes memory _calldata, bytes4 _selector) private {
        (bool success, bytes memory returndata) = address(_verifier).call(_calldata);
        assertFalse(success);
        assertEq(returndata.length, 4);
        assertEq(bytes4(returndata), _selector);
    }

    function _assertAnyRevert(bytes memory _calldata) private {
        (bool success,) = address(_verifier).call(_calldata);
        assertFalse(success);
    }
}
