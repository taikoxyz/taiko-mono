import { bridgeTxKey, isSameBridgeTx } from './bridgeTxIdentity';
import type { BridgeTransaction } from './types';

const tx = (srcTxHash: string, msgHash?: string) => ({ srcTxHash, msgHash }) as unknown as BridgeTransaction;

describe('bridgeTxKey', () => {
  it('identifies a message by its hash', () => {
    expect(bridgeTxKey(tx('0xtx', '0xmsg'))).toBe('0xmsg');
  });

  it('gives two messages from one transaction different keys', () => {
    // A keyed {#each} over these threw on the duplicate key, and the dedupe dropped the
    // second message outright
    expect(bridgeTxKey(tx('0xtx', '0xa'))).not.toBe(bridgeTxKey(tx('0xtx', '0xb')));
  });

  it('falls back to the transaction hash before the receipt has been read', () => {
    expect(bridgeTxKey(tx('0xtx'))).toBe('0xtx');
  });
});

describe('isSameBridgeTx', () => {
  it('matches on the message hash', () => {
    expect(isSameBridgeTx(tx('0xone', '0xmsg'), tx('0xtwo', '0xmsg'))).toBe(true);
  });

  it('separates two messages that share a transaction', () => {
    expect(isSameBridgeTx(tx('0xtx', '0xa'), tx('0xtx', '0xb'))).toBe(false);
  });

  it('falls back to the transaction hash when either side has no message hash', () => {
    expect(isSameBridgeTx(tx('0xtx'), tx('0xtx', '0xmsg'))).toBe(true);
    expect(isSameBridgeTx(tx('0xone'), tx('0xtwo', '0xmsg'))).toBe(false);
  });
});
