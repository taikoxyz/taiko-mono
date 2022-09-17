// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
interface ITokenVault {
    /**
     * @notice Transfers Ether to this vault and sends a message to the
     *         destination chain so the user can receive Ether.
     * @dev Ether are held by Bridges, not TokenVaults.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param maxProcessingFee @custom:see Bridge
     */
    function sendEther(
        uint256 destChainId,
        address to,
        uint256 gasLimit,
        uint256 maxProcessingFee,
        address refundAddress,
        string memory memo
    ) external payable;

    /**
     * @notice Transfers ERC20 tokens to this vault and sends a message to the
     *         destination chain so the user can receive the same amount of tokens
     *         by invoking the message call.
     * @param token The address of the token to be sent.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param refundAddress The fee refund address. If this address is address(0), extra
     *        fees will be refunded back to the `to` address.
     * @param amount The amount of token to be transferred.
     * @param maxProcessingFee @custom:see Bridge
     * @param gasLimit @custom:see Bridge
     */
    function sendERC20(
        uint256 destChainId,
        address to,
        address token,
        uint256 amount,
        uint256 gasLimit,
        uint256 maxProcessingFee,
        address refundAddress,
        string memory memo
    ) external payable;
}
