import type { Hash } from 'viem';

export const generateZeroHex = (length: number): Hash => {
  return ('0x' + '0'.repeat(length)) as Hash;
};
