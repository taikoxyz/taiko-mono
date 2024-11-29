// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/team/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/bridge/Bridge.sol";
import "test/shared/CommonTest.sol";

contract TaikoWithConfig is TaikoL1 {
    ITaikoL1.ConfigV3 private __config;

    function initWithConfig(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash,
        ITaikoL1.ConfigV3 memory _config
    )
        external
        initializer
    {
        __Taiko_init(_owner, _rollupResolver, _genesisBlockHash);
        __config = _config;
    }

    function getConfigV3() public view override returns (ITaikoL1.ConfigV3 memory) {
        return __config;
    }

    function _blobhash(uint256) internal pure override returns (bytes32) {
        return keccak256("BLOB");
    }

    function _verifyProof(
        IVerifier.Context[] memory _ctxs,
        bytes calldata _proof
    )
        internal
        override
    { }
}

abstract contract Layer1Test is CommonTest {
    function deployTaikoL1(
        bytes32 _genesisBlockHash,
        ITaikoL1.ConfigV3 memory _config
    )
        internal
        returns (TaikoL1)
    {
        return TaikoL1(
            deploy({
                name: "taiko",
                impl: address(new TaikoWithConfig()),
                data: abi.encodeCall(
                    TaikoWithConfig.initWithConfig,
                    (address(0), address(resolver), _genesisBlockHash, _config)
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

    function deploySgxVerifier() internal returns (SgxVerifier) {
        return SgxVerifier(
            deploy({
                name: "tier_sgx",
                impl: address(new SgxVerifier()),
                data: abi.encodeCall(SgxVerifier.init, (address(0), address(resolver)))
            })
        );
    }
}
