import { getContract, type GetContractResult, getWalletClient, type WalletClient } from '@wagmi/core';

import { PUBLIC_L1_CHAIN_ID } from '$env/static/public';

import { mint } from './mint';
import { testERC20Tokens } from './tokens';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const BLLToken = testERC20Tokens[0];

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
