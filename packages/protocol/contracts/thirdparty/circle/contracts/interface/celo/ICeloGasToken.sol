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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the Celo gas token standard for contracts
 * as defined at https://docs.celo.org/learn/add-gas-currency.
 */
interface ICeloGasToken is IERC20 {
    /**
     * @notice Reserve balance for making payments for gas in this FiatToken currency.
     * @param from The address from which to reserve balance.
     * @param value The amount of balance to reserve.
     * @dev This function is called by the Celo protocol when paying for transaction fees in this
     * currency. After the transaction is executed, unused gas is refunded to the sender and credited
     * to the various fee recipients via a call to `creditGasFees`. The events emitted by `creditGasFees`
     * reflect the *net* gas fee payments for the transaction.
     */
    function debitGasFees(address from, uint256 value) external;

    /**
     * @notice Credit balances of original payer and various fee recipients
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
