/**
 * The bridge rejects a message that carries a fee it can never pay out: with `gasLimit == 0`
 * only the destination owner can process the message, so a non-zero fee has no recipient.
 * Bridge.sol enforces it directly:
 *
 *     if (_message.gasLimit == 0) {
 *         if (_message.fee != 0) revert B_INVALID_FEE();
 *
 * The UI can reach that combination whenever the zero-gas-limit option outlives the fee
 * selection that accompanied it, so the pairing is normalised here rather than left to each
 * caller. A zero gas limit is a deliberate choice by the user; the fee is the part that
 * cannot survive it.
 *
 * @param gasLimit The gas limit about to be put on the message
 * @param fee The processing fee about to be put on the message
 * @return fee_ The fee that may actually be sent alongside that gas limit
 */
export function feeForGasLimit(gasLimit: number, fee: bigint): bigint {
  return gasLimit === 0 ? BigInt(0) : fee;
}
