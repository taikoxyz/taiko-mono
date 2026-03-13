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

/**
 * @dev Barebones interface of the fee currency adapter standard for
 * ERC-20 gas tokens that do not operate with 18 decimals. At a mini-
 * mum, an implementation must support balance queries, debiting, and
 * crediting to work with the Celo VM.
 */
interface IFiatTokenFeeAdapter {
    /**
     * @notice Return the balance of the address specified, but this balance
     * is scaled appropriately to the number of decimals on this adapter.
     * @dev The Celo VM calls balanceOf during its fee calculations on custom
     * currencies to ensure that the holder has enough; since the VM debits
     * and credits upscaled values, it needs to reference upscaled balances
     * as well. See
     * https://github.com/celo-org/celo-blockchain/blob/3808c45addf56cf547581599a1cb059bc4ae5089/core/state_transition.go#L321.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Reserve *adapted* balance for making payments for gas in this FiatToken currency.
     * @param from The address from which to reserve balance.
     * @param value The amount of balance to reserve.
     * @dev This function is called by the Celo protocol when paying for transaction fees in this
     * currency. After the transaction is executed, unused gas is refunded to the sender and credited
     * to the various fee recipients via a call to `creditGasFees`. The events emitted by `creditGasFees`
     * reflect the *net* gas fee payments for the transaction.
     */
    function debitGasFees(address from, uint256 value) external;

    /**
     * @notice Credit *adapted* balances of original payer and various fee recipients
     * after having made payments for gas in the form of this FiatToken currency.
     * @param from The original payer address from which balance was reserved via `debitGasFees`.
     * @param feeRecipient The main fee recipient address.
     * @param gatewayFeeRecipient Gateway address.
     * @param communityFund Celo Community Fund address.
     * @param refund Amount to be refunded by the VM to `from`.
     * @param tipTxFee Amount to distribute to `feeRecipient`.
     * @param gatewayFee Amount to distribute to `gatewayFeeRecipient`; this is deprecated and will always be 0.
     * @param baseTxFee Amount to distribute to `communityFund`.
     * @dev This function is called by the Celo protocol when paying for transaction fees in this
     * currency. After the transaction is executed, unused gas is refunded to the sender and credited
     * to the various fee recipients via a call to `creditGasFees`. The events emitted by `creditGasFees`
     * reflect the *net* gas fee payments for the transaction. As an invariant, the original debited amount
     * will always equal (refund + tipTxFee + gatewayFee + baseTxFee). Though the amount debited in debitGasFees
     * is always equal to (refund + tipTxFee + gatewayFee + baseTxFee), in practice, the gateway fee is never
     * used (0) and should ideally be ignored except in the function signature to optimize gas savings.
     */
    function creditGasFees(
        address from,
        address feeRecipient,
        address gatewayFeeRecipient,
        address communityFund,
        uint256 refund,
        uint256 tipTxFee,
        uint256 gatewayFee,
        uint256 baseTxFee
    ) external;
}
