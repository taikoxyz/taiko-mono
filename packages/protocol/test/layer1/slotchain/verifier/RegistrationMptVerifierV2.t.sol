// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IRegistrationMptVerifierV2
} from "../../../../contracts/layer1/slotchain/iface/IRegistrationMptVerifierV2.sol";
import {
    RegistrationMptVerifierV2
} from "../../../../contracts/layer1/slotchain/impl/RegistrationMptVerifierV2.sol";
import {
    LibRegistrationMptVerifierCall
} from "../../../../contracts/layer1/slotchain/libs/LibRegistrationMptVerifierCall.sol";
import { LibMptProof } from "../../../../contracts/shared/slotchain/libs/LibMptProof.sol";
import { CanonicalTrieFixtures } from "../../../shared/slotchain/utils/CanonicalTrieFixtures.sol";
import {
    SlotChainGoldenVectors
} from "../../../shared/slotchain/vectors/SlotChainGoldenVectors.sol";
import { Test } from "forge-std/src/Test.sol";

contract RegistrationVerifierCallHarness {
    function requireVerifier(
        address _verifier,
        bytes32 _runtimeHash,
        bytes32 _configurationHash
    )
        external
        view
    {
        LibRegistrationMptVerifierCall.requireVerifier(_verifier, _runtimeHash, _configurationHash);
    }

    function verify(
        address _verifier,
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 calldata _statement,
        bytes calldata _proof
    )
        external
        view
        returns (bytes32 statementHash_)
    {
        return LibRegistrationMptVerifierCall.verify(_verifier, _statement, _proof);
    }
}

contract MemoryStatementRegistryHarness {
    IRegistrationMptVerifierV2.RegistrationStorageStatementV2 private _trustedStatement;

    constructor(
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory _trustedStatement_
    ) {
        _trustedStatement = _trustedStatement_;
    }

    function verifyDerived(
        address _verifier,
        bytes calldata _proof
    )
        external
        view
        returns (bytes32 statementHash_)
    {
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement =
        _trustedStatement;
        return LibRegistrationMptVerifierCall.verify(_verifier, statement, _proof);
    }
}

contract StaticWordReturnMock {
    bytes32 private immutable _word;
    uint256 private immutable _returnLength;
    bool private immutable _mustRevert;

    constructor(bytes32 word_, uint256 returnLength_, bool mustRevert_) {
        _word = word_;
        _returnLength = returnLength_;
        _mustRevert = mustRevert_;
    }

    fallback() external {
        bytes32 word = _word;
        uint256 returnLength = _returnLength;
        bool mustRevert = _mustRevert;
        assembly ("memory-safe") {
            if mustRevert { revert(0, 0) }
            mstore(0, word)
            return(0, returnLength)
        }
    }
}

