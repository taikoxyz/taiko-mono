/**
 * The faucet prices the mint on the chain the token is minted on, and passes that chain in.
 * Resolving the client without it read whichever chain the wagmi config considered current
 * instead - every other read in this package names its chain, and this was one of the two
 * that did not.
 */
import { getPublicClient } from '@wagmi/core';
import { getContract } from 'viem';

import { checkMintable } from './checkMintable';

vi.mock('@wagmi/core');
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: vi.fn(),
}));
vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: vi.fn().mockResolvedValue({ account: { address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' } }),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));

const CHAIN_ID = 167001;
const token = { addresses: { [CHAIN_ID]: '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE' } } as never;

beforeEach(() => {
  vi.mocked(getContract).mockReturnValue({
    read: { minters: vi.fn().mockResolvedValue(false) },
    estimateGas: { mint: vi.fn().mockResolvedValue(BigInt(21_000)) },
  } as never);
  vi.mocked(getPublicClient).mockReturnValue({
    getGasPrice: vi.fn().mockResolvedValue(BigInt(1)),
    getBalance: vi.fn().mockResolvedValue(BigInt(1_000_000)),
  } as never);
});

describe('checkMintable', () => {
  it('prices the mint on the chain the token is minted on, not on the connected chain', async () => {
    await checkMintable(token, CHAIN_ID);

    expect(getPublicClient).toHaveBeenCalledWith(expect.anything(), { chainId: CHAIN_ID });
  });
});
