// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SignalServiceProofFixture } from "./SignalServiceProofFixture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { EssentialContract_EmptyStub } from "test/shared/helpers/EssentialContract_EmptyStub.sol";

contract SignalRootProviderStub {
    uint64 private _identifier;
    bytes32 private _root;
    uint8 private _mode;

    function configure(uint64 _id, bytes32 _stateRoot, uint8 _responseMode) external {
        _identifier = _id;
        _root = _stateRoot;
        _mode = _responseMode;
    }

    function getL1StateRoot(uint64 _id) external view returns (bytes32) {
        require(_id == _identifier, "provider identifier differs");
        if (_mode == 1) revert("provider unavailable");
        if (_mode == 2) {
            assembly { return(0, 0) }
        }
        if (_mode == 3) {
            assembly { return(0, 31) }
        }
        return _root;
    }
}

contract EtnaStartStub is EssentialContract {
    uint48 private _height;
    bytes32 private _hash;
    bool private _unavailable;

    function configure(uint48 _startHeight, bytes32 _startHash, bool _reverts) external {
        _height = _startHeight;
        _hash = _startHash;
        _unavailable = _reverts;
    }

    function etnaStart() external view returns (uint48, bytes32) {
        require(!_unavailable, "Etna start unavailable");
        return (_height, _hash);
    }
}

