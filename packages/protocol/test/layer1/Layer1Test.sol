// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/forced-inclusion/ForcedInclusionInbox.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/team/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/bridge/Bridge.sol";
import "test/shared/CommonTest.sol";

contract ConfigurableInbox is TaikoInbox {
    ITaikoInbox.Config private __config;

    constructor(address _resolver) TaikoInbox(_resolver) { }

    function initWithConfig(
        address _owner,
        bytes32 _genesisBlockHash,
        ITaikoInbox.Config memory _config
    )
        external
        initializer
    {
        __Taiko_init(_owner, _genesisBlockHash);
        __config = _config;
    }

    function pacayaConfig() public view override returns (ITaikoInbox.Config memory) {
        return __config;
    }

    function _calculateTxsHash(
        bytes32 _txListHash,
        BlobParams memory _blobParams
    )
        internal
        pure
        override
        returns (bytes32, bytes32[] memory)
    {
        return (_txListHash, new bytes32[](_blobParams.numBlobs));
    }
}

abstract contract Layer1Test is CommonTest {
    function deployInbox(
        bytes32 _genesisBlockHash,
        ITaikoInbox.Config memory _config
    )
        internal
        returns (TaikoInbox)
    {
        return TaikoInbox(
            deploy({
                name: "taiko",
                impl: address(new ConfigurableInbox(address(resolver))),
                data: abi.encodeCall(
                    ConfigurableInbox.initWithConfig, (address(0), _genesisBlockHash, _config)
                )
            })
        );
    }

    function deployForcedInclusionInbox() internal returns (ForcedInclusionInbox) {
        return ForcedInclusionInbox(
            deploy({
                name: "taiko_forced_inclusion_inbox",
                impl: address(new ForcedInclusionInbox(address(resolver))),
                data: abi.encodeCall(ForcedInclusionInbox.init, (address(0)))
            })
        );
    }

    function deployForcedInclusionStore(
        uint256 inclusionDelay,
        uint64 feeInGwei,
        address owner
    )
        internal
        returns (ForcedInclusionStore)
    {
        return ForcedInclusionStore(
            deploy({
                name: "forced_inclusion_store",
                impl: address(new ForcedInclusionStore(address(resolver), inclusionDelay, feeInGwei)),
                data: abi.encodeCall(ForcedInclusionStore.init, (owner))
            })
        );
    }

    function deployBondToken() internal returns (TaikoToken) {
        return TaikoToken(
            deploy({
                name: "bond_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(TaikoToken.init, (address(0), address(this)))
            })
        );
    }

    function deploySgxVerifier() internal returns (SgxVerifier) {
        return SgxVerifier(
            deploy({
                name: "tier_sgx",
                impl: address(new SgxVerifier(address(resolver), taikoChainId)),
                data: abi.encodeCall(SgxVerifier.init, (address(0)))
            })
        );
    }
}
