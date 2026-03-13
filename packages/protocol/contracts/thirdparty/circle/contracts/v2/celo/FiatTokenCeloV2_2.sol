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

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { FiatTokenV2_2 } from "../FiatTokenV2_2.sol";
import { ICeloGasToken } from "../../interface/celo/ICeloGasToken.sol";

contract FiatTokenCeloV2_2 is FiatTokenV2_2, ICeloGasToken {
    using SafeMath for uint256;
    event FeeCallerChanged(address indexed newAddress);

    /**
     * @notice Constant containing the storage slot indicating the current fee caller of
     * `debitGasFees` and `creditGasFees`. Only the fee caller should be able to represent
     * this FiatToken during a gas lifecycle. This slot starts off indicating address(0)
     * as the allowed fee caller, as the storage slot is empty.
     * @dev This constant is the Keccak-256 hash of "com.circle.fiattoken.celo.feecaller" and is
     * validated in the contract constructor. It does not occupy any storage slots, since
     * constants are embedded in the bytecode of a smart contract. This is intentionally done
     * so that the Celo variant of FiatToken can accommodate new state variables that may be
     * added in future FiatToken versions.
     */
    bytes32
        private constant FEE_CALLER_SLOT = 0xdca914aef3e4e19727959ebb1e70b58822e2c7b796d303902adc19513fcb4af5;

    /**
     * @notice Returns the current fee caller address allowed on `debitGasFees` and `creditGasFees`.
     * @dev Though Solidity generates implicit viewers/getters on contract state, because we
     * store the fee caller in a custom Keccak256 slot instead of a standard declaration, we
     * need an explicit getter for that slot.
     */
    function feeCaller() public view returns (address value) {
        assembly {
            value := sload(FEE_CALLER_SLOT)
        }
    }

    modifier onlyFeeCaller() virtual {
        require(
            msg.sender == feeCaller(),
            "FiatTokenCeloV2_2: caller is not the fee caller"
        );
        _;
    }

    /**
     * @notice Updates the fee caller address.
     * @param _newFeeCaller The address of the new pauser.
     */
    function updateFeeCaller(address _newFeeCaller) external onlyOwner {
        assembly {
            sstore(FEE_CALLER_SLOT, _newFeeCaller)
        }
        emit FeeCallerChanged(_newFeeCaller);
    }

    /**
     * @notice Constant containing the storage slot indicating the debited value currently
     * reserved for a transaction's gas paid in this token. This value also serves as a flag
     * indicating whether a debit is ongoing. Before and after every unique transaction on
     * the network, this slot should store a value of zero.
     * @dev This constant is the Keccak-256 hash of "com.circle.fiattoken.celo.debit" and is
     * validated in the contract constructor. It does not occupy any storage slots, since
     * constants are embedded in the bytecode of a smart contract. This is intentionally done
     * so that the Celo variant of FiatToken can accommodate new state variables that may be
     * added in future FiatToken versions.
     */
    bytes32
        private constant DEBITED_VALUE_SLOT = 0xd90dccaa76fe7208f2f477143b6adabfeb5d4a5136982894dfc51177fa8eda28;

    function _debitedValue() internal view returns (uint256 value) {
        assembly {
            value := sload(DEBITED_VALUE_SLOT)
        }
    }

    constructor() public {
        assert(
            DEBITED_VALUE_SLOT == keccak256("com.circle.fiattoken.celo.debit")
        );
        assert(
            FEE_CALLER_SLOT == keccak256("com.circle.fiattoken.celo.feecaller")
        );
    }

    function debitGasFees(address from, uint256 value)
        external
        override
        onlyFeeCaller
        whenNotPaused
        notBlacklisted(from)
    {
        require(
            _debitedValue() == 0,
            "FiatTokenCeloV2_2: Must fully credit before debit"
        );
        require(from != address(0), "ERC20: transfer from the zero address");

        _transferReservedGas(from, address(0), value);
        assembly {
            sstore(DEBITED_VALUE_SLOT, value)
        }
    }

    function creditGasFees(
        address from,
        address feeRecipient,
        // solhint-disable-next-line no-unused-vars
        address gatewayFeeRecipient,
        address communityFund,
        uint256 refund,
        uint256 tipTxFee,
        // solhint-disable-next-line no-unused-vars
        uint256 gatewayFee,
        uint256 baseTxFee
    )
        external
        override
        onlyFeeCaller
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(feeRecipient)
        notBlacklisted(communityFund)
    {
        uint256 creditValue = refund.add(tipTxFee).add(baseTxFee);

        // Because the Celo VM follows 1) debit, 2) main execution, and
        // 3) credit atomically as part of a single on-chain transaction,
        // we must ensure that the credit step attempts to credit pre-
        // cisely what was debited prior.
        require(
            _debitedValue() == creditValue,
            "FiatTokenCeloV2_2: Either no debit or mismatched debit"
        );

        // The credit portion of the gas lifecycle can be summarized
        // by the three Transfer events emitted here:
        // 0x0 to debitee,
        _transferReservedGas(address(0), from, creditValue);
        // debitee to validator,
        _transfer(from, feeRecipient, tipTxFee);
        // and debitee to Celo community fund.
        _transfer(from, communityFund, baseTxFee);

        // Mark the end of this debit-credit cycle.
        assembly {
            sstore(DEBITED_VALUE_SLOT, 0)
        }
    }

    /**
     * @dev This function differs from the standard _transfer function in that
     * it does *not* check against the from and the to addresses being 0x0.
     * This is needed for the usage of 0x0 as the gas intermediary.
     * Further, this function validates that _value is > 0. For a comparison,
     * see the FiatTokenV1#_transfer function.
     */
    function _transferReservedGas(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        require(_value > 0, "FiatTokenCeloV2_2: Must reserve > 0 gas");
        require(
            _value <= _balanceOf(_from),
            "ERC20: transfer amount exceeds balance"
        );

        _setBalance(_from, _balanceOf(_from).sub(_value));
        _setBalance(_to, _balanceOf(_to).add(_value));
        emit Transfer(_from, _to, _value);
    }
}