contract TestSignalServiceConfiguration is CommonTest, SignalServiceProofFixture {
    SignalRootProviderStub private _provider;
    EtnaStartStub private _inbox;
    address private _legacy;
    SignalService private _providerService;
    SignalService private _legacyService;

    function setUpOnEthereum() internal override {
        _provider = new SignalRootProviderStub();
        _provider.configure(VALID_PROOF_BLOCK_ID, VALID_PROOF_STATE_ROOT, 0);
        _inbox = EtnaStartStub(address(new ERC1967Proxy(address(new EtnaStartStub()), "")));
        _legacy = address(new ERC1967Proxy(address(new EssentialContract_EmptyStub()), ""));
        _providerService = _deploy(AUTHORIZED_SYNCER, address(_provider), address(0));
        _legacyService = _deploy(address(_inbox), address(0), _legacy);
    }

    function test_constructor_PreservesVersionAndExposesConfiguration() external view {
        assertEq(_providerService.VERSION(), 1);
        assertEq(_providerService.authorizedSyncer(), AUTHORIZED_SYNCER);
        assertEq(_providerService.stateRootProvider(), address(_provider));
        assertEq(_providerService.unzenInbox(), address(0));
        assertEq(_legacyService.authorizedSyncer(), address(_inbox));
        assertEq(_legacyService.stateRootProvider(), address(0));
        assertEq(_legacyService.unzenInbox(), _legacy);
    }

    function test_verifySignalReceived_UsesProviderWithoutLocalCheckpoint() external view {
        _verify(_providerService, VALID_SIGNAL_PROOF);
    }

    function test_verifySignalReceived_ProviderUsesFullUint64Identifier() external {
        uint64 identifier = type(uint64).max;
        _provider.configure(identifier, VALID_PROOF_STATE_ROOT, 0);
        _verify(_providerService, _proof(identifier, VALID_PROOF_STATE_ROOT));
    }

    function test_verifySignalReceived_ProviderRootOverridesConflictingLocalCheckpoint() external {
        _save(
            _providerService, AUTHORIZED_SYNCER, uint48(VALID_PROOF_BLOCK_ID), bytes32(uint256(99))
        );
        _verify(_providerService, VALID_SIGNAL_PROOF);
    }

    function test_verifySignalReceived_RevertWhen_ProviderRootDiffersDespiteValidCheckpoint()
        external
    {
        _saveValidLocalCheckpoint();
        _provider.configure(VALID_PROOF_BLOCK_ID, bytes32(uint256(99)), 0);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _verify(_providerService, VALID_SIGNAL_PROOF);
    }

    function test_verifySignalReceived_RevertWhen_ProviderRevertsDespiteValidCheckpoint() external {
        _assertUnavailableProviderRejects(1);
    }

    function test_verifySignalReceived_RevertWhen_ProviderReturnsNoDataDespiteValidCheckpoint()
        external
    {
        _assertUnavailableProviderRejects(2);
    }

    function test_verifySignalReceived_RevertWhen_ProviderReturnsShortDataDespiteValidCheckpoint()
        external
    {
        _assertUnavailableProviderRejects(3);
    }

    function test_verifySignalReceived_RevertWhen_ProviderHasNoCodeDespiteValidCheckpoint()
        external
    {
        _saveValidLocalCheckpoint();
        vm.etch(address(_provider), hex"");
        vm.expectRevert();
        _verify(_providerService, VALID_SIGNAL_PROOF);
    }

    function test_proveSignalReceived_RevertWhen_ProviderReturnsZeroAndCannotPoisonCache()
        external
    {
        _saveValidLocalCheckpoint();
        _provider.configure(VALID_PROOF_BLOCK_ID, bytes32(0), 0);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _providerService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        _verify(_providerService, hex"");
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _verify(_providerService, _proof(VALID_PROOF_BLOCK_ID, bytes32(0)));
    }

    function test_proveSignalReceived_CachedEmptyProofBypassesUnavailableProvider() external {
        _providerService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        vm.etch(address(_provider), hex"5f5ffd");
        _verify(_providerService, hex"");
        assertEq(
            _providerService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex""),
            0
        );
    }

    function test_saveCheckpoint_LegacyAcceptsAnyHeightBeforeStart() external {
        _save(_legacyService, _legacy, type(uint48).max, VALID_PROOF_STATE_ROOT);
        assertEq(_legacyService.getCheckpoint(type(uint48).max).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_LegacyUsesHashRatherThanHeightToDetectStart() external {
        _inbox.configure(2, bytes32(0), false);
        _save(_legacyService, _legacy, 3, VALID_PROOF_STATE_ROOT);
        assertEq(_legacyService.getCheckpoint(3).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_LegacyAcceptsBelowAndExactStart() external {
        _inbox.configure(2, VALID_BLOCK_HASH, false);
        _save(_legacyService, _legacy, 1, VALID_PROOF_STATE_ROOT);
        _save(_legacyService, _legacy, 2, VALID_PROOF_STATE_ROOT);
        assertEq(_legacyService.getCheckpoint(1).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_legacyService.getCheckpoint(2).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_RevertWhen_LegacyAboveStart() external {
        _inbox.configure(2, VALID_BLOCK_HASH, false);
        vm.expectRevert(SignalService.SS_UNZEN_CHECKPOINT_ABOVE_START.selector);
        _save(_legacyService, _legacy, 3, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_RevertWhen_LegacyAboveZeroStartWithNonzeroHash() external {
        _inbox.configure(0, VALID_BLOCK_HASH, false);
        vm.expectRevert(SignalService.SS_UNZEN_CHECKPOINT_ABOVE_START.selector);
        _save(_legacyService, _legacy, 1, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_PrimaryBypassesUnavailableInbox() external {
        _inbox.configure(2, VALID_BLOCK_HASH, true);
        _save(_legacyService, address(_inbox), 3, VALID_PROOF_STATE_ROOT);
        assertEq(_legacyService.getCheckpoint(3).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_constructor_RevertWhen_LegacyEqualsPrimary() external {
        vm.expectRevert(SignalService.SS_INVALID_SYNCER_CONFIG.selector);
        new SignalService(
            address(_inbox), REMOTE_SIGNAL_SERVICE, address(0), address(0), address(_inbox)
        );
    }

    function test_constructor_RevertWhen_LegacyEnabledWithProvider() external {
        vm.expectRevert(SignalService.SS_INVALID_SYNCER_CONFIG.selector);
        new SignalService(
            address(_inbox), REMOTE_SIGNAL_SERVICE, address(0), address(_provider), _legacy
        );
    }

    function test_constructor_RevertWhen_InboxProxiesAreSwapped() external {
        vm.expectRevert(SignalService.SS_INVALID_SYNCER_CONFIG.selector);
        new SignalService(_legacy, REMOTE_SIGNAL_SERVICE, address(0), address(0), address(_inbox));
    }

    function test_constructor_RevertWhen_PrimaryIsImplementation() external {
        address implementation = _inbox.impl();
        vm.expectRevert(SignalService.SS_INVALID_SYNCER_CONFIG.selector);
        new SignalService(implementation, REMOTE_SIGNAL_SERVICE, address(0), address(0), _legacy);
    }

    function test_constructor_RevertWhen_LegacyIsImplementation() external {
        address implementation = EssentialContract(_legacy).impl();
        vm.expectRevert(SignalService.SS_INVALID_SYNCER_CONFIG.selector);
        new SignalService(
            address(_inbox), REMOTE_SIGNAL_SERVICE, address(0), address(0), implementation
        );
    }

    function test_saveCheckpoint_RevertWhen_UnknownCallerWithoutReadingInbox() external {
        _inbox.configure(2, VALID_BLOCK_HASH, true);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        _save(_legacyService, Alice, 1, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_RevertWhen_LegacyDisabled() external {
        SignalService service = _deploy(address(_inbox), address(0), address(0));
        _inbox.configure(2, VALID_BLOCK_HASH, true);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        _save(service, _legacy, 1, VALID_PROOF_STATE_ROOT);
        _save(service, address(_inbox), 3, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_RevertWhen_LegacyStartUnavailable() external {
        _inbox.configure(2, VALID_BLOCK_HASH, true);
        vm.expectRevert();
        _save(_legacyService, _legacy, 1, VALID_PROOF_STATE_ROOT);
    }

    function _deploy(
        address _syncer,
        address _rootProvider,
        address _unzen
    )
        private
        returns (SignalService)
    {
        address implementation = address(
            new SignalService(_syncer, REMOTE_SIGNAL_SERVICE, address(0), _rootProvider, _unzen)
        );
        return SignalService(
            address(
                new ERC1967Proxy(
                    implementation, abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
    }

    function _verify(SignalService _service, bytes memory _proofBytes) private view {
        _service.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _proofBytes);
    }

    function _saveValidLocalCheckpoint() private {
        _save(
            _providerService,
            AUTHORIZED_SYNCER,
            uint48(VALID_PROOF_BLOCK_ID),
            VALID_PROOF_STATE_ROOT
        );
    }

    function _assertUnavailableProviderRejects(uint8 _mode) private {
        _saveValidLocalCheckpoint();
        _provider.configure(VALID_PROOF_BLOCK_ID, VALID_PROOF_STATE_ROOT, _mode);
        vm.expectRevert();
        _verify(_providerService, VALID_SIGNAL_PROOF);
    }

    function _save(SignalService _service, address _caller, uint48 _height, bytes32 _root) private {
        vm.prank(_caller);
        _service.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: _height, blockHash: VALID_BLOCK_HASH, stateRoot: _root
            })
        );
    }

    function _proof(uint64 _id, bytes32 _root) private pure returns (bytes memory) {
        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].blockId = _id;
        proofs[0].rootHash = _root;
        return abi.encode(proofs);
    }
}
