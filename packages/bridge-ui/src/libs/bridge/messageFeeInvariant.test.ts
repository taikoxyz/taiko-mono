import { feeForGasLimit } from './messageFeeInvariant';

/**
 * Bridge.sol:200 rejects a message whose gasLimit is 0 while its fee is not:
 *   if (_message.gasLimit == 0) { if (_message.fee != 0) revert B_INVALID_FEE();
 * The UI could reach that pairing whenever the zero-gas-limit choice outlived the fee
 * selection made alongside it, producing a revert only at send time.
 */
describe('feeForGasLimit', () => {
  it('drops the fee when the gas limit is zero', () => {
    expect(feeForGasLimit(0, BigInt('130220640000000'))).toBe(BigInt(0));
  });

  it('keeps the fee when the gas limit is non-zero', () => {
    const fee = BigInt('130220640000000');
    expect(feeForGasLimit(1_250_000, fee)).toBe(fee);
  });

  it('leaves an already-zero fee alone in both directions', () => {
    expect(feeForGasLimit(0, BigInt(0))).toBe(BigInt(0));
    expect(feeForGasLimit(500_000, BigInt(0))).toBe(BigInt(0));
  });

  it('never returns a combination the contract rejects', () => {
    const combinations: Array<[number, bigint]> = [
      [0, BigInt(0)],
      [0, BigInt(1)],
      [0, BigInt('130220640000000')],
      [1, BigInt(0)],
      [1, BigInt(1)],
      [750_000, BigInt('130220640000000')],
    ];
    for (const [gasLimit, fee] of combinations) {
      const sent = feeForGasLimit(gasLimit, fee);
      // The exact invariant from Bridge.sol
      expect(gasLimit === 0 && sent !== BigInt(0)).toBe(false);
    }
  });
});
