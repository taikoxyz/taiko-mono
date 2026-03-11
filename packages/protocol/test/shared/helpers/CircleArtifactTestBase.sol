// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";

/// @title CircleArtifactTestBase
/// @notice Shared helpers for deploying Circle FiatToken artifacts in 0.8.x tests.
abstract contract CircleArtifactTestBase is CircleArtifactDeployer {
    address internal constant PROXY_ADMIN = 0x1000000000000000000000000000000000000001;
    address internal constant MASTER_MINTER = 0x2000000000000000000000000000000000000002;
    address internal constant PAUSER = 0x3000000000000000000000000000000000000003;
    address internal constant BLACKLISTER = 0x4000000000000000000000000000000000000004;
    address internal constant TOKEN_OWNER = 0x5000000000000000000000000000000000000005;

    /// @dev Returns the default deployment config used by the Circle USDC tests.
    function _testUSDCConfig() internal pure returns (FiatTokenDeploymentConfig memory config_) {
        config_ = FiatTokenDeploymentConfig({
            tokenName: "USD Coin",
            tokenSymbol: "USDC",
            tokenCurrency: "USD",
            tokenDecimals: 6,
            proxyAdmin: PROXY_ADMIN,
            masterMinter: MASTER_MINTER,
            pauser: PAUSER,
            blacklister: BLACKLISTER,
            owner: TOKEN_OWNER
        });
    }

    /// @dev Deploys a fresh Circle-compatible USDC implementation + proxy pair.
    function _deployTestUSDC() internal returns (address impl_, address proxy_) {
        return _deployFiatToken(_testUSDCConfig());
    }

    /// @dev Deploys an additional Circle-compatible USDC proxy against an existing implementation.
    function _deployTestUSDCProxy(address _implementation) internal returns (address proxy_) {
        proxy_ = _deployFiatTokenProxy(_implementation, _testUSDCConfig());
    }
}
