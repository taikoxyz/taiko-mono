// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/tiers/LibTiers.sol";
import "src/layer1/team/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/bridge/Bridge.sol";
import "test/shared/CommonTest.sol";

contract TaikoL1WithConfig is TaikoL1 {
    ITaikoData.ConfigV3 private __config;

    function initWithConfig(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash,
        ITaikoData.ConfigV3 memory _config
    )
        external
        initializer
    {
        __TaikoL1_init(_owner, _rollupResolver, _genesisBlockHash);
        __config = _config;
    }

    function getConfigV3() public view override returns (ITaikoData.ConfigV3 memory) {
        return __config;
    }
}

abstract contract Layer1Test is CommonTest {
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
