/**
 * Copyright 2024 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.6.12;

import {
    IFiatTokenFeeAdapter
} from "../../interface/celo/IFiatTokenFeeAdapter.sol";
import { ICeloGasToken } from "../../interface/celo/ICeloGasToken.sol";
import { IDecimals } from "../../interface/celo/IDecimals.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

contract FiatTokenFeeAdapterV1 is IFiatTokenFeeAdapter {
    using SafeMath for uint256;

    ICeloGasToken public adaptedToken;

    uint8 internal _initializedVersion;
    uint8 public adapterDecimals;
    uint8 public tokenDecimals;
    uint256 public upscaleFactor;
    // This debited value matches the value stored on the
    // underlying token and is calculated by downscaling.
    uint256 internal _debitedValue = 0;

    modifier onlyCeloVm() virtual {
        require(
            msg.sender == address(0),
            "FiatTokenFeeAdapterV1: caller is not VM"
        );
        _;
    }

    function initializeV1(address _adaptedToken, uint8 _adapterDecimals)
        public
        virtual
    {
        // solhint-disable-next-line reason-string
        require(_initializedVersion == 0);

        tokenDecimals = IDecimals(_adaptedToken).decimals();
        require(
            tokenDecimals < _adapterDecimals,
            "FiatTokenFeeAdapterV1: Token decimals must be < adapter decimals"
        );
        require(
            // uint256 supports a max value of ~1.1579e77. Having the upscale
            // factor be 1e78 would overflow, but SafeMath does not implement
            // a `pow` function, so we must be careful here instead.
            _adapterDecimals - tokenDecimals < 78,
            "FiatTokenFeeAdapterV1: Digit difference too large"
        );
        upscaleFactor = uint256(10)**uint256(_adapterDecimals - tokenDecimals);

        adapterDecimals = _adapterDecimals;
        adaptedToken = ICeloGasToken(_adaptedToken);

        _initializedVersion = 1;
    }

    function balanceOf(address account)
        external
        override
        view
        returns (uint256)
    {
        return _upscale(adaptedToken.balanceOf(account));
    }

    function debitGasFees(address from, uint256 value)
        external
        override
        onlyCeloVm
    {
        require(
            _debitedValue == 0,
            "FiatTokenFeeAdapterV1: Must fully credit before debit"
        );
        uint256 valueScaled = _downscale(value);
        adaptedToken.debitGasFees(from, valueScaled);
        _debitedValue = valueScaled;
    }

    function creditGasFees(
        address refundRecipient,
        address feeRecipient,
        // solhint-disable-next-line no-unused-vars
        address gatewayFeeRecipient,
        address communityFund,
        uint256 refund,
        uint256 tipTxFee,
        // solhint-disable-next-line no-unused-vars
        uint256 gatewayFee,
        uint256 baseTxFee
    ) external override onlyCeloVm {
        if (_debitedValue == 0) {
            // When eth.estimateGas is called, this function is
            // called, but we don't want to credit anything, as
            // the edge case also violates the invariant. See
            // https://github.com/celo-org/celo-blockchain/blob/6388f0ec88fb7a2a82ee41b0e2c9cb7e2cff87e2/internal/ethapi/api.go#L1018-L1022.
            return;
        }

        uint256 refundScaled = _downscale(refund);
        uint256 tipTxFeeScaled = _downscale(tipTxFee);
        uint256 baseTxFeeScaled = _downscale(baseTxFee);
        uint256 creditValueScaled = refundScaled.add(tipTxFeeScaled).add(
            baseTxFeeScaled
        );

        require(
            creditValueScaled <= _debitedValue,
            "FiatTokenFeeAdapterV1: Cannot credit more than debited"
        );

        // When downscaling, data can be lost, leading to inaccurate sums.
        uint256 roundingError = _debitedValue.sub(creditValueScaled);
        if (roundingError > 0) {
            // In this case, allocate the remainder to the community fund (base fee).
            // Instead of allocating to the validator (tipTxFee), we do this to prevent
            // the risk of actors gaming the scaling system (even if the actual difference
            // is expected to be very small).
            baseTxFeeScaled = baseTxFeeScaled.add(roundingError);
        }

        adaptedToken.creditGasFees(
            refundRecipient,
            feeRecipient,
            address(0),
            communityFund,
            refundScaled,
            tipTxFeeScaled,
            0,
            baseTxFeeScaled
        );

        _debitedValue = 0;
    }

    /**
     * @notice Upscales a given value to logically have the same number of decimals as this adapter.
     * @param value The value to upscale.
     * @dev The caller is responsible for preconditions, as uint256 does not provide decimals.
     */
    function _upscale(uint256 value) internal view returns (uint256) {
        return value.mul(upscaleFactor);
    }

    /**
     * @notice Downscales a given value consistent with this adapter to its original factor.
     * @param value The value to downscale.
     * @dev The caller is responsible for preconditions, as uint256 does not provide decimals.
     * This downscaling will round down on the division operator.
     */
    function _downscale(uint256 value) internal view returns (uint256) {
        return value.div(upscaleFactor);
    }
}
