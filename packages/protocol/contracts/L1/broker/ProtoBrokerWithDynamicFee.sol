// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./ProtoBrokerWithStats.sol";

abstract contract ProtoBrokerWithDynamicFee is ProtoBrokerWithStats {
    using SafeCastUpgradeable for uint256;
    uint256[50] private __gap;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual override {
        ProtoBrokerWithStats._init(
            _addressManager,
            _gasPriceNow,
            _unsettledProverFeeThreshold
        );
    }

    function calculateActualFee(
        uint256, /*blockId*/
        uint256, /*uncleId*/
        address, /*prover*/
        uint128 gasPriceAtProposal,
        uint128 gasLimit,
        uint64 /*provingDelay*/
    ) internal virtual override returns (uint128) {
        return gasPriceAtProposal * (gasLimit + gasLimitBase());
    }
}