contract RegistrationMptVerifierV2Test is Test {
    bytes32 private constant _STATEMENT_TYPEHASH =
        0xc049f967468e58f1a5c9b9e1a147dfc233695ae69c5d4a95ec4ffb49b5687da0;
    bytes32 private constant _PROOF_SCHEMA_HASH =
        0x0027acbf8d87ef5b7c901c3dc27af4b56f1e4fb64953cf87f6fcd6ee878c963c;
    bytes32 private constant _CONFIGURATION_TYPEHASH =
        0x38f7fbc63e45f650bd5cbaffba0d81d5ca69f21ebdddfa74280d7e6eb5c319d6;

    RegistrationMptVerifierV2 private verifier;
    RegistrationVerifierCallHarness private callHarness;

    function setUp() external {
        verifier = new RegistrationMptVerifierV2();
        callHarness = new RegistrationVerifierCallHarness();
    }

    function test_verifyRegistration_AcceptsIndependentActualTrieFixtureAndExactWire()
        external
        view
    {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();
        bytes memory callData = abi.encodeCall(
            IRegistrationMptVerifierV2.verifyRegistration, (statement, fixture.proof)
        );
        assertEq(bytes4(callData), bytes4(0x33639818));
        assertEq(callData.length, 452 + _ceil32(fixture.proof.length));
        assertEq(_word(callData, 388), bytes32(uint256(0x1a0)));
        assertEq(_word(callData, 420), bytes32(fixture.proof.length));

        (bool success, bytes memory returned) = address(verifier).staticcall(callData);
        assertTrue(success);
        assertEq(returned.length, 32);
        assertEq(abi.decode(returned, (bytes32)), _hashStatement(statement));
    }

    function test_configurationHash_PinsEveryFrozenSchemaAndLimitField() external view {
        assertEq(
            IRegistrationMptVerifierV2.verifyRegistration.selector,
            SlotChainGoldenVectors.VERIFY_REGISTRATION_SELECTOR
        );
        assertEq(
            IRegistrationMptVerifierV2.registrationMptVerifierConfigHashV2.selector,
            SlotChainGoldenVectors.REGISTRATION_MPT_VERIFIER_CONFIG_GETTER_SELECTOR
        );
        bytes32 expected = keccak256(
            abi.encode(
                _CONFIGURATION_TYPEHASH,
                _STATEMENT_TYPEHASH,
                _PROOF_SCHEMA_HASH,
                bytes4(0x33639818),
                uint16(65),
                uint16(130),
                uint16(600),
                uint32(78_264),
                uint64(11_000_000)
            )
        );
        assertEq(
            _STATEMENT_TYPEHASH, SlotChainGoldenVectors.REGISTRATION_STORAGE_STATEMENT_TYPEHASH
        );
        assertEq(_PROOF_SCHEMA_HASH, SlotChainGoldenVectors.REGISTRATION_MPT_PROOF_SCHEMA_HASH);
        assertEq(verifier.registrationMptVerifierConfigHashV2(), expected);
        assertEq(expected, SlotChainGoldenVectors.REGISTRATION_MPT_VERIFIER_CONFIGURATION_HASH);
        assertEq(expected, SlotChainGoldenVectors.REGISTRATION_CONFIG_GETTER_RETURN);
    }

    function test_goldenStatementReturnAndWireHash_MatchIndependentModelVector() external pure {
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement =
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2({
                settlementChainId: 1,
                activeSettlementRouter: address(0xAD01),
                bridgeDomainRegistry: address(0xD010),
                routeKey: SlotChainGoldenVectors.REGISTRATION_ROUTE_KEY,
                destinationChainId: 16_788,
                protocolVersion: 2,
                canonicalSequence: 1,
                stateRoot: bytes32(uint256(type(uint256).max / 0xff) * 0x66),
                terminalDomainRegistrar: address(0x5103),
                registrarCodeHash: 0x4821a06eed7b3c4f52ed51529fc729262bdd9af96220c080fc8f2be686aabf9a,
                storageTrieKey: SlotChainGoldenVectors.REGISTRATION_COMMITMENT_TRIE_KEY,
                expectedValue: SlotChainGoldenVectors.DESTINATION_REGISTRATION_COMMITMENT
            });
        bytes memory proof = new bytes(35);
        proof[0] = 0xf8;
        proof[1] = 0x6a;
        for (uint256 i; i < 33; ++i) {
            proof[i + 2] = bytes1(uint8(i));
        }
        bytes memory callData =
            abi.encodeCall(IRegistrationMptVerifierV2.verifyRegistration, (statement, proof));

        bytes32 statementHash = _hashStatement(statement);
        assertEq(statementHash, SlotChainGoldenVectors.REGISTRATION_STORAGE_STATEMENT_HASH);
        assertEq(statementHash, SlotChainGoldenVectors.REGISTRATION_VERIFIER_RETURN);
        assertEq(callData.length, SlotChainGoldenVectors.VERIFY_REGISTRATION_CALLDATA_LENGTH);
        assertEq(keccak256(callData), SlotChainGoldenVectors.VERIFY_REGISTRATION_CALLDATA_HASH);
    }

    function test_verifyRegistration_BindsAllStatementFieldsInReturnedHash() external view {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();
        bytes32 baseline = verifier.verifyRegistration(statement, fixture.proof);

        statement.settlementChainId += 1;
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.activeSettlementRouter = address(uint160(statement.activeSettlementRouter) + 1);
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.bridgeDomainRegistry = address(uint160(statement.bridgeDomainRegistry) + 1);
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.routeKey = bytes32(uint256(statement.routeKey) + 1);
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.destinationChainId += 1;
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.protocolVersion += 1;
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
        statement.canonicalSequence += 1;
        assertNotEq(verifier.verifyRegistration(statement, fixture.proof), baseline);
    }

    function test_verifyRegistration_RejectsTrieIdentityAndValueSubstitution() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();

        statement.stateRoot = bytes32(uint256(statement.stateRoot) ^ 1);
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        verifier.verifyRegistration(statement, fixture.proof);

        (, statement) = _fixture();
        statement.terminalDomainRegistrar = address(uint160(statement.terminalDomainRegistrar) ^ 1);
        vm.expectRevert(LibMptProof.MptKeyMismatch.selector);
        verifier.verifyRegistration(statement, fixture.proof);

        (, statement) = _fixture();
        statement.registrarCodeHash = bytes32(uint256(statement.registrarCodeHash) ^ 1);
        vm.expectRevert(LibMptProof.InvalidMptAccount.selector);
        verifier.verifyRegistration(statement, fixture.proof);

        (, statement) = _fixture();
        statement.storageTrieKey = bytes32(uint256(statement.storageTrieKey) ^ 1);
        vm.expectRevert(LibMptProof.MptKeyMismatch.selector);
        verifier.verifyRegistration(statement, fixture.proof);

        (, statement) = _fixture();
        statement.expectedValue = bytes32(uint256(statement.expectedValue) + 1);
        vm.expectRevert(RegistrationMptVerifierV2.RegistrationStorageValueMismatch.selector);
        verifier.verifyRegistration(statement, fixture.proof);
    }

    function test_verifyRegistration_RejectsZeroSettlementAndDestinationChainIds() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();

        statement.settlementChainId = 0;
        vm.expectRevert(RegistrationMptVerifierV2.InvalidRegistrationStatement.selector);
        verifier.verifyRegistration(statement, fixture.proof);

        (, statement) = _fixture();
        statement.destinationChainId = 0;
        vm.expectRevert(RegistrationMptVerifierV2.InvalidRegistrationStatement.selector);
        verifier.verifyRegistration(statement, fixture.proof);
    }

    function test_verifyRegistration_RejectsGapSuffixDirtyPaddingAndDirtyNarrowWords() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();
        bytes memory canonical = abi.encodeCall(
            IRegistrationMptVerifierV2.verifyRegistration, (statement, fixture.proof)
        );

        bytes memory suffixed = bytes.concat(canonical, hex"00");
        _expectStaticRevert(suffixed);

        bytes memory dirtyPadding = _copy(canonical);
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _expectStaticRevert(dirtyPadding);

        bytes memory dirtyAddress = _copy(canonical);
        dirtyAddress[36] = 0x01;
        _expectStaticRevert(dirtyAddress);

        bytes memory dirtyUint64 = _copy(canonical);
        dirtyUint64[164] = 0x01;
        _expectStaticRevert(dirtyUint64);

        bytes memory gapped = new bytes(canonical.length + 32);
        for (uint256 i; i < 420; ++i) {
            gapped[i] = canonical[i];
        }
        _storeWord(gapped, 388, bytes32(uint256(0x1c0)));
        for (uint256 i = 420; i < canonical.length; ++i) {
            gapped[i + 32] = canonical[i];
        }
        _expectStaticRevert(gapped);
    }

    function test_verifyRegistration_RejectsCountsSizesAndTrailingProofBytes() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();

        bytes memory zeroCount = _copy(fixture.proof);
        zeroCount[0] = 0;
        zeroCount[1] = 0;
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        verifier.verifyRegistration(statement, zeroCount);

        bytes memory tooMany = _copy(fixture.proof);
        tooMany[0] = 0;
        tooMany[1] = bytes1(uint8(66));
        vm.expectRevert(RegistrationMptVerifierV2.InvalidRegistrationProofNodeCount.selector);
        verifier.verifyRegistration(statement, tooMany);

        bytes memory totalTooMany = _copy(fixture.proof);
        totalTooMany[0] = 0;
        totalTooMany[1] = bytes1(uint8(65));
        totalTooMany[2] = 0;
        totalTooMany[3] = bytes1(uint8(66));
        vm.expectRevert(RegistrationMptVerifierV2.InvalidRegistrationProofNodeCount.selector);
        verifier.verifyRegistration(statement, totalTooMany);

        bytes memory oversizedNode =
            bytes.concat(hex"00010001", hex"0259", new bytes(601), hex"0001c0");
        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        verifier.verifyRegistration(statement, oversizedNode);

        bytes memory trailing = bytes.concat(fixture.proof, hex"00");
        vm.expectRevert(RegistrationMptVerifierV2.TrailingRegistrationProofBytes.selector);
        verifier.verifyRegistration(statement, trailing);

        bytes memory oversizedProof = new bytes(78_265);
        vm.expectRevert(
            abi.encodeWithSelector(
                RegistrationMptVerifierV2.InvalidRegistrationProofLength.selector, 78_265
            )
        );
        verifier.verifyRegistration(statement, oversizedProof);
    }

    function test_verifyRegistration_AcceptsExactCountAndProofCapsBeforeSemanticTraversal()
        external
    {
        (, IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement) = _fixture();
        bytes memory count130 = new bytes(4 + 130 * 3);
        count130[1] = bytes1(uint8(65));
        count130[3] = bytes1(uint8(65));
        for (uint256 i; i < 130; ++i) {
            uint256 offset = 4 + i * 3;
            count130[offset + 1] = 0x01;
            count130[offset + 2] = 0xc0;
        }
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        verifier.verifyRegistration(statement, count130);

        bytes memory count131 = _copy(count130);
        count131[3] = bytes1(uint8(66));
        vm.expectRevert(RegistrationMptVerifierV2.InvalidRegistrationProofNodeCount.selector);
        verifier.verifyRegistration(statement, count131);

        bytes memory exactCap = new bytes(78_264);
        exactCap[1] = 0x01;
        exactCap[3] = 0x01;
        exactCap[5] = 0x01;
        exactCap[6] = 0xc0;
        exactCap[8] = 0x01;
        exactCap[9] = 0xc0;
        vm.expectRevert(RegistrationMptVerifierV2.TrailingRegistrationProofBytes.selector);
        verifier.verifyRegistration(statement, exactCap);
    }

    function test_maximumSemanticDepthDenseProof_RetainsThirtyPercentElevenMillionHeadroom()
        external
    {
        (uint256 verifierGas, bool exactCallSuccess) = _benchmarkDenseProof(65);
        _assertThirtyPercentHeadroom(verifierGas);
        assertTrue(exactCallSuccess);
    }

    function test_maximumSemanticDepthInlineSiblingProof_RetainsThirtyPercentElevenMillionHeadroom()
        external
    {
        (uint256 verifierGas, bool exactCallSuccess) = _benchmarkDenseProof(65, 1);
        _assertThirtyPercentHeadroom(verifierGas);
        assertTrue(exactCallSuccess);
    }

    function test_maximumSemanticDepthInlineBothPathsProof_RetainsThirtyPercentElevenMillionHeadroom()
        external
    {
        (uint256 verifierGas, bool exactCallSuccess) = _benchmarkDenseProof(65, 2);
        _assertThirtyPercentHeadroom(verifierGas);
        assertTrue(exactCallSuccess);
    }

    function test_benchmarkDenseProof_8NodesPerPath() external {
        _benchmarkDenseProof(8);
    }

    function test_benchmarkDenseProof_16NodesPerPath() external {
        _benchmarkDenseProof(16);
    }

    function test_benchmarkDenseProof_24NodesPerPath() external {
        _benchmarkDenseProof(24);
    }

    function test_benchmarkDenseProof_32NodesPerPath() external {
        _benchmarkDenseProof(32);
    }

    function test_benchmarkDenseProof_40NodesPerPath() external {
        _benchmarkDenseProof(40);
    }

    function test_benchmarkDenseProof_48NodesPerPath() external {
        _benchmarkDenseProof(48);
    }

    function test_benchmarkDenseProof_56NodesPerPath() external {
        _benchmarkDenseProof(56);
    }

    function test_benchmarkInlineSiblingDenseProof_8NodesPerPath() external {
        _benchmarkDenseProof(8, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_16NodesPerPath() external {
        _benchmarkDenseProof(16, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_24NodesPerPath() external {
        _benchmarkDenseProof(24, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_32NodesPerPath() external {
        _benchmarkDenseProof(32, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_40NodesPerPath() external {
        _benchmarkDenseProof(40, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_48NodesPerPath() external {
        _benchmarkDenseProof(48, 1);
    }

    function test_benchmarkInlineSiblingDenseProof_56NodesPerPath() external {
        _benchmarkDenseProof(56, 1);
    }

    function test_benchmarkInlineBothPathsDenseProof_34NodesPerPath() external {
        (, bool exactCallSuccess) = _benchmarkDenseProof(34, 2);
        assertTrue(exactCallSuccess);
    }

    function test_benchmarkInlineBothPathsDenseProof_40NodesPerPath() external {
        (, bool exactCallSuccess) = _benchmarkDenseProof(40, 2);
        assertTrue(exactCallSuccess);
    }

    function test_benchmarkLateAdversarialProof_LeafOnlyInlineSiblings() external {
        _benchmarkLateAdversarialProof(0);
    }

    function test_benchmarkLateAdversarialProof_LastSevenNibbles() external {
        _benchmarkLateAdversarialProof(7);
    }

    function test_benchmarkLateAdversarialProof_LastEightNibbles() external {
        _benchmarkLateAdversarialProof(8);
    }

    function test_benchmarkLateAdversarialProof_LastNineNibbles() external {
        _benchmarkLateAdversarialProof(9);
    }

    function test_lateAdversarialProof_RetainsThirtyPercentElevenMillionHeadroom() external {
        (uint256 verifierGas, bool exactCallSuccess) = _benchmarkLateAdversarialProof(32);
        _assertThirtyPercentHeadroom(verifierGas);
        assertTrue(exactCallSuccess);
    }

    function test_callLibrary_AuthenticatesRuntimeConfigurationAndExactStatementReturn() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();
        bytes32 runtimeHash = address(verifier).codehash;
        bytes32 configurationHash = verifier.registrationMptVerifierConfigHashV2();
        callHarness.requireVerifier(address(verifier), runtimeHash, configurationHash);
        assertEq(
            callHarness.verify(address(verifier), statement, fixture.proof),
            _hashStatement(statement)
        );

        vm.expectRevert(LibRegistrationMptVerifierCall.RegistrationVerifierRuntimeMismatch.selector);
        callHarness.requireVerifier(
            address(verifier), bytes32(uint256(runtimeHash) ^ 1), configurationHash
        );

        vm.expectRevert(
            LibRegistrationMptVerifierCall.RegistrationVerifierConfigurationMismatch.selector
        );
        callHarness.requireVerifier(
            address(verifier), runtimeHash, bytes32(uint256(configurationHash) ^ 1)
        );
    }

    function test_callLibrary_AcceptsStatementConstructedInternallyInMemory() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory trustedStatement
        ) = _fixture();
        MemoryStatementRegistryHarness registry =
            new MemoryStatementRegistryHarness(trustedStatement);

        assertEq(
            registry.verifyDerived(address(verifier), fixture.proof),
            _hashStatement(trustedStatement)
        );
    }

    function test_callLibrary_RejectsRevertShortTrailingAndWrongWordReturns() external {
        (
            CanonicalTrieFixtures.RegistrationFixture memory fixture,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement
        ) = _fixture();
        bytes32 statementHash = _hashStatement(statement);
        bytes32 configurationHash = verifier.registrationMptVerifierConfigHashV2();

        StaticWordReturnMock exactConfig = new StaticWordReturnMock(configurationHash, 32, false);
        callHarness.requireVerifier(
            address(exactConfig), address(exactConfig).codehash, configurationHash
        );

        StaticWordReturnMock shortReturn = new StaticWordReturnMock(configurationHash, 31, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRegistrationMptVerifierCall.RegistrationVerifierReturnLengthMismatch.selector, 31
            )
        );
        callHarness.requireVerifier(
            address(shortReturn), address(shortReturn).codehash, configurationHash
        );

        StaticWordReturnMock trailingReturn = new StaticWordReturnMock(configurationHash, 33, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRegistrationMptVerifierCall.RegistrationVerifierReturnLengthMismatch.selector, 33
            )
        );
        callHarness.requireVerifier(
            address(trailingReturn), address(trailingReturn).codehash, configurationHash
        );

        StaticWordReturnMock reverting = new StaticWordReturnMock(bytes32(0), 0, true);
        vm.expectRevert(LibRegistrationMptVerifierCall.RegistrationVerifierCallFailed.selector);
        callHarness.requireVerifier(
            address(reverting), address(reverting).codehash, configurationHash
        );

        StaticWordReturnMock exactStatement = new StaticWordReturnMock(statementHash, 32, false);
        assertEq(
            callHarness.verify(address(exactStatement), statement, fixture.proof), statementHash
        );

        StaticWordReturnMock wrongStatement =
            new StaticWordReturnMock(bytes32(uint256(statementHash) ^ 1), 32, false);
        vm.expectRevert(
            LibRegistrationMptVerifierCall.RegistrationVerifierStatementMismatch.selector
        );
        callHarness.verify(address(wrongStatement), statement, fixture.proof);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibRegistrationMptVerifierCall.RegistrationVerifierReturnLengthMismatch.selector, 31
            )
        );
        callHarness.verify(address(shortReturn), statement, fixture.proof);

        vm.expectRevert(LibRegistrationMptVerifierCall.RegistrationVerifierCallFailed.selector);
        callHarness.verify(address(reverting), statement, fixture.proof);
    }

    function _fixture()
        private
        pure
        returns (
            CanonicalTrieFixtures.RegistrationFixture memory fixture_,
            IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement_
        )
    {
        fixture_ = CanonicalTrieFixtures.registrationFixture();
        statement_ = _statementFor(fixture_);
    }

    function _statementFor(CanonicalTrieFixtures.RegistrationFixture memory _fixtureValue)
        private
        pure
        returns (IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement_)
    {
        statement_ = IRegistrationMptVerifierV2.RegistrationStorageStatementV2({
            settlementChainId: 1,
            activeSettlementRouter: address(0x1111),
            bridgeDomainRegistry: address(0x2222),
            routeKey: keccak256("route"),
            destinationChainId: 167_000,
            protocolVersion: 7,
            canonicalSequence: 0,
            stateRoot: _fixtureValue.stateRoot,
            terminalDomainRegistrar: _fixtureValue.account,
            registrarCodeHash: _fixtureValue.codeHash,
            storageTrieKey: _fixtureValue.storageKey,
            expectedValue: _fixtureValue.expectedValue
        });
    }

    function _hashStatement(
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory _statement
    )
        private
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encode(
                _STATEMENT_TYPEHASH,
                _statement.settlementChainId,
                _statement.activeSettlementRouter,
                _statement.bridgeDomainRegistry,
                _statement.routeKey,
                _statement.destinationChainId,
                _statement.protocolVersion,
                _statement.canonicalSequence,
                _statement.stateRoot,
                _statement.terminalDomainRegistrar,
                _statement.registrarCodeHash,
                _statement.storageTrieKey,
                _statement.expectedValue
            )
        );
    }

    function _benchmarkDenseProof(uint8 _nodesPerPath)
        private
        returns (uint256 verifierGas_, bool exactCallSuccess_)
    {
        return _benchmarkDenseProof(_nodesPerPath, 0);
    }

    function _benchmarkDenseProof(
        uint8 _nodesPerPath,
        uint8 _siblingMode
    )
        private
        returns (uint256 verifierGas_, bool exactCallSuccess_)
    {
        uint256 constructionStart = gasleft();
        CanonicalTrieFixtures.RegistrationFixture memory fixture;
        if (_siblingMode == 0) {
            fixture = CanonicalTrieFixtures.denseRegistrationFixture(_nodesPerPath);
        } else if (_siblingMode == 1) {
            fixture = CanonicalTrieFixtures.denseRegistrationFixtureWithInlineStorageSiblings(
                _nodesPerPath
            );
        } else {
            assertEq(_siblingMode, 2);
            fixture = CanonicalTrieFixtures.denseRegistrationFixtureWithInlineSiblingsBothPaths(
                _nodesPerPath
            );
        }
        uint256 constructionGas = constructionStart - gasleft();
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement =
            _statementFor(fixture);
        assertEq(uint8(fixture.proof[1]), _nodesPerPath);
        assertEq(uint8(fixture.proof[3]), _nodesPerPath);
        assertLe(fixture.proof.length, 78_264);

        uint256 verifierStart = gasleft();
        assertEq(verifier.verifyRegistration(statement, fixture.proof), _hashStatement(statement));
        verifierGas_ = verifierStart - gasleft();

        bytes memory exactCall = abi.encodeCall(
            RegistrationVerifierCallHarness.verify, (address(verifier), statement, fixture.proof)
        );
        uint256 exactCallStart = gasleft();
        bytes memory returned;
        (exactCallSuccess_, returned) = address(callHarness).staticcall(exactCall);
        uint256 exactCallGas = exactCallStart - gasleft();
        if (exactCallSuccess_) {
            assertEq(abi.decode(returned, (bytes32)), _hashStatement(statement));
        }

        emit log_named_uint("nodes per path", _nodesPerPath);
        emit log_named_uint("proof bytes", fixture.proof.length);
        emit log_named_uint("maximum framed node bytes", _maximumNodeBytes(fixture.proof));
        emit log_named_uint("sibling mode", _siblingMode);
        emit log_named_uint("fixture construction gas", constructionGas);
        emit log_named_uint("direct verifier gas", verifierGas_);
        emit log_named_uint("exact-call transaction-side gas", exactCallGas);
        emit log_named_uint("exact 11m call success", exactCallSuccess_ ? 1 : 0);
    }

    function _benchmarkLateAdversarialProof(uint8 _maximumWorkedRemainingNibbles)
        private
        returns (uint256 verifierGas_, bool exactCallSuccess_)
    {
        uint256 constructionStart = gasleft();
        CanonicalTrieFixtures.RegistrationFixture memory fixture =
            CanonicalTrieFixtures.lateAdversarialRegistrationFixture(_maximumWorkedRemainingNibbles);
        uint256 constructionGas = constructionStart - gasleft();
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory statement =
            _statementFor(fixture);
        assertEq(uint8(fixture.proof[1]), 34);
        assertEq(uint8(fixture.proof[3]), 34);
        assertLe(fixture.proof.length, 78_264);

        uint256 verifierStart = gasleft();
        assertEq(verifier.verifyRegistration(statement, fixture.proof), _hashStatement(statement));
        verifierGas_ = verifierStart - gasleft();

        bytes memory exactCall = abi.encodeCall(
            RegistrationVerifierCallHarness.verify, (address(verifier), statement, fixture.proof)
        );
        uint256 exactCallStart = gasleft();
        bytes memory returned;
        (exactCallSuccess_, returned) = address(callHarness).staticcall(exactCall);
        uint256 exactCallGas = exactCallStart - gasleft();
        if (exactCallSuccess_) {
            assertEq(abi.decode(returned, (bytes32)), _hashStatement(statement));
        }

        emit log_named_uint("worked remaining nibbles", _maximumWorkedRemainingNibbles);
        emit log_named_uint("proof bytes", fixture.proof.length);
        emit log_named_uint("maximum framed node bytes", _maximumNodeBytes(fixture.proof));
        emit log_named_uint("fixture construction gas", constructionGas);
        emit log_named_uint("direct verifier gas", verifierGas_);
        emit log_named_uint("exact-call transaction-side gas", exactCallGas);
        emit log_named_uint("exact 11m call success", exactCallSuccess_ ? 1 : 0);
    }

    function _assertThirtyPercentHeadroom(uint256 _measuredGas) private pure {
        uint256 requiredStipend = (_measuredGas * 130 + 99) / 100;
        assertLe(requiredStipend, 11_000_000);
    }

    function _maximumNodeBytes(bytes memory _proof) private pure returns (uint256 maximum_) {
        uint256 totalNodes = uint8(_proof[1]) + uint8(_proof[3]);
        uint256 cursor = 4;
        for (uint256 i; i < totalNodes; ++i) {
            uint256 length = (uint256(uint8(_proof[cursor])) << 8) | uint8(_proof[cursor + 1]);
            if (length > maximum_) maximum_ = length;
            cursor += 2 + length;
        }
        assert(cursor == _proof.length);
    }

    function _expectStaticRevert(bytes memory _callData) private view {
        (bool success,) = address(verifier).staticcall(_callData);
        assertFalse(success);
    }

    function _word(bytes memory _input, uint256 _offset) private pure returns (bytes32 word_) {
        assembly ("memory-safe") {
            word_ := mload(add(add(_input, 32), _offset))
        }
    }

    function _storeWord(
        bytes memory _input,
        uint256 _offset,
        bytes32 _wordValue
    )
        private
        pure
    {
        assembly ("memory-safe") {
            mstore(add(add(_input, 32), _offset), _wordValue)
        }
    }

    function _ceil32(uint256 _value) private pure returns (uint256 rounded_) {
        return (_value + 31) & ~uint256(31);
    }

    function _copy(bytes memory _input) private pure returns (bytes memory output_) {
        output_ = new bytes(_input.length);
        for (uint256 i; i < _input.length; ++i) {
            output_[i] = _input[i];
        }
    }
}
