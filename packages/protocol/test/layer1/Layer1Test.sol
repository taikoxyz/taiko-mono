// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/TaikoSgxVerifier.sol";
import "src/layer1/verifiers/TaikoSP1Verifier.sol";
import "src/layer1/verifiers/TaikoRisc0Verifier.sol";
import "src/layer1/team/ERC20Airdrop.sol";
import "src/shared/bridge/Bridge.sol";
import "test/shared/CommonTest.sol";

contract ConfigurableInbox is TaikoInbox {
    ITaikoInbox.Config private __config;

    constructor(
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService)
    { }

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

    function _getConfig() internal view override returns (ITaikoInbox.Config memory) {
        return __config;
    }

    // Helper to reach any arbitrary fork activation configs for tests.
    function setConfig(ITaikoInbox.Config memory _NewConfig) external {
        __config = _NewConfig;
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
        address _verifier,
        address _bondToken,
        address _signalService,
        ITaikoInbox.Config memory _config
    )
        internal
        returns (TaikoInbox)
    {
        return TaikoInbox(
            deploy({
                name: "taiko",
                impl: address(new ConfigurableInbox(address(0), _verifier, _bondToken, _signalService)),
                data: abi.encodeCall(
                    ConfigurableInbox.initWithConfig, (address(0), _genesisBlockHash, _config)
                )
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
}
