// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/tiers/LibTiers.sol";
import "src/layer1/team/airdrop/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/bridge/Bridge.sol";
import "test/shared/CommonTest.sol";

contract TaikoL1WithConfig is TaikoL1 {
    TaikoData.Config private __config;

    function initWithConfig(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash,
        bool _toPause,
        TaikoData.Config memory _config
    )
        external
        initializer
    {
        __Essential_init(_owner, _rollupResolver);
        LibUtils.init(state, _genesisBlockHash);
        if (_toPause) _pause();
        __config = _config;
    }

    function getConfig() public pure override returns (TaikoData.Config memory) {
        return __config;
    }
}

abstract contract Layer1Test is CommonTest {
    bytes32 internal GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");

    function deployTaikoL1(TaikoData.Config memory config) internal returns (TaikoL1 taikoL1) {
        taikoL1 = TaikoL1(
            deploy({
                name: "taiko",
                impl: address(new TaikoL1WithConfig()),
                data: abi.encodeCall(
                    TaikoL1WithConfig.initWithConfig,
                    (address(0), address(resolver), GENESIS_BLOCK_HASH, false, config)
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

    function deployGuardianProver() internal returns (GuardianProver) {
        return GuardianProver(
            deploy({
                name: "guardian_prover",
                impl: address(new GuardianProver()),
                data: abi.encodeCall(GuardianProver.init, (address(0), address(resolver)))
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
