import { getContract, type GetContractResult, getWalletClient, type WalletClient } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { mint } from './mint';
import { type Token, TokenType } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const PUBLIC_L1_CHAIN_ID = 11155111;
const PUBLIC_L2_CHAIN_ID = 1670005;

const L1_TOKEN_ADDRESS = '0x123456';

const BLLToken: Token = {
  name: 'MockToken',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: L1_TOKEN_ADDRESS,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  symbol: 'MOCK',
  decimals: 18,
  type: TokenType.ERC20,
};

const mockWalletClient = {
  account: { address: '0x123' },
} as unknown as WalletClient;

const mockTokenContract = {
  write: {
    mint: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], WalletClient>;

describe('mint', () => {
  it('should return a tx hash when minting', async () => {
    vi.mocked(getWalletClient).mockResolvedValue(mockWalletClient);
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
    vi.mocked(mockTokenContract.write.mint).mockResolvedValue('0x123456');

    await expect(mint(BLLToken, Number(PUBLIC_L1_CHAIN_ID))).resolves.toEqual('0x123456');
    expect(mockTokenContract.write.mint).toHaveBeenCalledWith([mockWalletClient.account.address]);
    expect(getContract).toHaveBeenCalledWith({
      walletClient: mockWalletClient,
      abi: expect.anything(),
      address: BLLToken.addresses[PUBLIC_L1_CHAIN_ID],
    });
  });
});
